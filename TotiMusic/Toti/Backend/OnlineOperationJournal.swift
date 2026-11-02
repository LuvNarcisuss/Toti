import CryptoKit
import Foundation

/// One actor owns all account journal files. Source libraries and original media are never opened.
actor OnlineOperationJournal {
    struct Entry: Codable, Sendable {
        let operationID: UUID
        let entityID: UUID
        let action: String
        let payloadDigest: String
        let createdAt: Date
        /// Optional for compatibility with journals written before recoverable payloads.
        var payload: [String: JSONValue]?
        var receipt: OnlineMutationReceipt?
    }

    private var journals: [UUID: [Entry]] = [:]
    private let root: URL
    private let eventActions: Set<String> = [
        "comment.save", "message.send", "group.create", "conversation.open", "report.save"
    ]

    init(root: URL) { self.root = root }

    func begin(account: UUID, action: String, entityID: UUID, payload: [String: JSONValue]) throws -> Entry {
        var entries = try load(account)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let bytes = try encoder.encode(payload)
        let digest = SHA256.hash(data: bytes).map { String(format: "%02x", $0) }.joined()
        let isEvent = eventActions.contains(action)
        if let index = entries.firstIndex(where: {
            $0.action == action && $0.payloadDigest == digest && (isEvent || $0.entityID == entityID)
        }) {
            // A user retry can recover a legacy digest-only entry without changing its identity.
            if entries[index].payload == nil {
                entries[index].payload = payload
                try persist(entries, account: account)
                journals[account] = entries
            }
            return entries[index]
        }
        if !isEvent, entries.contains(where: { $0.action == action && $0.entityID == entityID }) {
            throw TotiBackendError.pendingChange
        }
        let entry = Entry(operationID: UUID(), entityID: entityID, action: action,
                          payloadDigest: digest, createdAt: Date(), payload: payload)
        entries.append(entry)
        try persist(entries, account: account)
        journals[account] = entries
        return entry
    }

    /// Recovery is explicit, authenticated and restricted to this account by the service.
    func pending(account: UUID) throws -> [Entry] {
        try load(account).sorted {
            $0.createdAt == $1.createdAt
                ? $0.operationID.uuidString < $1.operationID.uuidString
                : $0.createdAt < $1.createdAt
        }
    }

    /// Record acknowledgement before removing the pending entry. Disk failure never changes a server receipt into failure.
    func acknowledge(_ entry: Entry, receipt: OnlineMutationReceipt, account: UUID) {
        guard var entries = try? load(account), let index = entries.firstIndex(where: { $0.operationID == entry.operationID }) else { return }
        entries[index].receipt = receipt
        journals[account] = entries
        try? persist(entries, account: account)
    }

    @discardableResult
    func complete(_ entry: Entry, account: UUID) -> Bool {
        guard var entries = try? load(account) else { return false }
        entries.removeAll { $0.operationID == entry.operationID }
        // Only forget the acknowledged entry after durable removal. If it fails, reuse the receipt on retry.
        do { try persist(entries, account: account); journals[account] = entries; return true }
        catch { return false }
    }

    func reject(_ entry: Entry, account: UUID) throws {
        var entries = try load(account)
        entries.removeAll { $0.operationID == entry.operationID }
        try persist(entries, account: account)
        journals[account] = entries
    }

    private func load(_ account: UUID) throws -> [Entry] {
        if let cached = journals[account] { return cached }
        let url = file(account)
        guard FileManager.default.fileExists(atPath: url.path) else {
            journals[account] = []; return []
        }
        do {
            let entries = try JSONDecoder().decode([Entry].self, from: Data(contentsOf: url))
            journals[account] = entries
            return entries
        } catch { throw TotiBackendError.localPersistence }
    }

    private func file(_ account: UUID) -> URL {
        root.appendingPathComponent(account.uuidString.lowercased(), isDirectory: true)
            .appendingPathComponent("operations.json")
    }

    private func persist(_ entries: [Entry], account: UUID) throws {
        do {
            let url = file(account)
            let directory = url.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            var excluded = directory
            var values = URLResourceValues()
            values.isExcludedFromBackup = true
            try excluded.setResourceValues(values)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys]
            try encoder.encode(entries).write(to: url, options: [.atomic, .completeFileProtection])
        } catch { throw TotiBackendError.localPersistence }
    }
}
