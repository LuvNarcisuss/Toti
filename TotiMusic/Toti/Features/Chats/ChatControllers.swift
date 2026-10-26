import AVFoundation
import Combine
import UIKit

private func artistID(_ person: MusicConversation) -> String {
  person.creator?.id ?? person.id
}

private enum ChatRowAction { case pin, read, mute, delete }

/// Square actions sit on the trailing edge. The row stops once they are open.
private final class ChatInboxCell: UITableViewCell {
  static let reuseID = "ChatInboxCell"
  static let actionWidth: CGFloat = 48
  private let canvas = UIView()
  private let foreground = UIView()
  private let actions = UIStackView()
  private let pinButton = UIButton(type: .custom)
  private let readButton = UIButton(type: .custom)
  private let muteButton = UIButton(type: .custom)
  private let deleteButton = UIButton(type: .custom)
  private var offset: CGFloat = 0
  private var dragOrigin: CGFloat = 0
  private let rowPan = UIPanGestureRecognizer()
  private weak var hookedTable: UITableView?
  var revealed: Bool { offset < -1 }
  var onWillOpen: (() -> Void)?
  var onAction: ((ChatRowAction) -> Void)?
  private var strip: CGFloat { Self.actionWidth * 4 }

  override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
    super.init(style: style, reuseIdentifier: reuseIdentifier)
    backgroundColor = .clear
    contentView.backgroundColor = .clear
    selectionStyle = .none
    clipsToBounds = true
    contentView.clipsToBounds = true
    actions.axis = .horizontal
    actions.spacing = 0
    actions.distribution = .fillEqually
    actions.alignment = .fill
    actions.isLayoutMarginsRelativeArrangement = false
    actions.insetsLayoutMarginsFromSafeArea = false
    contentView.addSubview(canvas)
    canvas.addSubview(foreground)
    canvas.addSubview(actions)
    canvas.translatesAutoresizingMaskIntoConstraints = false
    foreground.translatesAutoresizingMaskIntoConstraints = false
    actions.translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([
      canvas.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
      canvas.topAnchor.constraint(equalTo: contentView.topAnchor),
      canvas.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
      canvas.widthAnchor.constraint(equalTo: contentView.widthAnchor, constant: strip),
      foreground.leadingAnchor.constraint(equalTo: canvas.leadingAnchor),
      foreground.topAnchor.constraint(equalTo: canvas.topAnchor),
      foreground.bottomAnchor.constraint(equalTo: canvas.bottomAnchor),
      foreground.widthAnchor.constraint(equalTo: contentView.widthAnchor),
      actions.leadingAnchor.constraint(equalTo: foreground.trailingAnchor),
      actions.trailingAnchor.constraint(equalTo: canvas.trailingAnchor),
      actions.topAnchor.constraint(equalTo: canvas.topAnchor),
      actions.bottomAnchor.constraint(equalTo: canvas.bottomAnchor),
    ])
    styleAction(pinButton, TotiTheme.plum, .pin)
    styleAction(readButton, UIColor(red: 0.36, green: 0.55, blue: 0.22, alpha: 1), .read)
    styleAction(muteButton, UIColor(red: 0.16, green: 0.42, blue: 0.40, alpha: 1), .mute)
    styleAction(deleteButton, TotiTheme.pink, .delete)
    rowPan.addTarget(self, action: #selector(drag(_:)))
    rowPan.delegate = self
    contentView.addGestureRecognizer(rowPan)
  }

  override func didMoveToSuperview() {
    super.didMoveToSuperview()
    var ancestor = superview
    while let current = ancestor, !(current is UITableView) { ancestor = current.superview }
    guard let table = ancestor as? UITableView, hookedTable !== table else { return }
    hookedTable = table
    table.panGestureRecognizer.require(toFail: rowPan)
  }

