import Combine
import UIKit

final class PartyDiscoveryController: StackScreen {
  private let discoveryStore = PartyDiscoveryStore()
  private var rooms: [PartyRoom] { discoveryStore.rooms }
  private var category: PartyCategory?
  private let categories = BubbleTrack(
    titles: ["All"] + PartyCategory.allCases.map(\.title), index: 0, barHeight: 44)
  private let cardList = UIStackView()
  private var query = ""
  private var searchButton: UIButton?
  private var createButton: UIButton?
  override func build() {
    super.build()
    title = "Voice"
    navigationItem.leftBarButtonItem = barButton(totiMark())
    let search = iconButton(.search, "Search parties") { [weak self] in self?.toggleSearch() }
    searchButton = search
    navigationItem.rightBarButtonItem = barButton(search)
    let refresh = UIRefreshControl()
    refresh.addAction(UIAction { [weak self] _ in self?.reloadRooms() }, for: .valueChanged)
    scroll.refreshControl = refresh
    // The list is pinned to the page keyboard guide. Ignore the dock inset so cards pass under it.
    pinListUnderDock()
    let create = iconButton(.plus, "Create party") { [weak self] in
      guard let self else { return }
      let screen = PartyCreationController(store: self.store)
      guard let source = self.createButton else {
        self.presentScreen(screen, full: true)
        return
      }
      self.presentExpanded(from: source, screen)
    }
    createButton = create
    create.backgroundColor = TotiTheme.coral
    create.rounded(26)
    view.addSubview(create)
    NSLayoutConstraint.activate([
      create.trailingAnchor.constraint(
        equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -12),
      create.bottomAnchor.constraint(
        equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -14),
      create.widthAnchor.constraint(equalToConstant: 52),
      create.heightAnchor.constraint(equalToConstant: 52),
    ])
    scroll.contentInset.bottom = 80
    heading("Find your frequency")
    categories.onSelect = { [weak self] index in
      guard let self else { return }
      self.category = index == 0 ? nil : PartyCategory.allCases[index - 1]
      self.refresh()
    }
    content.addArrangedSubview(categories)
    cardList.axis = .vertical
    cardList.spacing = 18
    content.addArrangedSubview(cardList)
    discoveryStore.objectWillChange.receive(on: DispatchQueue.main).sink { [weak self] _ in
      self?.refresh()
    }.store(in: &tokens)
    Task { await discoveryStore.refresh(reorder: false) }
  }
  override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()
    let clearance = 80 + view.safeAreaInsets.bottom
    if abs(scroll.contentInset.bottom - clearance) > 0.5 {
      scroll.contentInset.bottom = clearance
      var indicators = scroll.verticalScrollIndicatorInsets
      indicators.bottom = view.safeAreaInsets.bottom
      scroll.verticalScrollIndicatorInsets = indicators
    }
    categories.ensureSelectionVisible()
    if let createButton { view.bringSubviewToFront(createButton) }
  }
  override func refresh() {
    guard isViewLoaded else { return }
    cardList.arrangedSubviews.forEach { $0.removeFromSuperview() }
    if discoveryStore.loading {
      let spinner = UIActivityIndicatorView(style: .medium)
      spinner.startAnimating()
      cardList.addArrangedSubview(spinner)
    }
    if let error = discoveryStore.failure {
      cardList.addArrangedSubview(
        actionButton(error + " Try again", icon: .refresh) { [weak self] in self?.reloadRooms() })
    }
    let visible = (store.library.roomDrafts.map(MusicRoomCatalog.room(from:)) + rooms).filter {
      room in
      !hidesRoom(room)
        && (category == nil || room.category == category)
        && (query.isEmpty
          || (room.title + room.description).localizedCaseInsensitiveContains(query))
    }
    if visible.isEmpty {
      cardList.addArrangedSubview(label("No rooms match. Try another genre or search."))
    }
    let columns = traitCollection.preferredContentSizeCategory.isAccessibilityCategory ? 1 : 2
    for i in stride(from: 0, to: visible.count, by: columns) {
      let row = stack(axis: .horizontal, spacing: 12)
      row.distribution = .fillEqually
      for room in visible[i..<min(i + columns, visible.count)] {
        row.addArrangedSubview(card(room))
      }
      if row.arrangedSubviews.count < columns { row.addArrangedSubview(UIView()) }
      cardList.addArrangedSubview(row)
    }
  }
  private func hidesRoom(_ room: PartyRoom) -> Bool {
    if store.isPartyReported(room.id) || store.isCreatorBlocked("party:" + room.id) { return true }
    return room.participants.contains { store.isCreatorBlocked($0.id) }
  }
  private func card(_ room: PartyRoom) -> UIView {
    let button = musicRoomCard(room, animated: true) { [weak self] person in
      guard let self else { return }
      self.push(CreatorController(store: self.store, creator: .artist(person)))
    }
    button.addAction(
      UIAction { [weak self] _ in
        guard let self else { return }
        self.presentScreen(PartyRoomController(store: self.store, room: room), full: true)
      }, for: .touchUpInside)
    return button
  }
  private func reloadRooms() {
    guard !discoveryStore.loading else { return }
    scroll.refreshControl?.beginRefreshing()
    Task {
      await discoveryStore.refresh()
      scroll.refreshControl?.endRefreshing()
    }
  }
  private func toggleSearch() {
    guard let searchButton else { return }
    if activeSearch != nil {
      activeSearch?.dismiss()
      return
    }
    expandSearch(from: searchButton, placeholder: "Search music rooms") { [weak self] text in
      self?.query = text
      self?.refresh()
    } onClose: { [weak self] in
      self?.query = ""
      self?.refresh()
    }
  }
}
/// The voice-room card. `animated` is only for the live list; a saved report keeps the still card.
@MainActor func musicRoomCard(
  _ room: PartyRoom, animated: Bool, stretches: Bool = false,
  onPerson: ((PartyParticipant) -> Void)? = nil
) -> UIControl {
  let button = PartyCardControl()
  button.backgroundColor = .clear
  button.clipsToBounds = false
  button.isAccessibilityElement = true
  button.accessibilityTraits = .button
  button.accessibilityLabel =
    "\(room.title), \(room.type.rawValue), \(room.onlineCount ?? 0) people"
  let frame = UIView()
  frame.isUserInteractionEnabled = false
  frame.backgroundColor = .black
  frame.layer.cornerRadius = 18
  frame.layer.cornerCurve = .continuous
  frame.clipsToBounds = true
  frame.translatesAutoresizingMaskIntoConstraints = false
  let cover = TotiPhoto(asset: MusicPhotography.cover(for: room))
  frame.addSubview(cover)
  cover.pin(to: frame)
  let shade = UIView()
  shade.backgroundColor = UIColor.black.withAlphaComponent(0.42)
  shade.isUserInteractionEnabled = false
  shade.translatesAutoresizingMaskIntoConstraints = false
  frame.addSubview(shade)
  let title = label(room.title, 16, .white, title: true)
  title.numberOfLines = 2
  let people = stack(axis: .horizontal, spacing: -4)
  people.alignment = .center
  people.isUserInteractionEnabled = false
  let shown = Array(room.participants.prefix(3))
  for person in shown {
    let photo = avatar(person, size: 22)
    people.addArrangedSubview(photo)
    guard let onPerson else { continue }
    let tap = AvatarHitButton(type: .custom)
    tap.accessibilityLabel = "Open \(person.name)'s profile"
    tap.isAccessibilityElement = false
    tap.addAction(UIAction { _ in onPerson(person) }, for: .touchUpInside)
    photo.isUserInteractionEnabled = true
    photo.addSubview(tap)
    tap.pin(to: photo)
    button.track(tap)
  }
  if let onPerson {
    button.accessibilityCustomActions = shown.map { person in
      UIAccessibilityCustomAction(name: "Open \(person.name)'s profile") { _ in
        onPerson(person)
        return true
      }
    }
  }
  people.addArrangedSubview(label("  \(room.onlineCount ?? 0)", 12, .white))
  let caption = stack([title, people], spacing: 6)
  caption.isUserInteractionEnabled = false
  shade.addSubview(caption)
  caption.pin(to: shade, insets: UIEdgeInsets(top: 8, left: 8, bottom: 8, right: 8))
  let ring = PulseRing()
  let marks = FrameMarks()
  ring.translatesAutoresizingMaskIntoConstraints = false
  marks.translatesAutoresizingMaskIntoConstraints = false
  button.addSubview(ring)
  button.addSubview(frame)
  button.addSubview(marks)
  NSLayoutConstraint.activate([
    frame.leadingAnchor.constraint(equalTo: button.leadingAnchor, constant: 4),
    frame.trailingAnchor.constraint(equalTo: button.trailingAnchor, constant: -4),
    frame.topAnchor.constraint(equalTo: button.topAnchor, constant: 8),
    frame.bottomAnchor.constraint(equalTo: button.bottomAnchor),
    ring.leadingAnchor.constraint(equalTo: frame.leadingAnchor, constant: -3),
    ring.trailingAnchor.constraint(equalTo: frame.trailingAnchor, constant: 3),
    ring.topAnchor.constraint(equalTo: frame.topAnchor, constant: -3),
    ring.bottomAnchor.constraint(equalTo: frame.bottomAnchor, constant: 3),
    marks.leadingAnchor.constraint(equalTo: ring.leadingAnchor),
    marks.trailingAnchor.constraint(equalTo: ring.trailingAnchor),
    marks.topAnchor.constraint(equalTo: ring.topAnchor),
    marks.bottomAnchor.constraint(equalTo: ring.bottomAnchor),
    shade.leadingAnchor.constraint(equalTo: frame.leadingAnchor),
    shade.trailingAnchor.constraint(equalTo: frame.trailingAnchor),
    shade.bottomAnchor.constraint(equalTo: frame.bottomAnchor),
  ])
  if !stretches {
    frame.heightAnchor.constraint(equalToConstant: 176).isActive = true
  }
  if room.appearance == .accent {
    let lamp = UIView()
    lamp.backgroundColor = TotiTheme.plum
    lamp.layer.cornerRadius = 4
    lamp.isUserInteractionEnabled = false
    lamp.translatesAutoresizingMaskIntoConstraints = false
    button.addSubview(lamp)
    NSLayoutConstraint.activate([
      lamp.widthAnchor.constraint(equalToConstant: 8),
      lamp.heightAnchor.constraint(equalToConstant: 8),
      lamp.centerXAnchor.constraint(equalTo: frame.trailingAnchor, constant: -2),
      lamp.centerYAnchor.constraint(equalTo: frame.topAnchor, constant: 2),
    ])
  }
  if animated { ring.start() }
  return button
}

