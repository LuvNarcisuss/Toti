import Foundation

struct ChatAttachment: Codable, Equatable {
    let path: String
    let filename: String
    let kind: String
    let byteCount: Int
    let contentType: String
}

struct ChatMessage: Identifiable, Codable {
    let id: String
    let author: String
    let text: String
    let time: String
    let isOwn: Bool
    var createdAt: Date? = nil
    var isPending: Bool? = nil
    var attachment: ChatAttachment? = nil
}

struct MusicConversation: Identifiable, Hashable {
    enum Kind { case person, group, activity }
    let id: String
    let name: String
    let avatars: [String]
    let kind: Kind
    let time: String
    let initialUnread: Int
    let initiallyPinned: Bool
    let story: String?
    let messages: [ChatMessage]
    var creator: CreatorProfile? = nil
    var summary: String { messages.last?.text ?? "Start with a hello." }
    static func == (lhs: Self, rhs: Self) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

struct LocalChatGroup: Codable, Equatable, Identifiable {
    var id: String
    var name: String
    var avatarAssets: [String]
    var createdAt: Date
}

struct ChatLocalState: Codable {
    var readIDs: Set<String> = []
    var pinOverrides: [String: Bool] = [:]
    var drafts: [String: String] = [:]
    // Optional fields preserve decoding of earlier library snapshots.
    var sentMessages: [String: [ChatMessage]]? = nil
    var followingOverrides: [String: Bool]? = nil
    var followerIDs: Set<String>? = nil
    var createdGroups: [LocalChatGroup]? = nil
    var unreadMarks: [String: Int]? = nil
    var mutedIDs: Set<String>? = nil
    var hiddenChatIDs: Set<String>? = nil
}

enum ChatInboxFilter: String, CaseIterable, Identifiable {
    case all = "All chats", unread = "Unread", pinned = "Pinned", drafts = "Drafts"
    var id: String { rawValue }
}

/// Authored conversations, not downloaded messages or real user activity.
/// Stable IDs let local read, pin and draft state survive catalog reloads.
enum MusicChatCatalog {
    // Authored relationships for the existing fictional inbox, not remote account data.
    static let initialMutualIDs: Set<String> = ["maya", "leo", "zoe"]
    static let initialFollowerIDs: Set<String> = ["maya", "leo", "zoe", "noah"]
    private static func conversation(_ id: String, _ name: String, avatars: [String], kind: MusicConversation.Kind = .person,
                                     time: String, unread: Int = 0, pinned: Bool = false, story: String? = nil,
                                     lines: [(String, String)]) -> MusicConversation {
        let clock = time.split(separator: ":").compactMap { Int($0) }
        let endMinute = clock.count == 2 ? clock[0] * 60 + clock[1] : 13 * 60 + 30
        return MusicConversation(id: id, name: name, avatars: avatars, kind: kind, time: time,
            initialUnread: unread, initiallyPinned: pinned, story: story,
            messages: lines.enumerated().map { index, line in
                ChatMessage(id: "\(id)-\(index)", author: line.0, text: line.1,
                            time: String(format: "%02d:%02d", (endMinute - lines.count + index + 1) / 60,
                                         (endMinute - lines.count + index + 1) % 60), isOwn: line.0 == "You")
            })
    }
    static let conversations: [MusicConversation] = [
        conversation("activity", "Music activity", avatars: ["TotiMark"], kind: .activity, time: "13:25", unread: 0, pinned: false, story: "A little inspiration for your next session.", lines: [
            ("Toti", "Find a voice that makes you stop and listen."),
            ("Toti", "Save a session to build your own listening shelf."),
            ("Toti", "Your music, your people."),
        ]),
        conversation("maya", "Maya Chen", avatars: ["Portrait1"], kind: .person, time: "13:26", unread: 1, pinned: true, story: "A melody notebook and a quiet afternoon.", lines: [
            ("Maya", "Have you heard that acoustic session?"),
            ("You", "The harmony in the chorus is lovely."),
            ("Maya", "I am trying to work it out on the piano."),
            ("You", "Send me your chord ideas when you have them."),
            ("Maya", "Let us give the chorus another listen."),
        ]),
        conversation("after-class", "The Listening Room", avatars: ["Portrait1", "Portrait2", "Portrait3", "Portrait4"], kind: .group, time: "12:27", unread: 2, pinned: false, lines: [
            ("Noah", "What are we listening to this weekend?"),
            ("You", "Something with warm vocals."),
            ("Zoe", "I have a few jazz records to share."),
            ("Leo", "Saturday listening: one favorite song each."),
        ]),
        conversation("leo", "Leo Brooks", avatars: ["Portrait2"], kind: .person, time: "12:28", unread: 0, pinned: false, story: "Digging through records for the next great bass line.", lines: [
            ("Leo", "That bass line has been in my head all day."),
            ("You", "The rhythm leaves so much space."),
            ("Leo", "Adding it to my evening playlist."),
        ]),
        conversation("zoe", "Zoe Park", avatars: ["Portrait3"], kind: .person, time: "11:29", unread: 1, pinned: false, story: "Jazz records, warm coffee, new ideas.", lines: [
            ("Zoe", "Do you have a favorite jazz singer?"),
            ("You", "I love a voice with a story in every line."),
            ("Zoe", "Same. The phrasing is everything."),
        ]),
        conversation("noah", "Noah Rivera", avatars: ["Portrait4"], kind: .person, time: "11:30", unread: 2, pinned: false, story: "A fresh playlist for a quiet morning.", lines: [
            ("Noah", "I am making a playlist for a slow Sunday."),
            ("You", "Start with something acoustic?"),
            ("Noah", "Found a song for the first track."),
        ]),
        conversation("kpop-circle", "Harmony Club", avatars: ["Portrait3", "Portrait5", "Portrait6", "Portrait2"], kind: .group, time: "10:31", unread: 0, pinned: false, lines: [
            ("Aria", "Which chorus should we try next?"),
            ("Zoe", "Something with a clear three-part harmony."),
            ("You", "We could learn one line at a time."),
            ("Finn", "I will start with the lower part."),
        ]),
        conversation("aria", "Aria Wilson", avatars: ["Portrait5"], kind: .person, time: "10:32", unread: 1, pinned: false, story: "Learning to let a song breathe.", lines: [
            ("Aria", "I keep rushing the quiet parts."),
            ("You", "Leave a little room after each line."),
            ("Aria", "The silence makes the next note feel bigger."),
        ]),
        conversation("finn", "Finn Taylor", avatars: ["Portrait6"], kind: .person, time: "09:33", unread: 2, pinned: false, story: "A microphone, a notebook and a new melody.", lines: [
            ("Finn", "Any tips for feeling relaxed while recording?"),
            ("You", "Try one take just for yourself first."),
            ("Finn", "One more take, then a tea break."),
        ]),
        conversation("ballet-friends", "Piano & Poetry", avatars: ["Portrait7", "Portrait8", "Portrait1", "Portrait5"], kind: .group, time: "09:34", unread: 0, pinned: false, lines: [
            ("Ivy", "I finally found the chords for my new verse."),
            ("You", "Those small discoveries add up."),
            ("Maya", "Bring it to our next listening session."),
        ]),
    ]
    static var people: [MusicConversation] { conversations.filter { $0.kind == .person } }
}
