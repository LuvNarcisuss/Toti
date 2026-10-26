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
    var onlineURL: URL? { TotiIdentity.agreementURLs[rawValue] }
    var fileURL: URL? {
        Bundle.main.url(forResource: rawValue, withExtension: "html")
    }
}

enum TotiUserAgreement {
    // Acceptance refers to the exact bundled files rather than the retired inline copy.
    static let version: String = {
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
