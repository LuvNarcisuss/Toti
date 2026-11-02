import Combine
import Foundation
import UIKit

/// Adapts authorized server records to the existing UIKit screens. The legacy library
/// is never read or written by this path; the projection is replaced after each read.
@MainActor
extension AppStore {
    private var onlineKinds: [String] {
        ["profile", "post", "comment", "note", "room", "conversation", "message",
         "follow", "block", "reaction", "report", "preference", "invitation"]
    }

    @discardableResult
    func refreshOnline(afterMutation: Bool = false) async -> Bool {
        guard isOnlineMode, !onlineReadInProgress, (!onlineMutationInProgress || afterMutation), TotiBackend.shared.isAuthenticated else { return false }
        let backend = TotiBackend.shared
        let generation = backend.generation
        let account = backend.accountID
        onlineReadInProgress = true
        objectWillChange.send()
        defer { onlineReadInProgress = false; objectWillChange.send() }
        do {
            var records: [String: [OnlineRecord]] = [:]
            var cursors: [String: String] = [:]
            // A bounded first page for each surface. More is an explicit user action.
            for kind in onlineKinds {
                let page = try await backend.page(kind: kind, cursor: nil, parentID: nil)
                records[kind] = page.records
                cursors[kind] = page.next_cursor
            }
            guard let account else { return false }
            let own = try await backend.page(kind: "profile", cursor: nil, parentID: account)
            guard own.records.contains(where: { $0.id == account }) else { throw TotiBackendError.invalidResponse }
            records["profile"]?.removeAll { $0.id == account }
            records["profile", default: []].append(contentsOf: own.records)
            // Reconcile the active history window, including older pages, without fetching all history.
            for key in Array(onlineThreadPages.keys) {
                let parts = key.split(separator: ":", maxSplits: 1).map(String.init)
                guard parts.count == 2, let parent = UUID(uuidString: parts[1]) else { continue }
                let kind = parts[0]
                records[kind]?.removeAll { $0.parent_id == parent }
                let parentKind = onlineThreadParentKinds[key] ?? (kind == "comment" ? "post" : "conversation")
                do {
                    let container = try await backend.page(kind: parentKind, cursor: nil, parentID: parent)
                    guard container.records.contains(where: { $0.id == parent }) else { throw TotiBackendError.sessionRequired }
                    records[parentKind]?.removeAll { $0.id == parent }
                    records[parentKind, default: []].append(contentsOf: container.records)
                    let page = try await backend.page(kind: kind, cursor: onlineThreadStarts[key], parentID: parent)
                    records[kind, default: []].append(contentsOf: page.records)
                    cursors[key] = page.next_cursor
                } catch {
                    guard generation == backend.generation else { return false }
                    onlineThreadPages[key] = nil
                    onlineThreadStarts[key] = nil
                    onlineThreadParentKinds[key] = nil
                    cursors[key] = nil
                    records[parentKind]?.removeAll { $0.id == parent }
                    // Other authorized surfaces remain usable after membership is revoked.
                }
            }
            do {
                let editorial = try await backend.editorialPosts()
                guard generation == backend.generation, account == backend.accountID else { return false }
                onlineEditorialPosts = editorial
                onlineEditorialError = nil
            } catch {
                guard generation == backend.generation, account == backend.accountID else { return false }
                onlineEditorialPosts = []
                onlineEditorialError = error.localizedDescription
            }
            do {
                let materials = try await backend.communityRoomMaterials()
                guard generation == backend.generation, account == backend.accountID else { return false }
                onlineCommunityRooms = materials.map(\.room)
                onlineCommunityRoomsError = nil
            } catch {
                guard generation == backend.generation, account == backend.accountID else { return false }
                onlineCommunityRooms = []
                onlineCommunityRoomsError = error.localizedDescription
            }
            guard generation == backend.generation, account == backend.accountID else { return false }
            onlineRecords = records
            onlineCursors = cursors
            onlineHasMore = !cursors.isEmpty
            onlineProjectedAccountID = account
            onlineProjectedGeneration = generation
            try projectOnlineRecords()
            onlineReadError = nil
            startOnlineReconciliation()
            return true
        } catch {
            guard generation == backend.generation, account == backend.accountID else { return false }
            // Never preserve a previously authorized inbox after a denied/failed reread.
            onlineRecords = [:]
            onlineEditorialPosts = []
            onlineEditorialError = nil
            onlineCommunityRooms = []
            onlineCommunityRoomsError = nil
            onlineCursors = [:]
            onlineHasMore = false
            adoptOnlineLibrary(LocalLibrary())
            onlineReadError = error.localizedDescription
            return false
        }
    }

