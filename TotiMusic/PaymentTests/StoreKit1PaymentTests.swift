import StoreKit
import StoreKitTest
import UIKit
import XCTest
@testable import toti

/// Runs the shipping StoreKit 1 service with Apple's local StoreKit server and real disk persistence.
/// The fixture is independent of the production catalog so an incorrect ID/amount fails the tests.
@MainActor
final class StoreKit1PaymentTests: XCTestCase {
    private var session: SKTestSession!
    private var purchasing: StoreKit1Purchasing!
    private var repository: LocalLibraryRepository!
    private var root: URL!
    private var ledger = WalletLedger.empty
    private var prices: [String: String] = [:]

    override func setUp() async throws {
        continueAfterFailure = true
        try await stopHostPayments()
        let configuration = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "TotiDiamonds", withExtension: "storekit"))
        session = try SKTestSession(contentsOf: configuration)
        session.resetToDefaultState()
        session.clearTransactions()
        session.disableDialogs = true
        root = FileManager.default.temporaryDirectory.appendingPathComponent("TotiPayment-" + UUID().uuidString)
        repository = LocalLibraryRepository(root: root)
        try await startService()
    }

    override func tearDown() async throws {
        await purchasing?.stop()
        purchasing?.clearMemory()
        session?.clearTransactions()
        session?.resetToDefaultState()
        if let root { try? FileManager.default.removeItem(at: root) }
    }

    private func startService(fetcher: StoreProductFetching? = nil, timeout: TimeInterval = 20, waitForCatalog: Bool = true) async throws {
        purchasing = StoreKit1Purchasing(productsFetcher: fetcher, productRequestTimeout: timeout)
        purchasing.onChange = { [weak self] ledger, prices in
            self?.ledger = ledger
            self?.prices = prices
        }
        purchasing.adopt(try await repository.loadWallet())
        enablePersistence()
        await purchasing.start()
        if waitForCatalog {
            try await eventually("Seven localized StoreKit products load") { self.prices.count == 7 }
        }
    }

    private func enablePersistence() {
        let repository = repository!
        purchasing.setPersist { ledger in
            do { try await repository.saveWallet(ledger); return true }
            catch { return false }
        }
    }

    private func buy(_ productID: String) async throws -> String? {
        let package = try XCTUnwrap(WalletCatalog.package(forProductID: productID))
        let completed = expectation(description: "Purchase settles: \(productID)")
        var message: String?
        var settled = false
        Task { @MainActor in
            message = await purchasing.purchase(package)
            settled = true
            completed.fulfill()
        }
        await fulfillment(of: [completed], timeout: 30)
        guard settled else { throw PaymentTestError.timeout }
        return message
    }

    private func eventually(_ description: String, condition: () -> Bool) async throws {
        let deadline = Date().addingTimeInterval(15)
        while !condition(), Date() < deadline { try await Task.sleep(nanoseconds: 100_000_000) }
        guard condition() else { XCTFail(description); throw PaymentTestError.timeout }
    }

    func testAllSevenPackagesCreditExactAmountsAndPersist() async throws {
        let expected: [(String, Int)] = [
            ("jezvdjvpoifednhy", 400), ("uylrrniaqxjtlaie", 800),
            ("oqojxyitbbjeayzj", 2450), ("skrseirtauvvrsol", 5150),
            ("bqrdrlkrlfpzjmod", 10800), ("psqtqagzmiiyhncr", 29400),
            ("bzwmucutltusfxpv", 63700)
        ]
        var total = 0
        let expectedPrices = ["$0.99", "$1.99", "$4.99", "$9.99", "$19.99", "$49.99", "$99.99"]
        for (index, tier) in expected.enumerated() {
            let (id, amount) = tier
            XCTAssertEqual(prices[id], expectedPrices[index])
            let message = try await buy(id)
            XCTAssertNil(message, message ?? "")
            total += amount
            XCTAssertEqual(ledger.diamonds, total)
            XCTAssertEqual(ledger.activity.first?.amount, amount)
            let saved = try await repository.loadWallet()
            XCTAssertEqual(saved.diamonds, total)
            print("PAYMENT_PASS \(id) +\(amount), balance=\(total), price=\(prices[id] ?? "missing")")
        }
        XCTAssertEqual(ledger.diamonds, 112700)
        XCTAssertEqual(ledger.creditedTransactionIDs.count, 7)
        try await eventually("Fulfilled transactions are finished") { SKPaymentQueue.default().transactions.isEmpty }
        await purchasing.stop()
        try await startService()
        XCTAssertEqual(ledger.diamonds, 112700)
        XCTAssertEqual(ledger.activity.count, 7)
    }

    func testRepeatConsumablePurchasesCreditEachNewTransaction() async throws {
        let trace = PaymentTransactionTrace()
        SKPaymentQueue.default().add(trace)
        defer { SKPaymentQueue.default().remove(trace) }
        for index in 0..<3 {
            print("REPEAT_BEGIN \(index) balance=\(ledger.diamonds) queue=\(SKPaymentQueue.default().transactions.map { "\(ObjectIdentifier($0)):\($0.transactionIdentifier ?? "nil"):\($0.transactionState.rawValue)" })")
            let result = try await buy("jezvdjvpoifednhy")
            print("REPEAT_END \(index) result=\(result ?? "success") balance=\(ledger.diamonds)")
            XCTAssertNil(result)
        }
        XCTAssertEqual(ledger.diamonds, 1200)
        XCTAssertEqual(Set(ledger.creditedTransactionIDs).count, 3)
    }

    @available(iOS 17.0, *)
    func testCancellationDoesNotCreditAndNextPurchaseSucceeds() async throws {
        try await session.setSimulatedError(.generic(.userCancelled), forAPI: .purchase)
        let canceled = try await buy("jezvdjvpoifednhy")
        XCTAssertEqual(canceled, "Purchase canceled. You have not been charged.")
        XCTAssertEqual(ledger.diamonds, 0)
        XCTAssertTrue(ledger.creditedTransactionIDs.isEmpty)
        // Reset the local server after the injected failure; clearing only its error value
        // leaves an empty failure payload on the iOS 26 StoreKit 1 test server.
        session.resetToDefaultState()
        session.disableDialogs = true
        let result = try await buy("jezvdjvpoifednhy")
        XCTAssertNil(result)
        XCTAssertEqual(ledger.diamonds, 400)
    }

    @available(iOS 17.0, *)
    func testPaymentFailureDoesNotCredit() async throws {
        try await session.setSimulatedError(.generic(.systemError(NSError(domain: NSURLErrorDomain, code: NSURLErrorNotConnectedToInternet))), forAPI: .purchase)
        let message = try await buy("uylrrniaqxjtlaie")
        XCTAssertNotNil(message)
        XCTAssertEqual(ledger.diamonds, 0)
        XCTAssertTrue(ledger.activity.isEmpty)
        let saved = try await repository.loadWallet()
        XCTAssertEqual(saved.diamonds, 0)
    }

    func testAskToBuyCreditsOnlyAfterApproval() async throws {
        session.askToBuyEnabled = true
        let pending = try await buy("uylrrniaqxjtlaie")
        XCTAssertEqual(pending, "This purchase is waiting for approval. Diamonds are added when it is approved.")
        XCTAssertEqual(ledger.diamonds, 0)
        let transaction = try XCTUnwrap(session.allTransactions().first { $0.pendingAskToBuyConfirmation })
        try session.approveAskToBuyTransaction(identifier: transaction.identifier)
        try await eventually("Approved purchase adds 800 diamonds") { self.ledger.diamonds == 800 }
        let saved = try await repository.loadWallet()
        XCTAssertEqual(saved.diamonds, 800)
    }

    func testFailedSaveRecoversOnObserverRestartAndDuplicateDoesNotCreditTwice() async throws {
        purchasing.setPersist { _ in false }
        let failedSave = try await buy("jezvdjvpoifednhy")
        XCTAssertTrue(failedSave?.contains("could not be saved") == true)
        XCTAssertEqual(ledger.diamonds, 0)
        let transaction = try XCTUnwrap(SKPaymentQueue.default().transactions.first { $0.transactionState == .purchased })
        let beforeRecovery = try await repository.loadWallet()
        XCTAssertEqual(beforeRecovery.diamonds, 0)
        await purchasing.stop()
        try await startService()
        try await eventually("Unfinished purchase is recovered") { self.ledger.diamonds == 400 }
        try await eventually("Recovered transaction is finished") { SKPaymentQueue.default().transactions.isEmpty }
        await purchasing.stop()
        try await startService()
        // Replay the actual StoreKit transaction into a fresh observer, exercising persisted ID deduplication.
        let duplicateHandled = expectation(description: "Duplicate transaction checks the saved ledger")
        let repository = repository!
        purchasing.setPersist { ledger in
            do {
                try await repository.saveWallet(ledger)
                duplicateHandled.fulfill()
                return true
            } catch { return false }
        }
        purchasing.paymentQueue(.default(), updatedTransactions: [transaction])
        await fulfillment(of: [duplicateHandled], timeout: 10)
        let saved = try await repository.loadWallet()
        XCTAssertEqual(saved.diamonds, 400)
        XCTAssertEqual(saved.creditedTransactionIDs.count, 1)
        XCTAssertEqual(saved.activity.count, 1)
    }

    func testPartialCatalogRetryAndStaleCallbackCannotReplaceNewRequest() async throws {
        let response = try await CatalogProbe().fetch(WalletCatalog.productIDs)
        let product = try XCTUnwrap(response.products.first { $0.productIdentifier == "jezvdjvpoifednhy" })
        await purchasing.stop()
        let fetcher = ControlledProductFetcher()
        try await startService(fetcher: fetcher, waitForCatalog: false)
        purchasing.retryProducts()
        XCTAssertEqual(fetcher.callbacks.count, 1, "Concurrent loads are coalesced")
        fetcher.deliver(0, .success(.init(products: [product], invalidProductIDs: Array(WalletCatalog.productIDs.subtracting([product.productIdentifier])))))
        XCTAssertEqual(purchasing.catalog.phase, .partial)
        XCTAssertEqual(prices, ["jezvdjvpoifednhy": "$0.99"])
        purchasing.retryProducts()
        fetcher.deliver(1, .failure(NSError(domain: NSURLErrorDomain, code: NSURLErrorNotConnectedToInternet)))
        XCTAssertEqual(purchasing.catalog.phase, .failed)
        XCTAssertEqual(prices.count, 1, "Valid offers survive a failed refresh")
        purchasing.retryProducts()
        fetcher.deliver(1, .success(.init(products: [], invalidProductIDs: Array(WalletCatalog.productIDs))))
        XCTAssertEqual(purchasing.catalog.phase, .loading, "Old callback must not end the new request")
        fetcher.deliver(2, .success(.init(products: response.products, invalidProductIDs: [])))
        XCTAssertEqual(purchasing.catalog.phase, .ready)
        XCTAssertEqual(prices.count, 7)
    }

    func testTimeoutCancelsRequestAndLateResultCannotReplaceRetry() async throws {
        let response = try await CatalogProbe().fetch(WalletCatalog.productIDs)
        await purchasing.stop()
        let fetcher = ControlledProductFetcher()
        try await startService(fetcher: fetcher, timeout: 0.15, waitForCatalog: false)
        try await eventually("Request reaches the explicit timeout state") { self.purchasing.catalog.phase == .timedOut }
        XCTAssertEqual(fetcher.cancelCount, 1)
        purchasing.retryProducts()
        fetcher.deliver(0, .success(.init(products: response.products, invalidProductIDs: [])))
        XCTAssertEqual(purchasing.catalog.phase, .loading)
        XCTAssertTrue(prices.isEmpty)
        fetcher.deliver(1, .success(.init(products: response.products, invalidProductIDs: [])))
        XCTAssertEqual(purchasing.catalog.phase, .ready)
    }

    func testSessionEndWhileLoadingPreventsDelayedPurchase() async throws {
        let response = try await CatalogProbe().fetch(WalletCatalog.productIDs)
        await purchasing.stop()
        let fetcher = ControlledProductFetcher()
        try await startService(fetcher: fetcher, waitForCatalog: false)
        let completed = expectation(description: "Session end releases pending purchase")
        var result: String?
        Task { @MainActor in
            result = await purchasing.purchase(WalletCatalog.package(forProductID: "jezvdjvpoifednhy")!)
            completed.fulfill()
        }
        await Task.yield()
        await purchasing.stop()
        fetcher.deliver(0, .success(.init(products: response.products, invalidProductIDs: [])))
        await fulfillment(of: [completed], timeout: 5)
        XCTAssertTrue(result?.contains("wallet was closed") == true)
        XCTAssertTrue(session.allTransactions().isEmpty)
        XCTAssertEqual(ledger.diamonds, 0)
        XCTAssertEqual(purchasing.catalog.phase, .idle)
    }

    func testEmptyCatalogAndSanitizedErrorDiagnostics() async throws {
        await purchasing.stop()
        let fetcher = ControlledProductFetcher()
        try await startService(fetcher: fetcher, waitForCatalog: false)
        fetcher.deliver(0, .success(.init(products: [], invalidProductIDs: Array(WalletCatalog.productIDs))))
        XCTAssertEqual(purchasing.catalog.phase, .unavailable)
        XCTAssertTrue(prices.isEmpty)
        XCTAssertEqual(purchasing.catalog.invalidIDs.count, 7)
        purchasing.retryProducts()
        fetcher.deliver(1, .failure(NSError(domain: "CatalogTest", code: 42, userInfo: [NSLocalizedDescriptionKey: "secret receipt", "receipt-data": "private"])))
        XCTAssertEqual(purchasing.catalog.phase, .failed)
        XCTAssertTrue(purchasing.diagnostics.contains("CatalogTest(42)"))
        XCTAssertFalse(purchasing.diagnostics.contains("secret"))
        XCTAssertFalse(purchasing.diagnostics.contains("private"))
    }
}

