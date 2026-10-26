import Foundation
import StoreKit
import OSLog

/// StoreKit 1 purchases for the diamond packages. A transaction is finished only after its diamonds are saved.
@MainActor
final class StoreKit1Purchasing: NSObject, SKPaymentTransactionObserver {
    var onChange: ((WalletLedger, [String: String]) -> Void)?

    var onCatalogChange: ((StoreCatalogStatus) -> Void)?
    private(set) var catalog = StoreCatalogStatus()
    private let productsFetcher: StoreProductFetching
    private let productRequestTimeout: TimeInterval
    private var productTimeout: Task<Void, Never>?
    private var sessionGeneration = 0
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.toti.music", category: "InAppPurchase")
    private var ledger = WalletLedger.empty
    private var products: [String: SKProduct] = [:]
    private var prices: [String: String] = [:]
    private var productWaiters: [CheckedContinuation<Void, Never>] = []
    private var productRequestInFlight = false
    private var productRequestGeneration = 0
    private var persist: ((WalletLedger) async -> Bool)?
    private var observing = false
    private var acceptingPurchases = false
    private var queueDelivered = false
    private var expected: [String: Int] = [:]
    private var waiters: [String: [PurchaseWait]] = [:]
    private var preexistingObjects: Set<ObjectIdentifier> = []
    private var preexistingIDs: Set<String> = []
    // Weak identities cannot mistake a recycled memory address for an old transaction.
    private let finishedObjects = NSHashTable<SKPaymentTransaction>(options: [.weakMemory, .objectPointerPersonality])
    private var finishing: [ObjectIdentifier: FinishedPurchase] = [:]
    private var tail: Task<Void, Never>?

    init(productsFetcher: StoreProductFetching? = nil, productRequestTimeout: TimeInterval = 20) {
        self.productsFetcher = productsFetcher ?? TotiStoreProductFetcher()
        self.productRequestTimeout = max(0.01, productRequestTimeout)
        super.init()
    }

    var hasUnfinishedTransactions: Bool { !SKPaymentQueue.default().transactions.isEmpty }