    func loadMoreOnline() async {
        guard isOnlineMode, !onlineReadInProgress, !onlineMutationInProgress, TotiBackend.shared.isAuthenticated else { return }
        onlineReadInProgress = true
        objectWillChange.send()
        defer { onlineReadInProgress = false; objectWillChange.send() }
        let generation = TotiBackend.shared.generation
        do {
            var updates = onlineRecords
            var cursors = onlineCursors
            for (kind, cursor) in onlineCursors.sorted(by: { $0.key < $1.key }) {
                let components = kind.split(separator: ":", maxSplits: 1).map(String.init)
                let recordKind = components[0]
                let parentID = components.count == 2 ? UUID(uuidString: components[1]) : nil
                let page = try await TotiBackend.shared.page(kind: recordKind, cursor: cursor, parentID: parentID)
                if let parentID { updates[recordKind]?.removeAll { $0.parent_id == parentID } }
                var indexed = Dictionary((updates[recordKind] ?? []).map { ($0.id, $0) }, uniquingKeysWith: { _, new in new })
                page.records.forEach { indexed[$0.id] = $0 }
                updates[recordKind] = indexed.values.sorted { $0.created_at == $1.created_at ? $0.id.uuidString > $1.id.uuidString : $0.created_at > $1.created_at }
                cursors[kind] = page.next_cursor
                if parentID != nil {
                    onlineThreadPages[kind] = 1
                    onlineThreadStarts[kind] = cursor
                }
            }
            guard generation == TotiBackend.shared.generation else { return }
            onlineRecords = updates
            onlineCursors = cursors
            onlineHasMore = !cursors.isEmpty
            try projectOnlineRecords()
            onlineReadError = nil
        } catch {
            guard generation == TotiBackend.shared.generation else { return }
            onlineReadError = error.localizedDescription
            onlineRecords = [:]
            adoptOnlineLibrary(LocalLibrary())
        }
    }

    func loadOnlineThread(kind: String, parentID: String) async {
        guard ["message", "comment"].contains(kind), let parent = UUID(uuidString: parentID),
              TotiBackend.shared.isAuthenticated else { return }
        let key = kind + ":" + parent.uuidString
        onlineThreadPages = [key: 1]
        onlineThreadStarts = [:]
        let parentKind = kind == "comment" ? "post" : ((onlineRecords["room"] ?? []).contains { $0.id == parent } ? "room" : "conversation")
        onlineThreadParentKinds = [key: parentKind]
        guard !onlineReadInProgress, !onlineMutationInProgress else { return }
        onlineReadInProgress = true
        defer { onlineReadInProgress = false; objectWillChange.send() }
        let generation = TotiBackend.shared.generation
        do {
            let container = try await TotiBackend.shared.page(kind: parentKind, cursor: nil, parentID: parent)
            guard container.records.contains(where: { $0.id == parent }) else { throw TotiBackendError.sessionRequired }
            let page = try await TotiBackend.shared.page(kind: kind, cursor: nil, parentID: parent)
            guard generation == TotiBackend.shared.generation else { return }
            onlineRecords[parentKind]?.removeAll { $0.id == parent }
            onlineRecords[parentKind, default: []].append(contentsOf: container.records)
            var records = onlineRecords[kind] ?? []
            records.removeAll { $0.parent_id == parent }
            var indexed = Dictionary(records.map { ($0.id, $0) }, uniquingKeysWith: { _, new in new })
            page.records.forEach { indexed[$0.id] = $0 }
            onlineRecords[kind] = Array(indexed.values)
            onlineCursors[kind + ":" + parent.uuidString] = page.next_cursor
            onlineHasMore = !onlineCursors.isEmpty
            try projectOnlineRecords()
        } catch {
            guard generation == TotiBackend.shared.generation else { return }
            onlineRecords[kind]?.removeAll { $0.parent_id == parent }
            onlineRecords[parentKind]?.removeAll { $0.id == parent }
            onlineThreadPages[key] = nil
            onlineThreadStarts[key] = nil
            onlineThreadParentKinds[key] = nil
            onlineReadError = error.localizedDescription
            try? projectOnlineRecords()
        }
    }

