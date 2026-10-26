import Foundation

enum NotebookCategory: String, Codable, CaseIterable {
  case lyrics = "Lyrics", chords = "Chords", ideas = "Ideas"
}

enum NotebookMood: String, Codable, CaseIterable {
  case hopeful = "Hopeful", reflective = "Reflective", energetic = "Energetic"
  case wistful = "Wistful", calm = "Calm"
}

enum NotebookValidationError: LocalizedError {
  case titleTooLong, bodyTooLong
  var errorDescription: String? {
    switch self {
    case .titleTooLong: return "Keep the title within 80 characters. Your full text is still here."
    case .bodyTooLong: return "Keep the note within 10,000 characters. Your full text is still here."
    }
  }
}

struct InspirationNote: Codable, Equatable, Identifiable {
  var id: UUID = UUID()
  var title: String = ""
  var body: String = ""
  var category: NotebookCategory = .ideas
  var mood: NotebookMood?
  var isPinned: Bool = false
  var createdAt: Date = Date()
  var updatedAt: Date = Date()

  var displayTitle: String {
    title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Untitled idea" : title
  }

  func validate() throws {
    guard title.count <= 80 else { throw NotebookValidationError.titleTooLong }
    guard body.count <= 10_000 else { throw NotebookValidationError.bodyTooLong }
  }

  func duplicate(at date: Date = Date()) -> InspirationNote {
    InspirationNote(title: title, body: body, category: category, mood: mood,
      createdAt: date, updatedAt: date)
  }

  var postDraftText: String {
    // Keep all content, including overlong input, for explicit editing in the post composer.
    if title.isEmpty { return body }
    if body.isEmpty { return title }
    return title + "\n\n" + body
  }

  func hasSameContent(as other: InspirationNote) -> Bool {
    title == other.title && body == other.body && category == other.category
      && mood == other.mood && isPinned == other.isPinned
  }
}

struct NotebookState: Codable, Equatable {
  var notes: [InspirationNote] = []

  mutating func save(_ note: InspirationNote, at date: Date = Date()) throws {
    try note.validate()
    var saved = note
    saved.updatedAt = date
    if let index = notes.firstIndex(where: { $0.id == note.id }) {
      saved.createdAt = notes[index].createdAt
      notes[index] = saved
    } else {
      notes.append(saved)
    }
  }

  func matching(category: NotebookCategory? = nil, query: String = "") -> [InspirationNote] {
    let term = query.trimmingCharacters(in: .whitespacesAndNewlines)
    return notes.filter { note in
      guard category == nil || note.category == category else { return false }
      let text = [note.title, note.body, note.category.rawValue, note.mood?.rawValue ?? ""]
        .joined(separator: " ")
      return term.isEmpty || text.localizedStandardContains(term)
    }.sorted { first, second in
      if first.isPinned != second.isPinned { return first.isPinned }
      if first.updatedAt != second.updatedAt { return first.updatedAt > second.updatedAt }
      return first.id.uuidString < second.id.uuidString
    }
  }
}

enum NotebookTemplate: String, CaseIterable {
  case lyric = "Opening lyric", chords = "Chord progression", idea = "Songwriting idea"

  var note: InspirationNote {
    switch self {
    case .lyric:
      return InspirationNote(title: "A first line", body: "The room went quiet when…\n\nWhat happens next?",
        category: .lyrics)
    case .chords:
      return InspirationNote(title: "A progression to explore", body: "Cmaj7 · Am7 · Dm7 · G7\n\nHow does it feel? What would you change?",
        category: .chords)
    case .idea:
      return InspirationNote(title: "A sound worth keeping", body: "A sound I noticed today:\n\nThe feeling it brought back:\n\nOne image for a song:",
        category: .ideas)
    }
  }
}
