import Foundation

/// Authored frontend conversation content, not posts fetched from real accounts.
/// Per-video ordering is repeatable; views never regenerate IDs during rendering.
enum MusicDiscussionContent {
    struct Line {
        let name: String
        let text: String
        let avatarAsset: String
    }

    static let phrases = MusicEditorial.discussion

    private static func stableSeed(for id: UUID) -> UInt64 {
        id.uuidString.utf8.reduce(UInt64(14695981039346656037)) {
            ($0 ^ UInt64($1)) &* 1099511628211
        }
    }

    static func commentCount(for id: UUID) -> Int { 14 + Int(stableSeed(for: id) % 9) }

    static func lines(for video: LocalVideo) -> [Line] {
        let seed = stableSeed(for: video.id)
        var generator = ConversationRandom(state: seed)
        var general = phrases.shuffled(using: &generator)
        let genre = video.bundledClip?.genre ?? .pop
        let specific = genre.discussionPrompts.shuffled(using: &generator)
        general = Array(specific.prefix(3)) + general
        let names = ["Emma", "Jay", "Sofia", "Marcus", "Chloe", "Daniel", "Maya", "Alex",
                     "Lena", "Noah", "Riley", "Oliver", "Nina", "Ethan", "Grace", "Lucas",
                     "Zoe", "Theo", "Ruby", "Leo", "Eva", "Finn", "Aria", "Miles"]
        let people = names.indices.shuffled(using: &generator)
        let count = commentCount(for: video.id)
        return general.prefix(count).enumerated().map { index, text in
            let person = people[index % people.count]
            return Line(name: names[person], text: text, avatarAsset: ArtistPortraits.asset(forName: names[person]))
        }
    }

    private struct ConversationRandom: RandomNumberGenerator {
        var state: UInt64
        mutating func next() -> UInt64 {
            state &+= 0x9E3779B97F4A7C15
            var value = state
            value = (value ^ (value >> 30)) &* 0xBF58476D1CE4E5B9
            value = (value ^ (value >> 27)) &* 0x94D049BB133111EB
            return value ^ (value >> 31)
        }
    }
}