  required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }

  private func styleAction(_ button: UIButton, _ color: UIColor, _ action: ChatRowAction) {
    button.backgroundColor = color
    button.layer.cornerRadius = 0
    button.clipsToBounds = true
    button.setTitleColor(.white, for: .normal)
    button.titleLabel?.font = TotiTheme.font(11)
    button.titleLabel?.numberOfLines = 2
    button.titleLabel?.textAlignment = .center
    button.titleLabel?.lineBreakMode = .byWordWrapping
    button.titleLabel?.adjustsFontSizeToFitWidth = true
    button.titleLabel?.minimumScaleFactor = 0.7
    button.contentHorizontalAlignment = .center
    button.contentVerticalAlignment = .center
    button.addAction(UIAction { [weak self] _ in self?.onAction?(action) }, for: .touchUpInside)
    actions.addArrangedSubview(button)
  }

  override func layoutSubviews() {
    super.layoutSubviews()
    let limit = Self.actionWidth - 4
    for button in [pinButton, readButton, muteButton, deleteButton] {
      button.titleLabel?.preferredMaxLayoutWidth = limit
    }
  }

  override func prepareForReuse() {
    super.prepareForReuse()
    onWillOpen = nil
    onAction = nil
    setOffset(0, animated: false)
    foreground.subviews.forEach { $0.removeFromSuperview() }
  }

  func apply(
    name: String, detail: String, time: String, unread: Int, muted: Bool, pinned: Bool,
    conversation: MusicConversation
  ) {
    foreground.subviews.forEach { $0.removeFromSuperview() }
    foreground.backgroundColor = pinned ? UIColor.white.withAlphaComponent(0.7) : .clear
    pinButton.setTitle(pinned ? "Unpin" : "Pin", for: .normal)
    readButton.setTitle(unread > 0 ? "Mark\nread" : "Mark\nunread", for: .normal)
    muteButton.setTitle(muted ? "Unmute" : "Mute", for: .normal)
    deleteButton.setTitle("Delete", for: .normal)
    let photo = conversationPortrait(conversation, size: 54)
    let title = label(name, 17, title: true)
    let subtitle = label(detail, 14, TotiTheme.muted)
    subtitle.numberOfLines = 1
    let text = stack([title, subtitle], spacing: 3)
    text.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
    let clock = label(time, 11, TotiTheme.muted)
    clock.textAlignment = .right
    clock.setContentCompressionResistancePriority(.required, for: .horizontal)
    var marks: [UIView] = []
    if muted {
      let bell = UIImageView(image: TotiIcon.bellOff.image(size: 18))
      bell.contentMode = .scaleAspectFit
      bell.translatesAutoresizingMaskIntoConstraints = false
      bell.widthAnchor.constraint(equalToConstant: 18).isActive = true
      bell.heightAnchor.constraint(equalToConstant: 18).isActive = true
      bell.isAccessibilityElement = true
      bell.accessibilityLabel = "Muted"
      marks.append(bell)
    }
    if unread > 0 { marks.append(unreadBubble(unread)) }
    let markRow = stack(marks, axis: .horizontal, spacing: 6)
    markRow.alignment = .center
    let side = stack([clock, markRow], spacing: 4)
    side.alignment = .trailing
    side.setContentCompressionResistancePriority(.required, for: .horizontal)
    let row = stack([photo, text, side], axis: .horizontal, spacing: 12)
    row.alignment = .center
    foreground.addSubview(row)
    row.translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([
      row.leadingAnchor.constraint(equalTo: foreground.leadingAnchor, constant: 16),
      row.trailingAnchor.constraint(equalTo: foreground.trailingAnchor, constant: -12),
      row.topAnchor.constraint(equalTo: foreground.topAnchor, constant: 10),
      row.bottomAnchor.constraint(equalTo: foreground.bottomAnchor, constant: -10),
    ])
    setOffset(0, animated: false)
    var spoken = [name, detail, time]
    if unread > 0 { spoken.append("\(unread) unread") }
    if muted { spoken.append("Muted") }
    if pinned { spoken.append("Pinned") }
    accessibilityLabel = spoken.joined(separator: ", ")
    accessibilityCustomActions = [pinButton, readButton, muteButton, deleteButton].map { button in
      let title = (button.title(for: .normal) ?? "").replacingOccurrences(of: "\n", with: " ")
      return UIAccessibilityCustomAction(name: title) { [weak self, weak button] _ in
        guard let self, let button else { return false }
        if button === self.pinButton { self.onAction?(.pin) }
        if button === self.readButton { self.onAction?(.read) }
        if button === self.muteButton { self.onAction?(.mute) }
        if button === self.deleteButton { self.onAction?(.delete) }
        return true
      }
    }
  }

  func close(animated: Bool) { setOffset(0, animated: animated) }

  private func setOffset(_ value: CGFloat, animated: Bool) {
    let clamped = min(0, max(-strip, value))
    offset = clamped
    let changes = { self.canvas.transform = CGAffineTransform(translationX: clamped, y: 0) }
    if animated {
      UIView.animate(
        withDuration: 0.2, delay: 0,
        options: [.curveEaseOut, .allowUserInteraction, .beginFromCurrentState], animations: changes)
    } else {
      changes()
    }
  }

  @objc private func drag(_ pan: UIPanGestureRecognizer) {
    let translation = pan.translation(in: contentView).x
    switch pan.state {
    case .began:
      dragOrigin = offset
      if offset == 0 { onWillOpen?() }
    case .changed:
      setOffset(dragOrigin + translation, animated: false)
    case .ended, .cancelled, .failed:
      let velocity = pan.velocity(in: contentView).x
      let open = velocity < -500 || (velocity <= 200 && offset < -strip * 0.35)
      if open { onWillOpen?() }
      setOffset(open ? -strip : 0, animated: true)
    default:
      break
    }
  }

  override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
    guard let pan = gestureRecognizer as? UIPanGestureRecognizer else { return true }
    let velocity = pan.velocity(in: contentView)
    if abs(velocity.x) <= abs(velocity.y) { return false }
    if offset == 0 && velocity.x > 0 { return false }
    return true
  }

  private func unreadBubble(_ count: Int) -> UIView {
    let holder = UIView()
    holder.translatesAutoresizingMaskIntoConstraints = false
    let plate = UIImageView(image: TotiIcon.unreadBadge.image(size: 22))
    plate.contentMode = .scaleAspectFit
    let caption = UILabel()
    let shown = min(count, 99)
    caption.text = "\(shown)"
    caption.textColor = .white
    caption.font = TotiTheme.font(11, title: true)
    caption.textAlignment = .center
    caption.adjustsFontSizeToFitWidth = true
    caption.minimumScaleFactor = 0.7
    holder.addSubview(plate)
    holder.addSubview(caption)
    plate.translatesAutoresizingMaskIntoConstraints = false
    caption.translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([
      holder.widthAnchor.constraint(equalToConstant: 22),
      holder.heightAnchor.constraint(equalToConstant: 22),
      plate.leadingAnchor.constraint(equalTo: holder.leadingAnchor),
      plate.trailingAnchor.constraint(equalTo: holder.trailingAnchor),
      plate.topAnchor.constraint(equalTo: holder.topAnchor),
      plate.bottomAnchor.constraint(equalTo: holder.bottomAnchor),
      caption.leadingAnchor.constraint(equalTo: holder.leadingAnchor, constant: 2),
      caption.trailingAnchor.constraint(equalTo: holder.trailingAnchor, constant: -2),
      caption.centerYAnchor.constraint(equalTo: holder.centerYAnchor),
    ])
    holder.isAccessibilityElement = true
    holder.accessibilityLabel = "\(shown) unread"
    return holder
  }
}