@MainActor private func avatar(_ participant: PartyParticipant, size: CGFloat) -> UIView {
  TotiPhoto(
    asset: participant.asset ?? MusicPhotography.creatorAvatar(for: participant.id),
    size: size, round: true)
}

private final class PartyCardControl: UIControl {
  private var avatarHits: [UIButton] = []
  func track(_ button: UIButton) { avatarHits.append(button) }
  override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
    guard isUserInteractionEnabled, !isHidden, alpha > 0.01, bounds.contains(point) else { return nil }
    for tap in avatarHits.reversed() {
      let local = tap.convert(point, from: self)
      if tap.point(inside: local, with: event) { return tap }
    }
    return self
  }
}

private final class AvatarHitButton: UIButton {
  override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
    bounds.insetBy(dx: -4, dy: -6).contains(point)
  }
}
private final class SeatMeter: UIView {
  private let bars: [CALayer] = (0..<3).map { _ in
    let bar = CALayer()
    bar.anchorPoint = CGPoint(x: 0.5, y: 1)
    return bar
  }
  override init(frame: CGRect) {
    super.init(frame: frame)
    isUserInteractionEnabled = false
    isAccessibilityElement = false
    bars.forEach { layer.addSublayer($0) }
  }

  required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }

  override func layoutSubviews() {
    super.layoutSubviews()
    let thickness: CGFloat = 2
    let gap: CGFloat = 3
    let group = thickness * 3 + gap * 2
    let origin = (bounds.width - group) / 2
    CATransaction.begin()
    CATransaction.setDisableActions(true)
    for (index, bar) in bars.enumerated() {
      bar.bounds = CGRect(x: 0, y: 0, width: thickness, height: bounds.height)
      bar.position = CGPoint(
        x: origin + CGFloat(index) * (thickness + gap) + thickness / 2, y: bounds.height)
      bar.cornerRadius = thickness / 2
      bar.backgroundColor = UIColor.white.cgColor
    }
    CATransaction.commit()
  }

  func start() {
    if UIAccessibility.isReduceMotionEnabled {
      let scales: [CGFloat] = [0.42, 0.86, 0.58]
      for (bar, scale) in zip(bars, scales) {
        bar.removeAnimation(forKey: "level")
        bar.transform = CATransform3DMakeScale(1, scale, 1)
      }
      return
    }
    let durations: [CFTimeInterval] = [0.46, 0.62, 0.38]
    for (index, bar) in bars.enumerated() {
      guard bar.animation(forKey: "level") == nil else { continue }
      let anim = CABasicAnimation(keyPath: "transform.scale.y")
      anim.fromValue = 0.28
      anim.toValue = 1
      anim.duration = durations[index]
      anim.autoreverses = true
      anim.repeatCount = .infinity
      anim.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
      bar.add(anim, forKey: "level")
    }
  }

  func stop() { bars.forEach { $0.removeAnimation(forKey: "level") } }
}

