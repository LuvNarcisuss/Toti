import XCTest
@testable import toti

@MainActor
final class CommunityWorkflowTests: XCTestCase {
  func testPrivateNoteToSeparatePostAndInteractionsSurviveRelaunch() async throws {
    // An isolated fixture root exercises local consent/session state, never the user's account.
    let root = FileManager.default.temporaryDirectory.appendingPathComponent("TotiWorkflow-" + UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let store = AppStore(storageRoot: root)
    await store.load()
    XCTAssertTrue(store.isLoaded)
    let entered = await store.acceptUserAgreement()
    XCTAssertTrue(entered)
    let note = InspirationNote(title: "Rain rhythm", body: "A new chorus", category: .lyrics)
    let noteSaved = await store.saveNotebookNote(note)
    XCTAssertTrue(noteSaved)
    var post = LoungePost(author: .signedIn(store.library.profile), body: note.postDraftText)
    let drafted = await store.saveLoungePost(post, asDraft: true)
    XCTAssertTrue(drafted)
    XCTAssertFalse(store.loungePosts.contains { $0.id == post.id })
    XCTAssertEqual(store.loungeDrafts.first?.body, note.postDraftText)
    XCTAssertEqual(store.notebookNotes.first?.id, note.id)
    post.body = "Rain rhythm: a new chorus"
    let posted = await store.saveLoungePost(post, asDraft: false)
    XCTAssertTrue(posted)
    let liked = await store.toggleLoungeLike(post.id)
    let saved = await store.toggleLoungeSave(post.id)
    let replied = await store.addLoungeComment("A phrase worth keeping", postID: post.id)
    XCTAssertTrue(liked && saved && replied)
    let loggedOut = await store.logOut()
    XCTAssertTrue(loggedOut)
    let restored = AppStore(storageRoot: root)
    await restored.load()
    XCTAssertTrue(restored.isLoaded)
    XCTAssertEqual(restored.notebookNotes.first?.body, "A new chorus")
    XCTAssertTrue(restored.savedLoungePosts.contains { $0.id == post.id })
    XCTAssertEqual(restored.loungeComments(for: post.id).count, 1)
    XCTAssertFalse(restored.loungeDrafts.contains { $0.id == post.id })
  }

  func testReportedPostDisappearsFromFeedSavedAndAuthorProfile() async throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent("TotiVisibility-" + UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let store = AppStore(storageRoot: root)
    await store.load()
    let entered = await store.acceptUserAgreement()
    XCTAssertTrue(entered)
    let post = try XCTUnwrap(store.loungePosts.first)
    XCTAssertEqual(store.statistics(for: post.author).following, 0)
    XCTAssertEqual(store.statistics(for: post.author).followers, 0)
    await store.toggleProfileFollow(post.author)
    XCTAssertEqual(store.statistics(for: post.author).followers, 1)
    let saved = await store.toggleLoungeSave(post.id)
    XCTAssertTrue(saved)
    let reported = await store.saveContentReport(ContentSafetyTarget(id: post.id.uuidString, title: post.body, kind: .post, creator: post.author), reason: .spam, details: "")
    XCTAssertTrue(reported)
    XCTAssertNil(store.loungePost(post.id))
    XCTAssertFalse(store.savedLoungePosts.contains { $0.id == post.id })
    XCTAssertFalse(store.loungePosts(for: post.author.id).contains { $0.id == post.id })
  }
}