    private func startOnlineReconciliation() {
        guard onlineRefreshTask == nil else { return }
        let generation = TotiBackend.shared.generation
        onlineRefreshTask = Task { [weak self] in
            while !Task.isCancelled {
                do { try await Task.sleep(nanoseconds: 20_000_000_000) } catch { return }
                guard let self, TotiBackend.shared.generation == generation else { return }
                guard UIApplication.shared.applicationState == .active, !self.isBusy else { continue }
                _ = await self.refreshOnline()
            }
        }
    }

    func loadProfileReactionPage(kind: String, cursor: String? = nil) async throws -> (posts: [LoungePost], next: String?) {
        let generation = TotiBackend.shared.generation
        let page = try await TotiBackend.shared.profileReactions(kind: kind, cursor: cursor)
        guard generation == TotiBackend.shared.generation else { throw TotiBackendError.accountChanged }
        var indexed = Dictionary((onlineRecords["post"] ?? []).map { ($0.id, $0) }, uniquingKeysWith: { _, last in last })
        page.records.forEach { indexed[$0.id] = $0 }
        onlineRecords["post"] = Array(indexed.values)
        try projectOnlineRecords()
        return (page.records.compactMap { loungePost($0.id) }, page.next_cursor)
    }

    private func projectOnlineRecords() throws {
        guard let account = TotiBackend.shared.accountID,
              onlineProjectedAccountID == account,
              onlineProjectedGeneration == TotiBackend.shared.generation else { return }
        var library = LocalLibrary()
        if let own = onlineRecords["profile"]?.first(where: { $0.id == account }) {
            library.profile = try own.decode(LocalProfile.self)
            library.profile.hasCustomAvatar = false
            library.profile.backendVersion = own.version
            library.profile.avatarMediaRevisionID = own.uuid("avatar_media_revision_id")
            library.profile.avatarPendingMediaRevisionID = own.uuid("avatar_pending_media_revision_id")
            library.profile.avatarMediaStatus = own.string("avatar_media_status")
            library.profile.avatarMediaFeedback = own.string("avatar_media_feedback")
        }
        let posts = try (onlineRecords["post"] ?? []).map { record -> LoungePost in
            var body = record.body
            body["id"] = .string(record.id.uuidString)
            body["backendVersion"] = .number(Double(record.version))
            body["author"] = .object(try JSONValue.object(onlineCreator(record.owner_id)))
            body["isEditorial"] = .bool(false)
            body["photoAsset"] = .null
            body["photoJPEG"] = .null
            body["mediaRevisionID"] = record.body["media_revision_id"] ?? .null
            body["mediaStatus"] = record.body["media_status"] ?? .null
            body["mediaFeedback"] = record.body["media_feedback"] ?? .null
            body["createdAt"] = .number(record.createdDate.timeIntervalSinceReferenceDate)
            body["updatedAt"] = .number(record.updatedDate.timeIntervalSinceReferenceDate)
            return try decodeOnline(LoungePost.self, body: body)
        }
        let comments = (onlineRecords["comment"] ?? []).compactMap { record -> LoungeComment? in
            guard let parent = record.parent_id ?? record.uuid("postID") else { return nil }
            return LoungeComment(id: record.id, postID: parent, author: onlineCreator(record.owner_id),
                                 body: record.string("body") ?? "", createdAt: record.createdDate)
        }
        var lounge = LoungeState(posts: posts, comments: comments)
        for record in onlineRecords["post"] ?? [] {
            if record.bool("my_liked") == true { lounge.likedPostIDs.insert(record.id) }
            if record.bool("my_saved") == true { lounge.savedPostIDs.insert(record.id) }
        }
        library.lounge = lounge
        library.notebook = NotebookState(notes: try (onlineRecords["note"] ?? []).map { record in
            var note = try record.decode(InspirationNote.self)
            note.backendVersion = record.version
            note.createdAt = record.createdDate
            note.updatedAt = record.updatedDate
            return note
        })
        library.roomDrafts = try (onlineRecords["room"] ?? []).filter { $0.owner_id == account }.map { record in
            var room = try record.decode(VoiceRoomDraft.self)
            room.backendVersion = record.version
            return room
        }
        var creators = CreatorLocalState()
        creators.followedIDs = Set(onlineProfileBodies.compactMap { id, body in
            body["my_following"]?.boolValue == true ? id : nil
        })
        library.creatorState = creators
        var safety = ContentSafetyState()
        for block in onlineRecords["block"] ?? [] {
            guard block.bool("enabled") != false, let target = block.uuid("target_id") else { continue }
            safety.blockedCreators[target.uuidString.lowercased()] = onlineCreator(target)
        }
        for report in onlineRecords["report"] ?? [] {
            guard let target = report.string("target_id") else { continue }
            let kind: ContentSafetyTarget.Kind
            switch report.string("target_kind") { case "profile": kind = .profile; case "comment", "message": kind = .comment; case "room": kind = .party; default: kind = .post }
            safety.reports.append(LocalContentReport(id: report.id, contentID: target, title: "Reported content", kind: kind,
                creatorID: "", creatorName: "", reason: ContentReportReason(rawValue: report.string("reason") ?? "") ?? .other,
                details: report.string("details") ?? "", savedAt: report.createdDate))
        }
        library.contentSafety = safety
        adoptOnlineLibrary(library)
    }

