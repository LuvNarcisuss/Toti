import Foundation
import UIKit
import XCTest
@testable import toti

final class NotebookTests: XCTestCase {
  func testUnicodeLimitsAllowFullDraftAndNeverTruncate() throws {
    let text = String(repeating: "🎼", count: 10_000)
    let note = InspirationNote(title: String(repeating: "é", count: 80), body: text)
    XCTAssertNoThrow(try note.validate())
    XCTAssertEqual(note.body, text)
    var tooLong = note
    tooLong.body += "a"
    XCTAssertThrowsError(try tooLong.validate())
    tooLong = note
    tooLong.title += "a"
    XCTAssertThrowsError(try tooLong.validate())
    XCTAssertNoThrow(try InspirationNote(title: "", body: "").validate())
    XCTAssertEqual(InspirationNote(title: " \n", body: "idea").displayTitle, "Untitled idea")
  }

  func testRoundTripPreservesPrivateNoteAndTimestamps() throws {
    let note = InspirationNote(title: "Bridge", body: "Cmaj7 → Am7\nA second line", category: .chords,
      mood: .reflective, isPinned: true, createdAt: Date(timeIntervalSince1970: 123),
      updatedAt: Date(timeIntervalSince1970: 456))
    let state = NotebookState(notes: [note])
    let restored = try JSONDecoder().decode(NotebookState.self, from: JSONEncoder().encode(state))
    XCTAssertEqual(restored, state)
  }

  func testEditPreservesIdentityAndCreationDateWithoutAppending() throws {
    let created = Date(timeIntervalSince1970: 100)
    let note = InspirationNote(title: "First", body: "verse", createdAt: created)
    var state = NotebookState(notes: [note])
    var edit = note
    edit.title = "Rewritten"
    edit.createdAt = Date(timeIntervalSince1970: 999)
    try state.save(edit, at: Date(timeIntervalSince1970: 200))
    XCTAssertEqual(state.notes.count, 1)
    XCTAssertEqual(state.notes[0].id, note.id)
    XCTAssertEqual(state.notes[0].title, "Rewritten")
    XCTAssertEqual(state.notes[0].createdAt, created)
    XCTAssertEqual(state.notes[0].updatedAt, Date(timeIntervalSince1970: 200))
  }

  func testInvalidSaveLeavesExistingStateUntouched() throws {
    let note = InspirationNote(title: "Keep", body: "original")
    var state = NotebookState(notes: [note])
    var edit = note
    edit.body = String(repeating: "x", count: 10_001)
    XCTAssertThrowsError(try state.save(edit))
    XCTAssertEqual(state.notes, [note])
  }

  func testDuplicateCopiesAllTextWithSeparateIdentityAndUnpinnedState() {
    let note = InspirationNote(title: String(repeating: "T", count: 80), body: "private lyric",
      category: .lyrics, mood: .hopeful, isPinned: true)
    let copy = note.duplicate(at: Date(timeIntervalSince1970: 400))
    XCTAssertNotEqual(copy.id, note.id)
    XCTAssertEqual(copy.title, note.title)
    XCTAssertEqual(copy.body, "private lyric")
    XCTAssertEqual(copy.category, .lyrics)
    XCTAssertEqual(copy.mood, .hopeful)
    XCTAssertFalse(copy.isPinned)
    XCTAssertEqual(copy.createdAt, Date(timeIntervalSince1970: 400))
  }

  func testSearchFiltersCategoryMoodAndBodyWithPinnedFirst() {
    let old = InspirationNote(title: "Night", body: "piano", category: .ideas,
      mood: .reflective, isPinned: true, updatedAt: Date(timeIntervalSince1970: 100))
    let new = InspirationNote(title: "Morning", body: "PIANO", category: .chords,
      updatedAt: Date(timeIntervalSince1970: 200))
    let state = NotebookState(notes: [new, old])
    XCTAssertEqual(state.matching(query: "piano").map(\.id), [old.id, new.id])
    XCTAssertEqual(state.matching(query: "REFLECTIVE").map(\.id), [old.id])
    XCTAssertEqual(state.matching(category: .chords, query: "piano").map(\.id), [new.id])
    XCTAssertEqual(state.matching(query: "lyrics").count, 0)
  }

  func testPostConversionKeepsLongTextAndDoesNotModifyOriginal() {
    let note = InspirationNote(title: "My chorus", body: String(repeating: "a", count: 2_000))
    XCTAssertEqual(note.postDraftText, "My chorus\n\n" + String(repeating: "a", count: 2_000))
    XCTAssertEqual(note.body.count, 2_000)
    XCTAssertEqual(InspirationNote(title: "", body: "verse").postDraftText, "verse")
  }
}