private final class PartySeatView: UIView {
  let participant: PartyParticipant
  var onOpen: (() -> Void)?
  private let meter = SeatMeter()
  private let micOff = UIImageView(image: TotiIcon.microphoneOffIvory.image(size: 18))

  init(participant: PartyParticipant, image: UIImage? = nil) {
    self.participant = participant
    super.init(frame: .zero)
    let ring = UIView()
    ring.backgroundColor = TotiTheme.coral.withAlphaComponent(0.55)
    ring.layer.borderWidth = 2.5
    ring.layer.borderColor = TotiTheme.plum.cgColor
    ring.layer.cornerRadius = 35
    ring.clipsToBounds = true
    ring.translatesAutoresizingMaskIntoConstraints = false
    let photo: UIView
    if let image {
      let view = TotiPhoto(size: 62, round: true)
      view.image = image
      photo = view
    } else {
      photo = avatar(participant, size: 62)
    }
    photo.translatesAutoresizingMaskIntoConstraints = false
    photo.isAccessibilityElement = false
    ring.addSubview(photo)
    meter.translatesAutoresizingMaskIntoConstraints = false
    meter.alpha = 0
    ring.addSubview(meter)
    micOff.contentMode = .scaleAspectFit
    micOff.translatesAutoresizingMaskIntoConstraints = false
    micOff.isHidden = true
    ring.addSubview(micOff)
    let open = UIButton(type: .custom)
    open.backgroundColor = .clear
    open.isAccessibilityElement = false
    open.addAction(UIAction { [weak self] _ in self?.onOpen?() }, for: .touchUpInside)
    ring.addSubview(open)
    open.pin(to: ring)
    let name = label(participant.name, 12, TotiTheme.muted)
    name.textAlignment = .center
    name.numberOfLines = 2
    name.adjustsFontSizeToFitWidth = true
    name.minimumScaleFactor = 0.7
    name.isAccessibilityElement = false
    let column = stack([ring, name], spacing: 6)
    column.alignment = .center
    addSubview(column)
    column.pin(to: self)
    NSLayoutConstraint.activate([
      widthAnchor.constraint(equalToConstant: 78),
      ring.widthAnchor.constraint(equalToConstant: 70),
      ring.heightAnchor.constraint(equalToConstant: 70),
      photo.centerXAnchor.constraint(equalTo: ring.centerXAnchor),
      photo.centerYAnchor.constraint(equalTo: ring.centerYAnchor),
      meter.widthAnchor.constraint(equalToConstant: 16),
      meter.heightAnchor.constraint(equalToConstant: 22),
      meter.centerXAnchor.constraint(equalTo: ring.centerXAnchor),
      meter.bottomAnchor.constraint(equalTo: ring.bottomAnchor, constant: -8),
      micOff.widthAnchor.constraint(equalToConstant: 20),
      micOff.heightAnchor.constraint(equalToConstant: 20),
      micOff.centerXAnchor.constraint(equalTo: ring.centerXAnchor),
      micOff.bottomAnchor.constraint(equalTo: ring.bottomAnchor, constant: -6),
    ])
    isAccessibilityElement = true
    accessibilityCustomActions = [
      UIAccessibilityCustomAction(name: "Open \(participant.name)'s profile") { [weak self] _ in
        guard let open = self?.onOpen else { return false }
        open()
        return true
      },
    ]
    apply(speaking: false, muted: false)
  }

