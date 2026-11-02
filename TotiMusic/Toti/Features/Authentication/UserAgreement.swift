import CryptoKit
import Foundation

struct AgreementAcceptance: Codable {
    let version: String
    let acceptedAt: Date
}

enum AgreementDocument: String, Identifiable, CaseIterable {
    case terms = "TermsOfService"
    case privacy = "PrivacyPolicy"
    var id: String { rawValue }
    var title: String { self == .terms ? "Toti - Terms of Service" : "Toti - Privacy Policy" }
    var linkTitle: String { self == .terms ? "Terms of Service" : "Privacy Policy" }
    var expectedPDFHash: String? { TotiIdentity.agreementHashes[rawValue] }
    var onlineURL: URL? { TotiIdentity.agreementURLs[rawValue] }
    var fileURL: URL? {
        Bundle.main.url(forResource: rawValue, withExtension: "html")
    }
}

enum TotiUserAgreement {
    // Online acceptance identifies the pinned PDF bytes; legacy local records stay decodable.
    static let version: String = {
        #if DEBUG
        if let value = ProcessInfo.processInfo.environment["TOTI_GUEST_ACCEPTANCE"], UUID(uuidString: value) != nil {
            return "guest-acceptance-test-not-user-consent-" + value
        }
        #endif
        if TotiBackendConfiguration.usesOnlineBackend {
            let identity = AgreementDocument.allCases.compactMap { $0.expectedPDFHash }.joined(separator: ":")
            guard AgreementDocument.allCases.allSatisfy({ $0.expectedPDFHash != nil && $0.onlineURL != nil }) else { return "unavailable" }
            let digest = SHA256.hash(data: Data(identity.utf8)).map { String(format: "%02x", $0) }.joined()
            return "pdf-" + String(digest.prefix(12))
        }
        var content = Data()
        for document in AgreementDocument.allCases {
            guard let url = document.fileURL, let bytes = try? Data(contentsOf: url) else {
                return "unavailable"
            }
            content.append(contentsOf: document.rawValue.utf8)
            content.append(0)
            content.append(bytes)
        }
        let digest = SHA256.hash(data: content).map { String(format: "%02x", $0) }.joined()
        return "local-" + String(digest.prefix(12))
    }()
}
