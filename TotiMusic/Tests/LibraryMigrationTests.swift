import XCTest
@testable import toti

final class LibraryMigrationTests: XCTestCase {
  private func temporaryRoot() throws -> URL {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent("TotiLibraryTests-" + UUID().uuidString)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    addTeardownBlock { try? FileManager.default.removeItem(at: root) }
    return root
  }

  func testLegacySnapshotWithoutNewStatesPreservesPrivateRecords() throws {
    var original = LocalLibrary()
    original.profile.displayName = "Existing artist"
    original.videos = [LocalVideo(id: UUID(), title: "Private recording", fileExtension: "mp4", duration: 12, importedAt: Date(), isSaved: true)]
    original.roomDrafts = [VoiceRoomDraft()]
    var object = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(original)) as? [String: Any])
    object.removeValue(forKey: "lounge")
    object.removeValue(forKey: "notebook")
    let restored = try JSONDecoder().decode(LocalLibrary.self, from: JSONSerialization.data(withJSONObject: object))
    XCTAssertNil(restored.lounge)
    XCTAssertNil(restored.notebook)
    XCTAssertEqual(restored.videos, original.videos)
    XCTAssertEqual(restored.roomDrafts, original.roomDrafts)
    XCTAssertEqual(restored.profile.displayName, "Existing artist")
  }

  func testUnreadableLibraryIsNeverSilentlyReplaced() async throws {
    let root = try temporaryRoot()
    let snapshot = root.appendingPathComponent("library-v1.json")
    let bytes = Data("{incomplete json".utf8)
    try bytes.write(to: snapshot)
    let repository = LocalLibraryRepository(root: root)
    do { _ = try await repository.load(); XCTFail("Corruption must be surfaced") } catch {}
    XCTAssertEqual(try Data(contentsOf: snapshot), bytes)
  }

  func testFailedSaveDoesNotEraseExistingFile() async throws {
    let parent = try temporaryRoot()
    let blockedRoot = parent.appendingPathComponent("not-a-directory")
    let original = Data("Keep this file".utf8)
    try original.write(to: blockedRoot)
    let repository = LocalLibraryRepository(root: blockedRoot)
    do { try await repository.save(LocalLibrary()); XCTFail("Must report storage failure") } catch {}
    XCTAssertEqual(try Data(contentsOf: blockedRoot), original)
  }

  func testExplicitDeletionOnlyClearsOwnedRoot() async throws {
    let parent = try temporaryRoot()
    let root = parent.appendingPathComponent("Owned")
    let original = parent.appendingPathComponent("original-photo.jpg")
    try Data([1, 2, 3]).write(to: original)
    let repository = LocalLibraryRepository(root: root)
    var library = LocalLibrary()
    library.profile.displayName = "Removed account"
    library.lounge = LoungeState()
    library.notebook = NotebookState()
    try await repository.save(library)
    try await repository.deleteLocalAccount()
    let fresh = try await repository.load()
    XCTAssertEqual(fresh.profile.displayName, "Music lover")
    XCTAssertNil(fresh.lounge)
    XCTAssertNil(fresh.notebook)
    XCTAssertEqual(try Data(contentsOf: original), Data([1, 2, 3]))
  }
}