  required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }

  func apply(speaking: Bool, muted: Bool) {
    micOff.isHidden = !muted
    meter.alpha = speaking && !muted ? 1 : 0
    if speaking && !muted { meter.start() } else { meter.stop() }
    accessibilityLabel = participant.name + (muted ? ", microphone closed" : ", microphone open")
  }
}

private final class InviteSeatView: UIControl {
  override init(frame: CGRect) {
    super.init(frame: frame)
    let ring = UIView()
    ring.isUserInteractionEnabled = false
    ring.backgroundColor = UIColor.white.withAlphaComponent(0.94)
    ring.layer.borderWidth = 2.5
    ring.layer.borderColor = TotiTheme.plum.cgColor
    ring.layer.cornerRadius = 35
    ring.clipsToBounds = true
    ring.translatesAutoresizingMaskIntoConstraints = false
    let plus = UIImageView(image: TotiIcon.plus.image(size: 28))
    plus.contentMode = .scaleAspectFit
    plus.isUserInteractionEnabled = false
    plus.translatesAutoresizingMaskIntoConstraints = false
    ring.addSubview(plus)
    let name = label("Invite", 12, TotiTheme.muted)
    name.textAlignment = .center
    name.numberOfLines = 2
    name.adjustsFontSizeToFitWidth = true
    name.minimumScaleFactor = 0.7
    name.isAccessibilityElement = false
    let column = stack([ring, name], spacing: 6)
    column.alignment = .center
    column.isUserInteractionEnabled = false
    addSubview(column)
    column.pin(to: self)
    NSLayoutConstraint.activate([
      widthAnchor.constraint(equalToConstant: 78),
      ring.widthAnchor.constraint(equalToConstant: 70),
      ring.heightAnchor.constraint(equalToConstant: 70),
      plus.centerXAnchor.constraint(equalTo: ring.centerXAnchor),
      plus.centerYAnchor.constraint(equalTo: ring.centerYAnchor),
      plus.widthAnchor.constraint(equalToConstant: 28),
      plus.heightAnchor.constraint(equalToConstant: 28),
    ])
    isAccessibilityElement = true
    accessibilityLabel = "Invite a friend"
    accessibilityTraits = .button
    addAction(
      UIAction { [weak self] _ in
        guard let self, !UIAccessibility.isReduceMotionEnabled else { return }
        UIView.animate(withDuration: 0.12, delay: 0, options: [.allowUserInteraction, .curveEaseOut]) {
          self.transform = CGAffineTransform(scaleX: 0.94, y: 0.94)
        }
      }, for: .touchDown)
    addAction(
      UIAction { [weak self] _ in
        UIView.animate(withDuration: 0.2, delay: 0, options: [.allowUserInteraction]) {
          self?.transform = .identity
        }
      }, for: [.touchUpInside, .touchUpOutside, .touchCancel, .touchDragExit])
  }

  required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }
}

private final class ReplyChip: UIControl {
  private let caption = UILabel()
  override init(frame: CGRect) {
    super.init(frame: frame)
    isHidden = true
    backgroundColor = TotiTheme.coral
    layer.cornerRadius = 10
    layer.cornerCurve = .continuous
    layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
    caption.font = TotiTheme.font(12)
    caption.textColor = TotiTheme.plum
    caption.numberOfLines = 1
    caption.lineBreakMode = .byTruncatingTail
    caption.isUserInteractionEnabled = false
    addSubview(caption)
    caption.translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([
      caption.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
      caption.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),
      caption.topAnchor.constraint(equalTo: topAnchor, constant: 5),
      caption.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -3),
      heightAnchor.constraint(greaterThanOrEqualToConstant: 26),
    ])
    accessibilityTraits = .button
  }
  required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }
  func show(name: String, text: String) {
    let snippet = text.count > 42 ? String(text.prefix(42)) + "…" : text
    caption.text = name + ": " + snippet
    isHidden = false
    accessibilityLabel = "Replying to " + name + ", " + snippet + ". Clear reply"
  }
  func clear() {
    caption.text = nil
    isHidden = true
    accessibilityLabel = nil
  }
}

private final class ReportPress: UILongPressGestureRecognizer {
  var lineID = ""
  var lineName = ""
  var lineText = ""
}