/// Retained fixtures are removed only after the user's separate cleanup confirmation.
@MainActor
final class NotebookOnlineAcceptanceTests: XCTestCase {
  func testPrivateCloudLifecycleIsolationAndRetainedFriendFixture() async throws {
    try XCTSkipUnless(ProcessInfo.processInfo.environment["TOTI_LIVE_GUEST_ACCEPTANCE"] == "1",
      "Requires authorized temporary accounts and retained cloud fixtures.")
    let run = try XCTUnwrap(ProcessInfo.processInfo.environment["TOTI_GUEST_ACCEPTANCE"])
    _ = try XCTUnwrap(UUID(uuidString: run))
    let owner = TotiBackend.shared
    try await owner.restore()
    XCTAssertTrue(owner.isAuthenticated, "The UI-created isolated guest must be reused.")
    let ownerID = try XCTUnwrap(owner.accountID)
    let root = URL.applicationSupportDirectory.appendingPathComponent("TotiOnline/Acceptance/" + run)
    let other = TotiBackend(storageKey: "toti-notebook-partner-" + run,
      journalRoot: root.appendingPathComponent("Partner"))
    try await other.signInAsGuest(agreementVersion: "notebook-acceptance-not-user-consent")
    let otherID = try XCTUnwrap(other.accountID)
    print("NOTEBOOK_RETAINED_ACCOUNTS run=\(run) owner=\(ownerID) partner=\(otherID)")
    let initial = try await owner.page(kind: "note")
    XCTAssertTrue(initial.records.contains { $0.body["title"]?.stringValue == "UI Acceptance Melody" })
    let privateID = UUID()
    var note = InspirationNote(id: privateID, title: "Retained private chorus", body: "Only the owner may read or change this note.", category: .lyrics, mood: .hopeful)
    var payload = try JSONValue.object(note)
    payload["expected_version"] = .number(0)
    let created = try await owner.mutate(action: "note.save", entityID: privateID, payload: payload)
    XCTAssertEqual(created.entity_id, privateID)
    let ownPage = try await owner.page(kind: "note", parentID: privateID)
    XCTAssertEqual(ownPage.records.first?.body["body"]?.stringValue, note.body)
    let foreignPage = try await other.page(kind: "note", parentID: privateID)
    XCTAssertTrue(foreignPage.records.isEmpty, "A second guest cannot read private notes.")
    do {
      _ = try await other.mutate(action: "note.save", entityID: privateID, payload: payload)
      XCTFail("A second guest must not overwrite another guest's private note.")
    } catch { }
    note.body = "Edited private chorus retained for manual acceptance."
    note.isPinned = true
    payload = try JSONValue.object(note)
    payload["expected_version"] = .number(Double(created.version))
    let edited = try await owner.mutate(action: "note.save", entityID: privateID, payload: payload)
    XCTAssertGreaterThan(edited.version, created.version)
    let pinned = try await owner.page(kind: "note", parentID: privateID)
    XCTAssertEqual(pinned.records.first?.body["isPinned"]?.boolValue, true)
    do {
      _ = try await owner.mutate(action: "note.save", entityID: privateID, payload: payload)
      XCTFail("A stale version must not overwrite the current note.")
    } catch { }
    let copy = note.duplicate()
    var copiedPayload = try JSONValue.object(copy)
    copiedPayload["expected_version"] = .number(0)
    _ = try await owner.mutate(action: "note.save", entityID: copy.id, payload: copiedPayload)
    let copied = try await owner.page(kind: "note", parentID: copy.id)
    XCTAssertEqual(copied.records.first?.body["isPinned"]?.boolValue, false)
    // Delete only this dedicated deletion probe; retain the original and final UI fixtures.
    _ = try await owner.mutate(action: "note.delete", entityID: copy.id, payload: [:])
    let deleted = try await owner.page(kind: "note", parentID: copy.id)
    XCTAssertTrue(deleted.records.isEmpty)
    do {
      _ = try await other.mutate(action: "note.delete", entityID: privateID, payload: [:])
      XCTFail("A second guest must not delete another guest's note.")
    } catch { }
    let restored = TotiBackend(storageKey: "toti-acceptance-" + run,
      journalRoot: root.appendingPathComponent("RestoreProbe"))
    try await restored.restore()
    XCTAssertEqual(restored.accountID, ownerID)
    let persisted = try await restored.page(kind: "note", parentID: privateID)
    XCTAssertEqual(persisted.records.first?.body["body"]?.stringValue, note.body)
    _ = try await owner.mutate(action: "profile.save", entityID: ownerID,
      payload: ["displayName": .string("Notebook Acceptance"), "biography": .string("Temporary account retained for manual acceptance.")])
    _ = try await other.mutate(action: "profile.save", entityID: otherID,
      payload: ["displayName": .string("Acceptance Partner"), "biography": .string("Temporary test partner, retained by request.")])
    _ = try await owner.mutate(action: "follow.set", entityID: otherID, payload: ["enabled": .bool(true)])
    _ = try await other.mutate(action: "follow.set", entityID: ownerID, payload: ["enabled": .bool(true)])
    let conversation = try await owner.mutate(action: "conversation.open", entityID: UUID(),
      payload: ["peer_id": .string(otherID.uuidString)])
    _ = try await other.mutate(action: "message.send", entityID: UUID(), payload: [
      "conversation_id": .string(conversation.entity_id.uuidString),
      "text": .string("Retained acceptance chat. Voice and video require an RTC service.")])
    let messages = try await owner.page(kind: "message", parentID: conversation.entity_id)
    XCTAssertFalse(messages.records.isEmpty)
    print("NOTEBOOK_RETAINED_FIXTURES note=\(privateID) conversation=\(conversation.entity_id)")
    XCTAssertFalse(TotiBackendConfiguration.rtcEnabled)
  }
}

