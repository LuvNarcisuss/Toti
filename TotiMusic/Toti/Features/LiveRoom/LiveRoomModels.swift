import Foundation

enum LiveRoomMode: String, CaseIterable, Identifiable {
    case choreography = "Studio session", freestyle = "Open mic"
    var id: String { rawValue }
    var title: String { rawValue }
    var symbol: String { "figure.dance" }
}

enum LiveMediaSource: Equatable {
    case local(URL), remote(URL), coverOnly
    var url: URL? {
        switch self { case .local(let url), .remote(let url): return url; case .coverOnly: return nil }
    }
}

enum LiveVideoScaling { case fill, fit }

struct LiveRoomMedia {
    var source: LiveMediaSource
    var scaling: LiveVideoScaling = .fill
    var coverAsset: String? = nil
    var coverURL: URL? = nil
    var credit: String? = nil
    var sourceURL: URL? = nil
}

struct Streamer {
    var name: String
    var avatarAsset: String? = nil
    var likeCount = 0
}

struct AudienceMember: Identifiable {
    let id: String
    var name: String
    var avatarAsset: String? = nil
    var symbol: String = "person.fill"
}

struct UserBadge: Identifiable {
    enum Kind { case level, fan, moderator, streamer }
    let kind: Kind
    let text: String
    var id: String { "\(kind)-\(text)" }
}

struct LiveComment: Identifiable {
    enum Kind { case regular, streamer, moderator, arrival, system }
    var id = UUID()
    var nickname: String
    var text: String
    var badges: [UserBadge] = []
    var kind: Kind = .regular
    var isLocal = false
}

struct LiveRoomConfiguration: Identifiable {
    var id: String
    var mode: LiveRoomMode
    var title: String
    var streamer: Streamer
    var audience: [AudienceMember] = []
    var initialComments: [LiveComment]
    var commentLoop: [LiveComment]
    var media: LiveRoomMedia
    var sourceVideoID: UUID? = nil
    var shareText: String { "\(title) · Find your rhythm with Toti." }
}

/// Authored chat atmosphere, not a network subscription or real account activity.
/// Handles are fictional. No viewer counts, delivery receipts or transactions are generated.
enum MusicCommentScript {
    static let lines: [(String, String)] = MusicEditorial.live.enumerated().map { index, text in
        let handles = ["VelvetVoice", "VinylHeart", "ChorusClub", "SoundStories", "IndieHour", "TempoTrail", "SoulNotes", "GoldenMic"]
        return (handles[index % handles.count], text)
    }

    static var comments: [LiveComment] { lines.map { LiveComment(nickname: $0.0, text: $0.1) } }
}

enum MusicRoomLibrary {
    static func room(video: LocalVideo, videoURL: URL, coverURL: URL, displayName: String) -> LiveRoomConfiguration {
        let opening = MusicDiscussionContent.lines(for: video).map {
            LiveComment(nickname: $0.name, text: $0.text)
        }
        let sequence = opening + MusicCommentScript.comments.shuffled()
        return LiveRoomConfiguration(id: video.id.uuidString,
            mode: video.bundledClip?.genre == .acoustic ? .freestyle : .choreography,
            title: video.title,
            streamer: Streamer(name: video.bundledClip?.creator ?? displayName,
                               avatarAsset: MusicPhotography.creatorAvatar(for: video.creatorID)),
            initialComments: Array(sequence.prefix(5)), commentLoop: sequence,
            media: LiveRoomMedia(source: .local(videoURL), coverURL: coverURL,
                credit: video.bundledClip.map { "\($0.creator) / Pexels" }, sourceURL: video.bundledClip?.sourceURL), sourceVideoID: video.id)
    }
    static func featured(_ mode: LiveRoomMode) -> LiveRoomConfiguration {
        let entry = mode == .freestyle ? MusicVideoCatalog.entries[1] : MusicVideoCatalog.entries[0]
        return room(video: entry.localVideo, videoURL: entry.resourceURL(fileExtension: "mp4"),
                    coverURL: entry.resourceURL(fileExtension: "jpg"), displayName: entry.creator)
    }
}
