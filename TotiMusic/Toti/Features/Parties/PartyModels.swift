import Foundation

enum PartyCategory: String, CaseIterable, Identifiable {
    case hipHop, kPop, jazz, freestyle, ballet, house
    var id: String { rawValue }
    var title: String {
        switch self {
        case .hipHop: return "Pop"; case .kPop: return "Soul"; case .jazz: return "Jazz"
        case .freestyle: return "Acoustic"; case .ballet: return "Classical"; case .house: return "Electronic"
        }
    }
    var asset: String { "PartyCategory-\(rawValue)" }
    var symbol: String {
        switch self {
        case .hipHop: return "waveform"; case .kPop: return "star.fill"; case .jazz: return "music.note"
        case .freestyle: return "figure.dance"; case .ballet: return "sparkles"; case .house: return "opticaldisc"
        }
    }
}

enum PartyRoomType: String, CaseIterable, Identifiable {
    case voice = "Voice party", video = "Video party"
    var id: String { rawValue }
}
enum PartyCardAppearance { case standard, accent }
struct PartyParticipant: Identifiable {
    let id: String
    let asset: String?
    let name: String
    var artworkURL: URL? = nil
}
struct PartyPopularity {
    let value: Int
    let label: String
}
struct PartyRoom: Identifiable, Hashable {
    let id: String
    var title: String
    var description: String
    var type: PartyRoomType
    var category: PartyCategory
    var appearance: PartyCardAppearance = .standard
    var tag: String? = nil
    var participants: [PartyParticipant] = []
    var popularity: PartyPopularity? = nil
    var onlineCount: Int? = nil
    var draftID: UUID? = nil
    var coverAsset: String? = nil
    var coverURL: URL? = nil
    var isCommunityArtwork = false
    static func == (lhs: Self, rhs: Self) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

/// Published room artwork characters are not Auth identities or live attendees.
struct CommunityVoiceRoom: Decodable {
    struct Person: Decodable {
        let name: String
        let asset: String
        let url: URL
    }
    let id: UUID
    let title: String
    let description: String
    let category: String
    let cover_asset: String
    let cover_url: URL
    let people: [Person]

    var room: PartyRoom {
        PartyRoom(id: "community-artwork:" + id.uuidString.lowercased(), title: title,
            description: description, type: .voice,
            category: PartyCategory(rawValue: category) ?? .freestyle,
            participants: people.enumerated().map { index, person in
                PartyParticipant(id: "community-artwork:\(id.uuidString):\(index)",
                    asset: person.asset, name: person.name, artworkURL: person.url)
            }, coverAsset: cover_asset, coverURL: cover_url, isCommunityArtwork: true)
    }
}
struct PartyFilter: Equatable {
    enum Kind: String, CaseIterable, Identifiable {
        case all = "All rooms", voice = "Voice", video = "Video"
        var id: String { rawValue }
    }
    var kind: Kind = .all
    var popularFirst = false
    var isActive: Bool { kind != .all || popularFirst }
    func includes(_ room: PartyRoom) -> Bool {
        kind == .all || (kind == .voice && room.type == .voice) || (kind == .video && room.type == .video)
    }
}

enum PartyTool: String, Identifiable {
    case mood, cards, orbit
    var id: String { rawValue }
    var title: String {
        switch self { case .mood: return "Listening mood"; case .cards: return "Conversation cards"; case .orbit: return "Listening circle" }
    }
}

/// Authored membership rosters, not a presence response from a voice service.
/// Every dancer has one portrait, and that portrait is not reused for anyone else.
enum MusicRoomCatalog {
    private static let names: [[String]] = [
        ["Maya", "Luca", "Elena", "Owen"],
        ["Emma", "Jay", "Priya", "Lucas", "Nina", "Theo"],
        ["Sofia", "Marcus", "Isla"],
        ["Aria", "Noah", "Zoe", "Finn", "Ivy"],
        ["Chloe", "Ethan", "Ruby", "Adam", "Leah", "Oscar", "Mila", "Alex"],
        ["Grace", "Oliver", "Ella", "Jude"],
        ["Freya", "Leo", "Alice", "Hugo", "Lily", "Max", "Eva"],
        ["Hazel", "James", "Rose", "Daniel", "Lucy", "Felix", "Clara", "Ben", "Mabel", "Cole"]
    ]
    private static func people(_ index: Int) -> [PartyParticipant] {
        names[index].enumerated().map { offset, name in
            PartyParticipant(id: "dancer-\(index)-\(offset)", asset: ArtistPortraits.asset(forName: name), name: name)
        }
    }
    private static func room(_ id: String, _ title: String, _ description: String, _ category: PartyCategory,
                             _ index: Int, type: PartyRoomType = .voice, accent: Bool = false, tag: String? = nil) -> PartyRoom {
        let participants = people(index)
        return PartyRoom(id: id, title: title, description: description, type: type, category: category,
            appearance: accent ? .accent : .standard, tag: tag, participants: participants,
            popularity: .init(value: participants.count * 3, label: "\(participants.count * 3)"), onlineCount: participants.count)
    }
    static let rooms: [PartyRoom] = [
        room("hip-hop-crew", "The Pop Lounge", "Share favorite hooks and the songs you cannot stop replaying.", .hipHop, 0),
        room("k-pop-combo", "Soul After Hours", "Warm vocals, favorite records and stories behind the songs.", .kPop, 1),
        room("jazz-afterhours", "Blue Note Room", "Talk improvisation, timeless records and late-night jazz.", .jazz, 2),
        room("freestyle-circle", "Acoustic Corner", "Strings, stripped-back songs and a space to listen closely.", .freestyle, 3),
        room("dance-camera", "Studio Stories", "Compare recording ideas, microphone setups and first takes.", .hipHop, 4),
        room("ballet-circle", "Piano & Strings", "A quiet room for piano pieces, orchestral favorites and new discoveries.", .ballet, 5),
        room("house-friends", "Electronic Frequencies", "Discuss synth textures, beat-making and favorite electronic records.", .house, 6),
        room("practice-break", "Songwriter Circle", "Share the stories that spark a melody and encourage each other.", .freestyle, 7),
    ]
    static func room(from draft: VoiceRoomDraft) -> PartyRoom {
        PartyRoom(id: draft.id.uuidString, title: draft.title, description: draft.description,
                  type: draft.partyType.flatMap(PartyRoomType.init(rawValue:)) ?? .voice,
                  category: draft.danceCategory.flatMap(PartyCategory.init(rawValue:)) ?? .freestyle,
                  draftID: draft.id)
    }
}