    var diagnostics: String {
        let bundle = Bundle.main
        return [
            "Bundle: \(bundle.bundleIdentifier ?? "unknown")",
            "Version: \(bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") ?? "unknown")",
            "Payments allowed: \(SKPaymentQueue.canMakePayments())",
            "Catalog: \(catalog.phase.rawValue)",
            "Requested: \(catalog.requestedIDs.joined(separator: ", "))",
            "Returned: \(catalog.returnedIDs.joined(separator: ", "))",
            "Invalid: \(catalog.invalidIDs.joined(separator: ", "))",
            "Error: \(catalog.errorSummary ?? "none")"
        ].joined(separator: "\n")
    }

    func adopt(_ ledger: WalletLedger) {
        self.ledger = ledger
        publish()
    }

    func setPersist(_ persist: @escaping (WalletLedger) async -> Bool) {
        self.persist = persist
    }

    func start() async {
        guard persist != nil else { return }
        guard !observing else {
            acceptingPurchases = true
            reloadProductsIfNeeded()
            return
        }
        sessionGeneration += 1
        let generation = sessionGeneration
        queueDelivered = false
        let unfinished = SKPaymentQueue.default().transactions
        for transaction in unfinished {
            rememberPreexisting(transaction)
        }
        observing = true
        acceptingPurchases = false
        SKPaymentQueue.default().add(self)
        // Reattaching an observer need not redeliver transactions already seen in this process.
        // Replay the queue snapshot too; persisted transaction IDs make delivery idempotent.
        enqueue(unfinished)
        for _ in 0..<10 { await Task.yield() }
        await drain()
        guard observing, sessionGeneration == generation else { return }
        acceptingPurchases = true
        beginProductRequest()
    }

    func reloadProductsIfNeeded() {
        guard acceptingPurchases, products.count < WalletCatalog.productIDs.count else { return }
        beginProductRequest()
    }

    func retryProducts() {
        guard acceptingPurchases else { return }
        beginProductRequest()
    }

    func stop() async {
        acceptingPurchases = false
        sessionGeneration += 1
        invalidateProductRequest()
        settleAllWaiting(message: "The wallet was closed. Any completed payment will be delivered when it reopens.")
        finishing.removeAll()
        products = [:]
        prices = [:]
        catalog.phase = .idle
        publishCatalog()
        publish()
        if observing {
            SKPaymentQueue.default().remove(self)
            observing = false
        }
        await drain()
    }

    func clearMemory() {
        ledger = .empty
        settleAllWaiting(message: "The wallet was closed. Check your purchase history if a payment was completed.")
        publish()
    }

    /// Spends diamonds for a gift on this device. Returns an English message when nothing was spent.
    func spend(_ gift: MusicGift, quantity: Int) async -> String? {
        guard (1...99).contains(quantity), gift.diamonds > 0 else {
            return "Please check the quantity and try again."
        }
        let (cost, overflow) = gift.diamonds.multipliedReportingOverflow(by: quantity)
        guard !overflow, cost > 0 else { return "Please check the quantity and try again." }
        guard ledger.diamonds >= cost else { return "Not enough diamonds. No diamonds were spent." }
        var next = ledger
        next.diamonds -= cost
        let countText = quantity.formatted(.number.locale(Locale(identifier: "en_US")))
        let costText = cost.formatted(.number.locale(Locale(identifier: "en_US")))
        next.activity.insert(
            WalletActivity(
                id: UUID().uuidString,
                title: "Sent \(countText) × \(gift.name) · \(costText) diamonds",
                currency: .diamonds, amount: cost, date: Date(), kind: "gift"
            ),
            at: 0
        )
        if next.activity.count > 40 { next.activity = Array(next.activity.prefix(40)) }
        guard next.isValid, let persist, await persist(next) else {
            return "Gift not sent. No diamonds were spent."
        }
        ledger = next
        publish()
        return nil
    }

    func purchase(_ package: WalletPackage) async -> String? {
        guard !package.storeProductID.isEmpty else {
            return "Purchases are not available yet. You have not been charged."
        }
        guard acceptingPurchases else { return "Please wait for the current request to finish." }
        guard SKPaymentQueue.canMakePayments() else {
            return "Purchases are turned off in Settings. You have not been charged."
        }
        let generation = sessionGeneration
        let product = await resolveProduct(package.storeProductID)
        guard acceptingPurchases, generation == sessionGeneration else {
            return "The wallet was closed before the purchase started. Please reopen it and try again."
        }
        guard let product else { return "This package is not available. You have not been charged." }
        guard expected.values.allSatisfy({ $0 == 0 }),
              !SKPaymentQueue.default().transactions.contains(where: { $0.payment.productIdentifier == package.storeProductID }) else {
            return "A purchase is still being processed. Please wait for it to finish."
        }
        let wait = PurchaseWait()
        expected[package.storeProductID, default: 0] += 1
        waiters[package.storeProductID, default: []].append(wait)
        SKPaymentQueue.default().add(SKPayment(product: product))
        return await withCheckedContinuation { continuation in
            if wait.settled {
                continuation.resume(returning: wait.message)
            } else {
                wait.continuation = continuation
            }
        }
    }

    private func resolveProduct(_ productID: String) async -> SKProduct? {
        if let product = products[productID] { return product }
        if !productRequestInFlight { beginProductRequest() }
        if productRequestInFlight {
            await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                productWaiters.append(continuation)
            }
        }
        return products[productID]
    }

    /// Coalesces requests and accepts exactly one result from the active request generation.
    private func beginProductRequest() {
        guard acceptingPurchases, !productRequestInFlight else { return }
        let identifiers = WalletCatalog.productIDs
        guard !identifiers.isEmpty else {
            catalog.phase = .unavailable
            publishCatalog()
            return
        }
        productRequestInFlight = true
        productRequestGeneration += 1
        let generation = productRequestGeneration
        catalog.phase = .loading
        catalog.requestedIDs = identifiers.sorted()
        catalog.errorSummary = nil
        publishCatalog()
        productsFetcher.start(identifiers) { [weak self] result in
            guard let self, self.productRequestInFlight, self.productRequestGeneration == generation else { return }
            self.productTimeout?.cancel()
            self.productTimeout = nil
            self.productRequestInFlight = false
            switch result {
            case .success(let response): self.apply(response.products, invalid: response.invalidProductIDs)
            case .failure(let error):
                self.catalog.phase = .failed
                self.catalog.errorSummary = storeErrorSummary(error)
                self.publishCatalog()
            }
            self.resumeProductWaiters()
        }
        guard productRequestInFlight else { return }
        let nanoseconds = UInt64(productRequestTimeout * 1_000_000_000)
        productTimeout = Task { @MainActor [weak self] in
            do { try await Task.sleep(nanoseconds: nanoseconds) } catch { return }
            guard let self, self.productRequestGeneration == generation, self.productRequestInFlight else { return }
            self.invalidateProductRequest()
            self.catalog.phase = .timedOut
            self.catalog.errorSummary = "StoreCatalogTimeout(1)"
            self.publishCatalog()
        }
    }

    private func invalidateProductRequest() {
        productRequestGeneration += 1
        productTimeout?.cancel()
        productTimeout = nil
        productsFetcher.cancel()
        productRequestInFlight = false
        resumeProductWaiters()
    }

    private func apply(_ loaded: [SKProduct], invalid: [String]) {
        let rejected = Set(invalid)
        var nextProducts: [String: SKProduct] = [:]
        var nextPrices: [String: String] = [:]
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        for product in loaded {
            guard !rejected.contains(product.productIdentifier),
                  WalletCatalog.package(forProductID: product.productIdentifier) != nil else { continue }
            formatter.locale = product.priceLocale
            guard let price = formatter.string(from: product.price) else { continue }
            nextProducts[product.productIdentifier] = product
            nextPrices[product.productIdentifier] = price
        }
        products = nextProducts
        prices = nextPrices
        catalog.returnedIDs = products.keys.sorted()
        catalog.invalidIDs = invalid.sorted()
        catalog.phase = products.isEmpty ? .unavailable : (products.count == WalletCatalog.productIDs.count ? .ready : .partial)
        catalog.errorSummary = nil
        publishCatalog()
        publish()
    }

    private func publishCatalog() {
        onCatalogChange?(catalog)
        logger.info("Catalog \(self.catalog.phase.rawValue, privacy: .public); returned=\(self.catalog.returnedIDs.joined(separator: ","), privacy: .public); invalid=\(self.catalog.invalidIDs.joined(separator: ","), privacy: .public); error=\(self.catalog.errorSummary ?? "none", privacy: .public)")
    }

    private func resumeProductWaiters() {
        let waiters = productWaiters
        productWaiters.removeAll()
        for waiter in waiters { waiter.resume() }
    }

    private func publish() {
        onChange?(ledger, prices)
    }

    private func enqueue(_ transactions: [SKPaymentTransaction]) {
        let previous = tail
        let next = Task { @MainActor in
            await previous?.value
            for transaction in transactions {
                await self.handle(transaction)
            }
        }
        tail = next
    }

    private func handle(_ transaction: SKPaymentTransaction) async {
        if finishedObjects.contains(transaction) { return }
        let productID = transaction.payment.productIdentifier
        switch transaction.transactionState {
        case .purchasing:
            return
        case .deferred:
            rememberPreexisting(transaction)
            resumeWaiting(
                productID,
                message: "This purchase is waiting for approval. Diamonds are added when it is approved."
            )
        case .failed:
            finish(transaction, message: failureMessage(transaction.error))
        case .purchased, .restored:
            guard WalletCatalog.package(forProductID: productID) != nil else {
                resumeWaiting(productID, message: "A completed purchase uses an unrecognized product. Please contact support with your App Store purchase history.")
                return
            }
            switch await credit(transaction) {
            case .savedNew:
                finish(transaction, message: nil)
            case .alreadySaved:
                finish(transaction, message: nil)
            case .notSaved:
                rememberPreexisting(transaction)
                resumeWaiting(
                    productID,
                    message: "Diamonds could not be saved on this device. If you were charged, they will be added when you open the app again."
                )
            }
        default:
            return
        }
    }

    private func drain() async {
        var drained: Task<Void, Never>?
        while let next = tail, next != drained {
            drained = next
            await next.value
        }
    }

    /// Credits one catalog consumable at most once.
    private func credit(_ transaction: SKPaymentTransaction) async -> CreditOutcome {
        let productID = transaction.payment.productIdentifier
        guard let package = WalletCatalog.package(forProductID: productID) else { return .notSaved }
        let identifiers = transactionIdentifiers(transaction)
        guard !identifiers.isEmpty else { return .notSaved }
        if identifiers.contains(where: { ledger.creditedTransactionIDs.contains($0) }) {
            preexistingIDs.formUnion(identifiers)
            guard let persist, await persist(ledger) else { return .notSaved }
            return .alreadySaved
        }
        let quantity = transaction.payment.quantity
        let (total, overflow) = package.amount.multipliedReportingOverflow(by: quantity)
        let (balance, balanceOverflow) = ledger.diamonds.addingReportingOverflow(total)
        guard quantity > 0, package.amount > 0, !overflow, !balanceOverflow, balance >= ledger.diamonds else {
            return .notSaved
        }
        var next = ledger
        next.diamonds = balance
        let amountText = total.formatted(.number.locale(Locale(identifier: "en_US")))
        next.activity.insert(
            WalletActivity(
                id: identifiers[0], title: "Added \(amountText) diamonds",
                currency: .diamonds, amount: total, date: transaction.transactionDate ?? Date()
            ),
            at: 0
        )
        if next.activity.count > 40 { next.activity = Array(next.activity.prefix(40)) }
        for identifier in identifiers where !next.creditedTransactionIDs.contains(identifier) {
            next.creditedTransactionIDs.append(identifier)
        }
        guard next.isValid, let persist, await persist(next) else { return .notSaved }
        preexistingIDs.formUnion(identifiers)
        ledger = next
        publish()
        return .savedNew
    }

    private func finish(_ transaction: SKPaymentTransaction, message: String?) {
        finishedObjects.add(transaction)
        forgetPreexisting(transaction)
        if expected[transaction.payment.productIdentifier, default: 0] > 0 {
            finishing[ObjectIdentifier(transaction)] = FinishedPurchase(transaction: transaction, message: message)
        }
        SKPaymentQueue.default().finishTransaction(transaction)
    }

    private func settleAllWaiting(message: String) {
        let pending = waiters
        waiters = [:]
        expected = [:]
        for list in pending.values {
            for wait in list { settle(wait, message: message) }
        }
    }

    nonisolated func paymentQueue(_ queue: SKPaymentQueue, removedTransactions transactions: [SKPaymentTransaction]) {
        Task { @MainActor in
            for transaction in transactions {
                if let completed = self.finishing.removeValue(forKey: ObjectIdentifier(transaction)) {
                    // A second purchase of the same consumable must wait until StoreKit removes the first.
                    self.resumeWaiting(completed.transaction.payment.productIdentifier, message: completed.message)
                }
            }
        }
    }

    private func resumeWaiting(_ productID: String, message: String?) {
        guard let count = expected[productID], count > 0 else { return }
        expected[productID] = count == 1 ? nil : count - 1
        guard var queue = waiters[productID], !queue.isEmpty else { return }
        let wait = queue.removeFirst()
        waiters[productID] = queue
        settle(wait, message: message)
    }

    private func settle(_ wait: PurchaseWait, message: String?) {
        guard !wait.settled else { return }
        wait.settled = true
        wait.message = message
        if let continuation = wait.continuation {
            wait.continuation = nil
            continuation.resume(returning: message)
        }
    }

    private func failureMessage(_ error: Error?) -> String {
        guard let error = error as? SKError else {
            return "Purchase did not go through. You have not been charged."
        }
        switch error.code {
        case .paymentCancelled:
            return "Purchase canceled. You have not been charged."
        case .paymentNotAllowed:
            return "Purchases are turned off in Settings. You have not been charged."
        case .storeProductNotAvailable:
            return "This package is not available. You have not been charged."
        default:
            return "Purchase did not go through. You have not been charged."
        }
    }

    private func transactionIdentifiers(_ transaction: SKPaymentTransaction) -> [String] {
        [transaction.transactionIdentifier, transaction.original?.transactionIdentifier]
            .compactMap { $0 }
            .filter { !$0.isEmpty }
    }

    private func rememberPreexisting(_ transaction: SKPaymentTransaction) {
        preexistingObjects.insert(ObjectIdentifier(transaction))
        preexistingIDs.formUnion(transactionIdentifiers(transaction))
    }

    private func forgetPreexisting(_ transaction: SKPaymentTransaction) {
        preexistingObjects.remove(ObjectIdentifier(transaction))
    }

    nonisolated func paymentQueue(_ queue: SKPaymentQueue, updatedTransactions transactions: [SKPaymentTransaction]) {
        let batch = transactions
        Task { @MainActor in
            guard self.observing else { return }
            if !self.queueDelivered && self.expected.isEmpty {
                self.queueDelivered = true
                for transaction in batch { self.rememberPreexisting(transaction) }
            } else if !self.acceptingPurchases {
                for transaction in batch { self.rememberPreexisting(transaction) }
            }
            self.enqueue(batch)
        }
    }
}

private struct FinishedPurchase {
    let transaction: SKPaymentTransaction
    let message: String?
}

private enum CreditOutcome {
    case savedNew
    case alreadySaved
    case notSaved
}

private final class PurchaseWait {
    var continuation: CheckedContinuation<String?, Never>?
    var settled = false
    var message: String?
}