    private var onlineProfileBodies: [String: [String: JSONValue]] {
        var profiles: [String: [String: JSONValue]] = [:]
        for row in onlineRecords.values.flatMap({ $0 }) {
            if let owner = row.body["owner_profile"]?.objectValue {
                profiles[row.owner_id.uuidString.lowercased()] = owner
            }
            if let peer = row.body["peer_profile"]?.objectValue, let id = peer["id"]?.stringValue {
                profiles[id.lowercased()] = peer
            }
            for member in row.body["member_profiles"]?.arrayValue ?? [] {
                if let body = member.objectValue, let id = body["id"]?.stringValue { profiles[id.lowercased()] = body }
            }
        }
        for row in onlineRecords["profile"] ?? [] { profiles[row.id.uuidString.lowercased()] = row.body }
        return profiles
    }

    func onlineCreator(_ id: UUID) -> CreatorProfile {
        let body = onlineProfileBodies[id.uuidString.lowercased()] ?? [:]
        let avatar = body["avatar_media_revision_id"]?.stringValue.flatMap(UUID.init(uuidString:))
            .map { "remote-media:" + $0.uuidString.lowercased() } ?? "TotiMark"
        return CreatorProfile(id: id.uuidString.lowercased(), name: body["displayName"]?.stringValue ?? "Music member",
            biography: body["biography"]?.stringValue ?? "", avatarAsset: avatar, avatarSymbol: "music.note",
            likes: 0, following: Int(body["following_count"]?.numberValue ?? 0), followers: Int(body["follower_count"]?.numberValue ?? 0),
            isLocalOwner: id == TotiBackend.shared.accountID)
    }

    var onlineOwnerProfile: CreatorProfile? {
        guard let account = TotiBackend.shared.accountID,
              onlineProjectedAccountID == account, onlineProjectedGeneration == TotiBackend.shared.generation else { return nil }
        return onlineCreator(account)
    }

    func mediaImage(revisionID: UUID) async throws -> Data {
        try await TotiBackend.shared.mediaImage(revisionID: revisionID)
    }

    var onlinePeople: [MusicConversation] {
        (onlineRecords["profile"] ?? []).filter { $0.id != TotiBackend.shared.accountID }.map { record in
            let creator = onlineCreator(record.id)
            return MusicConversation(id: creator.id, name: creator.name, avatars: [creator.avatarAsset ?? "TotiMark"], kind: .person,
                time: "", initialUnread: 0, initiallyPinned: false, story: nil, messages: [], creator: creator)
        }
    }

    var onlineFollowerIDs: Set<String> {
        Set(onlineProfileBodies.compactMap { id, body in body["follows_me"]?.boolValue == true ? id : nil })
    }

