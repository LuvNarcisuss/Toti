import XCTest
@testable import toti

final class OnlineOperationRecoveryTests: XCTestCase {
    private var root: URL!

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent("TotiOperationRecovery-" + UUID().uuidString, isDirectory: true)
    }
    override func tearDownWithError() throws {
        if FileManager.default.fileExists(atPath: root.path) { try FileManager.default.removeItem(at: root) }
    }

    func testUncertainMessageSurvivesRelaunchWithoutDuplicateIdentity() async throws {
        let account = UUID(), conversation = UUID()
        let payload: [String: JSONValue] = ["conversation_id": .string(conversation.uuidString), "text": .string("A new melody")]
        let first = try await OnlineOperationJournal(root: root).begin(account: account, action: "message.send", entityID: UUID(), payload: payload)
        let reopened = OnlineOperationJournal(root: root)
        let retry = try await reopened.begin(account: account, action: "message.send", entityID: UUID(), payload: payload)
        XCTAssertEqual(first.operationID, retry.operationID)
        XCTAssertEqual(first.entityID, retry.entityID)
        XCTAssertEqual(retry.payload, payload)
    }

    func testSameTextInDifferentRoomsNeverReusesPendingDestination() async throws {
        let journal = OnlineOperationJournal(root: root), account = UUID()
        let first = try await journal.begin(account: account, action: "room.message", entityID: UUID(), payload: ["text": .string("Hello")])
        let second = try await journal.begin(account: account, action: "room.message", entityID: UUID(), payload: ["text": .string("Hello")])
        XCTAssertNotEqual(first.operationID, second.operationID)
        XCTAssertNotEqual(first.entityID, second.entityID)
    }

    func testPendingPrivatePayloadIsIsolatedBetweenAccounts() async throws {
        let journal = OnlineOperationJournal(root: root), firstAccount = UUID(), secondAccount = UUID(), note = UUID()
        let payload: [String: JSONValue] = ["title": .string("Private lyric"), "body": .string("Keep this in my notebook")]
        let first = try await journal.begin(account: firstAccount, action: "note.save", entityID: note, payload: payload)
        let before = try await journal.pending(account: secondAccount)
        XCTAssertTrue(before.isEmpty)
        let second = try await journal.begin(account: secondAccount, action: "note.save", entityID: note, payload: payload)
        XCTAssertNotEqual(first.operationID, second.operationID)
    }

    func testConflictingEditRetainsRecoverableOriginalPayload() async throws {
        let account = UUID(), note = UUID(), journal = OnlineOperationJournal(root: root)
        let original: [String: JSONValue] = ["body": .string("Original unsaved verse"), "expected_version": .number(3)]
        let entry = try await journal.begin(account: account, action: "note.save", entityID: note, payload: original)
        do {
            _ = try await journal.begin(account: account, action: "note.save", entityID: note, payload: ["body": .string("Changed verse")])
            XCTFail("An uncertain earlier edit must be resolved first.")
        } catch TotiBackendError.pendingChange { }
        let recovered = try await OnlineOperationJournal(root: root).pending(account: account)
        XCTAssertEqual(recovered.first?.payload, original)
        try await journal.reject(entry, account: account)
        let corrected = try await journal.begin(account: account, action: "note.save", entityID: note, payload: ["body": .string("Changed verse")])
        XCTAssertNotEqual(corrected.operationID, entry.operationID)
    }

    func testAcknowledgedMessageAllowsIntentionalRepeatAsNewOperation() async throws {
        let journal = OnlineOperationJournal(root: root), account = UUID()
        let payload: [String: JSONValue] = ["conversation_id": .string(UUID().uuidString), "text": .string("Encore")]
        let first = try await journal.begin(account: account, action: "message.send", entityID: UUID(), payload: payload)
        await journal.acknowledge(first, receipt: OnlineMutationReceipt(entity_id: first.entityID, version: 1, status: "saved"), account: account)
        let removed = await journal.complete(first, account: account)
        XCTAssertTrue(removed)
        let second = try await journal.begin(account: account, action: "message.send", entityID: UUID(), payload: payload)
        XCTAssertNotEqual(first.operationID, second.operationID)
    }
}

final class OnlineSecureSessionTests: XCTestCase {
    func testSecureSessionSurvivesStorageReinitialization() throws {
        let key = "acceptance-session-" + UUID().uuidString
        let value = Data("Disposable session persistence probe".utf8)
        let storage = TotiKeychainStorage()
        defer { try? storage.remove(key: key) }
        try storage.store(key: key, value: value)
        XCTAssertEqual(try TotiKeychainStorage().retrieve(key: key), value)
        try storage.remove(key: key)
        XCTAssertNil(try TotiKeychainStorage().retrieve(key: key))
    }
}


@MainActor
final class OnlineGuestServiceAcceptanceTests: XCTestCase {
    func testGuestLoginPersistsRestoresAndDeletesOnlyItsTestAccount() async throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["TOTI_LIVE_GUEST_ACCEPTANCE"] == "1",
                          "Requires explicit authorization for disposable cloud guest creation and deletion.")
        let key = "acceptance-guest-" + UUID().uuidString
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(key, isDirectory: true)
        let service = TotiBackend(storageKey: key, journalRoot: root)
        defer {
            try? TotiKeychainStorage().remove(key: key)
            try? FileManager.default.removeItem(at: root)
        }
        do {
            try await service.signInAsGuest(agreementVersion: "guest-acceptance-test-not-user-consent")
            let account = try XCTUnwrap(service.accountID)
            let page = try await service.page(kind: "profile", parentID: account)
            XCTAssertEqual(page.records.first?.id, account)
            let restored = TotiBackend(storageKey: key, journalRoot: root)
            try await restored.restore()
            XCTAssertEqual(restored.accountID, account)
            let notes = try await restored.page(kind: "note")
            XCTAssertTrue(notes.records.isEmpty)
            try await restored.deleteAccount()
            XCTAssertFalse(restored.isAuthenticated)
        } catch {
            if service.accountID != nil { try? await service.deleteAccount() }
            throw error
        }
    }
}
