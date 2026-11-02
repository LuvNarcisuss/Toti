import Combine
import Foundation

@MainActor
final class WalletStore: ObservableObject {
    @Published private(set) var snapshot = WalletSnapshot()
    @Published private(set) var isBusy = false
    @Published private(set) var prices: [String: String] = [:]
    @Published private(set) var catalog = StoreCatalogStatus()
    private let purchasing = StoreKit1Purchasing()
    var requiresServerVerification = TotiBackendConfiguration.usesOnlineBackend
    var allowsLocalStoreKitTesting = false
    @Published private(set) var localTestingError: String?
    private var localTestingTask: Task<Void, Never>?
    private var localTestingAccount: UUID?
    private var localTestingGeneration: Int?
    @Published private(set) var localTestingReady = false

    var isLocalStoreKitTesting: Bool {
        #if DEBUG && targetEnvironment(simulator)
        return allowsLocalStoreKitTesting && ProcessInfo.processInfo.environment["TOTI_LOCAL_STOREKIT_TESTING"] == "1"
        #else
        return false
        #endif
    }
    var isServerWalletUnavailable: Bool { requiresServerVerification && !isLocalStoreKitTesting }
    private var canUsePurchaseService: Bool {
        !requiresServerVerification || (isLocalStoreKitTesting && localTestingReady
            && localTestingAccount == TotiBackend.shared.accountID
            && localTestingGeneration == TotiBackend.shared.generation)
    }

    init() {
        purchasing.onCatalogChange = { [weak self] in self?.catalog = $0 }
        purchasing.onChange = { [weak self] ledger, prices in
            self?.snapshot = ledger.snapshot
            self?.prices = prices
        }
    }

    func priceText(for package: WalletPackage) -> String {
        prices[package.storeProductID] ?? (catalog.phase == .loading ? "Loading…" : "Unavailable")
    }

    func canPurchase(_ package: WalletPackage) -> Bool {
        canUsePurchaseService && !isBusy && prices[package.storeProductID] != nil
    }

    var diagnostics: String { purchasing.diagnostics }
    var hasUnfinishedTransactions: Bool { purchasing.hasUnfinishedTransactions }
    func retryProducts() {
        if canUsePurchaseService { purchasing.retryProducts() }
        else { prepareProducts() }
    }

    func prepareProducts() {
        if isLocalStoreKitTesting {
            #if DEBUG && targetEnvironment(simulator)
            guard localTestingTask == nil else { return }
            localTestingTask = Task { [weak self] in
                guard let self else { return }
                await self.prepareLocalTesting()
                self.localTestingTask = nil
            }
            #endif
            return
        }
        guard !requiresServerVerification else { return }
        purchasing.reloadProductsIfNeeded()
    }

    func adopt(_ ledger: WalletLedger) {
        purchasing.adopt(ledger)
    }

    func setPersist(_ persist: @escaping (WalletLedger) async -> Bool) {
        purchasing.setPersist(persist)
    }

    func startPayments() async {
        guard !requiresServerVerification else { return }
        await purchasing.start()
    }

    func stopPayments() async {
        await purchasing.stop()
    }

    func clearAccountMemory() {
        if isLocalStoreKitTesting {
            purchasing.suspend()
            localTestingTask?.cancel()
            localTestingReady = false
            localTestingAccount = nil
            localTestingGeneration = nil
            localTestingError = nil
        }
        purchasing.clearMemory()
    }

    func purchase(_ package: WalletPackage) async -> String? {
        guard canUsePurchaseService else { return "Purchases are unavailable. Please reopen the wallet and try again." }
        guard !isBusy else { return "Please wait for the current request to finish." }
        isBusy = true
        defer { isBusy = false }
        return await purchasing.purchase(package)
    }

    func send(_ gift: MusicGift, quantity: Int, context: GiftContext) async -> String? {
        guard !requiresServerVerification else { return "Purchases and gifts are unavailable until server verification is configured." }
        guard !isBusy else { return "Please wait for the current request to finish." }
        guard context.isValid, (1...99).contains(quantity) else {
            return "Please check the recipient and quantity. No diamonds were spent."
        }
        isBusy = true
        defer { isBusy = false }
        return await purchasing.spend(gift, quantity: quantity, context: context)
    }

    #if DEBUG && targetEnvironment(simulator)
    /// Only the wallet is local. Authentication and all other online services stay unchanged.
    private func prepareLocalTesting() async {
        guard let account = TotiBackend.shared.accountID, TotiBackend.shared.isAuthenticated else { return }
        let generation = TotiBackend.shared.generation
        if localTestingReady, localTestingAccount == account, localTestingGeneration == generation {
            purchasing.reloadProductsIfNeeded()
            return
        }
        await purchasing.stop()
        guard !Task.isCancelled, generation == TotiBackend.shared.generation,
              account == TotiBackend.shared.accountID else { return }
        localTestingReady = false
        localTestingError = nil
        do {
            var root = URL.applicationSupportDirectory
                .appendingPathComponent("TotiOnline/StoreKitTesting", isDirectory: true)
                .appendingPathComponent(account.uuidString, isDirectory: true)
            if let run = ProcessInfo.processInfo.environment["TOTI_STOREKIT_TEST_RUN"],
               let id = UUID(uuidString: run) {
                root.appendPathComponent(id.uuidString, isDirectory: true)
            }
            let url = root.appendingPathComponent("wallet.json")
            let saved: LocalStoreKitWallet
            if FileManager.default.fileExists(atPath: url.path) {
                saved = try JSONDecoder().decode(LocalStoreKitWallet.self, from: Data(contentsOf: url))
                guard saved.account == account, saved.ledger.isValid else { throw CocoaError(.fileReadCorruptFile) }
            } else {
                saved = LocalStoreKitWallet(account: account, transactionOwner: UUID(), ledger: .empty)
                try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
                try JSONEncoder().encode(saved).write(to: url, options: .atomic)
            }
            purchasing.transactionOwner = saved.transactionOwner
            purchasing.adopt(saved.ledger)
            purchasing.setPersist { ledger in
                guard account == TotiBackend.shared.accountID,
                      generation == TotiBackend.shared.generation, ledger.isValid else { return false }
                do {
                    let next = LocalStoreKitWallet(account: account, transactionOwner: saved.transactionOwner, ledger: ledger)
                    try JSONEncoder().encode(next).write(to: url, options: .atomic)
                    return true
                } catch { return false }
            }
            localTestingAccount = account
            localTestingGeneration = generation
            localTestingReady = true
            await purchasing.start()
        } catch {
            localTestingError = "The local test wallet could not be opened. Its saved data has been kept. Try again."
        }
    }
    #endif
}

#if DEBUG && targetEnvironment(simulator)
private struct LocalStoreKitWallet: Codable {
    let account: UUID
    let transactionOwner: UUID
    let ledger: WalletLedger
}
#endif
