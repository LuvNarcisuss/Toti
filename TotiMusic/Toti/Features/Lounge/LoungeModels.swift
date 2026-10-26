import Foundation

enum LoungeTopic: String, Codable, CaseIterable {
    case listening = "Listening", concerts = "Concerts", makingMusic = "Making music", bandmate = "Find a bandmate"
}

struct LoungePost: Identifiable, Codable {
    var id = UUID()
    var author: CreatorProfile
    var body: String
    var topic: LoungeTopic = .listening
    var isDraft = false
    var createdAt = Date()
    var updatedAt = Date()
    /// A normalized JPEG, at most 1 MiB and 1,200 pixels per side. Storing the bounded
    /// attachment in the same atomic snapshot prevents orphan files and partial photo edits.
    var photoJPEG: Data? = nil
    var photoAsset: String? = nil
    var voiceRoomID: String? = nil
    var isEditorial = false

    func validationError(asDraft: Bool) -> String? {
        if let photoJPEG, photoJPEG.count > 1_048_576 { return "Choose a photo smaller than 1 MB." }
        if asDraft {
            // A Notebook conversion may exceed the posting limit. Preserve it as a draft.
            return body.count > 10_100 ? "Drafts can contain up to 10,100 characters." : nil
        }
        if body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return "Write something before saving your post." }
        if body.count > 1_000 { return "Posts can contain up to 1,000 characters. Shorten your text or save a draft." }
        return nil
    }

    func matches(_ query: String) -> Bool {
        let query = query.trimmingCharacters(in: .whitespacesAndNewlines)
        return query.isEmpty || (body + " " + topic.rawValue + " " + author.name).localizedCaseInsensitiveContains(query)
    }
}

struct LoungeComment: Identifiable, Codable {
    var id = UUID()
    let postID: UUID
    let author: CreatorProfile
    let body: String
    var createdAt = Date()

    static func validationError(_ text: String) -> String? {
        if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return "Write a reply first." }
        return text.count > 500 ? "Replies can contain up to 500 characters." : nil
    }
}

struct LoungeState: Codable {
    var posts: [LoungePost] = []
    var likedPostIDs: Set<UUID> = []
    var savedPostIDs: Set<UUID> = []
    var comments: [LoungeComment] = []

    func visiblePosts(blockedAuthorIDs: Set<String>, hiddenPostIDs: Set<UUID>) -> [LoungePost] {
        posts.filter { !$0.isDraft && !blockedAuthorIDs.contains($0.author.id) && !hiddenPostIDs.contains($0.id) }
    }

    /// Fictional editorial prompts, separate from user-owned posts. Photographs are
    /// illustrative licensed artwork; no pictured person is claimed to be the author.
    static let editorialPosts: [LoungePost] = {
        let date = Date(timeIntervalSince1970: 1_792_972_800)
        return [
            LoungePost(id: UUID(uuidString: "16F40C60-5DC2-4DB5-BF99-000000000001")!,
                       author: CreatorProfile(id: "editorial:maya", name: "Maya · Toti editorial", biography: "A fictional editorial voice for music conversation. Portrait is illustrative artwork.", avatarAsset: "Portrait1"),
                       body: "That moment when a song makes the whole room feel quieter. What have you been listening to on repeat lately?", topic: .listening,
                       createdAt: date, updatedAt: date, photoAsset: "MusicStudioBackdrop", voiceRoomID: "hip-hop-crew", isEditorial: true),
            LoungePost(id: UUID(uuidString: "16F40C60-5DC2-4DB5-BF99-000000000002")!,
                       author: CreatorProfile(id: "editorial:luca", name: "Luca · Toti editorial", biography: "A fictional editorial voice for music conversation. Portrait is illustrative artwork.", avatarAsset: "Portrait2"),
                       body: "Songwriting prompt: begin with a sound you heard on your way home. A train, rain on a window, a friend's laugh. Where does the melody go?", topic: .makingMusic,
                       createdAt: date.addingTimeInterval(-3_600), updatedAt: date, voiceRoomID: "practice-break", isEditorial: true),
            LoungePost(id: UUID(uuidString: "16F40C60-5DC2-4DB5-BF99-000000000003")!,
                       author: CreatorProfile(id: "editorial:elena", name: "Elena · Toti editorial", biography: "A fictional editorial voice for music conversation. Portrait is illustrative artwork.", avatarAsset: "Portrait3"),
                       body: "Your first rehearsal together: one familiar song, plenty of listening, and room to get it wrong. What would you want a new bandmate to know about your sound?", topic: .bandmate,
                       createdAt: date.addingTimeInterval(-7_200), updatedAt: date, isEditorial: true)
        ]
    }()
}
