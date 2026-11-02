import UIKit

final class NotebookController: StackScreen {
  private let entryGeneration = TotiBackend.shared.generation
  private var entryAccountIsCurrent: Bool { !store.isOnlineMode || entryGeneration == TotiBackend.shared.generation }
  private var query = ""
  private weak var searchButton: UIButton?
  private let categories = UISegmentedControl(items: ["All"] + NotebookCategory.allCases.map(\.rawValue))
  private let cards = UIStackView()

  init(store: AppStore) { super.init(store: store, title: "Notebook") }
  required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }

  override func build() {
    super.build()
    let search = iconButton(.search, "Search private notes") { [weak self] in self?.toggleSearch() }
    let create = iconButton(.plus, "New note") { [weak self] in self?.openEditor() }
    searchButton = search
    navigationItem.rightBarButtonItem = compactBarButtons([search, create])
    categories.selectedSegmentIndex = 0
    categories.selectedSegmentTintColor = TotiTheme.coral
    categories.setTitleTextAttributes([.font: TotiTheme.font(13)], for: .normal)
    categories.addTarget(self, action: #selector(filterChanged), for: .valueChanged)
    categories.heightAnchor.constraint(greaterThanOrEqualToConstant: 44).isActive = true
    content.addArrangedSubview(categories)
    cards.axis = .vertical
    cards.spacing = 14
    content.addArrangedSubview(cards)
  }

  @objc private func filterChanged() { refresh() }

  private func toggleSearch() {
    guard entryAccountIsCurrent, let searchButton else { return }
    if activeSearch != nil {
      activeSearch?.dismiss()
      return
    }
    expandSearch(from: searchButton, placeholder: "Search your private notes") { [weak self] text in
      guard let self, self.entryAccountIsCurrent else { return }
      self.query = text
      self.refresh()
    } onClose: { [weak self] in
      guard let self, self.entryAccountIsCurrent else { return }
      self.query = ""
      self.refresh()
    }
  }

  override func refresh() {
    guard isViewLoaded, entryAccountIsCurrent else { return }
    cards.arrangedSubviews.forEach { $0.removeFromSuperview() }
    appendOnlineControls(to: cards)
    let notebook = store.library.notebook ?? NotebookState()
    let hasNotes = !notebook.notes.isEmpty
    categories.isHidden = !hasNotes
    if !hasNotes { categories.selectedSegmentIndex = 0 }
    let index = categories.selectedSegmentIndex
    let category = index > 0 ? NotebookCategory.allCases[index - 1] : nil
    let notes = notebook.matching(category: category, query: query)
    let filtered = category != nil || !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    if !hasNotes && !filtered {
      showWelcomeCards()
    } else if notes.isEmpty {
      let reset = actionButton("Clear filters", icon: .search) { [weak self] in
        guard let self, self.entryAccountIsCurrent else { return }
        self.activeSearch?.dismiss()
        self.view.endEditing(true)
        self.query = ""
        self.categories.selectedSegmentIndex = 0
        self.refresh()
      }
      cards.addArrangedSubview(stateCard([
        label("No matching notes", 24, TotiTheme.plum, title: true),
        label("Try another word or category.", 15, TotiTheme.muted), reset,
      ]))
    } else {
      cards.addArrangedSubview(label("\(notes.count) private \(notes.count == 1 ? "note" : "notes")", 13,
        TotiTheme.muted))
      cards.addArrangedSubview(actionButton("Try a prompt", icon: .music, compact: true) { [weak self] in
        self?.showTemplates()
      })
      notes.forEach { cards.addArrangedSubview(noteCard($0)) }
    }
  }

  private func showWelcomeCards() {
    let artwork = UIImageView(image: TotiIcon.notebook.image(size: 88))
    artwork.contentMode = .scaleAspectFit
    artwork.isAccessibilityElement = false
    artwork.height(100)
    let eyebrow = label("A LITTLE SPACE FOR BIG IDEAS", 11, TotiTheme.plum)
    let heading = label("Your next song\nstarts here.", 27, TotiTheme.plum, title: true)
    heading.accessibilityTraits = .header
    let detail = label("Keep a lyric, a chord change or a thought before it slips away.", 15, TotiTheme.muted)
    [eyebrow, heading, detail].forEach { $0.textAlignment = .center }
    let create = actionButton("Write your first note", icon: .plus, primary: true) { [weak self] in
      self?.openEditor()
    }
    create.accessibilityIdentifier = "notebook.first-note"
    let hero = stateCard([artwork, eyebrow, heading, detail, create])
    hero.accessibilityIdentifier = "notebook.welcome"
    cards.addArrangedSubview(hero)
    let prompt = actionButton("Choose a writing prompt", icon: .music) { [weak self] in self?.showTemplates() }
    prompt.accessibilityIdentifier = "notebook.choose-prompt"
    cards.addArrangedSubview(stateCard([
      label("Start with a spark", 21, TotiTheme.plum, title: true),
      label("Explore a lyric, chord progression or songwriting idea. Make it your own before saving.", 15, TotiTheme.muted),
      prompt,
    ]))
    cards.addArrangedSubview(stateCard([
      label("A space of your own", 18, TotiTheme.plum, title: true),
      label(store.isOnlineMode ? "Your notes are private to your account. Turning a note into a Lounge draft keeps the original private." : "Your notes stay on this device. Turning a note into a Lounge draft keeps the original private.", 14, TotiTheme.muted),
    ]))
  }

  private func stateCard(_ views: [UIView]) -> UIView {
    let card = stack(views, spacing: 16)
    card.isLayoutMarginsRelativeArrangement = true
    card.directionalLayoutMargins = NSDirectionalEdgeInsets(top: 24, leading: 20, bottom: 24, trailing: 20)
    card.backgroundColor = UIColor.white.withAlphaComponent(0.92)
    card.layer.cornerRadius = 26
    card.layer.cornerCurve = .continuous
    card.layer.borderWidth = 1
    card.layer.borderColor = TotiTheme.line.cgColor
    return card
  }

  private func noteCard(_ note: InspirationNote) -> UIView {
    let caption = [note.isPinned ? "PINNED" : nil, note.category.rawValue.uppercased(), note.mood?.rawValue]
      .compactMap { $0 }.joined(separator: " · ")
    let more = iconButton(.more, "Actions for \(note.displayTitle)", size: 22) { [weak self] in
      self?.showActions(note)
    }
    let top = stack([label(caption, 12, TotiTheme.muted), more], axis: .horizontal, spacing: 6)
    let title = label(note.displayTitle, 22, TotiTheme.plum, title: true)
    title.numberOfLines = 2
    let excerpt = label(note.body.isEmpty ? "An idea waiting for words…" : note.body, 16, TotiTheme.muted)
    excerpt.numberOfLines = 3
    let date = note.updatedAt.formatted(date: .abbreviated, time: .omitted)
    let card = stack([top, title, excerpt, label("Edited \(date)", 12, TotiTheme.muted),
      actionButton("Open note", icon: .forward, compact: true) { [weak self] in self?.openEditor(note) }
    ], spacing: 10)
    card.isLayoutMarginsRelativeArrangement = true
    card.directionalLayoutMargins = NSDirectionalEdgeInsets(top: 12, leading: 18, bottom: 18, trailing: 18)
    card.backgroundColor = UIColor.white.withAlphaComponent(0.85)
    card.layer.cornerRadius = 10
    card.layer.borderWidth = 1
    card.layer.borderColor = TotiTheme.line.cgColor
    return card
  }

  private func openEditor(_ note: InspirationNote? = nil, template: NotebookTemplate? = nil) {
    guard entryAccountIsCurrent else { return }
    activeSearch?.dismiss()
    view.endEditing(true)
    let editor = NotebookEditorController(store: store, note: note, template: template)
    navigationController?.pushViewController(editor, animated: true)
  }

  private func showTemplates() {
    guard entryAccountIsCurrent, presentedViewController == nil else { return }
    activeSearch?.dismiss()
    view.endEditing(true)
    let alert = UIAlertController(title: "A place to start", message: "Prompts open as editable private drafts.",
      preferredStyle: .actionSheet)
    for template in NotebookTemplate.allCases {
      alert.addAction(UIAlertAction(title: template.rawValue, style: .default) { [weak self] _ in
        self?.openEditor(template: template)
      })
    }
    alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
    alert.popoverPresentationController?.sourceView = view
    alert.popoverPresentationController?.sourceRect = CGRect(x: view.bounds.midX, y: 180, width: 1, height: 1)
    present(alert, animated: true)
  }

  private func showActions(_ note: InspirationNote) {
    guard entryAccountIsCurrent else { return }
    let alert = UIAlertController(title: note.displayTitle, message: store.isOnlineMode ? "Private · saved to your account" : "Private · saved on this device",
      preferredStyle: .actionSheet)
    alert.addAction(UIAlertAction(title: note.isPinned ? "Unpin note" : "Pin note", style: .default) { [weak self] _ in
      guard let self, self.entryAccountIsCurrent else { return }
      self.save { await self.store.setNotebookPinned(note.id, pinned: !note.isPinned) }
    })
    alert.addAction(UIAlertAction(title: "Duplicate note", style: .default) { [weak self] _ in
      guard let self, self.entryAccountIsCurrent else { return }
      self.save { await self.store.duplicateNotebookNote(note.id) }
    })
    alert.addAction(UIAlertAction(title: "Delete note", style: .destructive) { [weak self] _ in
      self?.confirmDeletion(note)
    })
    alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
    alert.popoverPresentationController?.sourceView = view
    alert.popoverPresentationController?.sourceRect = CGRect(x: view.bounds.midX, y: view.bounds.midY, width: 1, height: 1)
    present(alert, animated: true)
  }

  private func confirmDeletion(_ note: InspirationNote) {
    guard entryAccountIsCurrent else { return }
    let alert = UIAlertController(title: "Delete this note?", message: store.isOnlineMode ? "This removes the private note from your account." : "This removes the private note from this device.",
      preferredStyle: .alert)
    alert.addAction(UIAlertAction(title: "Keep note", style: .cancel))
    alert.addAction(UIAlertAction(title: "Delete", style: .destructive) { [weak self] _ in
      guard let self, self.entryAccountIsCurrent else { return }
      self.save { await self.store.deleteNotebookNote(note.id) }
    })
    present(alert, animated: true)
  }
}