@MainActor
final class ChatAttachmentOnlineAcceptanceTests: XCTestCase {
  func testRetainedFriendsExchangePrivatePhotoAndFile() async throws {
    try XCTSkipUnless(ProcessInfo.processInfo.environment["TOTI_LIVE_GUEST_ACCEPTANCE"] == "1",
      "Requires authorized retained chat fixtures.")
    let run = try XCTUnwrap(ProcessInfo.processInfo.environment["TOTI_GUEST_ACCEPTANCE"])
    let owner = TotiBackend.shared
    try await owner.restore()
    let partner = TotiBackend(storageKey: "toti-notebook-partner-" + run,
      journalRoot: URL.applicationSupportDirectory.appendingPathComponent("TotiOnline/Acceptance/" + run + "/Partner"))
    try await partner.restore()
    let partnerID = try XCTUnwrap(partner.accountID)
    let conversations = try await owner.records(kind: "conversation")
    let conversation = try XCTUnwrap(conversations.first { $0.body["peer_id"]?.stringValue?.lowercased() == partnerID.uuidString.lowercased() })
    let photo = UIGraphicsImageRenderer(size: CGSize(width: 80, height: 60)).image { context in
      UIColor.systemOrange.setFill()
      context.fill(CGRect(x: 0, y: 0, width: 80, height: 60))
    }
    let jpeg = try XCTUnwrap(photo.jpegData(compressionQuality: 0.8))
    let imageID = UUID(), fileID = UUID()
    _ = try await owner.sendChatAttachment(jpeg, filename: "Acceptance photo.jpg", kind: "image",
      messageID: imageID, conversationID: conversation.id, text: "Retained attachment photo")
    let file = Data("Retained private file for manual chat attachment acceptance.\n".utf8)
    _ = try await owner.sendChatAttachment(file, filename: "Acceptance notes.txt", kind: "file",
      messageID: fileID, conversationID: conversation.id)
    let page = try await partner.page(kind: "message", parentID: conversation.id)
    let imageRow = try XCTUnwrap(page.records.first { $0.id == imageID })
    let fileRow = try XCTUnwrap(page.records.first { $0.id == fileID })
    func attachment(_ row: OnlineRecord) throws -> ChatAttachment {
      let value = try XCTUnwrap(row.body["attachment"])
      return try JSONDecoder().decode(ChatAttachment.self, from: JSONEncoder().encode(value))
    }
    let imageAttachment = try attachment(imageRow), fileAttachment = try attachment(fileRow)
    let receivedImage = try await partner.chatAttachmentData(imageAttachment)
    let receivedFile = try await partner.chatAttachmentData(fileAttachment)
    XCTAssertEqual(receivedImage, jpeg)
    XCTAssertEqual(receivedFile, file)
    XCTAssertEqual(imageAttachment.kind, "image")
    XCTAssertEqual(fileAttachment.filename, "Acceptance notes.txt")
    let publicURL = TotiBackendConfiguration.projectURL.appendingPathComponent("storage/v1/object/public/toti-chat-attachments/" + imageAttachment.path)
    let (_, response) = try await URLSession.shared.data(from: publicURL)
    XCTAssertNotEqual((response as? HTTPURLResponse)?.statusCode, 200, "Chat photos must not be public.")
    var blocked = false
    do {
      _ = try await owner.mutate(action: "block.set", entityID: partnerID, payload: ["enabled": .bool(true)])
      blocked = true
      do {
        _ = try await partner.chatAttachmentData(fileAttachment)
        XCTFail("Blocking must revoke authenticated attachment reads.")
      } catch { }
      _ = try await owner.mutate(action: "block.set", entityID: partnerID, payload: ["enabled": .bool(false)])
      blocked = false
    } catch {
      if blocked { _ = try? await owner.mutate(action: "block.set", entityID: partnerID, payload: ["enabled": .bool(false)]) }
      throw error
    }
    let ownerID = try XCTUnwrap(owner.accountID)
    _ = try await owner.mutate(action: "follow.set", entityID: partnerID, payload: ["enabled": .bool(true)])
    _ = try await partner.mutate(action: "follow.set", entityID: ownerID, payload: ["enabled": .bool(true)])
    let restoredRead = try await partner.chatAttachmentData(fileAttachment)
    XCTAssertEqual(restoredRead, file)
    print("RETAINED_CHAT_ATTACHMENTS photo=\(imageID) file=\(fileID) conversation=\(conversation.id)")
  }
}

