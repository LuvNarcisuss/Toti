import Foundation

enum MusicSurface { case live, shorts }

/// Music metadata is authored separately from filenames and licensing evidence.
enum MusicGenre: String, CaseIterable {
    case pop, soul, jazz, acoustic, classical, electronic
    var title: String { rawValue.capitalized }
    var caption: String {
        switch self {
        case .pop: return "A voice, a hook, a moment to remember."
        case .soul: return "Warm vocals and stories that stay with you."
        case .jazz: return "Phrasing, feeling and room to improvise."
        case .acoustic: return "Stripped back to the sound and the story."
        case .classical: return "Listen for the detail in every note."
        case .electronic: return "New textures, familiar feelings."
        }
    }
    var discussionPrompts: [String] {
        ["What do you enjoy most about " + title.lowercased() + "?", caption,
         "Which " + title.lowercased() + " record would you recommend next?"]
    }
}

struct MusicVideo {
    let id: UUID
    let title: String
    let creator: String
    let assetName: String
    let duration: Double
    let surface: MusicSurface
    let sourceURL: URL
    let genre: MusicGenre
    let hasOriginalAudio: Bool
    let collectionGeneration: Int
    var localVideo: LocalVideo {
        // isDance is a legacy persistence key; in Toti it stores explicit music-feed classification.
        LocalVideo(id: id, title: title, fileExtension: "mp4", duration: duration,
                   importedAt: Date(timeIntervalSince1970: 0), isSaved: false, isDance: true)
    }
    func resourceURL(fileExtension: String) -> URL {
        Bundle.main.url(forResource: assetName, withExtension: fileExtension)
            ?? Bundle.main.url(forResource: assetName, withExtension: fileExtension, subdirectory: "MusicMedia")
            ?? Bundle.main.bundleURL.appendingPathComponent("\(assetName).\(fileExtension)")
    }
}

enum MusicVideoCatalog {
    static func shuffledDiscoveryIDs(for surface: MusicSurface) -> [UUID] {
        let groups = Dictionary(grouping: entries.filter { $0.surface == surface }, by: \.collectionGeneration)
        return groups.keys.sorted(by: >).flatMap { (groups[$0] ?? []).shuffled().map(\.id) }
    }
    static let entries: [MusicVideo] = [
        MusicVideo(id: UUID(uuidString: "6D9A5EA7-6039-5149-9B37-307CDE241FA5")!, title: "Soul in the spotlight",
            creator: "ANTONI SHKRABA production", assetName: "music-8042838", duration: 13.36, surface: .live,
            sourceURL: URL(string: "https://www.pexels.com/video/a-woman-singing-with-a-microphone-8042838/")!, genre: .soul, hasOriginalAudio: false, collectionGeneration: 20261026),
        MusicVideo(id: UUID(uuidString: "72493D8B-83C3-59E7-BF3D-43907942D855")!, title: "The velvet vocal booth",
            creator: "Los Muertos Crew", assetName: "music-7586634", duration: 28.403375, surface: .live,
            sourceURL: URL(string: "https://www.pexels.com/video/a-woman-singing-while-using-condenser-microphone-7586634/")!, genre: .pop, hasOriginalAudio: false, collectionGeneration: 20261026),
        MusicVideo(id: UUID(uuidString: "D7A4AC09-627A-5B0F-BF42-6E9C826268D0")!, title: "Midnight microphone",
            creator: "cottonbro studio", assetName: "music-9419269", duration: 25.76, surface: .live,
            sourceURL: URL(string: "https://www.pexels.com/video/a-woman-holding-the-microphone-while-singing-9419269/")!, genre: .jazz, hasOriginalAudio: false, collectionGeneration: 20261026),
        MusicVideo(id: UUID(uuidString: "ACD2815E-2E43-5FB0-A2EC-700659F271EF")!, title: "One take, all heart",
            creator: "ANTONI SHKRABA production", assetName: "music-8135078", duration: 10.24, surface: .live,
            sourceURL: URL(string: "https://www.pexels.com/video/man-singing-in-the-music-studio-8135078/")!, genre: .pop, hasOriginalAudio: false, collectionGeneration: 20261026),
        MusicVideo(id: UUID(uuidString: "575E9128-EE24-5E68-83FF-4C532A7D8B1B")!, title: "A verse worth replaying",
            creator: "Ivan S", assetName: "music-8117115", duration: 10.08, surface: .shorts,
            sourceURL: URL(string: "https://www.pexels.com/video/a-man-singing-while-using-microphone-8117115/")!, genre: .acoustic, hasOriginalAudio: false, collectionGeneration: 20261026),
        MusicVideo(id: UUID(uuidString: "13F061AE-F418-5D10-A124-48BC740968E1")!, title: "Inside the recording room",
            creator: "cottonbro studio", assetName: "music-7090702", duration: 24.28, surface: .shorts,
            sourceURL: URL(string: "https://www.pexels.com/video/a-woman-singing-in-a-studio-7090702/")!, genre: .soul, hasOriginalAudio: false, collectionGeneration: 20261026),
        MusicVideo(id: UUID(uuidString: "01D6E1A1-1262-5488-9852-F91D57830970")!, title: "Find your own voice",
            creator: "cottonbro studio", assetName: "music-7087182", duration: 27.76, surface: .shorts,
            sourceURL: URL(string: "https://www.pexels.com/video/a-woman-singing-in-front-of-the-microphone-7087182/")!, genre: .pop, hasOriginalAudio: false, collectionGeneration: 20261026),
        MusicVideo(id: UUID(uuidString: "D92F5C94-6D97-5F2F-88A5-10F2243ECC5A")!, title: "Acoustic afternoon",
            creator: "ANTONI SHKRABA production", assetName: "music-8134898", duration: 10.84, surface: .shorts,
            sourceURL: URL(string: "https://www.pexels.com/video/woman-singing-in-the-microphone-8134898/")!, genre: .acoustic, hasOriginalAudio: false, collectionGeneration: 20261026),
        MusicVideo(id: UUID(uuidString: "6526429F-4E36-51C5-B942-9FD9FFC2F192")!, title: "Between the headphones",
            creator: "ANTONI SHKRABA production", assetName: "music-8134961", duration: 11.24, surface: .shorts,
            sourceURL: URL(string: "https://www.pexels.com/video/woman-singing-with-microphone-8134961/")!, genre: .pop, hasOriginalAudio: false, collectionGeneration: 20261026),
    ]
}