final class ChatsController: TotiScreen, UITableViewDelegate, UITableViewDataSource {
  private let table = UITableView(frame: .zero, style: .plain)
  private let inboxFilters = BubbleTrack(
    titles: ["All", "Unread", "Pinned", "Drafts"], barHeight: 40)
  private var query = "", filter = ChatInboxFilter.all, searching = false
  private var searchButton: UIButton?
  private weak var openRow: ChatInboxCell?
  private var conversations: [MusicConversation] {
    let listed = store.chatConversations.filter { c in
      let matches = query.isEmpty || (c.name + c.summary).localizedCaseInsensitiveContains(query)
      switch filter {
      case .all: return matches
      case .unread: return matches && store.chatUnreadCount(c) > 0
      case .pinned: return matches && store.isChatPinned(c)
      case .drafts: return matches && !(store.chatDraft(for: c) ?? "").isEmpty
      }
    }
    return listed.sorted { left, right in
      let leftPinned = store.isChatPinned(left)
      let rightPinned = store.isChatPinned(right)
      if leftPinned != rightPinned { return leftPinned && !rightPinned }
      return false
    }
  }
  override func build() {
    title = "Chats"
    navigationItem.leftBarButtonItem = barButton(totiMark())
    table.backgroundColor = .clear
    table.dataSource = self
    table.delegate = self
    table.separatorColor = TotiTheme.soft
    table.keyboardDismissMode = .interactive
    table.register(ChatInboxCell.self, forCellReuseIdentifier: ChatInboxCell.reuseID)
    inboxFilters.onSelect = { [weak self] index in
      guard let self, ChatInboxFilter.allCases.indices.contains(index) else { return }
      self.filter = ChatInboxFilter.allCases[index]
      self.openRow = nil
      self.table.reloadData()
    }
    view.addSubview(inboxFilters)
    view.addSubview(table)
    inboxFilters.translatesAutoresizingMaskIntoConstraints = false
    table.translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([
      inboxFilters.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 6),
      inboxFilters.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
      inboxFilters.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
      table.topAnchor.constraint(equalTo: inboxFilters.bottomAnchor, constant: 6),
      table.leadingAnchor.constraint(equalTo: view.leadingAnchor),
      table.trailingAnchor.constraint(equalTo: view.trailingAnchor),
      table.bottomAnchor.constraint(equalTo: view.bottomAnchor),
    ])
    let search = iconButton(.search, "Search chats") { [weak self] in self?.toggleSearch() }
    searchButton = search
    navigationItem.rightBarButtonItems = [
      barButton(iconButton(.plus, "Add a friend") { [weak self] in self?.addFriend() }),
      barButton(search),
    ]
    table.rowHeight = UITableView.automaticDimension
    table.estimatedRowHeight = 82
  }
  override func refresh() {
    guard isViewLoaded else { return }
    openRow = nil
    table.reloadData()
    storyHeader()
  }
  private func toggleSearch() {
    guard let searchButton else { return }
    if activeSearch != nil {
      activeSearch?.dismiss()
      return
    }
    searching = true
    storyHeader()
    expandSearch(from: searchButton, placeholder: "Search chats") { [weak self] text in
      self?.query = text
      self?.table.reloadData()
    } onClose: { [weak self] in
      guard let self else { return }
      self.searching = false
      self.query = ""
      self.refresh()
    }
  }
  private func storyHeader() {
    guard !searching else {
      table.tableHeaderView = nil
      return
    }
    let scroller = UIScrollView(frame: CGRect(x: 0, y: 0, width: view.bounds.width, height: 112))
    scroller.showsHorizontalScrollIndicator = false
    let row = stack(axis: .horizontal, spacing: 16)
    scroller.addSubview(row)
    row.translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([
      row.leadingAnchor.constraint(
        equalTo: scroller.contentLayoutGuide.leadingAnchor, constant: 16),
      row.trailingAnchor.constraint(
        equalTo: scroller.contentLayoutGuide.trailingAnchor, constant: -16),
      row.topAnchor.constraint(equalTo: scroller.contentLayoutGuide.topAnchor, constant: 8),
      row.bottomAnchor.constraint(equalTo: scroller.contentLayoutGuide.bottomAnchor, constant: -8),
      row.heightAnchor.constraint(equalTo: scroller.frameLayoutGuide.heightAnchor, constant: -16),
    ])
    for c in store.chatConversations.filter({ $0.story != nil }) {
      let b = UIButton(type: .custom)
      let photo = roundPortrait(
        asset: c.avatars.first, size: 58, personID: c.creator?.id ?? c.id)
      let name = label(c.name.components(separatedBy: " ").first ?? c.name, 12)
      name.textAlignment = .center
      name.isAccessibilityElement = false
      let column = stack([photo, name], spacing: 6)
      column.alignment = .center
      column.isUserInteractionEnabled = false
      b.addSubview(column)
      column.translatesAutoresizingMaskIntoConstraints = false
      NSLayoutConstraint.activate([
        b.widthAnchor.constraint(equalToConstant: 72),
        column.topAnchor.constraint(equalTo: b.topAnchor),
        column.bottomAnchor.constraint(equalTo: b.bottomAnchor),
        column.centerXAnchor.constraint(equalTo: b.centerXAnchor),
      ])
      b.accessibilityLabel = c.name
      b.addAction(
        UIAction { [weak self] _ in self?.message(c.story ?? "", title: c.name) },
        for: .touchUpInside)
      row.addArrangedSubview(b)
    }
    table.tableHeaderView = scroller
  }
  private func addFriend() {
    let group = actionButton("Create a group", icon: .chats) { [weak self] in
      guard let self else { return }
      self.dismissCard { self.push(CreateGroupController(store: self.store)) }
    }
    let add = actionButton("Add a friend", icon: .plus) { [weak self] in
      guard let self else { return }
      self.dismissCard { self.push(AddFriendController(store: self.store)) }
    }
    let scan = actionButton("Scan", icon: .video) { [weak self] in
      guard let self else { return }
      self.dismissCard { self.presentScreen(FriendScanController(store: self.store), full: true) }
    }
    showBottomPanel(stack([label("New", 22, title: true), group, add, scan], spacing: 12))
  }
  func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    conversations.count
  }
  func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    let c = conversations[indexPath.row]
    let unread = store.chatUnreadCount(c)
    let detail =
      store.chatDraft(for: c).flatMap { $0.isEmpty ? nil : "Draft: " + $0 } ?? store.messages(
        for: c
      ).last?.text ?? c.summary
    let cell =
      tableView.dequeueReusableCell(withIdentifier: ChatInboxCell.reuseID, for: indexPath)
      as! ChatInboxCell
    cell.apply(
      name: c.name, detail: detail, time: c.time, unread: unread, muted: store.isChatMuted(c),
      pinned: store.isChatPinned(c), conversation: c)
    cell.onWillOpen = { [weak self, weak cell] in
      guard let self, let cell else { return }
      if self.openRow !== cell { self.openRow?.close(animated: true) }
      self.openRow = cell
    }
    cell.onAction = { [weak self] action in
      guard let self else { return }
      Task {
        switch action {
        case .pin: await self.store.toggleChatPin(c)
        case .read:
          if unread > 0 {
            await self.store.markChatRead(c.id)
          } else {
            await self.store.markChatUnread(c)
          }
        case .mute: await self.store.toggleChatMute(c)
        case .delete: await self.store.hideChat(c)
        }
      }
    }
    return cell
  }
  func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
    openRow?.close(animated: true)
    openRow = nil
  }
  func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    if openRow != nil {
      openRow?.close(animated: true)
      openRow = nil
      return
    }
    open(conversations[indexPath.row])
  }
  private func open(_ c: MusicConversation) {
    Task { await store.markChatRead(c.id) }
    push(ConversationController(store: store, conversation: c))
  }
}
final class AddFriendController: StackScreen {
  private var query = ""
  private let results = UIStackView()
  private let field = UITextField()
  override func build() {
    super.build()
    title = "Add a friend"
    let capsule = UIView()
    capsule.backgroundColor = UIColor.white.withAlphaComponent(0.96)
    capsule.layer.cornerRadius = 26
    capsule.clipsToBounds = true
    capsule.height(52)
    let icon = UIImageView(image: TotiIcon.search.image(size: 20))
    icon.contentMode = .scaleAspectFit
    icon.translatesAutoresizingMaskIntoConstraints = false
    field.placeholder = "Enter an ID"
    field.font = TotiTheme.font(16)
    field.textColor = TotiTheme.ink
    field.tintColor = TotiTheme.plum
    field.autocorrectionType = .no
    field.autocapitalizationType = .none
    field.returnKeyType = .search
    field.accessibilityLabel = "Enter an ID"
    field.translatesAutoresizingMaskIntoConstraints = false
    field.addAction(UIAction { [weak self] _ in self?.applyQuery() }, for: .editingChanged)
    capsule.addSubview(icon)
    capsule.addSubview(field)
    NSLayoutConstraint.activate([
      icon.leadingAnchor.constraint(equalTo: capsule.leadingAnchor, constant: 16),
      icon.centerYAnchor.constraint(equalTo: capsule.centerYAnchor),
      icon.widthAnchor.constraint(equalToConstant: 20),
      icon.heightAnchor.constraint(equalToConstant: 20),
      field.leadingAnchor.constraint(equalTo: icon.trailingAnchor, constant: 10),
      field.trailingAnchor.constraint(equalTo: capsule.trailingAnchor, constant: -16),
      field.topAnchor.constraint(equalTo: capsule.topAnchor),
      field.bottomAnchor.constraint(equalTo: capsule.bottomAnchor),
    ])
    content.addArrangedSubview(capsule)
    results.axis = .vertical
    results.spacing = 12
    content.addArrangedSubview(results)
  }
  override func refresh() {
    guard isViewLoaded else { return }
    showResults()
  }
  private func applyQuery() {
    query = field.text ?? ""
    showResults()
  }
  private func showResults() {
    results.arrangedSubviews.forEach { $0.removeFromSuperview() }
    let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else {
      results.addArrangedSubview(label("Enter an artist ID.", 15, TotiTheme.muted))
      return
    }
    let people = store.chatConversations.filter {
      $0.kind == .person && $0.creator?.isLocalOwner != true
        && (artistID($0).localizedCaseInsensitiveContains(trimmed)
          || $0.id.localizedCaseInsensitiveContains(trimmed))
    }
    guard !people.isEmpty else {
      results.addArrangedSubview(label("No artist matches that ID.", 15, TotiTheme.muted))
      return
    }
    for person in people {
      results.addArrangedSubview(personRow(person))
    }
  }
  private func personRow(_ person: MusicConversation) -> UIView {
    let added = store.followsChatPartner(person)
    let photo = conversationPortrait(person, size: 52)
    let name = label(person.name, 17, title: true)
    let idLine = label("ID " + artistID(person), 13, TotiTheme.muted)
    let text = stack([name, idLine], spacing: 2)
    let button = actionButton(added ? "Added" : "Add", icon: added ? .check : .plus, primary: !added) {
      [weak self] in
      guard let self else { return }
      Task { await self.store.toggleChatFollow(person) }
    }
    button.accessibilityLabel = (added ? "Added, " : "Add ") + person.name
    let row = stack([photo, text, button], axis: .horizontal, spacing: 10)
    row.alignment = .center
    text.setContentHuggingPriority(.defaultLow, for: .horizontal)
    return row
  }
}
final class ConversationController: TotiScreen, UITableViewDataSource, UITextFieldDelegate {
  let conversation: MusicConversation
  var entryNotice: String?
  private let table = UITableView(frame: .zero, style: .plain), input = field("Message")
  private let hint = label("", 12, TotiTheme.muted)
  private var lastCount = 0
  private var draftTask: Task<Void, Never>?
  init(store: AppStore, conversation: MusicConversation) {
    self.conversation = conversation
    super.init(store: store, title: conversation.name)
  }
  required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }
  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    if let entryNotice {
      message(entryNotice)
      self.entryNotice = nil
    }
  }
  override func build() {
    table.dataSource = self
    table.backgroundColor = .clear
    table.separatorStyle = .none
    table.keyboardDismissMode = .interactive
    table.allowsSelection = false
    view.addSubview(table)
    table.translatesAutoresizingMaskIntoConstraints = false
    input.text = store.chatDraft(for: conversation)
    input.delegate = self
    input.addAction(UIAction { [weak self] _ in self?.saveDraft() }, for: .editingChanged)
    let send = iconButton(.send, "Send") { [weak self] in self?.send() }
    let bottom = stack([hint, stack([input, send], axis: .horizontal, spacing: 8)], spacing: 4)
    view.addSubview(bottom)
    bottom.translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([
      table.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
      table.leadingAnchor.constraint(equalTo: view.leadingAnchor),
      table.trailingAnchor.constraint(equalTo: view.trailingAnchor),
      table.bottomAnchor.constraint(equalTo: bottom.topAnchor, constant: -8),
      bottom.leadingAnchor.constraint(
        equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 12),
      bottom.trailingAnchor.constraint(
        equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -12),
      bottom.bottomAnchor.constraint(equalTo: view.keyboardLayoutGuide.topAnchor, constant: -8),
    ])
    if conversation.kind == .person {
      navigationItem.rightBarButtonItems = [
        barButton(iconButton(.more, "Profile") { [weak self] in self?.openProfile() }),
        barButton(iconButton(.video, "Video call") { [weak self] in self?.call(video: true) }),
        barButton(iconButton(.handset, "Voice call") { [weak self] in self?.call(video: false) }),
      ]
    }
    bottom.isHidden = conversation.kind == .activity
    if conversation.kind == .group {
      let name = label(conversation.name, 15, title: true)
      name.numberOfLines = 1
      name.lineBreakMode = .byTruncatingTail
      let identity = stack([conversationPortrait(conversation, size: 32), name],
                           axis: .horizontal, spacing: 8)
      identity.alignment = .center
      navigationItem.titleView = identity
    }
  }
  override func refresh() {
    guard isViewLoaded else { return }
    let count = store.messages(for: conversation).count
    let nearBottom = table.contentSize.height - table.contentOffset.y - table.bounds.height < 100
    table.reloadData()
    table.layoutIfNeeded()
    if count != lastCount && (nearBottom || lastCount == 0), count > 0 {
      table.scrollToRow(
        at: IndexPath(row: count - 1, section: 0), at: .bottom,
        animated: lastCount > 0 && !UIAccessibility.isReduceMotionEnabled)
    }
    lastCount = count
    let canSend = store.canSendChatMessage(conversation)
    hint.text =
      store.isMutualChat(conversation) || conversation.kind != .person
      ? ""
      : canSend
        ? "Send a hello. Follow each other to keep chatting."
        : "You can send more messages once you follow each other."
    input.isEnabled = canSend
  }
  func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    store.messages(for: conversation).count
  }
  func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    let message = store.messages(for: conversation)[indexPath.row]
    let cell = UITableViewCell()
    cell.backgroundColor = .clear
    let text = label(message.text, 16)
    let meta = label(
      message.author + " · " + message.time + (message.isPending == true ? " · Saved locally · Not delivered" : ""), 10,
      TotiTheme.muted)
    let bubble = stack([meta, text], spacing: 5)
    bubble.backgroundColor =
      message.isOwn
      ? TotiTheme.coral.withAlphaComponent(0.75) : UIColor.white.withAlphaComponent(0.9)
    bubble.rounded(18)
    bubble.isLayoutMarginsRelativeArrangement = true
    bubble.layoutMargins = UIEdgeInsets(top: 12, left: 14, bottom: 12, right: 14)
    cell.contentView.addSubview(bubble)
    bubble.translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([
      bubble.topAnchor.constraint(equalTo: cell.contentView.topAnchor, constant: 7),
      bubble.bottomAnchor.constraint(equalTo: cell.contentView.bottomAnchor, constant: -7),
      bubble.widthAnchor.constraint(
        lessThanOrEqualTo: cell.contentView.widthAnchor, multiplier: 0.82),
      message.isOwn
        ? bubble.trailingAnchor.constraint(equalTo: cell.contentView.trailingAnchor, constant: -12)
        : bubble.leadingAnchor.constraint(equalTo: cell.contentView.leadingAnchor, constant: 12),
    ])
    return cell
  }
  func textFieldShouldReturn(_ textField: UITextField) -> Bool {
    send()
    return false
  }
  private func openProfile() {
    let profile: CreatorProfile
    if let creator = conversation.creator {
      profile = creator
    } else {
      profile = CreatorProfile(
        id: conversation.id, name: conversation.name,
        biography: conversation.story ?? "A music lover in your chats.",
        avatarAsset: conversation.avatars.first)
    }
    push(CreatorController(store: store, creator: profile))
  }
  private func send() {
    draftTask?.cancel()
    let text = input.text ?? ""
    guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
    Task {
      if await store.sendChatMessage(text, to: conversation) {
        input.text = ""
        refresh()
      } else {
        message(store.lastSaveError ?? "This message could not be saved.")
      }
    }
  }
  private func saveDraft() {
    draftTask?.cancel()
    let text = input.text ?? ""
    let id = conversation.id
    draftTask = Task { [weak self] in
      do { try await Task.sleep(for: .milliseconds(350)) } catch { return }
      guard let self else { return }
      if let creator = self.conversation.creator {
        _ = await self.store.saveCreatorMessageDraft(text, creator: creator)
      } else {
        _ = await self.store.saveChatDraft(text, conversationID: id)
      }
    }
  }
  override func viewWillDisappear(_ animated: Bool) {
    super.viewWillDisappear(animated)
    draftTask?.cancel()
    let text = input.text ?? ""
    let id = conversation.id
    Task {
      if let creator = conversation.creator {
        _ = await store.saveCreatorMessageDraft(text, creator: creator)
      } else {
        _ = await store.saveChatDraft(text, conversationID: id)
      }
    }
  }
  private func call(video: Bool) {
    presentScreen(
      CallController(
        store: store, name: conversation.name,
        asset: portraitAsset(
          conversation.avatars.first ?? conversation.creator?.avatarAsset,
          personID: conversation.creator?.id ?? conversation.id),
        video: video),
      full: true)
  }
  deinit { draftTask?.cancel() }
}