final class PartyRoomController: TotiScreen, UITableViewDataSource, UITableViewDelegate {
  private struct RoomLine {
    let id = UUID()
    var name: String
    var text: String
    var replyName: String?
    var replyText: String?
  }
  let room: PartyRoom
  private let table = UITableView(frame: .zero, style: .plain), input = field("Say something…")
  private let replyChip = ReplyChip()
  private var newMessages: StudioButton!
  private var messages: [RoomLine] = []
  private var reply: RoomLine?
  private var speakerOn = true
  private var micOn = true
  private var speakerButton: UIButton?
  private var micButton: UIButton?
  private var seats: [PartySeatView] = []
  private var mutedSeatIDs: Set<String> = []
  private var speakingIDs: Set<String> = []
  private var speakClear: Task<Void, Never>?
  init(store: AppStore, room: PartyRoom) {
    self.room = room
    super.init(store: store, title: room.title)
  }
  required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }
  override func build() {
    let me = PartyParticipant(
      id: "local-owner", asset: MusicPhotography.creatorAvatar(for: "local-owner"),
      name: store.library.profile.displayName)
    let others = Array(room.participants.prefix(3))
    let visible = [me] + others
    if let closed = others.first { mutedSeatIDs = [closed.id] }
    let row = UIStackView()
    row.axis = .horizontal
    row.alignment = .top
    row.spacing = 8
    for person in visible {
      let seat = PartySeatView(
        participant: person,
        image: person.id == "local-owner" ? store.ownerAvatarImage() : nil)
      seat.onOpen = { [weak self] in self?.openArtist(person) }
      seats.append(seat)
      row.addArrangedSubview(seat)
    }
    refreshSeats()
    let band = UIView()
    let scroller = UIScrollView()
    scroller.showsHorizontalScrollIndicator = false
    scroller.alwaysBounceHorizontal = false
    scroller.clipsToBounds = true
    row.translatesAutoresizingMaskIntoConstraints = false
    scroller.translatesAutoresizingMaskIntoConstraints = false
    scroller.addSubview(row)
    let invite = InviteSeatView()
    invite.addAction(UIAction { [weak self] _ in self?.showInvite() }, for: .touchUpInside)
    let lineup = stack([scroller, invite], axis: .horizontal, spacing: 8)
    lineup.alignment = .top
    let peopleWidth = CGFloat(visible.count) * 78 + CGFloat(max(visible.count - 1, 0)) * 8
    let scrollerWidth = scroller.widthAnchor.constraint(equalToConstant: peopleWidth)
    scrollerWidth.priority = UILayoutPriority(999)
    band.addSubview(lineup)
    lineup.translatesAutoresizingMaskIntoConstraints = false
    table.backgroundColor = .clear
    table.separatorStyle = .none
    table.dataSource = self
    table.delegate = self
    table.keyboardDismissMode = .interactive
    view.addSubview(band)
    view.addSubview(table)
    band.translatesAutoresizingMaskIntoConstraints = false
    table.translatesAutoresizingMaskIntoConstraints = false
    let speaker = iconButton(.speakerIvory, "Speaker on", size: 32) { [weak self] in
      self?.toggleSpeaker()
    }
    let mic = iconButton(.microphoneIvory, "Microphone on", size: 32) { [weak self] in
      self?.toggleMic()
    }
    speakerButton = speaker
    micButton = mic
    let send = iconButton(.send, "Send") { [weak self] in self?.send() }
    let gift = iconButton(.gift, "Send a gift") { [weak self] in self?.showGifts() }
    let tools = stack([speaker, mic], axis: .horizontal, spacing: 0)
    tools.alignment = .center
    pack(speaker)
    pack(mic)
    pack(send)
    pack(gift)
    tools.setContentHuggingPriority(.required, for: .horizontal)
    tools.setContentCompressionResistancePriority(.required, for: .horizontal)
    input.setContentHuggingPriority(.defaultLow, for: .horizontal)
    input.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
    replyChip.addAction(UIAction { [weak self] _ in self?.clearReply() }, for: .touchUpInside)
    replyChip.setContentHuggingPriority(.required, for: .horizontal)
    let column = stack([replyChip, input], spacing: 0)
    column.alignment = .leading
    column.setContentHuggingPriority(.defaultLow, for: .horizontal)
    column.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
    let composer = stack([tools, column, send, gift], axis: .horizontal, spacing: 2)
    composer.alignment = .bottom
    view.addSubview(composer)
    composer.translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([
      band.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
      band.leadingAnchor.constraint(equalTo: view.leadingAnchor),
      band.trailingAnchor.constraint(equalTo: view.trailingAnchor),
      lineup.topAnchor.constraint(equalTo: band.topAnchor, constant: 4),
      lineup.bottomAnchor.constraint(equalTo: band.bottomAnchor),
      lineup.centerXAnchor.constraint(equalTo: band.centerXAnchor),
      lineup.leadingAnchor.constraint(greaterThanOrEqualTo: band.leadingAnchor, constant: 12),
      lineup.trailingAnchor.constraint(lessThanOrEqualTo: band.trailingAnchor, constant: -12),
      scrollerWidth,
      scroller.heightAnchor.constraint(equalTo: row.heightAnchor),
      row.leadingAnchor.constraint(equalTo: scroller.contentLayoutGuide.leadingAnchor),
      row.trailingAnchor.constraint(equalTo: scroller.contentLayoutGuide.trailingAnchor),
      row.topAnchor.constraint(equalTo: scroller.contentLayoutGuide.topAnchor),
      row.bottomAnchor.constraint(equalTo: scroller.contentLayoutGuide.bottomAnchor),
      table.topAnchor.constraint(equalTo: band.bottomAnchor, constant: 8),
      table.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 8),
      table.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -8),
      table.bottomAnchor.constraint(equalTo: composer.topAnchor, constant: -6),
      input.widthAnchor.constraint(equalTo: column.widthAnchor),
      replyChip.widthAnchor.constraint(lessThanOrEqualTo: column.widthAnchor),
      composer.leadingAnchor.constraint(
        equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 8),
      composer.trailingAnchor.constraint(
        equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -8),
      composer.bottomAnchor.constraint(equalTo: view.keyboardLayoutGuide.topAnchor, constant: -6),
    ])
    let connectionNotice = label("Local room · real-time voice is not connected.\nMessages stay in this room while it is open.", 14, TotiTheme.muted)
    connectionNotice.textAlignment = .center
    connectionNotice.frame = CGRect(x: 0, y: 0, width: 300, height: 64)
    table.tableHeaderView = connectionNotice
    newMessages = actionButton("New messages", tone: .coral, compact: true) { [weak self] in
      self?.scrollBottom()
    }
    newMessages.isHidden = true
    view.addSubview(newMessages)
    newMessages.translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([
      newMessages.bottomAnchor.constraint(equalTo: composer.topAnchor, constant: -6),
      newMessages.centerXAnchor.constraint(equalTo: table.centerXAnchor),
      newMessages.heightAnchor.constraint(greaterThanOrEqualToConstant: 44),
    ])
    navigationItem.rightBarButtonItems = [
      barButton(iconButton(.info, "Party details") { [weak self] in self?.showInfo() }),
      barButton(iconButton(.share, "Share party") { [weak self] in self?.showShare() }),
    ]
    NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification).sink {
      [weak self] _ in self?.stop()
    }.store(in: &tokens)
  }
  private func openArtist(_ person: PartyParticipant) {
    let creator =
      person.id == "local-owner"
      ? CreatorProfile.signedIn(store.library.profile) : .artist(person)
    push(CreatorController(store: store, creator: creator))
  }
  private func showGifts() {
    let people = room.participants.map { GiftAudienceMember(id: $0.id, name: $0.name) }
    let gifts = GiftsController(
      store: store, roomID: room.id, recipients: people, picksRecipient: true)
    gifts.onSent = { [weak self] gift, count in
      guard let self else { return }
      GiftBurst.show(gift: gift, quantity: count, in: self.view)
    }
    presentScreen(gifts)
  }
  private func toggleSpeaker() {
    speakerOn.toggle()
    speakerButton?.setImage(
      (speakerOn ? TotiIcon.speakerIvory : .mutedIvory).image(size: 32), for: .normal)
    speakerButton?.accessibilityLabel = speakerOn ? "Speaker on" : "Speaker off"
    if !speakerOn {
      speakClear?.cancel()
      speakingIDs = []
    }
    refreshSeats()
  }
  private func toggleMic() {
    micOn.toggle()
    if micOn {
      mutedSeatIDs.remove("local-owner")
    } else {
      mutedSeatIDs.insert("local-owner")
      speakingIDs.remove("local-owner")
    }
    micButton?.setImage(
      (micOn ? TotiIcon.microphoneIvory : .microphoneOffIvory).image(size: 32), for: .normal)
    micButton?.accessibilityLabel = micOn ? "Microphone on" : "Microphone off"
    refreshSeats()
  }
  private func refreshSeats() {
    for seat in seats {
      seat.apply(
        speaking: speakingIDs.contains(seat.participant.id),
        muted: mutedSeatIDs.contains(seat.participant.id))
    }
  }
  private func showInfo() {
    let info = PartyInfoController(store: store, room: room)
    info.onResolved = { [weak self] in
      guard let self else { return }
      (self.navigationController ?? self).dismiss(animated: true)
    }
    presentScreen(info)
  }
  override func refresh() {
    guard isViewLoaded else { return }
    let kept = messages.filter { !store.isCommentReported($0.id.uuidString) }
    guard kept.count != messages.count else { return }
    if let reply, store.isCommentReported(reply.id.uuidString) { clearReply() }
    messages = kept
    table.reloadData()
  }
  private func clearReply() {
    reply = nil
    replyChip.clear()
  }
  /// Pins a bottom-bar control to the icon width so the field keeps the extra space.
  private func pack(_ view: UIView) {
    for constraint in view.constraints where constraint.firstAttribute == .width
      && constraint.relation == .greaterThanOrEqual && constraint.secondItem == nil
    {
      constraint.isActive = false
    }
    view.widthAnchor.constraint(equalToConstant: 36).isActive = true
    view.setContentHuggingPriority(.required, for: .horizontal)
    view.setContentCompressionResistancePriority(.required, for: .horizontal)
  }
  private func showInvite() {
    let title = label("Invite", 22, title: true)
    let close = iconButton(.close, "Close") { [weak self] in self?.dismissCard() }
    let header = stack([title, UIView(), close], axis: .horizontal, spacing: 8)
    header.alignment = .center
    let people = store.chatConversations.filter {
      $0.kind == .person && $0.creator?.isLocalOwner != true && store.followsChatPartner($0)
    }
    let row = UIStackView()
    row.axis = .horizontal
    row.alignment = .top
    row.spacing = 14
    let scroller = UIScrollView()
    scroller.showsHorizontalScrollIndicator = false
    scroller.translatesAutoresizingMaskIntoConstraints = false
    scroller.heightAnchor.constraint(equalToConstant: 96).isActive = true
    if people.isEmpty {
      let empty = label("Add a friend in Chats before inviting someone.", 14, TotiTheme.muted)
      scroller.addSubview(empty)
      empty.translatesAutoresizingMaskIntoConstraints = false
      NSLayoutConstraint.activate([
        empty.leadingAnchor.constraint(equalTo: scroller.contentLayoutGuide.leadingAnchor),
        empty.trailingAnchor.constraint(equalTo: scroller.contentLayoutGuide.trailingAnchor),
        empty.centerYAnchor.constraint(equalTo: scroller.frameLayoutGuide.centerYAnchor),
        empty.widthAnchor.constraint(equalTo: scroller.frameLayoutGuide.widthAnchor),
      ])
    } else {
      scroller.addSubview(row)
      row.translatesAutoresizingMaskIntoConstraints = false
      NSLayoutConstraint.activate([
        row.leadingAnchor.constraint(equalTo: scroller.contentLayoutGuide.leadingAnchor),
        row.trailingAnchor.constraint(equalTo: scroller.contentLayoutGuide.trailingAnchor),
        row.topAnchor.constraint(equalTo: scroller.contentLayoutGuide.topAnchor),
        row.bottomAnchor.constraint(equalTo: scroller.contentLayoutGuide.bottomAnchor),
        row.heightAnchor.constraint(equalTo: scroller.frameLayoutGuide.heightAnchor),
      ])
      for person in people { row.addArrangedSubview(invitePerson(person)) }
    }
    showBottomPanel(stack([header, scroller], spacing: 16))
  }
  private func invitePerson(_ person: MusicConversation) -> UIView {
    let item = UIButton(type: .custom)
    let photo = conversationPortrait(person, size: 56)
    let nickname = person.name.components(separatedBy: " ").first ?? person.name
    let name = label(nickname, 12)
    name.textAlignment = .center
    name.numberOfLines = 1
    name.isAccessibilityElement = false
    let column = stack([photo, name], spacing: 6)
    column.alignment = .center
    column.isUserInteractionEnabled = false
    item.addSubview(column)
    column.translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([
      item.widthAnchor.constraint(equalToConstant: 68),
      column.topAnchor.constraint(equalTo: item.topAnchor),
      column.bottomAnchor.constraint(equalTo: item.bottomAnchor),
      column.centerXAnchor.constraint(equalTo: item.centerXAnchor),
      column.leadingAnchor.constraint(greaterThanOrEqualTo: item.leadingAnchor),
      column.trailingAnchor.constraint(lessThanOrEqualTo: item.trailingAnchor),
    ])
    item.accessibilityLabel = "Invite \(person.name)"
    item.addAction(UIAction { [weak self] _ in self?.invite(person) }, for: .touchUpInside)
    return item
  }
  private func invite(_ person: MusicConversation) {
    let title = room.title.trimmingCharacters(in: .whitespacesAndNewlines)
    let name = title.isEmpty ? "this party" : title
    let text = "Come listen with me in \(name). Open Voice and look for this party."
    dismissCard { [weak self] in
      guard let self else { return }
      Task { [weak self] in
        guard let self else { return }
        if await self.store.sendChatMessage(text, to: person) {
          self.message("Invite saved in your chat with \(person.name). It stays on this device.")
        } else {
          self.message(self.store.lastSaveError ?? "That invite could not be saved.")
        }
      }
    }
  }
  private func showShare() {
    let title = room.title.trimmingCharacters(in: .whitespacesAndNewlines)
    let name = title.isEmpty ? "this party" : title
    let address = "toti://party/\(room.id)"
    showContentShare(text: "Join the music in \(name). Party address: \(address)", address: address)
  }
  override func viewWillDisappear(_ animated: Bool) {
    super.viewWillDisappear(animated)
    stop()
  }
  private func stop() {
    speakClear?.cancel()
    speakingIDs = []
    refreshSeats()
  }
  private func append(_ lines: [RoomLine]) {
    let bottom = table.contentSize.height - table.contentOffset.y - table.bounds.height < 100
    let start = messages.count
    messages += lines
    if messages.count > 200 {
      messages = Array(messages.suffix(200))
      table.reloadData()
    } else {
      table.insertRows(
        at: (start..<messages.count).map { IndexPath(row: $0, section: 0) },
        with: UIAccessibility.isReduceMotionEnabled ? .none : .fade)
    }
    if bottom { scrollBottom() } else { newMessages.isHidden = false }
    markSpeaking(lines)
  }
  private func markSpeaking(_ lines: [RoomLine]) {
    speakClear?.cancel()
    guard speakerOn else {
      speakingIDs = []
      refreshSeats()
      return
    }
    let names = Set(lines.map(\.name))
    speakingIDs = Set(
      seats.compactMap { seat in
        let named = names.contains(seat.participant.name)
          || (names.contains("You") && seat.participant.id == "local-owner")
        return named && !mutedSeatIDs.contains(seat.participant.id) ? seat.participant.id : nil
      })
    refreshSeats()
    speakClear = Task { [weak self] in
      try? await Task.sleep(for: .milliseconds(1400))
      guard let self, !Task.isCancelled else { return }
      self.speakingIDs = []
      self.refreshSeats()
    }
  }
  private func scrollBottom() {
    guard !messages.isEmpty else { return }
    table.layoutIfNeeded()
    table.scrollToRow(
      at: IndexPath(row: messages.count - 1, section: 0), at: .bottom,
      animated: !UIAccessibility.isReduceMotionEnabled)
    newMessages.isHidden = true
  }
  private func send() {
    let text = (input.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    guard !text.isEmpty, text.count <= 200, CreationValidation.isEnglish(text) else { return }
    let quote = reply
    append([
      RoomLine(name: "You", text: text, replyName: quote?.name, replyText: quote?.text)
    ])
    input.text = ""
    clearReply()
    scrollBottom()
  }
  func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    messages.count
  }
  func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    let line = messages[indexPath.row]
    let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
    cell.backgroundColor = .clear
    cell.selectionStyle = .none
    let name = label(line.name, 12, TotiTheme.muted)
    var rows: [UIView] = [name]
    if let replyName = line.replyName, let replyText = line.replyText {
      let snippet = replyText.count > 48 ? String(replyText.prefix(48)) + "…" : replyText
      let quote = label(replyName + ": " + snippet, 12, TotiTheme.plum)
      quote.numberOfLines = 1
      let box = UIView()
      box.backgroundColor = TotiTheme.coral
      box.layer.cornerRadius = 8
      box.layer.cornerCurve = .continuous
      box.addSubview(quote)
      quote.pin(to: box, insets: UIEdgeInsets(top: 4, left: 8, bottom: 4, right: 8))
      rows.append(box)
    }
    let body = label(line.text, 16, TotiTheme.plum)
    rows.append(body)
    let column = stack(rows, spacing: 2)
    cell.contentView.addSubview(column)
    column.translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([
      column.leadingAnchor.constraint(equalTo: cell.contentView.leadingAnchor, constant: 12),
      column.trailingAnchor.constraint(equalTo: cell.contentView.trailingAnchor, constant: -12),
      column.topAnchor.constraint(equalTo: cell.contentView.topAnchor, constant: 6),
      column.bottomAnchor.constraint(equalTo: cell.contentView.bottomAnchor, constant: -6),
    ])
    cell.accessibilityLabel = line.name + ", " + line.text
    if line.name == "You" {
      cell.accessibilityHint = "Reply to this message"
    } else {
      let press = ReportPress(target: self, action: #selector(reportMessage(_:)))
      press.lineID = line.id.uuidString
      press.lineName = line.name
      press.lineText = line.text
      cell.addGestureRecognizer(press)
      cell.accessibilityHint = "Reply to this message, or report it"
      cell.accessibilityCustomActions = [
        UIAccessibilityCustomAction(name: "Report comment") { [weak self] _ in
          self?.openMessageReport(id: line.id.uuidString, name: line.name, text: line.text)
          return true
        },
      ]
    }
    return cell
  }
  @objc private func reportMessage(_ gesture: ReportPress) {
    guard gesture.state == .began else { return }
    openMessageReport(id: gesture.lineID, name: gesture.lineName, text: gesture.lineText)
  }
  private func openMessageReport(id: String, name: String, text: String) {
    guard name != "You" else { return }
    showCard([
      label("Report comment", 22, title: true),
      label(name + ": " + text, 15, TotiTheme.muted),
      actionButton("Report", icon: .flag, tone: .danger) { [weak self] in
        guard let self else { return }
        self.dismissCard {
          self.presentScreen(
            SafetyController(
              store: self.store,
              target: .comment(id: id, name: name, text: text),
              reporting: true))
        }
      },
      actionButton("Cancel") { [weak self] in self?.dismissCard() },
    ])
  }
  func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    let line = messages[indexPath.row]
    reply = line
    replyChip.show(name: line.name, text: line.text)
    input.becomeFirstResponder()
  }
  deinit {
    speakClear?.cancel()
  }
}

