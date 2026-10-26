import Foundation

enum WalletCurrency: String, Codable, CaseIterable, Identifiable {
    case diamonds = "Diamonds"
    var id: String { rawValue }
    var symbol: String { "diamond.fill" }
}

struct WalletPackage: Identifiable {
    let currency: WalletCurrency
    let amount: Int
    let usdCents: Int
    // Catalog identifier; availability must be resolved through the purchase service.
    let storeProductID: String
    var id: String { "\(currency.id)-\(amount)" }
    /// Catalog reference only. The charge price comes from StoreKit.
    var price: String { String(format: "$%d.%02d", usdCents / 100, usdCents % 100) }
    var amountText: String { amount.formatted(.number.locale(Locale(identifier: "en_US"))) }
}

enum WalletCatalog {
    // Store product IDs from the purchase catalog. USD amounts are references, not the charge.
    private static let diamondTiers: [(amount: Int, usdCents: Int)] = [
        (400, 99),
        (800, 199),
        (2_450, 499),
        (5_150, 999),
        (10_800, 1_999),
        (29_400, 4_999),
        (63_700, 9_999)
    ]

    static func packages(for currency: WalletCurrency) -> [WalletPackage] {
        diamondTiers.map { tier in
            WalletPackage(currency: currency, amount: tier.amount,
                          usdCents: tier.usdCents, storeProductID: TotiIdentity.diamondProducts[tier.amount] ?? "")
        }
    }

    static var productIDs: Set<String> {
        Set(packages(for: .diamonds).map(\.storeProductID).filter { !$0.isEmpty })
    }

    static func package(forProductID productID: String) -> WalletPackage? {
        guard !productID.isEmpty else { return nil }
        return packages(for: .diamonds).first { $0.storeProductID == productID }
    }
}

struct MusicGift: Identifiable {
    let id: String
    let name: String
    let symbol: String
    let diamonds: Int
    let hue: Double

    static let catalog: [Self] = [
        .init(id: "rose", name: "Rose", symbol: "camera.macro", diamonds: 10, hue: 0.96),
        .init(id: "balloons", name: "Balloons", symbol: "balloon.2.fill", diamonds: 50, hue: 0.54),
        .init(id: "heart", name: "Heart", symbol: "heart.fill", diamonds: 100, hue: 0.94),
        .init(id: "beat", name: "Beat Drop", symbol: "music.note", diamonds: 200, hue: 0.72),
        .init(id: "spotlight", name: "Spotlight", symbol: "sparkles", diamonds: 500, hue: 0.12),
        .init(id: "bouquet", name: "Bouquet", symbol: "camera.macro", diamonds: 1_000, hue: 0.88),
        .init(id: "crown", name: "Vocal Crown", symbol: "crown.fill", diamonds: 2_000, hue: 0.10),
        .init(id: "encore", name: "Encore", symbol: "party.popper.fill", diamonds: 5_000, hue: 0.04),
        .init(id: "galaxy", name: "Sound Galaxy", symbol: "moon.stars.fill", diamonds: 10_000, hue: 0.67)
    ]
}

struct GiftRecipient: Codable, Equatable {
    let id: String
    let name: String
}

struct GiftContext: Codable, Equatable {
    enum Surface: String, Codable { case post, voiceRoom }
    let surface: Surface
    let sourceID: String
    let sourceTitle: String
    var recipients: [GiftRecipient]

    var recipientText: String { recipients.map(\.name).joined(separator: ", ") }
    var isValid: Bool {
        !sourceID.isEmpty && !sourceTitle.isEmpty && !recipients.isEmpty
            && Set(recipients.map(\.id)).count == recipients.count
            && recipients.allSatisfy { !$0.id.isEmpty && $0.id != "local-owner" && !$0.name.isEmpty }
    }
}

struct WalletActivity: Codable, Identifiable {
    let id: String
    let title: String
    let currency: WalletCurrency
    let amount: Int
    let date: Date
    /// "gift" is a local spend. A missing value is a diamond purchase.
    var kind: String? = nil
    // Optional fields preserve previously saved purchases and gifts.
    var giftContext: GiftContext? = nil
    var giftID: String? = nil
    var giftQuantity: Int? = nil
}

struct WalletSnapshot {
    var diamonds = 0
    var activity: [WalletActivity] = []
    func balance(_ currency: WalletCurrency) -> Int { diamonds }
}

/// Device ledger for consumable diamond purchases. Missing file means an empty ledger.
struct WalletLedger: Codable {
    var schemaVersion = 1
    var diamonds: Int
    var activity: [WalletActivity]
    var creditedTransactionIDs: [String]

    static let empty = WalletLedger(diamonds: 0, activity: [], creditedTransactionIDs: [])

    var snapshot: WalletSnapshot { WalletSnapshot(diamonds: diamonds, activity: activity) }

    var isValid: Bool {
        schemaVersion == 1
            && diamonds >= 0
            && creditedTransactionIDs.allSatisfy { !$0.isEmpty }
            && Set(creditedTransactionIDs).count == creditedTransactionIDs.count
            && Set(activity.map(\.id)).count == activity.count
            && activity.allSatisfy { item in
                guard item.amount > 0, !item.id.isEmpty, !item.title.isEmpty, item.currency == .diamonds else {
                    return false
                }
                if item.kind == "gift" {
                    guard let context = item.giftContext else { return true }
                    guard context.isValid, let quantity = item.giftQuantity,
                          (1...99).contains(quantity),
                          let gift = MusicGift.catalog.first(where: { $0.id == item.giftID }) else { return false }
                    return item.amount == gift.diamonds * quantity
                }
                return (item.kind == nil || item.kind == "credit") && creditedTransactionIDs.contains(item.id)
            }
    }
}