    var onlineRooms: [PartyRoom] {
        (onlineRecords["room"] ?? []).map { record in
            let members = record.strings("member_ids").compactMap(UUID.init(uuidString:)).map { id -> PartyParticipant in
                let profile = onlineCreator(id)
                return PartyParticipant(id: profile.id, asset: profile.avatarAsset ?? "TotiMark", name: profile.name)
            }
            return PartyRoom(id: record.id.uuidString.lowercased(), title: record.string("title") ?? "Music room",
                description: record.string("description") ?? "", type: .voice,
                category: record.string("danceCategory").flatMap(PartyCategory.init(rawValue:)) ?? .freestyle,
                tag: "Text room", participants: members, popularity: nil, onlineCount: nil,
                draftID: record.owner_id == TotiBackend.shared.accountID ? record.id : nil)
        }
    }

    var onlineConversations: [MusicConversation] {
        guard onlineProjectedGeneration == TotiBackend.shared.generation else { return [] }
        return (onlineRecords["conversation"] ?? []).compactMap { record in
            let id = record.id.uuidString.lowercased()
            if onlinePreference(id)?.bool("hidden") == true { return nil }
            let peer = record.uuid("peer_id")
            let creator = peer.map(onlineCreator)
            let isGroup = record.bool("is_group") == true || record.string("type") == "group" || record.string("kind") == "group"
            let messages = onlineMessages(parentID: record.id)
            let avatars = isGroup ? record.strings("member_ids").compactMap(UUID.init(uuidString:)).map { onlineCreator($0).avatarAsset ?? "TotiMark" }
                : [creator?.avatarAsset ?? "TotiMark"]
            return MusicConversation(id: id, name: isGroup ? (record.string("name") ?? "Music group") : (creator?.name ?? "Conversation"),
                avatars: avatars.isEmpty ? ["TotiMark"] : avatars, kind: isGroup ? .group : .person,
                time: messages.last?.time ?? "", initialUnread: 0, initiallyPinned: false, story: nil, messages: messages, creator: creator)
        }
    }

    private func onlineMessages(parentID: UUID) -> [ChatMessage] {
        (onlineRecords["message"] ?? []).filter { ($0.parent_id ?? $0.uuid("conversation_id") ?? $0.uuid("room_id")) == parentID }
            .sorted { ($0.integer("sequence") ?? 0) < ($1.integer("sequence") ?? 0) }
            .map { record in
                let own = record.owner_id == TotiBackend.shared.accountID
                return ChatMessage(id: record.id.uuidString.lowercased(), author: own ? "You" : onlineCreator(record.owner_id).name,
                    text: record.string("text") ?? "", time: record.createdDate.formatted(.dateTime.hour().minute().locale(Locale(identifier: "en_US"))),
                    isOwn: own, createdAt: record.createdDate, isPending: false,
                    attachment: record.body["attachment"].flatMap { value in
                        guard let data = try? JSONEncoder().encode(value) else { return nil }
                        return try? JSONDecoder().decode(ChatAttachment.self, from: data)
                    })
            }
    }

    func onlinePreference(_ id: String) -> OnlineRecord? {
        guard let target = UUID(uuidString: id), var conversation = onlineRecords["conversation"]?.first(where: { $0.id == target }),
              let preference = conversation.body["preference"]?.objectValue else { return nil }
        conversation.body = preference
        return conversation
    }

    func onlineProfileMetric(_ name: String, creatorID: String) -> Int? {
        onlineProfileBodies[creatorID.lowercased()]?[name]?.numberValue.map { Int($0) }
    }

    func onlineStatistics(_ creator: CreatorProfile) -> CreatorStatistics {
        CreatorStatistics(likes: onlineProfileMetric("like_count", creatorID: creator.id) ?? 0,
                          saves: onlineProfileMetric("save_count", creatorID: creator.id) ?? 0,
                          following: onlineProfileMetric("following_count", creatorID: creator.id) ?? 0,
                          followers: onlineProfileMetric("follower_count", creatorID: creator.id) ?? 0)
    }

    func acknowledgedOnlineVersion(for id: UUID) -> Int? { onlineAcknowledgedVersions[id] }