final class EditorialPreferenceStorageTests: XCTestCase {
  func testRoomSafetyPreservesLegacyPreferencesAndSurvivesReload() throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    let storage = TotiEditorialPreferenceStorage(fileURL: root.appendingPathComponent("preferences.json"))
    let legacy = Data(#"{"followedAuthorIDs":["ava-bennett"],"blockedAuthorIDs":[],"drafts":{"ava-bennett":"Keep this"}}"#.utf8)
    try legacy.write(to: storage.fileURL)
    XCTAssertNil(try storage.read().roomReports)
    try storage.update {
      $0.blockedRoomTitles = ["community-artwork:room": "Music room"]
      $0.roomReports = ["community-artwork:room": TotiEditorialRoomReport(title: "Music room", reason: .spam, details: "Unwanted content", savedAt: Date())]
    }
    let saved = try storage.read()
    XCTAssertEqual(saved.blockedRoomTitles?["community-artwork:room"], "Music room")
    XCTAssertEqual(saved.roomReports?["community-artwork:room"]?.details, "Unwanted content")
    XCTAssertEqual(saved.drafts["ava-bennett"], "Keep this")
    XCTAssertTrue(saved.followedAuthorIDs.contains("ava-bennett"))
    try storage.update { $0.blockedRoomTitles?.removeAll(); $0.roomReports?.removeAll() }
    XCTAssertTrue(try storage.read().roomReports?.isEmpty == true)
    XCTAssertEqual(try storage.read().drafts, saved.drafts)
  }

  func testPreferencesAndPrivateDraftSurviveReloadWithoutCrossingAccounts() throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let first = TotiEditorialPreferenceStorage(fileURL: root.appendingPathComponent("first/preferences.json"))
    let second = TotiEditorialPreferenceStorage(fileURL: root.appendingPathComponent("second/preferences.json"))
    XCTAssertEqual(try first.read(), TotiEditorialPreferenceState())
    try first.update { state in
      state.followedAuthorIDs.insert("ava-bennett")
      state.blockedAuthorIDs.insert("ethan-cole")
      state.drafts["ava-bennett"] = "A private thought, never sent."
    }
    let reopened = TotiEditorialPreferenceStorage(fileURL: first.fileURL)
    XCTAssertTrue(try reopened.read().followedAuthorIDs.contains("ava-bennett"))
    XCTAssertTrue(try reopened.read().blockedAuthorIDs.contains("ethan-cole"))
    XCTAssertEqual(try reopened.read().drafts["ava-bennett"], "A private thought, never sent.")
    XCTAssertEqual(try second.read(), TotiEditorialPreferenceState())
  }

  func testCorruptPreferencesArePreservedAndRejectMutation() throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    let storage = TotiEditorialPreferenceStorage(fileURL: root.appendingPathComponent("preferences.json"))
    let original = Data("Unreadable preferences".utf8)
    try original.write(to: storage.fileURL)
    XCTAssertThrowsError(try storage.read())
    XCTAssertThrowsError(try storage.update { $0.followedAuthorIDs.insert("ava-bennett") })
    XCTAssertEqual(try Data(contentsOf: storage.fileURL), original)
  }

  func testOversizedDraftDoesNotReplaceAcknowledgedPreferences() throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let storage = TotiEditorialPreferenceStorage(fileURL: root.appendingPathComponent("preferences.json"))
    try storage.update { $0.drafts["ava-bennett"] = "Saved draft" }
    let original = try Data(contentsOf: storage.fileURL)
    XCTAssertThrowsError(try storage.update { $0.drafts["ava-bennett"] = String(repeating: "a", count: 2_001) })
    XCTAssertEqual(try Data(contentsOf: storage.fileURL), original)
  }
}

@MainActor
final class RetainedProfileRelationshipAcceptanceTests: XCTestCase {
  private func retainedBackends() async throws -> (TotiBackend, TotiBackend, UUID, UUID) {
    try XCTSkipUnless(ProcessInfo.processInfo.environment["TOTI_LIVE_GUEST_ACCEPTANCE"] == "1",
      "Requires authorized retained relationship acceptance.")
    let run = try XCTUnwrap(ProcessInfo.processInfo.environment["TOTI_GUEST_ACCEPTANCE"])
    let owner = TotiBackend.shared
    try await owner.restore()
    let ownerID = try XCTUnwrap(owner.accountID)
    XCTAssertEqual(ownerID.uuidString.lowercased(), "d1ae68c2-d6eb-495c-bf2b-a1b4b430a629")
    let root = URL.applicationSupportDirectory.appendingPathComponent("TotiOnline/Acceptance/" + run)
    let partner = TotiBackend(storageKey: "toti-notebook-partner-" + run,
      journalRoot: root.appendingPathComponent("Partner"))
    try await partner.restore()
    let partnerID = try XCTUnwrap(partner.accountID)
    XCTAssertEqual(partnerID.uuidString.lowercased(), "cded9cf8-1182-4802-ac9b-334c1c7d3040")
    guard ownerID.uuidString.lowercased() == "d1ae68c2-d6eb-495c-bf2b-a1b4b430a629",
      partnerID.uuidString.lowercased() == "cded9cf8-1182-4802-ac9b-334c1c7d3040" else {
      throw TotiBackendError.accountChanged
    }
    return (owner, partner, ownerID, partnerID)
  }

  private func restoreMutual(_ owner: TotiBackend, _ partner: TotiBackend, _ ownerID: UUID, _ partnerID: UUID) async throws {
    _ = try await owner.mutate(action: "block.set", entityID: partnerID, payload: ["enabled": .bool(false)])
    _ = try await partner.mutate(action: "block.set", entityID: ownerID, payload: ["enabled": .bool(false)])
    _ = try await owner.mutate(action: "follow.set", entityID: partnerID, payload: ["enabled": .bool(true)])
    _ = try await partner.mutate(action: "follow.set", entityID: ownerID, payload: ["enabled": .bool(true)])
  }

