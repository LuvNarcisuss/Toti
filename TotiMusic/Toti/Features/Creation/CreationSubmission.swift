import Foundation

enum CreationKind: String, Codable, Identifiable {
    case live, shortVideo
    var id: String { rawValue }
    var title: String { self == .live ? "Create a live session" : "Create a short video" }
    var label: String { self == .live ? "Live" : "Short video" }
    var symbol: String { self == .live ? "video" : "play.rectangle" }
}

/// A durable submission outbox. Only a review service may advance this status.
struct CreationSubmission: Identifiable, Codable {
    enum Status: String, Codable { case awaitingSubmission }
    var id = UUID()
    let kind: CreationKind
    let title: String
    let caption: String
    let category: String
    var videoID: UUID? = nil
    var hasCover = false
    var createdAt = Date()
    var status: Status = .awaitingSubmission
}

enum CreationValidation {
    static func isEnglish(_ text: String) -> Bool {
        !text.unicodeScalars.contains { $0.properties.isAlphabetic && !$0.isASCII }
    }
    static func valid(title: String, caption: String) -> Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        && title.count <= 80 && caption.count <= 500 && isEnglish(title) && isEnglish(caption)
    }
}

enum CreationError: LocalizedError {
    case shortTooLong, coverUnavailable
    var errorDescription: String? {
        switch self {
        case .shortTooLong: return "Choose a music video of up to 3 minutes."
        case .coverUnavailable: return "This photo could not be opened. Choose another cover."
        }
    }
}
