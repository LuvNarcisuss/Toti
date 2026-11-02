import XCTest
import Supabase
@testable import toti

final class OnlineMediaRecoveryTests: XCTestCase {
    private var root: URL!
    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent("TotiMediaRecovery-" + UUID().uuidString, isDirectory: true)
    }
    override func tearDownWithError() throws {
        if FileManager.default.fileExists(atPath: root.path) { try FileManager.default.removeItem(at: root) }
    }

    func testUploadIdentityAndExactBytesSurviveReinitialization() async throws {
        let account = UUID(), entity = UUID(), bytes = Data([1, 2, 3, 4])
        let first = try await OnlineMediaJournal(root: root).begin(account: account, jpeg: bytes, kind: "post", entityID: entity)
        let second = try await OnlineMediaJournal(root: root).begin(account: account, jpeg: bytes, kind: "post", entityID: entity)
        XCTAssertEqual(first.revisionID, second.revisionID)
        XCTAssertEqual(second.jpeg, bytes)
    }

    func testPrivateUploadDoesNotEnterAnotherAccountJournal() async throws {
        let journal = OnlineMediaJournal(root: root), account = UUID(), other = UUID(), entity = UUID()
        _ = try await journal.begin(account: account, jpeg: Data([1]), kind: "avatar", entityID: entity)
        let unseen = try await journal.pending(account: other)
        XCTAssertTrue(unseen.isEmpty)
        let separate = try await journal.begin(account: other, jpeg: Data([2]), kind: "avatar", entityID: entity)
        let originals = try await journal.pending(account: account)
        XCTAssertNotEqual(originals.first?.revisionID, separate.revisionID)
    }

    func testAcknowledgementRemainsRecoverableUntilAttachment() async throws {
        let account = UUID(), entity = UUID(), journal = OnlineMediaJournal(root: root)
        let entry = try await journal.begin(account: account, jpeg: Data([1, 2]), kind: "post", entityID: entity)
        let revision = OnlineMediaRevision(id: entry.revisionID, entity_id: entity, kind: "post", status: "pending", sha256: String(repeating: "a", count: 64))
        await journal.acknowledge(entry, revision: revision, account: account)
        let reopened = OnlineMediaJournal(root: root)
        let retry = try await reopened.begin(account: account, jpeg: entry.jpeg, kind: "post", entityID: entity)
        XCTAssertEqual(retry.revision?.id, entry.revisionID)
        await reopened.complete(revisionID: entry.revisionID, account: account)
        let final = try await OnlineMediaJournal(root: root).pending(account: account)
        XCTAssertTrue(final.isEmpty)
    }

    func testDefiniteSQLRejectionReleasesOnlyLinkedPhotoForCorrection() async throws {
        let account = UUID(), entity = UUID()
        let media = OnlineMediaJournal(root: root.appendingPathComponent("Media"))
        let operations = OnlineOperationJournal(root: root.appendingPathComponent("Operations"))
        let upload = try await media.begin(account: account, jpeg: Data([1]), kind: "post", entityID: entity)
        let unrelated = try await media.begin(account: account, jpeg: Data([9]), kind: "post", entityID: UUID())
        let mutation = try await operations.begin(account: account, action: "post.save", entityID: entity,
            payload: ["media_revision_id": .string(upload.revisionID.uuidString), "expected_version": .number(1)])
        let released = try await OnlineMutationRecovery.discardRejectedIntent(
            error: PostgrestError(code: "40001", message: "Reload before editing"), entry: mutation,
            account: account, operations: operations, media: media)
        XCTAssertTrue(released)
        let pendingMedia = try await media.pending(account: account)
        XCTAssertEqual(pendingMedia.map(\.revisionID), [unrelated.revisionID])
        let pendingOperations = try await operations.pending(account: account)
        XCTAssertTrue(pendingOperations.isEmpty)
        let corrected = try await media.begin(account: account, jpeg: Data([2]), kind: "post", entityID: entity)
        XCTAssertNotEqual(corrected.revisionID, upload.revisionID)
    }

    func testUnknownOutcomePreservesBothIntentsAndBlocksChangedBytes() async throws {
        let account = UUID(), entity = UUID()
        let mediaRoot = root.appendingPathComponent("Media"), operationRoot = root.appendingPathComponent("Operations")
        let media = OnlineMediaJournal(root: mediaRoot), operations = OnlineOperationJournal(root: operationRoot)
        let upload = try await media.begin(account: account, jpeg: Data([1]), kind: "post", entityID: entity)
        let mutation = try await operations.begin(account: account, action: "post.save", entityID: entity,
            payload: ["media_revision_id": .string(upload.revisionID.uuidString)])
        let released = try await OnlineMutationRecovery.discardRejectedIntent(error: URLError(.timedOut),
            entry: mutation, account: account, operations: operations, media: media)
        XCTAssertFalse(released)
        let pendingOperations = try await OnlineOperationJournal(root: operationRoot).pending(account: account)
        XCTAssertEqual(pendingOperations.first?.operationID, mutation.operationID)
        let reopened = OnlineMediaJournal(root: mediaRoot)
        let pendingMedia = try await reopened.pending(account: account)
        XCTAssertEqual(pendingMedia.first?.jpeg, upload.jpeg)
        XCTAssertEqual(pendingMedia.first?.revisionID, upload.revisionID)
        do {
            _ = try await reopened.begin(account: account, jpeg: Data([2]), kind: "post", entityID: entity)
            XCTFail("A photo with an uncertain outcome must retain its exact retry identity.")
        } catch TotiBackendError.pendingChange { }
    }
}
