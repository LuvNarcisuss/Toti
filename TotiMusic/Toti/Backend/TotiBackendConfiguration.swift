import Foundation

enum TotiBackendConfiguration {
    /// Online is the selected product mode. The Guest integration is enabled and never restores fictional business data.
    static let usesOnlineBackend = true
    /// Guest entry is enabled for the current integration build; this is not production release acceptance.
    static let rolloutEnabled = true
    static let projectURL = URL(string: "https://gjodhvpzkdnxdjmorjfw.supabase.co")!
    static let publishableKey = "sb_publishable_BAGC-R5SQ56dXcnnkNS3yQ_S67ER5Ke"
    static let sdkVersion = "2.55.5"
    static let authStorageKey = "toti-gjodhvpzkdnxdjmorjfw-session"
    static let onlineDirectory = "TotiOnline"
    static let rtcEnabled = false
    static let purchasesEnabled = false
    static let accountDeletionEnabled = true
}
