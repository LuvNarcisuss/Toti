import Foundation

struct CreatorProfile: Identifiable, Codable {
    let id: String
    let name: String
    let biography: String
    var coverURL: URL? = nil
    var avatarAsset: String? = nil
    var avatarSymbol = "figure.dance"
    var likes: Int? = nil
    var following: Int? = nil
    var followers: Int? = nil
    var ipRegion: String? = nil
    var sourceURL: URL? = nil
    var isLocalOwner = false

    var relationshipStatistics: CreatorStatistics {
        let baseline = CreatorStatistics.authored(for: id)
        // Per-work totals are derived by AppStore. Retain legacy stored likes for decoding only.
        return CreatorStatistics(likes: 0, saves: 0,
                                 following: following ?? baseline.following,
                                 followers: followers ?? baseline.followers)
    }

    static func from(video: LocalVideo, profile: LocalProfile, coverURL: URL) -> Self {
        let clip = video.bundledClip
        return Self(id: video.creatorID, name: video.creatorName(profile: profile),
                    biography: clip == nil ? profile.biography : "Music films. Vocals, stories and studio sessions.",
                    coverURL: coverURL,
                    avatarAsset: clip != nil || profile.avatarSymbol == "figure.dance"
                        ? MusicPhotography.creatorAvatar(for: video.creatorID) : nil,
                    avatarSymbol: clip == nil ? profile.avatarSymbol : "figure.dance",
                    sourceURL: clip?.sourceURL, isLocalOwner: clip == nil)
    }

    static func from(room: LiveRoomConfiguration) -> Self {
        Self(id: "room-creator:\(room.id)", name: room.streamer.name,
             biography: "Finding connection through music.", coverURL: room.media.coverURL,
             avatarAsset: room.streamer.avatarAsset ?? MusicPhotography.creatorAvatar(for: "room-creator:\(room.id)"),
             sourceURL: room.media.sourceURL)
    }

    static func artist(_ person: PartyParticipant) -> Self {
        Self(
            id: person.id, name: person.name,
            biography: "Sharing songs and meeting fellow music lovers.",
            avatarAsset: person.asset ?? MusicPhotography.creatorAvatar(for: person.id))
    }

    static func signedIn(_ profile: LocalProfile) -> Self {
        Self(
            id: "local-owner", name: profile.displayName, biography: profile.biography,
            avatarAsset: MusicPhotography.creatorAvatar(for: "local-owner"),
            avatarSymbol: profile.avatarSymbol, isLocalOwner: true)
    }
}

extension LocalVideo {
    var creatorID: String { bundledClip.map { "pexels:\($0.creator)" } ?? "local-owner" }
}

/// Optional in LocalLibrary for backward-compatible decoding of saved libraries.
struct CreatorLocalState: Codable {
    var followedIDs: Set<String> = []
    var messageDrafts: [String: String] = [:]
    var conversations: [String: CreatorConversationRecord]? = nil
}

struct CreatorConversationRecord: Codable {
    var creator: CreatorProfile
    var updatedAt: Date?
}

/// Local presentation figures, not counts fetched from the credited media source.
/// Stable IDs keep each creator's figures consistent across videos and app launches.
struct CreatorStatistics {
    let likes: Int
    let saves: Int
    let following: Int
    let followers: Int

    static func authored(for creatorID: String) -> Self {
        func value(_ field: String) -> UInt64 {
            (creatorID + ":" + field).utf8.reduce(UInt64(14695981039346656037)) {
                ($0 ^ UInt64($1)) &* 1099511628211
            }
        }
        let following = 10 + Int(value("following") % 21)
        let followers = 10 + Int(value("followers") % 20)
        return Self(likes: 0, saves: 0, following: following, followers: followers)
    }
}