  func testRetainedRelationshipGateAndPreferenceSnapshot() async throws {
    let (owner, partner, ownerID, partnerID) = try await retainedBackends()
    let initial = try await owner.page(kind: "profile", parentID: partnerID)
    let profile = try XCTUnwrap(initial.records.first { $0.id == partnerID })
    XCTAssertEqual(profile.body["my_following"]?.boolValue, true)
    XCTAssertEqual(profile.body["follows_me"]?.boolValue, true)
    guard profile.body["my_following"]?.boolValue == true, profile.body["follows_me"]?.boolValue == true else {
      throw TotiBackendError.accountChanged
    }
    let preferences = try TotiEditorialPreferences.storage()
    let backup = preferences.fileURL.deletingLastPathComponent().appendingPathComponent("acceptance-baseline.json")
    let bytes: Data?
    do { bytes = try Data(contentsOf: preferences.fileURL) }
    catch let error as CocoaError where error.code == .fileReadNoSuchFile { bytes = nil }
    try FileManager.default.createDirectory(at: backup.deletingLastPathComponent(), withIntermediateDirectories: true)
    try JSONEncoder().encode(bytes).write(to: backup, options: [.atomic, .completeFileProtection])
    let store = AppStore()
    do {
      let refreshed = await store.refreshOnline()
      XCTAssertTrue(refreshed)
      let creator = store.onlineCreator(partnerID)
      XCTAssertTrue(store.isMutualProfile(creator))
      _ = try await owner.mutate(action: "follow.set", entityID: partnerID, payload: ["enabled": .bool(false)])
      _ = await store.refreshOnline()
      XCTAssertFalse(store.isMutualProfile(creator), "An incoming follow alone does not enable Message.")
      _ = try await partner.mutate(action: "follow.set", entityID: ownerID, payload: ["enabled": .bool(false)])
      _ = try await owner.mutate(action: "follow.set", entityID: partnerID, payload: ["enabled": .bool(true)])
      _ = await store.refreshOnline()
      XCTAssertTrue(store.followsProfile(creator))
      XCTAssertFalse(store.isMutualProfile(creator), "A unilateral outgoing follow does not enable Message.")
      _ = try await partner.mutate(action: "follow.set", entityID: ownerID, payload: ["enabled": .bool(true)])
      _ = await store.refreshOnline()
      XCTAssertTrue(store.isMutualProfile(creator))
      _ = try await owner.mutate(action: "block.set", entityID: partnerID, payload: ["enabled": .bool(true)])
      _ = await store.refreshOnline()
      XCTAssertTrue(store.isCreatorBlocked(creator.id))
      XCTAssertFalse(store.isMutualProfile(creator))
      _ = try await owner.mutate(action: "block.set", entityID: partnerID, payload: ["enabled": .bool(false)])
      _ = await store.refreshOnline()
      XCTAssertFalse(store.isCreatorBlocked(creator.id))
      XCTAssertFalse(store.isMutualProfile(creator), "Unblocking cannot manufacture restored mutual following.")
      try await restoreMutual(owner, partner, ownerID, partnerID)
    } catch {
      try await restoreMutual(owner, partner, ownerID, partnerID)
      throw error
    }
    print("PROFILE_RELATIONSHIP_SERVICE retained identities verified; incoming-only, outgoing-only, mutual, blocked and unblocked gates checked; baseline mutual restored.")
  }

  func testRestoreRetainedRelationshipsAndEditorialPreferences() async throws {
    let (owner, partner, ownerID, partnerID) = try await retainedBackends()
    try await restoreMutual(owner, partner, ownerID, partnerID)
    let preferences = try TotiEditorialPreferences.storage()
    let backup = preferences.fileURL.deletingLastPathComponent().appendingPathComponent("acceptance-baseline.json")
    let bytes = try JSONDecoder().decode(Data?.self, from: Data(contentsOf: backup))
    if let bytes { try bytes.write(to: preferences.fileURL, options: [.atomic, .completeFileProtection]) }
    else if FileManager.default.fileExists(atPath: preferences.fileURL.path) {
      try FileManager.default.removeItem(at: preferences.fileURL)
    }
    let restoredPage = try await owner.page(kind: "profile", parentID: partnerID)
    let profile = try XCTUnwrap(restoredPage.records.first)
    XCTAssertEqual(profile.body["my_following"]?.boolValue, true)
    XCTAssertEqual(profile.body["follows_me"]?.boolValue, true)
    print("PROFILE_RELATIONSHIP_RESTORED original mutual relationship and editorial preference bytes restored; no accounts or business records deleted.")
  }
}

@MainActor
final class ProfileMetricTests: XCTestCase {
  func testBibiMetricOrderAndReceivedValueMapping() {
    XCTAssertEqual(TotiProfileMetric.allCases.map(\.rawValue), ["Likes", "Saves", "Following", "Followers"])
    XCTAssertEqual(totiProfileCollectionCount(1), "1 post loaded")
    XCTAssertEqual(totiProfileCollectionCount(0), "0 posts loaded")
    XCTAssertEqual(totiProfileCollectionCount(1, noun: "draft"), "1 draft loaded")
    XCTAssertEqual(TotiProfileMetric.allCases.map(\.field), ["like_count", "save_count", "following_count", "follower_count"])
    let values = CreatorStatistics(likes: 17, saves: 11, following: 3, followers: 5)
    XCTAssertEqual(TotiProfileMetric.allCases.map { $0.value(in: values) }, [17, 11, 3, 5])
  }

