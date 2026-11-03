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
        "TermsOfService": "3373e79a40eef257b8785ded7ef6534853041d35750a7ffb471118a4fb435d72",
        "PrivacyPolicy": "287d26f7cd6acb0c435b09caa7e4fddfabeca8ebfcbd89041777fd9ab45b3bcc",
    ]
    /// Diamond amount → consumable product ID; the two additional tiers await App Store Connect registration.
    static let diamondProducts: [Int: String] = [
        400: "jezvdjvpoifednhy",
        800: "uylrrniaqxjtlaie",
        2_450: "oqojxyitbbjeayzj",
        5_150: "skrseirtauvvrsol",
        10_800: "bqrdrlkrlfpzjmod",
        16_800: "qcrxcepelpjfskbi",
        29_400: "psqtqagzmiiyhncr",
        42_700: "fwcwwzfkbeawlbql",
        63_700: "bzwmucutltusfxpv"
    ]
}