@MainActor
private final class ControlledProductFetcher: StoreProductFetching {
    var callbacks: [(Result<StoreProductResponse, Error>) -> Void] = []
    var cancelCount = 0
    func start(_ identifiers: Set<String>, completion: @escaping (Result<StoreProductResponse, Error>) -> Void) {
        callbacks.append(completion)
    }
    func cancel() { cancelCount += 1 }
    // Deliberately retains callbacks after cancel to reproduce late StoreKit delivery.
    func deliver(_ index: Int, _ result: Result<StoreProductResponse, Error>) { callbacks[index](result) }
}

private enum PaymentTestError: Error { case timeout }

private final class PaymentTransactionTrace: NSObject, SKPaymentTransactionObserver {
    func paymentQueue(_ queue: SKPaymentQueue, removedTransactions transactions: [SKPaymentTransaction]) {
        for transaction in transactions {
            print("PAYMENT_REMOVED object=\(ObjectIdentifier(transaction)) id=\(transaction.transactionIdentifier ?? "nil")")
        }
    }
    func paymentQueue(_ queue: SKPaymentQueue, updatedTransactions transactions: [SKPaymentTransaction]) {
        for transaction in transactions {
            print("PAYMENT_TRACE object=\(ObjectIdentifier(transaction)) id=\(transaction.transactionIdentifier ?? "nil") state=\(transaction.transactionState.rawValue)")
        }
    }
}

