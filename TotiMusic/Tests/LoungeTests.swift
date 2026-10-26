import XCTest
import UIKit
@testable import toti

final class LoungeTests: XCTestCase {
    private var author: CreatorProfile { CreatorProfile(id: "local-owner", name: "Me", biography: "", isLocalOwner: true) }

    func testPostValidationAcceptsUnicodeAndCountsGraphemes() {
        var post = LoungePost(author: author, body: String(repeating: "🎵", count: 1_000))
        XCTAssertNil(post.validationError(asDraft: false))
        post.body += "x"
        XCTAssertNotNil(post.validationError(asDraft: false))
        XCTAssertNil(post.validationError(asDraft: true))
        post.body = " \n "
        XCTAssertNotNil(post.validationError(asDraft: false))
        XCTAssertNil(post.validationError(asDraft: true))
    }

    func testDraftDoesNotLeakIntoFeedAndPhotoRoundTrips() throws {
        let draft = LoungePost(author: author, body: "private idea", isDraft: true, photoJPEG: Data([1,2,3]))
        let state = LoungeState(posts: [draft], likedPostIDs: [draft.id], savedPostIDs: [draft.id])
        let decoded = try JSONDecoder().decode(LoungeState.self, from: JSONEncoder().encode(state))
        XCTAssertEqual(decoded.posts.first?.photoJPEG, draft.photoJPEG)
        XCTAssertEqual(decoded.savedPostIDs, state.savedPostIDs)
        XCTAssertTrue(decoded.visiblePosts(blockedAuthorIDs: [], hiddenPostIDs: []).isEmpty)
    }

    func testVisibilityRemovesBlockedAndReportedPostsWithoutDeletingData() {
        let mine = LoungePost(author: author, body: "A melody")
        let other = LoungePost(author: CreatorProfile(id: "other", name: "Other", biography: ""), body: "A rhythm")
        let state = LoungeState(posts: [mine, other])
        XCTAssertEqual(state.visiblePosts(blockedAuthorIDs: ["other"], hiddenPostIDs: []).map(\.id), [mine.id])
        XCTAssertEqual(state.visiblePosts(blockedAuthorIDs: [], hiddenPostIDs: [mine.id]).map(\.id), [other.id])
        XCTAssertEqual(state.posts.count, 2)
    }

    func testCommentValidationAndPhotoBounds() {
        XCTAssertNotNil(LoungeComment.validationError("  "))
        XCTAssertNil(LoungeComment.validationError(String(repeating: "é", count: 500)))
        XCTAssertNotNil(LoungeComment.validationError(String(repeating: "é", count: 501)))
        let post = LoungePost(author: author, body: "Photo", photoJPEG: Data(count: 1_048_577))
        XCTAssertNotNil(post.validationError(asDraft: false))
    }

    func testSeedIDsStableAndNoInventedInteractions() {
        XCTAssertEqual(LoungeState.editorialPosts.map { $0.id.uuidString }, [
            "16F40C60-5DC2-4DB5-BF99-000000000001",
            "16F40C60-5DC2-4DB5-BF99-000000000002",
            "16F40C60-5DC2-4DB5-BF99-000000000003"
        ])
        XCTAssertTrue(LoungeState.editorialPosts.allSatisfy { $0.isEditorial && !$0.author.isLocalOwner })
        XCTAssertEqual(Set(LoungeState.editorialPosts.map(\.id)).count, LoungeState.editorialPosts.count)
        XCTAssertTrue(LoungeState().likedPostIDs.isEmpty)
        XCTAssertTrue(LoungeState().savedPostIDs.isEmpty)
        XCTAssertTrue(LoungeState().comments.isEmpty)
    }

    func testSearchIncludesTopicAndAuthorAndIgnoresCase() {
        let post = LoungePost(author: author, body: "A quiet melody", topic: .concerts)
        XCTAssertTrue(post.matches("  MELODY  "))
        XCTAssertTrue(post.matches("concerts"))
        XCTAssertTrue(post.matches("Me"))
        XCTAssertFalse(post.matches("drums"))
    }

    @MainActor
    func testPhotoImportDownsamplesAndRejectsInvalidBytes() throws {
        XCTAssertNil(LoungePhotoImport.normalizedJPEG(Data([0, 1, 2, 3])))
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let image = UIGraphicsImageRenderer(size: CGSize(width: 2_400, height: 1_800), format: format).image { context in
            UIColor.orange.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 2_400, height: 1_800))
        }
        let source = try XCTUnwrap(image.jpegData(compressionQuality: 1))
        let jpeg = try XCTUnwrap(LoungePhotoImport.normalizedJPEG(source))
        let decoded = try XCTUnwrap(UIImage(data: jpeg))
        XCTAssertLessThanOrEqual(jpeg.count, 1_048_576)
        XCTAssertEqual(decoded.size.width, 1_200)
        XCTAssertEqual(decoded.size.height, 900)
    }

}