    func saveOnlineModel<T: Encodable>(_ value: T, action: String, id: UUID,
                                      mediaJPEG: Data? = nil, mediaKind: String? = nil) async -> Bool {
        do {
            var payload = try JSONValue.object(value)
            payload["expected_version"] = payload.removeValue(forKey: "backendVersion") ?? .number(0)
            payload.removeValue(forKey: "author")
            payload.removeValue(forKey: "createdAt")
            payload.removeValue(forKey: "updatedAt")
            payload.removeValue(forKey: "photoAsset")
            payload.removeValue(forKey: "isEditorial")
            // No local file, source artwork or JPEG ever reaches the record mutation.
            payload.removeValue(forKey: "photoJPEG")
            payload.removeValue(forKey: "hasCustomAvatar")
            payload.removeValue(forKey: "avatarMediaRevisionID")
            payload.removeValue(forKey: "avatarPendingMediaRevisionID")
            payload.removeValue(forKey: "avatarMediaStatus")
            payload.removeValue(forKey: "avatarMediaFeedback")
            payload.removeValue(forKey: "mediaStatus")
            payload.removeValue(forKey: "mediaFeedback")
            let revision = payload.removeValue(forKey: "mediaRevisionID")
            if action == "post.save" { payload["media_revision_id"] = revision ?? .null }
            let selectedPhoto = (value as? LoungePost)?.photoJPEG ?? mediaJPEG
            return await onlineMutation(action: action, id: id, payload: payload,
                                        mediaJPEG: selectedPhoto, mediaKind: action == "post.save" ? "post" : mediaKind) != nil
        } catch { noteSaveError(error.localizedDescription); return false }
    }

    func saveOnlineProfile(_ profile: LocalProfile, avatarJPEG: Data?) async -> Bool {
        guard let id = TotiBackend.shared.accountID else { return false }
        return await saveOnlineModel(profile, action: "profile.save", id: id, mediaJPEG: avatarJPEG, mediaKind: "avatar")
    }

    /// The transport persists and reuses the entity and operation IDs for uncertain
    /// create acknowledgements. A fresh intent is allowed after an acknowledged write.
    func retryStableEntity(action: String, context: String, text: String) -> UUID { UUID() }

    @discardableResult
    func performOnline(action: String, id: UUID, payload: [String: JSONValue] = [:]) async -> Bool {
        await onlineMutation(action: action, id: id, payload: payload) != nil
    }

    private func onlineMutation(action: String, id: UUID, payload: [String: JSONValue],
                                mediaJPEG: Data? = nil, mediaKind: String? = nil) async -> OnlineMutationReceipt? {
        guard !onlineMutationInProgress, !onlineReadInProgress, TotiBackend.shared.isAuthenticated,
              onlineProjectedGeneration == TotiBackend.shared.generation else {
            noteSaveError("Wait for the current request or sign in again."); return nil
        }
        let generation = TotiBackend.shared.generation
        onlineMutationInProgress = true
        objectWillChange.send()
        defer { onlineMutationInProgress = false; objectWillChange.send() }
        noteSaveError(nil)
        do {
            let receipt: OnlineMutationReceipt
            if let mediaJPEG, let mediaKind {
                receipt = try await TotiBackend.shared.mutateWithMedia(action: action, entityID: id, payload: payload,
                                                                       jpeg: mediaJPEG, kind: mediaKind)
            } else {
                receipt = try await TotiBackend.shared.mutate(action: action, entityID: id, payload: payload)
            }
            guard generation == TotiBackend.shared.generation else { return nil }
            onlineAcknowledgedVersions[receipt.entity_id] = receipt.version
            // A successful write stays successful even when the follow-up read fails.
            if !(await refreshOnline(afterMutation: true)) {
                onlineReadError = "Saved to your account. Refresh to load the latest changes."
            }
            return receipt
        } catch {
            guard generation == TotiBackend.shared.generation else { return nil }
            noteSaveError(error.localizedDescription)
            return nil
        }
    }

    func saveOnlinePreference(_ id: String, payload: [String: JSONValue]) async -> Bool {
        guard let id = UUID(uuidString: id) else { noteSaveError("Open a saved conversation first."); return false }
        return await performOnline(action: "preference.save", id: id, payload: payload)
    }