final class PartyInfoController: StackScreen {
  let room: PartyRoom
  var onResolved: (() -> Void)?
  init(store: AppStore, room: PartyRoom) {
    self.room = room
    super.init(store: store, title: room.title)
  }
  required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }
  override func build() {
    super.build()
    heading("About this party")
    content.addArrangedSubview(label(room.description))
    let count = room.participants.count
    let people = count == 1 ? "1 person" : "\(count) people"
    content.addArrangedSubview(
      label(room.category.title + " · " + people, 15, TotiTheme.muted))
    content.addArrangedSubview(
      label(
        "Voice in this room stays on this device. A live connection is not available.",
        15, TotiTheme.muted))
    let creator = blockTarget()
    content.addArrangedSubview(
      actionButton("Report", icon: .flag) { [weak self] in
        guard let self else { return }
        let safety = SafetyController(
          store: self.store,
          target: .party(id: self.room.id, title: self.room.title, detail: self.room.description),
          reporting: true)
        safety.onResolved = self.onResolved
        self.push(safety)
      })
    content.addArrangedSubview(
      actionButton("Block " + creator.name, icon: .block) { [weak self] in
        guard let self else { return }
        self.confirm(
          "Block " + creator.name + "?",
          message:
            "Their posts, comments and voice rooms will be hidden. You can unblock them from Blocked in Settings.",
          destructive: true, button: "Block"
        ) { [weak self] in
          guard let self else { return }
          Task {
            if await self.store.blockCreator(creator) {
              let leave = self.onResolved
              self.dismiss(animated: true) { leave?() }
            } else {
              self.message(self.store.lastSaveError ?? "Please try again.")
            }
          }
        }
      })
  }
  private func blockTarget() -> CreatorProfile {
    if let host = room.participants.first {
      return CreatorProfile(
        id: host.id, name: host.name, biography: room.title, avatarAsset: host.asset)
    }
    return CreatorProfile(
      id: "party:" + room.id, name: room.title, biography: room.description, avatarAsset: nil)
  }
}

