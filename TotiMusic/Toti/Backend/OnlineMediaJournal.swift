import CryptoKit
import Foundation
import Supabase

struct OnlineMediaRevision: Codable, Sendable {
    let id: UUID
    let entity_id: UUID
    let kind: String
    let status: String
    let sha256: String
    var owner_feedback: String?
}

/// Contains only photos explicitly submitted by this account. Original Photos items
/// and the independent local archive are never read. Bytes survive uncertain uploads.
actor OnlineMediaJournal {
    struct Entry: Codable, Sendable {
        let revisionID: UUID
        let entityID: UUID
        let kind: String
        let digest: String
        let jpeg: Data
        let createdAt: Date
        var revision: OnlineMediaRevision?
    }

    private let root: URL
    private var entries: [UUID: [Entry]] = [:]
    init(root: URL) { self.root = root }

    func begin(account: UUID, jpeg: Data, kind: String, entityID: UUID) throws -> Entry {
        var items = try load(account)
        let digest = SHA256.hash(data: jpeg).map { String(format: "%02x", $0) }.joined()
        if let existing = items.first(where: { $0.entityID == entityID && $0.kind == kind && $0.digest == digest }) {
            return existing
        }
        // Resolve the previous submitted intent before replacing its bytes or identity.
        guard !items.contains(where: { $0.entityID == entityID && $0.kind == kind }) else {
            throw TotiBackendError.pendingChange
        }
        guard items.count < 32 else { throw TotiBackendError.morePendingOperations }
        let entry = Entry(revisionID: UUID(), entityID: entityID, kind: kind,
                          digest: digest, jpeg: jpeg, createdAt: Date())
        items.append(entry)
        try persist(items, account: account)
        entries[account] = items
        return entry
    }

    func pending(account: UUID) throws -> [Entry] { try load(account).sorted { $0.createdAt < $1.createdAt } }

    /// Acknowledgement remains reusable until the owning profile/post is attached.
    func acknowledge(_ entry: Entry, revision: OnlineMediaRevision, account: UUID) {
        guard var items = try? load(account), let index = items.firstIndex(where: { $0.revisionID == entry.revisionID }) else { return }
        items[index].revision = revision
        entries[account] = items
        try? persist(items, account: account)
    }

    func complete(revisionID: UUID, account: UUID) {
        guard var items = try? load(account) else { return }
        items.removeAll { $0.revisionID == revisionID }
        do { try persist(items, account: account); entries[account] = items }
        catch { /* Keep the reusable acknowledgement when cleanup cannot be persisted. */ }
    }

    func complete(entityID: UUID, kind: String, account: UUID) {
        guard var items = try? load(account) else { return }
        items.removeAll { $0.entityID == entityID && $0.kind == kind }
        do { try persist(items, account: account); entries[account] = items }
        catch { /* Preserve retry bytes until cleanup is durable. */ }
    }

    func reject(_ entry: Entry, account: UUID) throws {
        var items = try load(account)
        items.removeAll { $0.revisionID == entry.revisionID }
        try persist(items, account: account)
        entries[account] = items
    }

    /// Release only the local upload intent referenced by an authoritatively rejected
    /// record mutation. This does not remove the immutable server object or source photo.
    func rejectAttachment(for mutation: OnlineOperationJournal.Entry, account: UUID) throws {
        let kind: String
        switch mutation.action {
        case "profile.save": kind = "avatar"
        case "post.save": kind = "post"
        default: return
        }
        guard let value = mutation.payload?["media_revision_id"]?.stringValue,
              let revisionID = UUID(uuidString: value),
              let upload = try load(account).first(where: {
                  $0.revisionID == revisionID && $0.entityID == mutation.entityID && $0.kind == kind
              }) else { return }
        try reject(upload, account: account)
    }

    private func load(_ account: UUID) throws -> [Entry] {
        if let cached = entries[account] { return cached }
        guard FileManager.default.fileExists(atPath: file(account).path) else { entries[account] = []; return [] }
        do {
            let items = try JSONDecoder().decode([Entry].self, from: Data(contentsOf: file(account)))
            entries[account] = items
            return items
        } catch { throw TotiBackendError.localPersistence }
    }

    private func file(_ account: UUID) -> URL {
        root.appendingPathComponent(account.uuidString.lowercased(), isDirectory: true)
            .appendingPathComponent("media-uploads.json")
    }

    private func persist(_ items: [Entry], account: UUID) throws {
        do {
            let url = file(account)
            let directory = url.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            var excluded = directory
            var values = URLResourceValues()
            values.isExcludedFromBackup = true
            try excluded.setResourceValues(values)
            try JSONEncoder().encode(items).write(to: url, options: [.atomic, .completeFileProtection])
        } catch { throw TotiBackendError.localPersistence }
    }
}

/// A testable recovery boundary shared by direct saves and Retry pending changes.
/// Unknown outcomes retain both durable identities and their exact submitted bytes.
enum OnlineMutationRecovery {
    @discardableResult
    static func discardRejectedIntent(error: Error, entry: OnlineOperationJournal.Entry, account: UUID,
                                      operations: OnlineOperationJournal, media: OnlineMediaJournal) async throws -> Bool {
        guard let failure = error as? PostgrestError, let code = failure.code,
              code == "P0001" || code == "42501" || code == "40001" || code.hasPrefix("22") || code.hasPrefix("23") else {
            return false
        }
        // Persist media cleanup first. If it fails, retain the operation so an explicit
        // retry can revisit this cleanup instead of leaving an unreachable media lock.
        try await media.rejectAttachment(for: entry, account: account)
        try await operations.reject(entry, account: account)
        return true
    }
}
