import Foundation
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