final class NotebookEditorController: StackScreen, UITextViewDelegate, UIGestureRecognizerDelegate {
  private let entryGeneration = TotiBackend.shared.generation
  private var entryAccountIsCurrent: Bool { !store.isOnlineMode || entryGeneration == TotiBackend.shared.generation }
  private var draft: InspirationNote
  private var baseline: InspirationNote
  private let titleInput = field("Untitled idea")
  private let bodyInput = UITextView()
  private let categoryInput = UISegmentedControl(items: NotebookCategory.allCases.map(\.rawValue))
  private let moodInput = UIButton(type: .custom)
  private let pinInput = UISwitch()
  private let counts = label("", 12, TotiTheme.muted)
  private let status = label("Private · saved only on this device", 13, TotiTheme.muted)
  private var saveButton: StudioButton?
  private var saving = false
  private weak var previousPopDelegate: UIGestureRecognizerDelegate?
  private weak var guardedPopGesture: UIGestureRecognizer?

  init(store: AppStore, note: InspirationNote? = nil, template: NotebookTemplate? = nil) {
    let initial = note ?? InspirationNote()
    baseline = initial
    draft = initial
    if let template, note == nil {
      let prompt = template.note
      draft.title = prompt.title
      draft.body = prompt.body
      draft.category = prompt.category
    }
    super.init(store: store, title: note == nil ? "New note" : "Your note")
  }
  required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }

  override func build() {
    super.build()
    titleInput.text = draft.title
    titleInput.font = TotiTheme.font(23, title: true)
    titleInput.accessibilityLabel = "Note title, up to 80 characters"
    titleInput.addTarget(self, action: #selector(inputChanged), for: .editingChanged)
    categoryInput.selectedSegmentIndex = NotebookCategory.allCases.firstIndex(of: draft.category) ?? 2
    categoryInput.selectedSegmentTintColor = TotiTheme.coral
    categoryInput.setTitleTextAttributes([.font: TotiTheme.font(14)], for: .normal)
    categoryInput.heightAnchor.constraint(greaterThanOrEqualToConstant: 44).isActive = true
    categoryInput.addTarget(self, action: #selector(inputChanged), for: .valueChanged)
    bodyInput.text = draft.body
    bodyInput.delegate = self
    bodyInput.font = TotiTheme.font(18)
    bodyInput.adjustsFontForContentSizeCategory = true
    bodyInput.textColor = TotiTheme.ink
    bodyInput.backgroundColor = UIColor.white.withAlphaComponent(0.9)
    bodyInput.layer.cornerRadius = 12
    bodyInput.layer.borderColor = TotiTheme.line.cgColor
    bodyInput.layer.borderWidth = 1
    bodyInput.textContainerInset = UIEdgeInsets(top: 16, left: 12, bottom: 16, right: 12)
    bodyInput.accessibilityLabel = "Note body, up to 10,000 characters"
    bodyInput.heightAnchor.constraint(equalToConstant: 320).isActive = true
    moodInput.setTitleColor(TotiTheme.plum, for: .normal)
    moodInput.titleLabel?.font = TotiTheme.font(16)
    moodInput.titleLabel?.adjustsFontForContentSizeCategory = true
    moodInput.heightAnchor.constraint(greaterThanOrEqualToConstant: 44).isActive = true
    moodInput.contentHorizontalAlignment = .leading
    moodInput.addTarget(self, action: #selector(chooseMood), for: .touchUpInside)
    pinInput.isOn = draft.isPinned
    pinInput.onTintColor = TotiTheme.plum
    pinInput.accessibilityLabel = "Pin this note"
    pinInput.addTarget(self, action: #selector(inputChanged), for: .valueChanged)
    let pinRow = stack([label("Pin this note"), pinInput], axis: .horizontal)
    pinRow.alignment = .center
    let save = actionButton("Save note", icon: .check, primary: true) { [weak self] in
      self?.saveDraft(exitAfter: false)
    }
    saveButton = save
    let convert = actionButton("Turn into a post", icon: .share) { [weak self] in self?.convertToPost() }
    [label("Title (optional)", 14, TotiTheme.muted), titleInput, label("Category", 14, TotiTheme.muted), categoryInput,
      label("Your note", 14, TotiTheme.muted), bodyInput, counts,
      moodInput, pinRow, status, save, convert].forEach { content.addArrangedSubview($0) }
    updateStatus()
  }

  override func refresh() {
    // Store notifications may arrive during typing; only the user's controls own draft text.
    guard isViewLoaded else { return }
    saveButton?.isEnabled = !saving && !store.isBusy
  }

  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    navigationItem.hidesBackButton = true
    navigationItem.leftBarButtonItem = barButton(iconButton(.back, "Close note") { [weak self] in
      self?.requestExit()
    })
    if let pop = navigationController?.interactivePopGestureRecognizer, pop.delegate !== self {
      previousPopDelegate = pop.delegate
      guardedPopGesture = pop
      pop.delegate = self
    }
  }

  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    navigationController?.presentationController?.delegate = self
    updateStatus()
  }

  override func viewDidDisappear(_ animated: Bool) {
    super.viewDidDisappear(animated)
    if let pop = guardedPopGesture, pop.delegate === self {
      pop.delegate = previousPopDelegate
    }
  }

  private var dirty: Bool { !draft.hasSameContent(as: baseline) }

  @objc private func inputChanged() {
    guard entryAccountIsCurrent else { return }
    draft.title = titleInput.text ?? ""
    draft.body = bodyInput.text ?? ""
    draft.category = NotebookCategory.allCases[categoryInput.selectedSegmentIndex]
    draft.isPinned = pinInput.isOn
    updateStatus()
  }

  func textViewDidChange(_ textView: UITextView) { inputChanged() }

  private func updateStatus() {
    counts.text = "Title \(draft.title.count)/80 · Note \(draft.body.count)/10,000"
    moodInput.setTitle("Mood: \(draft.mood?.rawValue ?? "None")  ›", for: .normal)
    do {
      try draft.validate()
      counts.textColor = TotiTheme.muted
      let hasSavedNote = store.notebookNotes.contains { $0.id == draft.id }
      status.text = dirty ? "Unsaved changes · private to you" :
        (hasSavedNote ? (store.isOnlineMode ? "Private · saved to your account" : "Private · saved only on this device") : "New private note · not saved yet")
      status.textColor = TotiTheme.muted
    } catch {
      counts.textColor = TotiTheme.dangerInk
      status.text = error.localizedDescription
      status.textColor = TotiTheme.dangerInk
    }
    isModalInPresentation = dirty || saving
    navigationController?.isModalInPresentation = dirty || saving
    if saving { status.text = "Saving your private note…" }
    refresh()
  }

  @objc private func chooseMood() {
    guard entryAccountIsCurrent else { return }
    let alert = UIAlertController(title: "A mood for this idea", message: nil, preferredStyle: .actionSheet)
    alert.addAction(UIAlertAction(title: "None", style: .default) { [weak self] _ in
      guard let self, self.entryAccountIsCurrent else { return }
      self.draft.mood = nil
      self.updateStatus()
    })
    for mood in NotebookMood.allCases {
      alert.addAction(UIAlertAction(title: mood.rawValue, style: .default) { [weak self] _ in
        guard let self, self.entryAccountIsCurrent else { return }
        self.draft.mood = mood
        self.updateStatus()
      })
    }
    alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
    alert.popoverPresentationController?.sourceView = moodInput
    alert.popoverPresentationController?.sourceRect = moodInput.bounds
    present(alert, animated: true)
  }

  private func saveDraft(exitAfter: Bool) {
    guard entryAccountIsCurrent else { return }
    guard !saving else { return }
    inputChanged()
    do { try draft.validate() } catch {
      showSaveError(error.localizedDescription, exitAfter: exitAfter)
      return
    }
    saving = true
    content.isUserInteractionEnabled = false
    updateStatus()
    let snapshot = draft
    Task { [weak self] in
      guard let self, self.entryAccountIsCurrent else { return }
      let saved = await self.store.saveNotebookNote(snapshot)
      guard self.entryAccountIsCurrent else { return }
      self.saving = false
      self.content.isUserInteractionEnabled = true
      if saved {
        self.draft = self.store.notebookNotes.first(where: { $0.id == snapshot.id }) ?? snapshot
        if self.store.isOnlineMode {
          self.draft.backendVersion = self.store.acknowledgedOnlineVersion(for: snapshot.id) ?? self.draft.backendVersion
        }
        self.baseline = self.draft
        self.updateStatus()
        if exitAfter { self.finishExit() }
        else { self.status.text = self.store.isOnlineMode ? "Saved to your account · private to you" : "Saved on this device · private to you" }
      } else {
        self.updateStatus()
        self.showSaveError(self.store.lastSaveError ?? "The note could not be saved. Your changes are still here.",
          exitAfter: exitAfter)
      }
    }
  }

  private func showSaveError(_ text: String, exitAfter: Bool) {
    status.text = text
    status.textColor = TotiTheme.dangerInk
    let alert = UIAlertController(title: "Note was not saved", message: text, preferredStyle: .alert)
    alert.addAction(UIAlertAction(title: "Keep editing", style: .cancel))
    alert.addAction(UIAlertAction(title: "Retry", style: .default) { [weak self] _ in
      self?.saveDraft(exitAfter: exitAfter)
    })
    present(alert, animated: true)
  }

  private func requestExit() {
    guard !saving, presentedViewController == nil else { return }
    view.endEditing(true)
    inputChanged()
    guard dirty else { finishExit(); return }
    let alert = UIAlertController(title: "Save your changes?", message: "This note has unsaved edits.",
      preferredStyle: .alert)
    alert.addAction(UIAlertAction(title: "Save", style: .default) { [weak self] _ in self?.saveDraft(exitAfter: true) })
    alert.addAction(UIAlertAction(title: "Discard", style: .destructive) { [weak self] _ in self?.finishExit() })
    alert.addAction(UIAlertAction(title: "Keep editing", style: .cancel))
    present(alert, animated: true)
  }

  private func finishExit() {
    isModalInPresentation = false
    navigationController?.isModalInPresentation = false
    if let nav = navigationController, nav.viewControllers.first !== self {
      nav.popViewController(animated: true)
    } else { super.dismissCollapsed() }
  }

  override func dismissCollapsed() { requestExit() }

  func presentationControllerShouldDismiss(_ presentationController: UIPresentationController) -> Bool {
    !dirty && !saving
  }

  func presentationControllerDidAttemptToDismiss(_ presentationController: UIPresentationController) {
    requestExit()
  }

  func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
    if saving { return false }
    if dirty { requestExit(); return false }
    return (navigationController?.viewControllers.count ?? 0) > 1
  }

  private func convertToPost() {
    guard entryAccountIsCurrent else { return }
    inputChanged()
    let alert = UIAlertController(title: "Create a separate post draft?",
      message: "Your original note stays private. Its title and text will be copied into a Lounge draft for you to edit. Nothing is posted automatically.",
      preferredStyle: .alert)
    alert.addAction(UIAlertAction(title: "Keep private", style: .cancel))
    alert.addAction(UIAlertAction(title: "Open post draft", style: .default) { [weak self] _ in
      guard let self, self.entryAccountIsCurrent else { return }
      self.view.endEditing(true)
      self.navigationController?.pushViewController(
        LoungeComposerController(store: self.store, initialText: self.draft.postDraftText), animated: true)
    })
    present(alert, animated: true)
  }
}
