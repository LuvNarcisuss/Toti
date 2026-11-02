import Foundation

/// App-owned configuration. Add only endpoints and products owned by this application.
enum TotiIdentity {
    static let name = "Toti"
    static let storageDirectory = "Toti"
    static let shareScheme = "toti"
    static let agreementURLs: [String: URL] = [
        "TermsOfService": URL(string: "https://gjodhvpzkdnxdjmorjfw.supabase.co/storage/v1/object/public/toti-agreements/2026-10-30/TermsOfService.pdf")!,
        "PrivacyPolicy": URL(string: "https://gjodhvpzkdnxdjmorjfw.supabase.co/storage/v1/object/public/toti-agreements/2026-10-30/PrivacyPolicy.pdf")!
    ]
    static let agreementHashes: [String: String] = [
        "TermsOfService": "69bc7580388991acaf39d338388ed25a8616eb38b441cc4b29ee5f6520984803",
        "PrivacyPolicy": "b16c3aaea7283452cada8c4a5456a686442aff0b844fe74af7ecd3dcbf81b57c",
    ]
    /// Diamond amount → consumable App Store Connect product ID (catalog 40617780).
    static let diamondProducts: [Int: String] = [
        400: "jezvdjvpoifednhy",
        800: "uylrrniaqxjtlaie",
        2_450: "oqojxyitbbjeayzj",
        5_150: "skrseirtauvvrsol",
        10_800: "bqrdrlkrlfpzjmod",
        29_400: "psqtqagzmiiyhncr",
        63_700: "bzwmucutltusfxpv"
    ]
}
