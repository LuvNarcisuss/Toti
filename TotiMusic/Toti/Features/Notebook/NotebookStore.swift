import Foundation

extension AppStore {
  var notebookNotes: [InspirationNote] {
    (library.notebook ?? NotebookState()).matching()
  }

  func saveNotebookNote(_ note: InspirationNote) async -> Bool {
    guard !isBusy else {
      noteSaveError("Another change is being saved. Please try again.")
      return false
    }
    var updated = library
    var notebook = updated.notebook ?? NotebookState()
    do {
      try notebook.save(note)
    } catch {
      noteSaveError(error.localizedDescription)
      return false
    }
    updated.notebook = notebook
    return await commit(updated)
  }

  func setNotebookPinned(_ id: UUID, pinned: Bool) async -> Bool {
    guard var note = notebookNotes.first(where: { $0.id == id }) else {
      noteSaveError("This note is no longer available.")
      return false
    }
    note.isPinned = pinned
    return await saveNotebookNote(note)
  }

  func duplicateNotebookNote(_ id: UUID) async -> Bool {
    guard let note = notebookNotes.first(where: { $0.id == id }) else {
      noteSaveError("This note is no longer available.")
      return false
    }
    return await saveNotebookNote(note.duplicate())
  }

  func deleteNotebookNote(_ id: UUID) async -> Bool {
    guard !isBusy else {
      noteSaveError("Another change is being saved. Please try again.")
      return false
    }
    var updated = library
    var notebook = updated.notebook ?? NotebookState()
    notebook.notes.removeAll { $0.id == id }
    updated.notebook = notebook
    return await commit(updated)
  }
}
