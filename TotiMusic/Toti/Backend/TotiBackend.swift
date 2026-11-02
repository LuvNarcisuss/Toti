import Combine
import CryptoKit
import Foundation
import ImageIO
import Supabase

/// The sole online session owner. All requests share a gate so a queued account change
/// cannot cause an earlier request to run with a different account's credentials.
@MainActor
final class TotiBackend: ObservableObject {
    static let shared: TotiBackend = {
        #if DEBUG
        if let value = ProcessInfo.processInfo.environment["TOTI_GUEST_ACCEPTANCE"],
           let run = UUID(uuidString: value) {
            let root = URL.applicationSupportDirectory.appendingPathComponent("TotiOnline/Acceptance", isDirectory: true)
                .appendingPathComponent(run.uuidString, isDirectory: true)
            return TotiBackend(storageKey: "toti-acceptance-" + run.uuidString, journalRoot: root)
        }
        #endif
        return TotiBackend()
    }()
    @Published private(set) var accountID: UUID?
    @Published private(set) var generation = 0
    @Published private(set) var deletionPending = false
    private(set) var isTransitioning = false
    var isAuthenticated: Bool { accountID != nil && TotiBackendConfiguration.rolloutEnabled }

    private var gateHeld = false
    private var gateWaiters: [CheckedContinuation<Void, Never>] = []
    private var authObservation: Task<Void, Never>?
    private let authStorageKey: String
    private let attachmentRoot: URL
    private let journal: OnlineOperationJournal
    private let mediaJournal: OnlineMediaJournal
    private var mediaCache: [UUID: Data] = [:]
    private var mediaCacheOrder: [UUID] = []
    private lazy var mediaSession: URLSession = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.urlCache = nil
        configuration.httpCookieStorage = nil
        configuration.urlCredentialStorage = nil
        configuration.httpShouldSetCookies = false
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.timeoutIntervalForRequest = 20
        configuration.timeoutIntervalForResource = 30
        return URLSession(configuration: configuration, delegate: OnlineMediaDownloadDelegate(), delegateQueue: nil)
    }()
    private lazy var client: SupabaseClient = makeClient()

    init(storageKey: String = TotiBackendConfiguration.authStorageKey, journalRoot: URL? = nil) {
        authStorageKey = storageKey
        let root = journalRoot ?? URL.applicationSupportDirectory
            .appendingPathComponent(TotiBackendConfiguration.onlineDirectory, isDirectory: true)
            .appendingPathComponent("Operations", isDirectory: true)
        attachmentRoot = root.appendingPathComponent("ChatAttachments", isDirectory: true)
        journal = OnlineOperationJournal(root: root)
        mediaJournal = OnlineMediaJournal(root: root)
    }

    func restore() async throws {
        try requireRollout()
        let epoch = beginTransition()
        defer { endTransition(epoch) }
        await acquire()
        defer { release() }
        try check(epoch)
        do {
            let session = try await client.auth.session
            try check(epoch)
            let verified = try await client.auth.user()
            try check(epoch)
            guard verified.id == session.user.id else { throw TotiBackendError.accountChanged }
            // The RPC checks live session/account status before returning any data.
            let _: OnlinePage = try await client.rpc("toti_read", params: ReadParameters(p_kind: "profile"))
                .execute().value
            try check(epoch)
            accountID = verified.id
            deletionPending = false
        } catch AuthError.sessionMissing {
            try check(epoch)
            accountID = nil
        }
    }

    /// Reuse the persisted session after interrupted enrollment; never silently replace it.
    func signInAsGuest(agreementVersion: String) async throws {
        try requireRollout()
        guard !agreementVersion.isEmpty, agreementVersion != "unavailable", agreementVersion.count <= 100 else {
            throw TotiBackendError.invalidAgreement
        }
        let epoch = beginTransition()
        defer { endTransition(epoch) }
        await acquire()
        defer { release() }
        try check(epoch)
        try TotiKeychainStorage().verifyAvailable()
        if client.auth.currentSession == nil {
            let created = try await client.auth.signInAnonymously()
            try check(epoch)
            guard client.auth.currentSession?.user.id == created.user.id else {
                throw TotiBackendError.secureSessionUnavailable
            }
        }
        let session = try await client.auth.session
        try check(epoch)
        let user = try await client.auth.user()
        try check(epoch)
        guard user.id == session.user.id else { throw TotiBackendError.accountChanged }
        let _ = try await performMutation(account: user.id, epoch: epoch, action: "enroll", entityID: user.id,
                                          payload: ["agreement_version": .string(agreementVersion)])
        try check(epoch)
        accountID = user.id
        deletionPending = false
    }

    func signOut() async throws {
        // Clearing visible ownership happens before waiting for in-flight requests.
        let epoch = beginTransition()
        defer { endTransition(epoch) }
        await acquire()
        defer { release() }
        try check(epoch)
        guard TotiBackendConfiguration.rolloutEnabled else {
            try TotiKeychainStorage().remove(key: authStorageKey)
            return
        }
        try await client.auth.signOut(scope: .local)
        try check(epoch)
    }

    func page(kind: String, cursor: String? = nil, parentID: UUID? = nil) async throws -> OnlinePage {
        try requireRollout()
        let (account, epoch) = try context()
        await acquire()
        defer { release() }
        try check(epoch, account: account)
        let response: OnlinePage = try await client.rpc("toti_read", params: ReadParameters(
            p_kind: kind, p_cursor: cursor, p_parent_id: parentID)).execute().value
        try check(epoch, account: account)
        guard response.records.count <= 100, response.next_cursor == nil || response.next_cursor != cursor else {
            throw TotiBackendError.invalidResponse
        }
        return response
    }

    /// Only use for small complete collections. Large surfaces must use page() and expose Load more.
    func records(kind: String, parentID: UUID? = nil) async throws -> [OnlineRecord] {
        let (account, epoch) = try context()
        var cursor: String?
        var visited = Set<String>()
        var result: [OnlineRecord] = []
        var positions: [UUID: Int] = [:]
        for _ in 0..<4 {
            let response = try await page(kind: kind, cursor: cursor, parentID: parentID)
            try check(epoch, account: account)
            for record in response.records {
                if let position = positions[record.id] { result[position] = record }
                else { positions[record.id] = result.count; result.append(record) }
            }
            guard let next = response.next_cursor else { return result }
            guard visited.insert(next).inserted else { throw TotiBackendError.invalidResponse }
            cursor = next
        }
        throw TotiBackendError.incompletePage
    }

    func mutate(action: String, entityID: UUID, payload: [String: JSONValue]) async throws -> OnlineMutationReceipt {
        try requireRollout()
        let (account, epoch) = try context()
        await acquire()
        defer { release() }
        try check(epoch, account: account)
        return try await performMutation(account: account, epoch: epoch, action: action,
                                          entityID: entityID, payload: payload)
    }

    func sendChatAttachment(_ data: Data, filename: String, kind: String, messageID: UUID,
                            conversationID: UUID, text: String = "") async throws -> OnlineMutationReceipt {
        try requireRollout()
        let (account, epoch) = try context()
        await acquire()
        defer { release() }
        try check(epoch, account: account)
        guard !data.isEmpty, data.count <= 10_485_760, ["image", "file"].contains(kind),
              !filename.isEmpty, filename.count <= 160, text.count <= 2_000 else { throw TotiBackendError.invalidResponse }
        let directory = attachmentRoot.appendingPathComponent(account.uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let file = directory.appendingPathComponent(messageID.uuidString)
        if FileManager.default.fileExists(atPath: file.path) {
            guard try Data(contentsOf: file) == data else { throw TotiBackendError.invalidResponse }
        } else { try data.write(to: file, options: [.atomic, .completeFileProtection]) }
        let path = account.uuidString.lowercased() + "/" + conversationID.uuidString.lowercased() + "/"
            + messageID.uuidString.lowercased() + (kind == "image" ? ".jpg" : ".bin")
        return try await performMutation(account: account, epoch: epoch, action: "message.attachment", entityID: messageID,
            payload: ["conversation_id": .string(conversationID.uuidString), "path": .string(path),
                      "filename": .string(filename), "kind": .string(kind), "text": .string(text),
                      "sha256": .string(SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined())])
    }

    func chatAttachmentData(_ attachment: ChatAttachment) async throws -> Data {
        try requireRollout()
        let (account, epoch) = try context()
        await acquire()
        defer { release() }
        try check(epoch, account: account)
        guard attachment.path.split(separator: "/").count == 3, !attachment.path.contains(".."),
              attachment.byteCount > 0, attachment.byteCount <= 10_485_760 else { throw TotiBackendError.invalidResponse }
        let data = try await client.storage.from("toti-chat-attachments").download(path: attachment.path, cacheNonce: UUID().uuidString)
        try check(epoch, account: account)
        guard data.count == attachment.byteCount else { throw TotiBackendError.invalidResponse }
        return data
    }

    private func executeAttachment(_ entry: OnlineOperationJournal.Entry, account: UUID, epoch: Int,
                                   payload: [String: JSONValue]) async throws -> OnlineMutationReceipt {
        guard let conversation = payload["conversation_id"]?.stringValue.flatMap(UUID.init(uuidString:)),
              let path = payload["path"]?.stringValue, let filename = payload["filename"]?.stringValue,
              let kind = payload["kind"]?.stringValue else { throw TotiBackendError.invalidResponse }
        let file = attachmentRoot.appendingPathComponent(account.uuidString).appendingPathComponent(entry.entityID.uuidString)
        let data = try Data(contentsOf: file)
        guard data.count <= 10_485_760,
              SHA256.hash(data: data).map({ String(format: "%02x", $0) }).joined() == payload["sha256"]?.stringValue else {
            throw TotiBackendError.invalidResponse
        }
        let storage = client.storage.from("toti-chat-attachments")
        do {
            try await storage.upload(path, data: data,
                options: FileOptions(contentType: kind == "image" ? "image/jpeg" : "application/octet-stream", upsert: false))
        } catch {
            // An uncertain upload can already exist. Immutable bytes must match before finalization.
            let original = error
            guard let existing = try? await storage.download(path: path, cacheNonce: UUID().uuidString), existing == data else { throw original }
        }
        try check(epoch, account: account)
        return try await client.rpc("toti_send_attachment", params: AttachmentParameters(
            p_operation_id: entry.operationID, p_message_id: entry.entityID, p_conversation_id: conversation,
            p_path: path, p_filename: filename, p_kind: kind, p_text: payload["text"]?.stringValue ?? "")).execute().value
    }

    func editorialPosts() async throws -> [OnlineEditorialPost] {
        try requireRollout()
        let (account, epoch) = try context()
        await acquire()
        defer { release() }
        try check(epoch, account: account)
        let response: [OnlineEditorialPost] = try await client.rpc("toti_editorial_posts").execute().value
        try check(epoch, account: account)
        guard response.count <= 50 else { throw TotiBackendError.invalidResponse }
        return response
    }

    func profileReactions(kind: String, cursor: String? = nil) async throws -> OnlinePage {
        try requireRollout()
        guard ["like", "save"].contains(kind) else { throw TotiBackendError.invalidResponse }
        let (account, epoch) = try context()
        await acquire()
        defer { release() }
        try check(epoch, account: account)
        let parameters: [String: JSONValue] = ["p_kind": .string(kind), "p_cursor": cursor.map(JSONValue.string) ?? .null]
        let page: OnlinePage = try await client.rpc("toti_profile_reactions", params: parameters).execute().value
        try check(epoch, account: account)
        guard page.records.count <= 30, Set(page.records.map(\.id)).count == page.records.count,
              page.next_cursor == nil || page.next_cursor != cursor else { throw TotiBackendError.invalidResponse }
        return page
    }

    func editorialActivity(postID: UUID, action: String = "read", payload: [String: JSONValue] = [:],
                           requestID: UUID? = nil) async throws -> EditorialActivitySnapshot {
        try requireRollout()
        let (account, epoch) = try context()
        await acquire()
        defer { release() }
        try check(epoch, account: account)
        let parameters: [String: JSONValue] = ["p_post_id": .string(postID.uuidString),
            "p_action": .string(action), "p_payload": .object(payload),
            "p_request_id": requestID.map { .string($0.uuidString) } ?? .null]
        let result: EditorialActivitySnapshot = try await client.rpc("toti_editorial_activity", params: parameters).execute().value
        try check(epoch, account: account)
        guard result.post.id == postID, result.comments.count <= 40,
              Set(result.comments.map(\.id)).count == result.comments.count else { throw TotiBackendError.invalidResponse }
        return result
    }

    func communityRoomMaterials() async throws -> [CommunityVoiceRoom] {
        try requireRollout()
        let (account, epoch) = try context()
        await acquire()
        defer { release() }
        try check(epoch, account: account)
        let response: [CommunityVoiceRoom] = try await client.rpc("toti_community_room_materials").execute().value
        try check(epoch, account: account)
        let covers: Set<String> = ["RoomCoverHipHop", "RoomCoverKPop", "RoomCoverJazz", "RoomCoverFreestyle", "MusicPianoRoom", "MusicProductionRoom"]
        func validURL(_ url: URL, asset: String) -> Bool {
            url.scheme == "https" && url.host == "gjodhvpzkdnxdjmorjfw.supabase.co"
                && url.path.hasPrefix("/storage/v1/object/public/toti-build-assets/")
                && url.lastPathComponent == asset + ".jpg" && url.query == nil && url.fragment == nil
        }
        let portraits = response.flatMap(\.people)
        guard response.count <= 6, Set(response.map(\.id)).count == response.count,
              Set(response.map(\.cover_asset)).count == response.count,
              Set(portraits.map(\.asset)).count == portraits.count,
              response.allSatisfy({ covers.contains($0.cover_asset) && validURL($0.cover_url, asset: $0.cover_asset)
                  && $0.people.count == 3 && PartyCategory(rawValue: $0.category) != nil }),
              portraits.allSatisfy({ $0.asset.hasPrefix("Portrait") && validURL($0.url, asset: $0.asset) })
        else { throw TotiBackendError.invalidResponse }
        return response
    }

    /// Persist the exact explicitly selected payload before transmitting anything.
    /// Decoder validation here is a size guard; the service performs authoritative validation.
    func uploadMedia(jpeg: Data, kind: String, entityID: UUID) async throws -> OnlineMediaRevision {
        try requireRollout()
        try validateMedia(jpeg: jpeg, kind: kind)
        let (account, epoch) = try context()
        await acquire()
        defer { release() }
        try check(epoch, account: account)
        let entry = try await mediaJournal.begin(account: account, jpeg: jpeg, kind: kind, entityID: entityID)
        try check(epoch, account: account)
        return try await executeMediaUpload(entry, account: account, epoch: epoch)
    }

    /// The owning record intent is durable before upload starts. Recovery can therefore
    /// finish a submitted save after termination between uploading and attaching bytes.
    func mutateWithMedia(action: String, entityID: UUID, payload: [String: JSONValue],
                         jpeg: Data, kind: String) async throws -> OnlineMutationReceipt {
        try requireRollout()
        guard (action == "post.save" && kind == "post") || (action == "profile.save" && kind == "avatar") else {
            throw TotiBackendError.invalidResponse
        }
        try validateMedia(jpeg: jpeg, kind: kind)
        let (account, epoch) = try context()
        await acquire()
        defer { release() }
        try check(epoch, account: account)
        let upload = try await mediaJournal.begin(account: account, jpeg: jpeg, kind: kind, entityID: entityID)
        try check(epoch, account: account)
        var payload = payload
        payload["media_revision_id"] = .string(upload.revisionID.uuidString)
        let mutation = try await journal.begin(account: account, action: action, entityID: entityID, payload: payload)
        try check(epoch, account: account)
        if let receipt = mutation.receipt {
            await completeAttachedMedia(action: action, entityID: entityID, payload: payload, account: account)
            await journal.complete(mutation, account: account)
            try check(epoch, account: account)
            return receipt
        }
        do { let _ = try await executeMediaUpload(upload, account: account, epoch: epoch) }
        catch TotiBackendError.invalidMedia {
            try await journal.reject(mutation, account: account)
            throw TotiBackendError.invalidMedia
        }
        return try await executeMutation(mutation, account: account, epoch: epoch, payload: payload)
    }

    private func validateMedia(jpeg: Data, kind: String) throws {
        guard ["avatar", "post"].contains(kind), !jpeg.isEmpty, jpeg.count <= 1_048_576,
              jpeg.starts(with: [0xff, 0xd8, 0xff]),
              let source = CGImageSourceCreateWithData(jpeg as CFData, nil),
              CGImageSourceGetCount(source) == 1,
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? Int,
              let height = properties[kCGImagePropertyPixelHeight] as? Int,
              width > 0, height > 0, width <= 1_200, height <= 1_200 else { throw TotiBackendError.invalidMedia }
    }

    /// Read authorization is renewed even for memory hits: blocks, review and visibility
    /// changes must take effect before a cached photo is returned to another surface.
    func mediaImage(revisionID: UUID) async throws -> Data {
        try requireRollout()
        let (account, epoch) = try context()
        await acquire()
        defer { release() }
        try check(epoch, account: account)
        do {
            let grant: MediaReadResponse = try await client.functions.invoke("toti-media-read",
                options: FunctionInvokeOptions(body: ["revision_id": revisionID.uuidString]))
            try check(epoch, account: account)
            guard let url = URL(string: grant.signed_url), url.scheme == "https",
                  url.host == TotiBackendConfiguration.projectURL.host,
                  url.path.hasPrefix("/storage/v1/object/sign/toti-media/"),
                  let expiry = Self.mediaExpiry(grant.expires_at), expiry > Date(),
                  expiry.timeIntervalSinceNow <= 120 else { throw TotiBackendError.invalidResponse }
            if let bytes = mediaCache[revisionID] {
                mediaCacheOrder.removeAll { $0 == revisionID }
                mediaCacheOrder.append(revisionID)
                return bytes
            }
            var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 20)
            request.setValue("image/jpeg", forHTTPHeaderField: "Accept")
            let bytes = try await downloadOnlineMedia(session: mediaSession, request: request)
            try check(epoch, account: account)
            while mediaCacheOrder.count >= 16 || mediaCache.values.reduce(0, { $0 + $1.count }) + bytes.count > 16_777_216 {
                guard !mediaCacheOrder.isEmpty else { break }
                mediaCache[mediaCacheOrder.removeFirst()] = nil
            }
            mediaCache[revisionID] = bytes
            mediaCacheOrder.append(revisionID)
            return bytes
        } catch {
            mediaCache[revisionID] = nil
            mediaCacheOrder.removeAll { $0 == revisionID }
            throw error
        }
    }

    private func executeMediaUpload(_ entry: OnlineMediaJournal.Entry, account: UUID, epoch: Int) async throws -> OnlineMediaRevision {
        try check(epoch, account: account)
        if let revision = entry.revision { return revision }
        do {
            let revision: OnlineMediaRevision = try await client.functions.invoke("toti-media-upload", options: FunctionInvokeOptions(body: [
                "revision_id": entry.revisionID.uuidString, "kind": entry.kind,
                "entity_id": entry.entityID.uuidString, "jpeg_base64": entry.jpeg.base64EncodedString()
            ]))
            guard revision.id == entry.revisionID, revision.entity_id == entry.entityID,
                  revision.kind == entry.kind, ["pending", "approved", "rejected"].contains(revision.status),
                  revision.sha256.count == 64, revision.sha256.allSatisfy({ $0.isHexDigit }) else {
                throw TotiBackendError.invalidResponse
            }
            await mediaJournal.acknowledge(entry, revision: revision, account: account)
            try check(epoch, account: account)
            return revision
        } catch {
            // Only authoritative input rejection can release the submitted intent.
            // A timeout, gateway/decode failure or conflict preserves the UUID and bytes.
            if case FunctionsError.httpError(let code, _) = error, [400, 413, 415, 422].contains(code) {
                try await mediaJournal.reject(entry, account: account)
                throw TotiBackendError.invalidMedia
            }
            throw error
        }
    }

    /// Replays only explicitly submitted business operations for the currently signed-in
    /// account. Called by the user's Retry pending changes action, never during startup.
    func retryPendingOperations() async throws {
        try requireRollout()
        let (account, epoch) = try context()
        await acquire()
        defer { release() }
        try check(epoch, account: account)
        let allowed: Set<String> = [
            "profile.save", "post.save", "post.delete", "comment.save", "comment.delete",
            "note.save", "note.delete", "room.save", "room.delete", "room.join", "room.leave",
            "room.message", "follow.set", "block.set", "reaction.set", "report.save",
            "conversation.open", "group.create", "invitation.accept", "invitation.decline",
            "conversation.leave", "conversation.remove", "message.send", "message.attachment", "preference.save"
        ]
        let pending = try await journal.pending(account: account)
        let entries = pending.filter { allowed.contains($0.action) }
        try check(epoch, account: account)
        for entry in try await mediaJournal.pending(account: account) {
            do { let _ = try await executeMediaUpload(entry, account: account, epoch: epoch) }
            catch TotiBackendError.invalidMedia {
                for mutation in entries where mutation.payload?["media_revision_id"]?.stringValue == entry.revisionID.uuidString {
                    try await journal.reject(mutation, account: account)
                }
                throw TotiBackendError.invalidMedia
            }
        }
        for entry in entries.prefix(100) {
            try check(epoch, account: account)
            if let receipt = entry.receipt {
                // Acknowledged requests only need local journal cleanup; do not issue them again.
                await journal.acknowledge(entry, receipt: receipt, account: account)
                await completeAttachedMedia(action: entry.action, entityID: entry.entityID, payload: entry.payload ?? [:], account: account)
                guard await journal.complete(entry, account: account) else { throw TotiBackendError.localPersistence }
                removeCompletedAttachment(entry, account: account)
                continue
            }
            guard let payload = entry.payload else { throw TotiBackendError.pendingPayloadUnavailable }
            let _ = try await executeMutation(entry, account: account, epoch: epoch, payload: payload)
            let remaining = try await journal.pending(account: account)
            if remaining.contains(where: { $0.operationID == entry.operationID }) {
                throw TotiBackendError.localPersistence
            }
        }
        try check(epoch, account: account)
        if entries.count > 100 { throw TotiBackendError.morePendingOperations }
    }

    func deleteAccount() async throws {
        try requireRollout()
        guard TotiBackendConfiguration.accountDeletionEnabled else {
            throw TotiBackendError.deletionUnavailable
        }
        let (account, _) = try context()
        let epoch = beginTransition()
        defer { endTransition(epoch) }
        await acquire()
        defer { release() }
        try check(epoch)
        let entry = try await journal.begin(account: account, action: "account.delete", entityID: account, payload: [:])
        try check(epoch)
        do {
            let result: DeletionResponse = try await client.functions.invoke("toti-delete-account",
                options: FunctionInvokeOptions(body: ["operation_id": entry.operationID.uuidString]))
            guard result.status == "complete" || result.status == "pending" else {
                throw TotiBackendError.invalidResponse
            }
            // Access is denied by the server before cleanup; never restore the old visible account.
            let receipt = OnlineMutationReceipt(entity_id: account, version: 1, status: result.status)
            await journal.acknowledge(entry, receipt: receipt, account: account)
            if result.status == "complete" { await journal.complete(entry, account: account) }
            try check(epoch)
            deletionPending = result.status == "pending"
            // The SDK removes local session state before attempting remote logout. A deleted
            // account or revoked session can legitimately make that remote request unavailable.
            try? await client.auth.signOut(scope: .local)
            try check(epoch)
            if deletionPending { throw TotiBackendError.deletionPending }
        } catch {
            // An unknown network outcome may already have closed the account. Keep it signed out;
            // the durable server cleanup job, not local state, determines completion.
            try? await client.auth.signOut(scope: .local)
            throw error
        }
    }

    private func performMutation(account: UUID, epoch: Int, action: String, entityID: UUID,
                                 payload: [String: JSONValue]) async throws -> OnlineMutationReceipt {
        let entry = try await journal.begin(account: account, action: action, entityID: entityID, payload: payload)
        try check(epoch)
        if let receipt = entry.receipt {
            await completeAttachedMedia(action: action, entityID: entityID, payload: payload, account: account)
            if await journal.complete(entry, account: account) { removeCompletedAttachment(entry, account: account) }
            try check(epoch)
            return receipt
        }
        return try await executeMutation(entry, account: account, epoch: epoch, payload: payload)
    }

    private func executeMutation(_ entry: OnlineOperationJournal.Entry, account: UUID, epoch: Int,
                                 payload: [String: JSONValue]) async throws -> OnlineMutationReceipt {
        try check(epoch)
        do {
            let receipt: OnlineMutationReceipt
            if entry.action == "message.attachment" {
                receipt = try await executeAttachment(entry, account: account, epoch: epoch, payload: payload)
            } else {
                receipt = try await client.rpc("toti_mutate", params: MutationParameters(
                    p_operation_id: entry.operationID, p_action: entry.action,
                    p_entity_id: entry.entityID, p_payload: payload)).execute().value
            }
            await journal.acknowledge(entry, receipt: receipt, account: account)
            await completeAttachedMedia(action: entry.action, entityID: entry.entityID, payload: payload, account: account)
            if await journal.complete(entry, account: account) { removeCompletedAttachment(entry, account: account) }
            try check(epoch)
            return receipt
        } catch {
            // These are explicit PostgreSQL transaction rejections. Network failures, decode
            // failures and gateway errors retain the exact operation identity for safe replay.
            try await OnlineMutationRecovery.discardRejectedIntent(error: error, entry: entry, account: account,
                                                                    operations: journal, media: mediaJournal)
            throw error
        }
    }

    private func removeCompletedAttachment(_ entry: OnlineOperationJournal.Entry, account: UUID) {
        guard entry.action == "message.attachment" else { return }
        let file = attachmentRoot.appendingPathComponent(account.uuidString).appendingPathComponent(entry.entityID.uuidString)
        try? FileManager.default.removeItem(at: file)
    }

    private func completeAttachedMedia(action: String, entityID: UUID, payload: [String: JSONValue], account: UUID) async {
        if action == "message.attachment" { return }
        guard ["profile.save", "post.save"].contains(action), let attachment = payload["media_revision_id"] else { return }
        if let value = attachment.stringValue, let id = UUID(uuidString: value) {
            await mediaJournal.complete(revisionID: id, account: account)
        } else if case .null = attachment {
            await mediaJournal.complete(entityID: entityID, kind: action == "profile.save" ? "avatar" : "post", account: account)
        }
    }

    private func makeClient() -> SupabaseClient {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 60
        configuration.urlCache = nil
        let sdk = SupabaseClient(supabaseURL: TotiBackendConfiguration.projectURL,
            supabaseKey: TotiBackendConfiguration.publishableKey,
            options: SupabaseClientOptions(
                db: .init(encoder: JSONEncoder(), decoder: JSONDecoder()),
                auth: .init(storage: TotiKeychainStorage(), storageKey: authStorageKey,
                            autoRefreshToken: true, emitLocalSessionAsInitialSession: false),
                global: .init(session: URLSession(configuration: configuration))))
        authObservation = Task { [weak self, sdk] in
            for await (event, session) in sdk.auth.authStateChanges {
                guard let self else { return }
                if self.accountID != nil, event != .initialSession,
                   event == .signedOut || event == .userDeleted || session?.user.id != self.accountID {
                    self.generation += 1
                    self.accountID = nil
                    self.clearMediaCache()
                }
            }
        }
        return sdk
    }

    private func requireRollout() throws {
        guard TotiBackendConfiguration.rolloutEnabled else { throw TotiBackendError.rolloutClosed }
    }

    private func context() throws -> (UUID, Int) {
        guard let accountID else { throw TotiBackendError.sessionRequired }
        return (accountID, generation)
    }

    private func beginTransition() -> Int {
        isTransitioning = true
        generation += 1
        accountID = nil
        clearMediaCache()
        return generation
    }

    private func clearMediaCache() {
        mediaCache.removeAll()
        mediaCacheOrder.removeAll()
    }

    private static func mediaExpiry(_ value: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: value) ?? ISO8601DateFormatter().date(from: value)
    }

    private func endTransition(_ epoch: Int) {
        if generation == epoch { isTransitioning = false }
    }

    private func check(_ epoch: Int, account: UUID? = nil) throws {
        try Task.checkCancellation()
        guard generation == epoch, account == nil || accountID == account else {
            throw TotiBackendError.accountChanged
        }
    }

    private func normalizedEmail(_ value: String) throws -> String {
        let email = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let parts = email.split(separator: "@", omittingEmptySubsequences: false)
        guard email.count <= 254, parts.count == 2, !parts[0].isEmpty, parts[1].contains("."),
              !email.contains(where: { $0.isWhitespace || $0.isNewline }) else { throw TotiBackendError.invalidEmail }
        return email
    }

    private func acquire() async {
        if !gateHeld { gateHeld = true; return }
        await withCheckedContinuation { gateWaiters.append($0) }
    }

    private func release() {
        if gateWaiters.isEmpty { gateHeld = false }
        else { gateWaiters.removeFirst().resume() }
    }

    private struct ReadParameters: Encodable {
        let p_kind: String
        var p_cursor: String? = nil
        var p_parent_id: UUID? = nil
    }
    private struct AttachmentParameters: Encodable {
        let p_operation_id: UUID
        let p_message_id: UUID
        let p_conversation_id: UUID
        let p_path: String
        let p_filename: String
        let p_kind: String
        let p_text: String
    }
    private struct MutationParameters: Encodable {
        let p_operation_id: UUID
        let p_action: String
        let p_entity_id: UUID
        let p_payload: [String: JSONValue]
    }
    private struct DeletionResponse: Decodable { let status: String }
    private struct MediaReadResponse: Decodable { let signed_url: String; let expires_at: String }
}

