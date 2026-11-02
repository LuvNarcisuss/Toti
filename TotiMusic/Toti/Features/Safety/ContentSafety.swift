import Foundation

struct ContentSafetyTarget: Identifiable {
    enum Kind: String, Codable {
        case live = "Live video", shortVideo = "Short video", comment = "Comment", party = "Voice room"
        case phrase = "Phrase"
        case post = "Music post"
        case profile = "Profile"
    }
    let id: String
    let title: String
    let kind: Kind
    let creator: CreatorProfile

    static func comment(id: String, name: String, text: String) -> Self {
        Self(id: id, title: text, kind: .comment,
             creator: CreatorProfile(id: "comment-author:" + name, name: name, biography: ""))
    }

    static func phrase(id: String, title: String, authorID: String, authorName: String) -> Self {
        Self(
            id: id, title: title, kind: .phrase,
            creator: CreatorProfile(id: authorID, name: authorName, biography: ""))
    }

    static func party(id: String, title: String, detail: String) -> Self {
        Self(id: id, title: title, kind: .party,
             creator: CreatorProfile(id: "party:" + id, name: title, biography: detail))
    }
}

enum ContentReportReason: String, Codable, CaseIterable, Identifiable {
    case spam = "Spam or misleading content"
    case harassment = "Harassment or bullying"
    case hate = "Hate or discrimination"
    case sexual = "Sexual content"
    case violence = "Violence"
    case dangerous = "Dangerous activity"
    case other = "Other"
    var id: String { rawValue }
}

struct LocalContentReport: Codable, Identifiable {
    let id: UUID
    let contentID: String
    let title: String
    let kind: ContentSafetyTarget.Kind
    let creatorID: String
    let creatorName: String
    let reason: ContentReportReason
    let details: String
    let savedAt: Date
}

/// One Settings row for a video, comment, or voice room. Several reasons stay one row.
struct ReportedContentItem: Identifiable, Equatable {
    let contentID: String
    let kind: ContentSafetyTarget.Kind
    let title: String
    let creatorName: String
    let reason: ContentReportReason
    let savedAt: Date
    var id: String { kind.rawValue + ":" + contentID }
}

struct ContentSafetyState: Codable {
    var blockedCreators: [String: CreatorProfile] = [:]
    var reports: [LocalContentReport] = []
}
