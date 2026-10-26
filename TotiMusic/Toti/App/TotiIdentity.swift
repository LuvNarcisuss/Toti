import Foundation

/// App-owned configuration. Add only endpoints and products owned by this application.
enum TotiIdentity {
    static let name = "Toti"
    static let storageDirectory = "Toti"
    static let shareScheme = "toti"
    static let agreementURLs: [String: URL] = [:]
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