  func testReceivedCountsResolveEmbeddedAuthorBeyondProfileDirectoryPage() {
    let authorID = UUID()
    let store = AppStore()
    let creator = CreatorProfile(id: authorID.uuidString.lowercased(), name: "Metric fixture", biography: "")
    store.onlineRecords["post"] = [OnlineRecord(id: UUID(), owner_id: authorID, kind: "post", parent_id: nil,
      body: ["owner_profile": .object(["id": .string(authorID.uuidString.lowercased()),
        "like_count": .number(17), "save_count": .number(11),
        "following_count": .number(3), "follower_count": .number(5)])],
      version: 1, created_at: "2026-11-02T00:00:00Z", updated_at: "2026-11-02T00:00:00Z")]
    let values = store.onlineStatistics(creator)
    XCTAssertEqual(values.likes, 17)
    XCTAssertEqual(values.saves, 11)
    XCTAssertEqual(values.following, 3)
    XCTAssertEqual(values.followers, 5)
    XCTAssertEqual(store.onlineProfileMetric("save_count", creatorID: authorID.uuidString), 11)
    XCTAssertNil(store.onlineProfileMetric("save_count", creatorID: UUID().uuidString))
  }

  func testMissingStatisticsStayUnknownRatherThanInventingZero() {
    let row = totiProfileMetrics(TotiProfileMetric.allCases.map { ($0.rawValue, nil) }) as! UIStackView
    XCTAssertEqual(row.arrangedSubviews.map(\.accessibilityLabel), ["Likes", "Saves", "Following", "Followers"])
    XCTAssertEqual(row.arrangedSubviews.map(\.accessibilityValue), ["—", "—", "—", "—"])
    XCTAssertEqual(ContentSafetyTarget.Kind.profile.rawValue, "Profile")
  }
}

@MainActor
final class EditorialPresentationFigureTests: XCTestCase {
  func testFiguresAreDistinctStableAndSeparateFromMemberStatistics() {
    let authors = Array(TotiEditorialAuthor.catalog.values)
    XCTAssertEqual(authors.count, 6)
    var signatures = Set<String>()
    let store = AppStore()
    for author in authors {
      guard let figures = author.presentationStatistics else { XCTFail("Missing editorial figures"); continue }
      XCTAssertGreaterThan(figures.likes, figures.saves)
      XCTAssertGreaterThan(figures.saves, 0)
      XCTAssertGreaterThan(figures.following, 0)
      XCTAssertGreaterThan(figures.followers, 0)
      let values = TotiProfileMetric.allCases.map { $0.value(in: figures) }
      signatures.insert(values.map(String.init).joined(separator: ","))
      XCTAssertEqual(author.presentationStatistics.map { $0.likes }, figures.likes)
      XCTAssertNil(store.onlineProfileMetric("follower_count", creatorID: author.id))
      XCTAssertFalse(store.isMutualProfile(CreatorProfile(id: author.id, name: author.name, biography: author.biography)))
    }
    XCTAssertEqual(signatures.count, 6)
    XCTAssertNil(TotiEditorialAuthor.publisher.presentationStatistics)
  }
}

