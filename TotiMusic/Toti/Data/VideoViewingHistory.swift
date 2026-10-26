import Foundation

/// A separate atomic file prevents playback history from racing profile/chat saves.
actor VideoViewingHistory {
    private let url: URL
    private var records: [String: Date]?
    private var recordingEnabled = false
    init(root: URL) { url = root.appendingPathComponent("video-viewing-history.json") }

    func load() throws -> [UUID: Date] {
        if records == nil {
            do { records = try JSONDecoder().decode([String: Date].self, from: Data(contentsOf: url)) }
            catch let error as NSError where error.domain == NSCocoaErrorDomain && error.code == NSFileReadNoSuchFileError {
                records = [:]
            }
        }
        return Dictionary(uniqueKeysWithValues: (records ?? [:]).compactMap { key, date in
            UUID(uuidString: key).map { ($0, date) }
        })
    }

    // Actor isolation drains earlier writes before account deletion starts.
    func setRecordingEnabled(_ enabled: Bool) { recordingEnabled = enabled }
    func clearMemory() { records = nil }

    func record(_ id: UUID, at date: Date) throws {
        guard recordingEnabled else { return }
        _ = try load()
        var updated = records ?? [:]
        updated[id.uuidString] = max(updated[id.uuidString] ?? .distantPast, date)
        // Keep the local file bounded without modifying the user's media library.
        if updated.count > 2000 {
            updated = Dictionary(uniqueKeysWithValues: updated.sorted { $0.value > $1.value }.prefix(2000).map { ($0.key, $0.value) })
        }
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONEncoder().encode(updated).write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        records = updated
    }
}