    func sendOnlineAttachment(_ data: Data, filename: String, kind: String, messageID: UUID,
                              text: String, conversation: MusicConversation) async -> Bool {
        guard !onlineMutationInProgress, !onlineReadInProgress,
              let id = UUID(uuidString: conversation.id), canSendChatMessage(conversation) else {
            noteSaveError("Wait for the current request or refresh this conversation."); return false
        }
        let generation = TotiBackend.shared.generation
        onlineMutationInProgress = true
        defer { onlineMutationInProgress = false; objectWillChange.send() }
        noteSaveError(nil)
        do {
            _ = try await TotiBackend.shared.sendChatAttachment(data, filename: filename, kind: kind,
                messageID: messageID, conversationID: id, text: text)
            guard generation == TotiBackend.shared.generation else { return false }
            if !(await refreshOnline(afterMutation: true)) {
                onlineReadError = "Attachment sent. Refresh to load the latest messages."
            }
            return true
        } catch {
            guard generation == TotiBackend.shared.generation else { return false }
            noteSaveError(error.localizedDescription)
            return false
        }
    }

    func sendOnlineMessage(_ text: String, conversation: MusicConversation) async -> Bool {
        guard let id = UUID(uuidString: conversation.id), !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, text.count <= 2_000 else {
            noteSaveError("Write a message of up to 2,000 characters."); return false
        }
        return await performOnline(action: "message.send", id: UUID(),
            payload: ["conversation_id": .string(id.uuidString), "text": .string(text)])
    }

    func openOnlineConversation(_ creator: CreatorProfile) async -> Bool {
        guard let peer = UUID(uuidString: creator.id) else { noteSaveError("This account is unavailable."); return false }
        return await performOnline(action: "conversation.open", id: UUID(), payload: ["peer_id": .string(peer.uuidString)])
    }

    func createOnlineGroup(_ people: [MusicConversation]) async -> MusicConversation? {
        let ids = Set(people.compactMap { $0.creator?.id ?? $0.id }.compactMap(UUID.init(uuidString:)))
        guard ids.count >= 2 else { noteSaveError("Choose at least two accounts."); return nil }
        let name = String(people.map(\.name).joined(separator: ", ").prefix(48))
        guard let receipt = await onlineMutation(action: "group.create", id: UUID(), payload: [
            "name": .string(name), "member_ids": .array(ids.sorted { $0.uuidString < $1.uuidString }.map { .string($0.uuidString) })
        ]) else { return nil }
        return onlineConversations.first { $0.id == receipt.entity_id.uuidString.lowercased() }
            ?? MusicConversation(id: receipt.entity_id.uuidString.lowercased(), name: name, avatars: ["TotiMark"], kind: .group,
                time: "", initialUnread: 0, initiallyPinned: false, story: nil, messages: [])
    }

    var onlineInvitations: [OnlineRecord] {
        (onlineRecords["invitation"] ?? []).filter { $0.string("status") == "pending" }
    }

    func respondToOnlineInvitation(_ id: UUID, accept: Bool) async -> Bool {
        await performOnline(action: accept ? "invitation.accept" : "invitation.decline", id: id)
    }

    func leaveOnlineConversation(_ id: String) async -> Bool {
        guard let id = UUID(uuidString: id) else { return false }
        return await performOnline(action: "conversation.leave", id: id)
    }

    func onlineConversationMembers(_ id: String) -> [CreatorProfile] {
        guard let id = UUID(uuidString: id), let row = onlineRecords["conversation"]?.first(where: { $0.id == id }) else { return [] }
        return row.strings("member_ids").compactMap(UUID.init(uuidString:)).map(onlineCreator)
    }

    func onlineConversationIsOwned(_ id: String) -> Bool {
        guard let id = UUID(uuidString: id) else { return false }
        return onlineRecords["conversation"]?.first { $0.id == id }?.owner_id == TotiBackend.shared.accountID
    }

    func removeOnlineConversationMember(_ memberID: String, conversationID: String) async -> Bool {
        guard let id = UUID(uuidString: conversationID), let member = UUID(uuidString: memberID) else { return false }
        return await performOnline(action: "conversation.remove", id: id, payload: ["member_id": .string(member.uuidString)])
    }

    func onlineRoomOwner(_ room: PartyRoom) -> CreatorProfile? {
        guard let id = UUID(uuidString: room.id), let record = onlineRecords["room"]?.first(where: { $0.id == id }) else { return nil }
        return onlineCreator(record.owner_id)
    }