private final class OnlineMediaDownloadDelegate: NSObject, URLSessionTaskDelegate {
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
        completionHandler(nil)
    }
}

/// The byte loop runs off MainActor, bounds memory before decoding, and never writes a file.
private func downloadOnlineMedia(session: URLSession, request: URLRequest) async throws -> Data {
    let (stream, response) = try await session.bytes(for: request)
    guard let response = response as? HTTPURLResponse, response.statusCode == 200,
          response.mimeType == "image/jpeg", response.expectedContentLength <= 1_048_576 else {
        throw TotiBackendError.invalidResponse
    }
    var bytes = Data()
    for try await byte in stream {
        guard bytes.count < 1_048_576 else { throw TotiBackendError.invalidResponse }
        bytes.append(byte)
        if bytes.count % 65_536 == 0 { try Task.checkCancellation() }
    }
    guard bytes.starts(with: [0xff, 0xd8, 0xff]), let source = CGImageSourceCreateWithData(bytes as CFData, nil),
          CGImageSourceGetCount(source) == 1,
          let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
          let width = properties[kCGImagePropertyPixelWidth] as? Int,
          let height = properties[kCGImagePropertyPixelHeight] as? Int,
          width > 0, height > 0, width <= 2_048, height <= 2_048, width * height <= 4_194_304 else {
        throw TotiBackendError.invalidResponse
    }
    return bytes
}
