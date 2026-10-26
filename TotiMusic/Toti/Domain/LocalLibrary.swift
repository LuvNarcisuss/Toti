import Foundation

struct LocalProfile: Codable, Equatable {
    var displayName = "Music lover"
    var biography = "Collecting songs, sharing stories."
    var avatarSymbol = "figure.dance"
    /// Optional so older libraries still decode. The photo file lives beside the library.
    var hasCustomAvatar: Bool? = nil
}

struct LocalVideo: Codable, Identifiable, Equatable {
    let id: UUID
    var title: String
    let fileExtension: String
    let duration: Double
    let importedAt: Date
    var isSaved: Bool
    // Older imports remain in the personal library until explicitly categorized.
    var isDance: Bool? = nil

    var bundledClip: MusicVideo? { MusicVideoCatalog.entries.first { $0.id == id } }
    var isBundled: Bool { bundledClip != nil }

    var durationLabel: String {
        let seconds = Int(duration)
        return String(format: "%d:%02d", seconds / 60, seconds % 60)
    }
}

enum RoomTopic: String, Codable, CaseIterable, Identifiable {
    case music = "Music", everyday = "Everyday", unwind = "Unwind"
    var id: String { rawValue }
    var title: String {
        switch self {
        case .music: return "Beats"
        case .everyday: return "Practice"
        case .unwind: return "Cooldown"
        }
    }
    var symbol: String {
        switch self {
        case .music: return "music.note"
        case .everyday: return "figure.dance"
        case .unwind: return "moon.stars.fill"
        }
    }
}

struct VoiceRoomDraft: Codable, Identifiable, Equatable {
    var id = UUID()
    var title = ""
    var description = ""
    var topic: RoomTopic = .music
    var seatCount = 6
    var updatedAt = Date()
    var danceCategory: String? = nil
    var partyType: String? = nil
}

struct LocalLibrary: Codable {
    var schemaVersion = 1
    var lounge: LoungeState? = nil
    var notebook: NotebookState? = nil
    var profile = LocalProfile()
    var videos: [LocalVideo] = []
    var roomDrafts: [VoiceRoomDraft] = []
    var messageDraft = ""
    // Optional for compatibility with existing version-1 snapshots.
    var savedDemoVideoIDs: Set<UUID>? = nil
    var chatState: ChatLocalState? = nil
    var creatorState: CreatorLocalState? = nil
    var contentSafety: ContentSafetyState? = nil
    var agreementAcceptance: AgreementAcceptance? = nil
    var submissions: [CreationSubmission]? = nil
    /// Phrases written on this device, plus keep order and learned marks. Missing on older libraries.
    var phraseBook: PhraseBookState? = nil
}

struct AppNotice: Identifiable {
    let id = UUID()
    let title: String
    let message: String
}

enum LocalLibraryError: LocalizedError {
    case unreadableLibrary, unsupportedVersion, storageUnavailable, accountDeletionFailed
    case invalidVideo, videoTooLarge, importFailed, missingVideo, photoUnavailable

    var errorDescription: String? {
        switch self {
        case .accountDeletionFailed:
            return "Account deletion could not finish. Tap Try again to complete it before continuing."
        case .unreadableLibrary:
            return "Your saved library could not be read. Existing files have been kept. Try again before making changes."
        case .unsupportedVersion:
            return "This library was saved by a different app version. Update the app before making changes."
        case .storageUnavailable:
            return "Your changes could not be saved on this device. Check available storage and try again."
        case .invalidVideo:
            return "Choose a playable video with a duration of up to 30 minutes. Your original file has not been changed."
        case .videoTooLarge:
            return "Choose a video smaller than 250 MB. Your original file has not been changed."
        case .importFailed:
            return "The video could not be imported. If it is stored in iCloud, download it in Photos, then try again."
        case .missingVideo:
            return "This video is no longer available. Add it again from Photos."
        case .photoUnavailable:
            return "Choose another photo."
        }
    }
}