final class PartyCreationController: StackScreen {
  private var draft: VoiceRoomDraft
  init(store: AppStore, draft: VoiceRoomDraft = VoiceRoomDraft()) {
    self.draft = draft
    super.init(store: store, title: "Create a party")
  }
  required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }
  override func build() {
    super.build()
    let name = field("Party name", text: draft.title)
    let description = field("What's the vibe?", text: draft.description)
    content.addArrangedSubview(name)
    content.addArrangedSubview(description)
    let category = StudioChoice(
      items: PartyCategory.allCases.map(\.title),
      index: PartyCategory.allCases.firstIndex(where: { $0.rawValue == draft.danceCategory }) ?? 0)
    content.addArrangedSubview(category)
    let seats = StudioChoice(
      items: ["4 people", "6 people", "8 people"],
      index: [4, 6, 8].firstIndex(of: draft.seatCount) ?? 1)
    content.addArrangedSubview(seats)
    content.addArrangedSubview(
      actionButton("Save party", icon: .voice, primary: true) { [weak self] in
        guard let self else { return }
        self.draft.title = name.text ?? ""
        self.draft.description = description.text ?? ""
        self.draft.danceCategory = PartyCategory.allCases[max(0, category.index)].rawValue
        self.draft.seatCount = [4, 6, 8][max(0, seats.index)]
        Task {
          if await self.store.saveRoom(self.draft) {
            self.dismissCollapsed()
          } else {
            self.message(
              self.store.lastSaveError
                ?? "Add a name up to 60 characters and a description up to 240 characters.")
          }
        }
      })
    if store.library.roomDrafts.contains(where: { $0.id == draft.id }) {
      content.addArrangedSubview(
        actionButton("Delete party", icon: .trash) { [weak self] in
          guard let self else { return }
          self.confirm(
            "Delete party?", message: "This removes your saved party.", destructive: true,
            button: "Delete"
          ) {
            Task { if await self.store.deleteRoom(self.draft.id) { self.dismissCollapsed() } }
          }
        })
    }
  }
}