@MainActor
final class EditorialPostActivityAcceptanceTests: XCTestCase {
  func testRetainedGuestReactionsRepliesAndOwnership() async throws {
    try XCTSkipUnless(ProcessInfo.processInfo.environment["TOTI_LIVE_GUEST_ACCEPTANCE"] == "1", "Requires retained Guest fixture authorization.")
    let run = try XCTUnwrap(ProcessInfo.processInfo.environment["TOTI_GUEST_ACCEPTANCE"])
    let owner = TotiBackend.shared
    try await owner.restore()
    XCTAssertEqual(owner.accountID?.uuidString.lowercased(), "d1ae68c2-d6eb-495c-bf2b-a1b4b430a629")
    let partner = TotiBackend(storageKey: "toti-notebook-partner-" + run,
      journalRoot: URL.applicationSupportDirectory.appendingPathComponent("TotiOnline/Acceptance/" + run + "/Partner"))
    try await partner.restore()
    XCTAssertEqual(partner.accountID?.uuidString.lowercased(), "cded9cf8-1182-4802-ac9b-334c1c7d3040")
    guard owner.accountID?.uuidString.lowercased() == "d1ae68c2-d6eb-495c-bf2b-a1b4b430a629",
      partner.accountID?.uuidString.lowercased() == "cded9cf8-1182-4802-ac9b-334c1c7d3040" else { throw TotiBackendError.accountChanged }
    let post = try XCTUnwrap(UUID(uuidString: "16f40c60-5dc2-4db5-bf99-000000000006"))
    let initial = try await owner.editorialActivity(postID: post)
    let peerInitial = try await partner.editorialActivity(postID: post)
    let request = UUID()
    let liked = try await owner.editorialActivity(postID: post, action: "like", payload: ["enabled": .bool(true)], requestID: request)
    let replay = try await owner.editorialActivity(postID: post, action: "like", payload: ["enabled": .bool(true)], requestID: request)
    XCTAssertEqual(liked.post.liked, true)
    XCTAssertEqual(liked.post.like_count, (initial.post.like_count ?? 0) + (initial.post.liked == true ? 0 : 1))
    XCTAssertEqual(replay.post.like_count, liked.post.like_count)
    do {
      _ = try await owner.editorialActivity(postID: post, action: "like", payload: ["enabled": .bool(false)], requestID: request)
      XCTFail("A request ID must not accept a changed payload")
    } catch { }
    let saved = try await owner.editorialActivity(postID: post, action: "save", payload: ["enabled": .bool(true)], requestID: UUID())
    XCTAssertEqual(saved.post.saved, true)
    let reloaded = try await owner.editorialPosts()
    XCTAssertEqual(reloaded.first { $0.id == post }?.saved, true)
    XCTAssertEqual(reloaded.first { $0.id == post }?.liked, true)
    let replyID = try XCTUnwrap(UUID(uuidString: "1ac20ba3-7cd6-4c7e-b989-ce3773957310"))
    let body = "Retained post acceptance: music brings people together."
    let payload: [String: JSONValue] = ["id": .string(replyID.uuidString), "body": .string(body)]
    let replyRequest = UUID()
    let replied = try await owner.editorialActivity(postID: post, action: "comment", payload: payload, requestID: replyRequest)
    let repeated = try await owner.editorialActivity(postID: post, action: "comment", payload: payload, requestID: replyRequest)
    XCTAssertEqual(repeated.comments.filter { $0.id == replyID }.count, 1)
    XCTAssertEqual(repeated.post.comment_count, replied.post.comment_count)
    let peer = try await partner.editorialActivity(postID: post)
    XCTAssertEqual(peer.comments.first { $0.id == replyID }?.author_id, owner.accountID)
    XCTAssertEqual(peer.post.liked, peerInitial.post.liked)
    XCTAssertEqual(peer.post.saved, peerInitial.post.saved)
    do {
      _ = try await partner.editorialActivity(postID: post, action: "delete_comment", payload: ["id": .string(replyID.uuidString)], requestID: UUID())
      XCTFail("A peer must not delete another member's reply")
    } catch { }
    do {
      _ = try await owner.editorialActivity(postID: post, action: "comment",
        payload: ["id": .string(UUID().uuidString), "body": .string(String(repeating: "a", count: 501))], requestID: UUID())
      XCTFail("The server must reject an oversized reply")
    } catch { }
    do {
      _ = try await owner.editorialActivity(postID: post, payload: ["before_id": .string(replyID.uuidString)])
      XCTFail("A partial pagination cursor must be rejected")
    } catch { }
    let transientID = UUID()
    _ = try await owner.editorialActivity(postID: post, action: "comment",
      payload: ["id": .string(transientID.uuidString), "body": .string("Reply deletion interaction check.")], requestID: UUID())
    let deleted = try await owner.editorialActivity(postID: post, action: "delete_comment", payload: ["id": .string(transientID.uuidString)], requestID: UUID())
    XCTAssertFalse(deleted.comments.contains { $0.id == transientID })
    XCTAssertTrue(deleted.comments.contains { $0.id == replyID })
    let finalPeer = try await partner.editorialActivity(postID: post)
    XCTAssertFalse(finalPeer.comments.contains { $0.id == transientID })
    XCTAssertTrue(finalPeer.comments.contains { $0.id == replyID })
    let memberPost = UUID(uuidString: "48c301f2-2dcc-4964-93bd-b2ea67e75bc4")!
    _ = try await owner.mutate(action: "post.save", entityID: memberPost, payload: [
      "body": .string("Retained member post acceptance: a quiet piano melody and a new chorus."),
      "topic": .string("Listening"), "isDraft": .bool(false)])
    _ = try await partner.mutate(action: "reaction.set", entityID: memberPost, payload: ["kind": .string("like"), "enabled": .bool(true)])
    _ = try await partner.mutate(action: "reaction.set", entityID: memberPost, payload: ["kind": .string("save"), "enabled": .bool(true)])
    _ = try await partner.mutate(action: "comment.save", entityID: UUID(uuidString: "b00cf06a-dbdc-42d7-a9f9-ce69ba8cc48c")!, payload: [
      "postID": .string(memberPost.uuidString), "body": .string("Retained reply on the member post.")])
    let memberPage = try await owner.page(kind: "post", parentID: memberPost)
    let member = try XCTUnwrap(memberPage.records.first { $0.id == memberPost })
    XCTAssertGreaterThanOrEqual(try XCTUnwrap(member.integer("save_count")), 1)
    XCTAssertGreaterThanOrEqual(try XCTUnwrap(member.integer("like_count")), 1)
    let record: [String: String] = ["post_id": post.uuidString, "retained_comment_id": replyID.uuidString,
      "owner_id": owner.accountID!.uuidString, "partner_id": partner.accountID!.uuidString, "member_post_id": memberPost.uuidString]
    try JSONEncoder().encode(record).write(to: URL(fileURLWithPath: "/private/tmp/toti-post-detail-fixtures.json"), options: .atomic)
  }