/// Stops the normal app observer before a test owns the queue. Uses existing controller APIs only.
@MainActor
private func stopHostPayments() async throws {
    let deadline = Date().addingTimeInterval(20)
    while Date() < deadline {
        let windows = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.flatMap(\.windows)
        if let navigation = windows.first(where: { $0.isKeyWindow })?.rootViewController as? UINavigationController,
           let screen = navigation.viewControllers.first as? TotiScreen {
            await screen.store.wallet.stopPayments()
            return
        }
        try await Task.sleep(nanoseconds: 100_000_000)
    }
    throw PaymentTestError.timeout
}

@MainActor
final class CatalogAvailabilityTests: XCTestCase {
    func testAppleCatalogWithoutLocalStoreKitConfiguration() async throws {
        try await stopHostPayments()
        let probe = CatalogProbe()
        let response = try await probe.fetch(WalletCatalog.productIDs)
        let detail = "APPLE_CATALOG loaded=\(response.products.map(\.productIdentifier).sorted()), invalid=\(response.invalidProductIdentifiers.sorted())"
        print(detail)
        let attachment = XCTAttachment(string: detail)
        attachment.lifetime = .keepAlways
        add(attachment)
        guard response.products.count == 7 else {
            throw XCTSkip("Apple did not return all seven products. See catalog attachment; this is not a sandbox purchase pass.")
        }
    }
}

@MainActor
private final class CatalogProbe: NSObject, SKProductsRequestDelegate {
    private var request: SKProductsRequest?
    private var continuation: CheckedContinuation<SKProductsResponse, Error>?

    func fetch(_ identifiers: Set<String>) async throws -> SKProductsResponse {
        try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            let request = SKProductsRequest(productIdentifiers: identifiers)
            self.request = request
            request.delegate = self
            request.start()
            DispatchQueue.main.asyncAfter(deadline: .now() + 25) { [weak self] in
                guard let self, let continuation = self.continuation else { return }
                self.continuation = nil
                self.request?.cancel()
                continuation.resume(throwing: XCTSkip("Apple catalog request timed out without a local StoreKit configuration."))
            }
        }
    }
    nonisolated func productsRequest(_ request: SKProductsRequest, didReceive response: SKProductsResponse) {
        Task { @MainActor in
            self.continuation?.resume(returning: response)
            self.continuation = nil
        }
    }
    nonisolated func request(_ request: SKRequest, didFailWithError error: Error) {
        Task { @MainActor in
            self.continuation?.resume(throwing: XCTSkip("Apple catalog unavailable: \(error)"))
            self.continuation = nil
        }
    }
}
