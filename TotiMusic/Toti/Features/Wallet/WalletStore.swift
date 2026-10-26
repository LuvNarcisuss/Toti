import Combine
import Foundation

@MainActor
final class WalletStore: ObservableObject {
    @Published private(set) var snapshot = WalletSnapshot()
    @Published private(set) var isBusy = false
    @Published private(set) var prices: [String: String] = [:]
    @Published private(set) var catalog = StoreCatalogStatus()
    private let purchasing = StoreKit1Purchasing()

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
        !isBusy && prices[package.storeProductID] != nil
    }

    var diagnostics: String { purchasing.diagnostics }
    var hasUnfinishedTransactions: Bool { purchasing.hasUnfinishedTransactions }
    func retryProducts() { purchasing.retryProducts() }

    func prepareProducts() {
        purchasing.reloadProductsIfNeeded()
    }

    func adopt(_ ledger: WalletLedger) {
        purchasing.adopt(ledger)
    }

    func setPersist(_ persist: @escaping (WalletLedger) async -> Bool) {
        purchasing.setPersist(persist)
    }

    func startPayments() async {
        await purchasing.start()
    }

    func stopPayments() async {
        await purchasing.stop()
    }

    func clearAccountMemory() {
        purchasing.clearMemory()
    }

    func purchase(_ package: WalletPackage) async -> String? {
        guard !isBusy else { return "Please wait for the current request to finish." }
        isBusy = true
        defer { isBusy = false }
        return await purchasing.purchase(package)
    }

    func send(_ gift: MusicGift, quantity: Int, context: GiftContext) async -> String? {
        guard !isBusy else { return "Please wait for the current request to finish." }
        guard context.isValid, (1...99).contains(quantity) else {
            return "Please check the recipient and quantity. No diamonds were spent."
        }
        isBusy = true
        defer { isBusy = false }
        return await purchasing.spend(gift, quantity: quantity, context: context)
    }
}