final class CreateGroupController: TotiScreen {
  private var selected: [String] = []
  private var marks: [String: UIImageView] = [:]
  private var create: StudioButton!
  private let list = UIStackView()

  override func build() {
    title = "Create a group"
    let scroll = UIScrollView()
    scroll.keyboardDismissMode = .interactive
    scroll.translatesAutoresizingMaskIntoConstraints = false
    let column = UIStackView()
    column.axis = .vertical
    column.spacing = 14
    column.translatesAutoresizingMaskIntoConstraints = false
    let face = UIButton(type: .custom)
    face.backgroundColor = UIColor.white.withAlphaComponent(0.92)
    face.layer.cornerRadius = 16
    face.height(54)
    face.accessibilityLabel = "Face to face"
    let faceTitle = label("Face to face", 17, title: true)
    faceTitle.isAccessibilityElement = false
    let chevron = UIImageView(image: TotiIcon.forward.image(size: 18))
    chevron.translatesAutoresizingMaskIntoConstraints = false
    face.addSubview(faceTitle)
    face.addSubview(chevron)
    faceTitle.translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([
      faceTitle.leadingAnchor.constraint(equalTo: face.leadingAnchor, constant: 16),
      faceTitle.centerYAnchor.constraint(equalTo: face.centerYAnchor),
      chevron.trailingAnchor.constraint(equalTo: face.trailingAnchor, constant: -14),
      chevron.centerYAnchor.constraint(equalTo: face.centerYAnchor),
      chevron.widthAnchor.constraint(equalToConstant: 18),
      chevron.heightAnchor.constraint(equalToConstant: 18),
    ])
    face.addAction(
      UIAction { [weak self] _ in
        guard let self else { return }
        self.push(FaceToFaceController(store: self.store))
      }, for: .touchUpInside)
    let rule = UIView()
    rule.backgroundColor = TotiTheme.plum.withAlphaComponent(0.18)
    rule.height(1)
    list.axis = .vertical
    list.spacing = 8
    column.addArrangedSubview(face)
    column.addArrangedSubview(rule)
    column.addArrangedSubview(list)
    scroll.addSubview(column)
    view.addSubview(scroll)
    create = actionButton("Create now", tone: .coral) { [weak self] in self?.createGroup() }
    view.addSubview(create)
    create.translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([
      scroll.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
      scroll.leadingAnchor.constraint(equalTo: view.leadingAnchor),
      scroll.trailingAnchor.constraint(equalTo: view.trailingAnchor),
      scroll.bottomAnchor.constraint(equalTo: create.topAnchor, constant: -12),
      column.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor, constant: 8),
      column.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor, constant: -12),
      column.leadingAnchor.constraint(equalTo: scroll.contentLayoutGuide.leadingAnchor, constant: 16),
      column.trailingAnchor.constraint(equalTo: scroll.contentLayoutGuide.trailingAnchor, constant: -16),
      column.widthAnchor.constraint(equalTo: scroll.frameLayoutGuide.widthAnchor, constant: -32),
      create.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 16),
      create.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -16),
      create.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -12),
    ])
    reloadPeople()
    refreshCreate()
  }

  private var friends: [MusicConversation] {
    store.chatConversations.filter {
      $0.kind == .person && $0.creator?.isLocalOwner != true && store.followsChatPartner($0)
    }
  }

  private func reloadPeople() {
    list.arrangedSubviews.forEach { $0.removeFromSuperview() }
    marks.removeAll()
    if friends.isEmpty {
      list.addArrangedSubview(label("Add a friend before creating a group.", 15, TotiTheme.muted))
      return
    }
    for person in friends {
      list.addArrangedSubview(friendRow(person))
    }
  }

  private func friendRow(_ person: MusicConversation) -> UIView {
    let row = UIButton(type: .custom)
    row.backgroundColor = UIColor.white.withAlphaComponent(0.88)
    row.layer.cornerRadius = 16
    row.height(64)
    row.accessibilityLabel = person.name
    let on = selected.contains(person.id)
    let mark = UIImageView(image: (on ? TotiIcon.checkboxOn : TotiIcon.checkbox).image(size: 26))
    mark.translatesAutoresizingMaskIntoConstraints = false
    marks[person.id] = mark
    let photo = conversationPortrait(person, size: 44)
    let name = label(person.name, 16, title: true)
    name.isAccessibilityElement = false
    row.addSubview(mark)
    row.addSubview(photo)
    row.addSubview(name)
    photo.translatesAutoresizingMaskIntoConstraints = false
    name.translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([
      mark.leadingAnchor.constraint(equalTo: row.leadingAnchor, constant: 12),
      mark.centerYAnchor.constraint(equalTo: row.centerYAnchor),
      mark.widthAnchor.constraint(equalToConstant: 26),
      mark.heightAnchor.constraint(equalToConstant: 26),
      photo.leadingAnchor.constraint(equalTo: mark.trailingAnchor, constant: 10),
      photo.centerYAnchor.constraint(equalTo: row.centerYAnchor),
      name.leadingAnchor.constraint(equalTo: photo.trailingAnchor, constant: 10),
      name.trailingAnchor.constraint(lessThanOrEqualTo: row.trailingAnchor, constant: -12),
      name.centerYAnchor.constraint(equalTo: row.centerYAnchor),
    ])
    row.addAction(UIAction { [weak self] _ in self?.toggle(person.id) }, for: .touchUpInside)
    return row
  }

  private func toggle(_ id: String) {
    if let index = selected.firstIndex(of: id) {
      selected.remove(at: index)
    } else {
      selected.append(id)
    }
    let on = selected.contains(id)
    marks[id]?.image = (on ? TotiIcon.checkboxOn : TotiIcon.checkbox).image(size: 26)
    refreshCreate()
  }

  override func refresh() {
    guard isViewLoaded else { return }
    reloadPeople()
    refreshCreate()
  }

  private func refreshCreate() {
    let ready = selected.count >= 2
    create.isEnabled = ready
    create.caption.textColor = ready ? TotiTheme.ink : TotiTheme.muted
    create.accessibilityLabel = ready ? "Create now" : "Create now, choose at least two friends"
  }

  private func createGroup() {
    let chosen = friends.filter { selected.contains($0.id) }
    guard chosen.count >= 2 else { return }
    Task { [weak self] in
      guard let self else { return }
      if let conversation = await self.store.createChatGroup(with: chosen) {
        let screen = ConversationController(store: self.store, conversation: conversation)
        screen.entryNotice = "This group is saved on this device."
        guard var stack = self.navigationController?.viewControllers else { return }
        stack.removeAll { $0 === self }
        stack.append(screen)
        self.navigationController?.setViewControllers(stack, animated: true)
      } else {
        self.message(self.store.lastSaveError ?? "The group could not be saved.")
      }
    }
  }
}