    func joinOnlineRoom(_ room: PartyRoom) async -> Bool {
        guard let id = UUID(uuidString: room.id) else { return false }
        return await performOnline(action: "room.join", id: id)
    }

    func leaveOnlineRoom(_ room: PartyRoom) async -> Bool {
        guard let id = UUID(uuidString: room.id) else { return false }
        return await performOnline(action: "room.leave", id: id)
    }

    func sendOnlineRoomMessage(_ text: String, room: PartyRoom) async -> Bool {
        guard let id = UUID(uuidString: room.id) else { return false }
        return await performOnline(action: "room.message", id: id, payload: ["text": .string(text)])
    }

    func onlineRoomMessages(_ room: PartyRoom) -> [ChatMessage] {
        UUID(uuidString: room.id).map { onlineMessages(parentID: $0) } ?? []
    }

    func reportOnline(_ target: ContentSafetyTarget, reason: ContentReportReason, details: String) async -> Bool {
        guard let id = UUID(uuidString: target.id) else { noteSaveError("This content is unavailable."); return false }
        let kind: String
        switch target.kind { case .profile: kind = "profile"; case .post: kind = "post"; case .comment: kind = onlineRecords["message"]?.contains { $0.id == id } == true ? "message" : "comment"; case .party: kind = "room"; default: return false }
        return await performOnline(action: "report.save", id: UUID(), payload: [
            "target_id": .string(id.uuidString), "target_kind": .string(kind), "reason": .string(reason.rawValue), "details": .string(details)
        ])
    }

    func retryPendingOnlineChanges() async -> Bool {
        guard !onlineMutationInProgress, !onlineReadInProgress, TotiBackend.shared.isAuthenticated else {
            noteSaveError("Wait for the current request to finish."); return false
        }
        let generation = TotiBackend.shared.generation
        onlineMutationInProgress = true
        objectWillChange.send()
        defer { onlineMutationInProgress = false; objectWillChange.send() }
        do {
            try await TotiBackend.shared.retryPendingOperations()
            guard generation == TotiBackend.shared.generation else { return false }
            _ = await refreshOnline(afterMutation: true)
            return true
        } catch {
            guard generation == TotiBackend.shared.generation else { return false }
            let detail = error.localizedDescription
            // Earlier operations may already be acknowledged even if a later retry failed.
            _ = await refreshOnline(afterMutation: true)
            noteSaveError("Some pending changes may already be saved. " + detail)
            return false
        }
    }

    func signOutOnline() async -> Bool {
        guard !onlineMutationInProgress else { noteSaveError("Wait for the current request to finish."); return false }
        do {
            try await TotiBackend.shared.signOut()
            finishOnlineExit()
            return true
        } catch {
            noteSaveError(error.localizedDescription)
            // Local credentials may have been cleared even if server revocation failed.
            if !TotiBackend.shared.isAuthenticated { finishOnlineExit() }
            return false
        }
    }

    func deleteOnlineAccount() async -> Bool {
        guard !onlineMutationInProgress else { return false }
        do {
            try await TotiBackend.shared.deleteAccount()
            finishOnlineExit()
            return true
        } catch {
            noteSaveError(error.localizedDescription)
            if !TotiBackend.shared.isAuthenticated { finishOnlineExit() }
            return false
        }
    }
}

private func decodeOnline<T: Decodable>(_ type: T.Type, body: [String: JSONValue]) throws -> T {
    try JSONDecoder().decode(type, from: JSONEncoder().encode(body))
}

extension OnlineRecord {
    func string(_ key: String) -> String? { body[key]?.stringValue }
    func bool(_ key: String) -> Bool? { body[key]?.boolValue }
    func uuid(_ key: String) -> UUID? { string(key).flatMap(UUID.init(uuidString:)) }
    func strings(_ key: String) -> [String] { body[key]?.arrayValue?.compactMap(\.stringValue) ?? [] }
    func integer(_ key: String) -> Int? {
        guard case let .number(value)? = body[key], value.isFinite, value >= Double(Int.min), value < Double(Int.max) else { return nil }
        return Int(value)
    }
    var createdDate: Date { Self.date(created_at) }
    var updatedDate: Date { Self.date(updated_at) }
    private static func date(_ text: String) -> Date {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: text) ?? ISO8601DateFormatter().date(from: text) ?? .distantPast
    }
}