  func testEmbeddedCommentProfileCannotReplaceAnEditableProfileVersion() {
    let store = AppStore()
    let authorID = UUID()
    let post = OnlineEditorialPost(id: UUID(), title: "A melody", body: "Listen closely.", topic: "Listening", photo_asset: nil, created_at: "2026-11-02T00:00:00Z")
    store.onlineEditorialPosts = [post]
    let original = OnlineRecord(id: authorID, owner_id: authorID, kind: "profile", parent_id: nil,
      body: ["displayName": .string("Current profile")], version: 37,
      created_at: "2026-10-01T00:00:00Z", updated_at: "2026-11-02T00:00:00Z")
    store.onlineRecords["profile"] = [original]
    let comment = EditorialActivityComment(id: UUID(), author_id: authorID, body: "A reply.",
      created_at: "2026-11-02T00:00:00Z", profile: ["displayName": .string("Embedded snapshot")])
    store.applyEditorialActivity(EditorialActivitySnapshot(post: post, comments: [comment], next_cursor: nil))
    XCTAssertEqual(store.onlineRecords["profile"]?.first?.version, 37)
    XCTAssertEqual(store.onlineRecords["profile"]?.first?.body, original.body)
    XCTAssertEqual(store.onlineRecords["profile"]?.first?.updated_at, original.updated_at)
  }

  func testShareReferenceRejectsOtherSchemesAndBoundsMessage() {
    let id = UUID()
    let content = PostShareContent(id: id, editorial: true, title: "Music", body: String(repeating: "a", count: 4_000))
    XCTAssertLessThan(content.text.count, 2_000)
    XCTAssertEqual(PostShareContent.reference(in: content.text)?.id, id)
    XCTAssertEqual(PostShareContent.reference(in: content.text)?.editorial, true)
    XCTAssertNil(PostShareContent.reference(in: "https://example.com/post/" + id.uuidString))
    XCTAssertNil(PostShareContent.reference(in: "toti://post/" + id.uuidString + "?redirect=example.com"))
    XCTAssertNil(PostShareContent.reference(in: "toti://post/extra/" + id.uuidString))
    XCTAssertNil(PostShareContent.reference(in: "toti://post/not-a-uuid"))
  }
}

@MainActor
final class ProfileReactionCollectionAcceptanceTests: XCTestCase {
  func testPrivateCollectionProjectionAndCursorValidation() async throws {
    try XCTSkipUnless(ProcessInfo.processInfo.environment["TOTI_LIVE_GUEST_ACCEPTANCE"] == "1", "Requires retained Guest authorization.")
    let backend = TotiBackend.shared
    try await backend.restore()
    let owner = try XCTUnwrap(backend.accountID)
    XCTAssertEqual(owner.uuidString.lowercased(), "d1ae68c2-d6eb-495c-bf2b-a1b4b430a629")
    guard owner.uuidString.lowercased() == "d1ae68c2-d6eb-495c-bf2b-a1b4b430a629" else { throw TotiBackendError.accountChanged }
    for kind in ["like", "save"] {
      let page = try await backend.profileReactions(kind: kind)
      XCTAssertLessThanOrEqual(page.records.count, 30)
      XCTAssertEqual(Set(page.records.map(\.id)).count, page.records.count)
      for record in page.records {
        XCTAssertEqual(record.kind, "post")
        XCTAssertEqual(record.bool(kind == "like" ? "my_liked" : "my_saved"), true)
        let exact = try await backend.page(kind: "post", parentID: record.id)
        XCTAssertTrue(exact.records.contains { $0.id == record.id })
      }
    }
    let run = try XCTUnwrap(ProcessInfo.processInfo.environment["TOTI_GUEST_ACCEPTANCE"])
    let partner = TotiBackend(storageKey: "toti-notebook-partner-" + run,
      journalRoot: URL.applicationSupportDirectory.appendingPathComponent("TotiOnline/Acceptance/" + run + "/Partner"))
    try await partner.restore()
    XCTAssertEqual(partner.accountID?.uuidString.lowercased(), "cded9cf8-1182-4802-ac9b-334c1c7d3040")
    let retainedPost = try XCTUnwrap(UUID(uuidString: "48c301f2-2dcc-4964-93bd-b2ea67e75bc4"))
    for kind in ["like", "save"] {
      let page = try await partner.profileReactions(kind: kind)
      XCTAssertFalse(page.records.contains { $0.id == retainedPost }, "Deleted posts must disappear from reaction collections")
    }
    let forged: [String: String] = ["kind":"like", "actor":"cded9cf8-1182-4802-ac9b-334c1c7d3040",
      "at":"2026-11-02T00:00:00Z", "id":UUID().uuidString]
    let cursor = try JSONEncoder().encode(forged).base64EncodedString()
    do {
      _ = try await backend.profileReactions(kind: "like", cursor: cursor)
      XCTFail("A cursor from another account must not be accepted")
    } catch { }
    do {
      _ = try await backend.profileReactions(kind: "save", cursor: "invalid")
      XCTFail("A malformed cursor must not be accepted")
    } catch { }
  }
}