final class FaceToFaceController: StackScreen {
  override func build() {
    super.build()
    title = "Face to face"
    heading("Face to face")
    content.addArrangedSubview(
      label(
        "A nearby group match is not available. Choose at least two friends to save a group on this device.",
        16, TotiTheme.muted))
  }
}

final class FriendScanController: TotiScreen, AVCaptureMetadataOutputObjectsDelegate {
  private let session = AVCaptureSession()
  private let cameraQueue = DispatchQueue(label: "toti.friend-scan")
  private let cameraLayer = AVCaptureVideoPreviewLayer()
  private let status = label("Point the camera at a friend code.", 16, .white)
  private let card = UIStackView()
  private var handled = false
  private var matchedID: String?

  override func build() {
    cameraLayer.videoGravity = .resizeAspectFill
    view.layer.addSublayer(cameraLayer)
    status.textAlignment = .center
    status.backgroundColor = UIColor.black.withAlphaComponent(0.45)
    status.layer.cornerRadius = 14
    status.clipsToBounds = true
    view.addSubview(status)
    status.translatesAutoresizingMaskIntoConstraints = false
    card.axis = .vertical
    card.spacing = 12
    card.alignment = .center
    card.isLayoutMarginsRelativeArrangement = true
    card.layoutMargins = UIEdgeInsets(top: 18, left: 18, bottom: 18, right: 18)
    card.backgroundColor = TotiTheme.background
    card.layer.cornerRadius = 24
    card.clipsToBounds = true
    card.isHidden = true
    view.addSubview(card)
    card.translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([
      status.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
      status.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
      status.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -24),
      card.centerXAnchor.constraint(equalTo: view.centerXAnchor),
      card.centerYAnchor.constraint(equalTo: view.centerYAnchor),
      card.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 24),
      card.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -24),
    ])
    switch AVCaptureDevice.authorizationStatus(for: .video) {
    case .authorized: configure()
    case .notDetermined:
      AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
        Task { @MainActor in
          guard let self else { return }
          granted ? self.configure() : self.showDenied()
        }
      }
    default: showDenied()
    }
  }

  override func refresh() {
    guard isViewLoaded, let matchedID, let person = artist(matching: matchedID) else { return }
    show(person)
  }

  override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()
    cameraLayer.frame = view.bounds
  }

  override func viewWillDisappear(_ animated: Bool) {
    super.viewWillDisappear(animated)
    setCameraRunning(false)
  }

  private func showDenied() {
    status.text = "Camera access is off. You can allow it in Settings."
    status.textColor = TotiTheme.ink
    status.backgroundColor = TotiTheme.background
  }

  private func configure() {
    session.beginConfiguration()
    session.sessionPreset = .high
    guard let device = AVCaptureDevice.default(for: .video),
      let input = try? AVCaptureDeviceInput(device: device), session.canAddInput(input)
    else {
      status.text = "The camera is unavailable."
      session.commitConfiguration()
      return
    }
    session.addInput(input)
    let output = AVCaptureMetadataOutput()
    guard session.canAddOutput(output) else {
      status.text = "The camera is unavailable."
      session.commitConfiguration()
      return
    }
    session.addOutput(output)
    output.setMetadataObjectsDelegate(self, queue: .main)
    output.metadataObjectTypes = [.qr]
    session.commitConfiguration()
    cameraLayer.session = session
    setCameraRunning(true)
  }

  private func setCameraRunning(_ running: Bool) {
    let session = session
    cameraQueue.async {
      if running {
        if !session.isRunning { session.startRunning() }
      } else if session.isRunning {
        session.stopRunning()
      }
    }
  }

  func metadataOutput(
    _ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject],
    from connection: AVCaptureConnection
  ) {
    guard !handled,
      let code = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
      let value = code.stringValue
    else { return }
    handled = true
    setCameraRunning(false)
    resolve(value)
  }

  private func artist(matching token: String) -> MusicConversation? {
    store.chatConversations.first {
      $0.kind == .person && $0.creator?.isLocalOwner != true
        && ($0.id.caseInsensitiveCompare(token) == .orderedSame
          || artistID($0).caseInsensitiveCompare(token) == .orderedSame)
    }
  }

  private func resolve(_ value: String) {
    let token = value.trimmingCharacters(in: .whitespacesAndNewlines)
    let id = token.lowercased().hasPrefix("toti://friend/")
      ? String(token.dropFirst("toti://friend/".count)) : token
    guard let person = artist(matching: id) else {
      status.isHidden = false
      status.text = "No artist matches this code."
      card.isHidden = true
      matchedID = nil
      handled = false
      setCameraRunning(true)
      return
    }
    matchedID = person.id
    show(person)
  }

  private func show(_ person: MusicConversation) {
    status.isHidden = true
    card.isHidden = false
    card.arrangedSubviews.forEach { $0.removeFromSuperview() }
    let photo = conversationPortrait(person, size: 84)
    let name = label(person.name, 22, title: true)
    name.textAlignment = .center
    let added = store.followsChatPartner(person)
    let button = actionButton(added ? "Added" : "Add", icon: added ? .check : .plus, primary: !added) {
      [weak self] in
      guard let self else { return }
      Task { await self.store.toggleChatFollow(person) }
    }
    card.addArrangedSubview(photo)
    card.addArrangedSubview(name)
    card.addArrangedSubview(button)
  }
}
