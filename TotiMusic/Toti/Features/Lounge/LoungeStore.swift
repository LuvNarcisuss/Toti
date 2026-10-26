import Foundation

@MainActor
extension AppStore {
    var loungePosts: [LoungePost] {
        var state = library.lounge ?? LoungeState()
        state.posts += LoungeState.editorialPosts
        let hidden = Set((library.contentSafety?.reports ?? []).filter { $0.kind == .post }.compactMap { UUID(uuidString: $0.contentID) })
        return state.visiblePosts(blockedAuthorIDs: Set(library.contentSafety?.blockedCreators.keys.map { $0 } ?? []), hiddenPostIDs: hidden)
            .map(currentLoungeAuthor).sorted { $0.createdAt > $1.createdAt }
    }

    var loungeDrafts: [LoungePost] {
        (library.lounge?.posts ?? []).filter { $0.isDraft && $0.author.isLocalOwner }.map(currentLoungeAuthor).sorted { $0.updatedAt > $1.updatedAt }
    }

    var savedLoungePosts: [LoungePost] { loungePosts.filter { library.lounge?.savedPostIDs.contains($0.id) == true } }
    func loungePosts(for authorID: String) -> [LoungePost] { loungePosts.filter { $0.author.id == authorID } }
    func loungePost(_ id: UUID) -> LoungePost? { loungePosts.first { $0.id == id } }
    func loungeComments(for postID: UUID) -> [LoungeComment] {
        guard loungePost(postID) != nil else { return [] }
        return (library.lounge?.comments ?? []).filter {
            $0.postID == postID && !isCreatorBlocked($0.author.id) && !isCommentReported($0.id.uuidString)
        }.sorted { $0.createdAt < $1.createdAt }
    }

    var loungeVoiceRooms: [PartyRoom] {
        (library.roomDrafts.map(MusicRoomCatalog.room(from:)) + MusicRoomCatalog.rooms).filter { room in
            room.type == .voice && !isPartyReported(room.id) && !isCreatorBlocked("party:" + room.id)
                && !room.participants.contains { isCreatorBlocked($0.id) }
        }
    }

    private func currentLoungeAuthor(_ post: LoungePost) -> LoungePost {
        var post = post
        if post.author.isLocalOwner { post.author = .signedIn(library.profile) }
        return post
    }

    func saveLoungePost(_ post: LoungePost, asDraft: Bool) async -> Bool {
        guard post.author.isLocalOwner, !post.isEditorial else { noteSaveError("Only your own posts can be edited."); return false }
        if let error = post.validationError(asDraft: asDraft) { noteSaveError(error); return false }
        var updated = library
        var state = updated.lounge ?? LoungeState()
        if let existing = state.posts.first(where: { $0.id == post.id }), !existing.author.isLocalOwner { return false }
        var saved = post
        saved.author = .signedIn(library.profile)
        saved.isDraft = asDraft
        saved.updatedAt = Date()
        if let previous = state.posts.first(where: { $0.id == saved.id }), previous.isDraft && !asDraft {
            saved.createdAt = Date()
        }
        if let index = state.posts.firstIndex(where: { $0.id == saved.id }) { state.posts[index] = saved }
        else { state.posts.append(saved) }
        updated.lounge = state
        return await commit(updated)
    }

    func deleteLoungePost(_ id: UUID) async -> Bool {
        var updated = library
        guard var state = updated.lounge, state.posts.contains(where: { $0.id == id && $0.author.isLocalOwner }) else { return false }
        state.posts.removeAll { $0.id == id }
        state.comments.removeAll { $0.postID == id }
        state.likedPostIDs.remove(id)
        state.savedPostIDs.remove(id)
        updated.lounge = state
        return await commit(updated)
    }

    func toggleLoungeLike(_ id: UUID) async -> Bool {
        guard loungePost(id) != nil else { noteSaveError("This post is no longer available."); return false }
        var updated = library
        var state = updated.lounge ?? LoungeState()
        if !state.likedPostIDs.insert(id).inserted { state.likedPostIDs.remove(id) }
        updated.lounge = state
        return await commit(updated)
    }

    func toggleLoungeSave(_ id: UUID) async -> Bool {
        guard loungePost(id) != nil else { noteSaveError("This post is no longer available."); return false }
        var updated = library
        var state = updated.lounge ?? LoungeState()
        if !state.savedPostIDs.insert(id).inserted { state.savedPostIDs.remove(id) }
        updated.lounge = state
        return await commit(updated)
    }

    func addLoungeComment(_ text: String, postID: UUID) async -> Bool {
        if let error = LoungeComment.validationError(text) { noteSaveError(error); return false }
        guard loungePost(postID) != nil else { noteSaveError("This post is no longer available."); return false }
        var updated = library
        var state = updated.lounge ?? LoungeState()
        state.comments.append(LoungeComment(postID: postID, author: .signedIn(library.profile), body: text.trimmingCharacters(in: .whitespacesAndNewlines)))
        updated.lounge = state
        return await commit(updated)
    }

    func deleteLoungeComment(_ id: UUID) async -> Bool {
        var updated = library
        guard var state = updated.lounge, state.comments.contains(where: { $0.id == id && $0.author.isLocalOwner }) else { return false }
        state.comments.removeAll { $0.id == id }
        updated.lounge = state
        return await commit(updated)
    }
}
