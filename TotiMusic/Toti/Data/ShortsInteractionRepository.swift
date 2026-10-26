import Foundation

struct ShortsInteractionSnapshot: Codable {
    var schemaVersion = 1
    var liked: Set<UUID> = []
    var comments: [UUID: [ShortComment]] = [:]
    var completedShares: [UUID: Int] = [:]
    /// Extra live-room taps after the first like. Missing on older files.
    var bonusLikes: [UUID: Int]? = nil
    /// Independent room applause, never membership in the short-video Liked collection.
    var liveLikes: [UUID: Int]? = nil
}

/// Separate from library saves so profile/favorite updates cannot overwrite discussions.
actor ShortsInteractionRepository {
    private let url: URL
    init(root: URL) { url = root.appendingPathComponent("shorts-interactions-v1.json") }

    func load() throws -> ShortsInteractionSnapshot {
        let data: Data
        do { data = try Data(contentsOf: url) }
        catch let error as NSError where error.domain == NSCocoaErrorDomain && error.code == NSFileReadNoSuchFileError {
            return ShortsInteractionSnapshot()
        }
        var snapshot = try JSONDecoder().decode(ShortsInteractionSnapshot.self, from: data)
        guard snapshot.schemaVersion == 1 else { throw LocalLibraryError.unsupportedVersion }
        guard snapshot.completedShares.values.allSatisfy({ $0 >= 0 }) else { throw LocalLibraryError.unreadableLibrary }
        if let bonus = snapshot.bonusLikes, bonus.values.contains(where: { $0 < 0 }) {
            throw LocalLibraryError.unreadableLibrary
        }
        if let likes = snapshot.liveLikes, likes.values.contains(where: { $0 < 0 }) {
            throw LocalLibraryError.unreadableLibrary
        }
        for entries in snapshot.comments.values {
            let identifiers = Set(entries.map(\.id))
            let roots = Set(entries.filter { $0.parentID == nil }.map(\.id))
            guard identifiers.count == entries.count,
                  entries.allSatisfy({ entry in
                      guard let parent = entry.parentID else { return true }
                      return parent != entry.id && roots.contains(parent)
                  }) else { throw LocalLibraryError.unreadableLibrary }
        }
        // Only migrate IDs explicitly classified as Live. Preserve unknown/imported
        // identities and short-video reactions because older records have no origin field.
        var migrated = false
        var live = snapshot.liveLikes ?? [:]
        var bonus = snapshot.bonusLikes ?? [:]
        for clip in MusicVideoCatalog.entries where clip.surface == .live {
            let first = snapshot.liked.remove(clip.id) != nil ? 1 : 0
            let extra = bonus.removeValue(forKey: clip.id) ?? 0
            guard first > 0 || extra > 0 else { continue }
            let (legacy, legacyOverflow) = first.addingReportingOverflow(extra)
            let (total, totalOverflow) = live[clip.id, default: 0].addingReportingOverflow(legacy)
            guard !legacyOverflow, !totalOverflow else { throw LocalLibraryError.unreadableLibrary }
            live[clip.id] = total
            migrated = true
        }
        if migrated {
            snapshot.liveLikes = live
            snapshot.bonusLikes = bonus.isEmpty ? nil : bonus
            try save(snapshot)
        }
        return snapshot
    }

    func save(_ snapshot: ShortsInteractionSnapshot) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONEncoder().encode(snapshot).write(to: url,
            options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
    }
}
