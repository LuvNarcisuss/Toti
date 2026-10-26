import AVFoundation
import UIKit

@MainActor final class VideoTile: UIControl {
  private let frameView = UIView()
  private let playerView = VideoLayerView()
  private let cover = TotiPhoto()
  private let caption = UILabel()
  private let avatar = TotiPhoto(size: 24, round: true)
  private let avatarHit = UIButton(type: .custom)
  private let living = LivingBadge()
  private let ring = PulseRing()
  private let marks = FrameMarks()
  private let lamp = UIView()
  private var queue: AVQueuePlayer?
  private var looper: AVPlayerLooper?
  private var loopTask: Task<Void, Never>?
  private var statusObservation: NSKeyValueObservation?
  private var mediaURL: URL?
  private var configuredURL: URL?
  private var wantsPlay = false
  private var plainConstraints: [NSLayoutConstraint] = []
  private var liveConstraints: [NSLayoutConstraint] = []
  var onTap: (() -> Void)?
  var onAvatar: (() -> Void)? {
    didSet { refreshAvatarAccess() }
  }
  private var creatorName = ""

  override init(frame: CGRect) {
    super.init(frame: frame)
    backgroundColor = TotiTheme.soft
    layer.cornerRadius = 19
    clipsToBounds = true
    frameView.backgroundColor = .black
    frameView.layer.cornerRadius = 18
    frameView.layer.cornerCurve = .continuous
    frameView.clipsToBounds = true
    frameView.isUserInteractionEnabled = false
    frameView.translatesAutoresizingMaskIntoConstraints = false
    playerView.isUserInteractionEnabled = false
    playerView.videoLayer.videoGravity = .resizeAspectFill
    playerView.isHidden = true
    cover.isUserInteractionEnabled = false
    addSubview(ring)
    addSubview(frameView)
    frameView.addSubview(playerView)
    frameView.addSubview(cover)
    playerView.pin(to: frameView)
    cover.pin(to: frameView)
    let shade = UIView()
    shade.backgroundColor = UIColor.black.withAlphaComponent(0.38)
    shade.isUserInteractionEnabled = false
    frameView.addSubview(shade)
    shade.translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([
      shade.leadingAnchor.constraint(equalTo: frameView.leadingAnchor),
      shade.trailingAnchor.constraint(equalTo: frameView.trailingAnchor),
      shade.bottomAnchor.constraint(equalTo: frameView.bottomAnchor),
    ])
    caption.font = TotiTheme.font(14)
    caption.textColor = .white
    caption.numberOfLines = 2
    caption.adjustsFontForContentSizeCategory = true
    let row = stack([avatar, caption], axis: .horizontal, spacing: 7)
    row.alignment = .center
    row.isUserInteractionEnabled = false
    avatar.addSubview(avatarHit)
    avatarHit.pin(to: avatar)
    avatarHit.isAccessibilityElement = false
    avatarHit.addAction(UIAction { [weak self] _ in self?.onAvatar?() }, for: .touchUpInside)
    shade.addSubview(row)
    row.pin(to: shade, insets: UIEdgeInsets(top: 9, left: 9, bottom: 9, right: 9))
    living.isHidden = true
    ring.isHidden = true
    marks.isHidden = true
    lamp.isHidden = true
    lamp.backgroundColor = TotiTheme.plum
    lamp.layer.cornerRadius = 4
    lamp.isUserInteractionEnabled = false
    for item in [marks, lamp] as [UIView] {
      item.translatesAutoresizingMaskIntoConstraints = false
      addSubview(item)
    }
    living.translatesAutoresizingMaskIntoConstraints = false
    frameView.addSubview(living)
    NSLayoutConstraint.activate([
      living.centerXAnchor.constraint(equalTo: frameView.centerXAnchor),
      living.bottomAnchor.constraint(equalTo: shade.topAnchor, constant: -6),
    ])
    ring.translatesAutoresizingMaskIntoConstraints = false
    plainConstraints = [
      frameView.leadingAnchor.constraint(equalTo: leadingAnchor),
      frameView.trailingAnchor.constraint(equalTo: trailingAnchor),
      frameView.topAnchor.constraint(equalTo: topAnchor),
      frameView.bottomAnchor.constraint(equalTo: bottomAnchor),
    ]
    liveConstraints = [
      frameView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 4),
      frameView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -4),
      frameView.topAnchor.constraint(equalTo: topAnchor, constant: 8),
      frameView.bottomAnchor.constraint(equalTo: bottomAnchor),
      ring.leadingAnchor.constraint(equalTo: frameView.leadingAnchor, constant: -3),
      ring.trailingAnchor.constraint(equalTo: frameView.trailingAnchor, constant: 3),
      ring.topAnchor.constraint(equalTo: frameView.topAnchor, constant: -3),
      ring.bottomAnchor.constraint(equalTo: frameView.bottomAnchor, constant: 3),
      marks.leadingAnchor.constraint(equalTo: ring.leadingAnchor),
      marks.trailingAnchor.constraint(equalTo: ring.trailingAnchor),
      marks.topAnchor.constraint(equalTo: ring.topAnchor),
      marks.bottomAnchor.constraint(equalTo: ring.bottomAnchor),
      lamp.widthAnchor.constraint(equalToConstant: 8),
      lamp.heightAnchor.constraint(equalToConstant: 8),
      lamp.centerXAnchor.constraint(equalTo: frameView.trailingAnchor, constant: -2),
      lamp.centerYAnchor.constraint(equalTo: frameView.topAnchor, constant: 2),
    ]
    NSLayoutConstraint.activate(plainConstraints)
    addAction(UIAction { [weak self] _ in self?.onTap?() }, for: .touchUpInside)
    isAccessibilityElement = true
    accessibilityTraits = .button
  }

  override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
    guard onAvatar != nil else { return super.hitTest(point, with: event) }
    guard isUserInteractionEnabled, !isHidden, alpha > 0.01, bounds.contains(point) else { return nil }
    let local = avatar.convert(point, from: self)
    if avatar.bounds.insetBy(dx: -8, dy: -8).contains(local) { return avatarHit }
    return self
  }

  private func refreshAvatarAccess() {
    guard onAvatar != nil else {
      accessibilityCustomActions = nil
      return
    }
    let name = creatorName.isEmpty ? "profile" : creatorName + "'s profile"
    accessibilityCustomActions = [
      UIAccessibilityCustomAction(name: "Open " + name) { [weak self] _ in
        self?.onAvatar?()
        return true
      },
    ]
  }

  required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }

  func configure(_ video: LocalVideo, store: AppStore, showDuration: Bool, plays: Bool = false) {
    cover.alpha = 1
    cover.load(store.coverURL(video))
    if video.creatorID == "local-owner", let image = store.ownerAvatarImage() {
      avatar.image = image
    } else {
      avatar.image = UIImage(named: MusicPhotography.creatorAvatar(for: video.creatorID))
    }
    caption.text = video.title + (showDuration ? "\n" + video.durationLabel : (plays ? "\n" + (video.bundledClip?.genre.title ?? "Music") : ""))
    let creator = video.creatorName(profile: store.library.profile)
    creatorName = creator
    accessibilityLabel = video.title + ", " + creator + (plays ? ", Recorded session" : "")
    refreshAvatarAccess()
    setLiveChrome(plays)
    mediaURL = plays ? store.videoURL(video) : nil
    if !plays { stopPlayback() }
  }

  /// Phrase cards keep the live tile and put the phrase name on it.
  func presentPhrase(_ title: String, author: String, avatar: UIImage?) {
    caption.text = title
    creatorName = author
    if let avatar { self.avatar.image = avatar }
    accessibilityLabel = title + ", " + author
    refreshAvatarAccess()
  }

  /// Cover, title, and live chrome only. No player and no moving badge.
  func configureStatic(_ video: LocalVideo, store: AppStore, live: Bool) {
    configure(video, store: store, showDuration: !live, plays: false)
    if live {
      setLiveChrome(true)
      mediaURL = nil
      stopPlayback()
    }
    onTap = nil
  }

  func setPlaying(_ playing: Bool) {
    let changed = wantsPlay != playing || (playing && queue == nil && configuredURL == nil)
    wantsPlay = playing
    guard mediaURL != nil, changed else { return }
    if playing {
      if queue == nil, let mediaURL { prepare(mediaURL) }
      queue?.play()
      living.start()
      ring.start()
      pulseLamp()
    } else {
      queue?.pause()
      living.stop()
      ring.stop()
      lamp.layer.removeAnimation(forKey: "lamp")
    }
  }

  override func willMove(toSuperview newSuperview: UIView?) {
    super.willMove(toSuperview: newSuperview)
    if newSuperview == nil {
      mediaURL = nil
      stopPlayback()
    }
  }

  private func setLiveChrome(_ on: Bool) {
    living.isHidden = !on
    ring.isHidden = true
    marks.isHidden = true
    lamp.isHidden = true
    backgroundColor = on ? .clear : TotiTheme.soft
    layer.cornerRadius = on ? 0 : 19
    clipsToBounds = !on
    NSLayoutConstraint.deactivate(on ? plainConstraints : liveConstraints)
    NSLayoutConstraint.activate(on ? liveConstraints : plainConstraints)
  }

  /// Home live cards loop the opening second. The opened room still plays the film.
  private func prepare(_ url: URL) {
    if queue != nil, configuredURL == url { return }
    let resume = wantsPlay
    stopPlayback()
    wantsPlay = resume
    mediaURL = url
    configuredURL = url
    guard FileManager.default.fileExists(atPath: url.path) else { return }
    let asset = AVURLAsset(url: url)
    let item = AVPlayerItem(asset: asset)
    let queue = AVQueuePlayer()
    queue.isMuted = true
    self.queue = queue
    playerView.videoLayer.player = queue
    playerView.isHidden = false
    statusObservation = queue.observe(\.timeControlStatus, options: [.new]) {
      [weak self] player, _ in
      let status = player.timeControlStatus
      Task { @MainActor [weak self] in
        guard let self, self.queue === player, status == .playing else { return }
        if UIAccessibility.isReduceMotionEnabled {
          self.cover.alpha = 0
        } else {
          UIView.animate(withDuration: 0.2) { self.cover.alpha = 0 }
        }
      }
    }
    loopTask = Task { [weak self] in
      let duration = try? await asset.load(.duration)
      let seconds = duration?.seconds ?? .nan
      let clip: Double
      if seconds.isFinite, seconds > 0.12 {
        clip = min(1, seconds - 0.04)
      } else if seconds.isFinite, seconds > 0.05 {
        clip = seconds * 0.85
      } else {
        clip = 1
      }
      guard !Task.isCancelled, let self, self.queue === queue, self.looper == nil else { return }
      let range = CMTimeRange(
        start: .zero, duration: CMTime(seconds: clip, preferredTimescale: 600))
      self.looper = AVPlayerLooper(player: queue, templateItem: item, timeRange: range)
      if self.wantsPlay { queue.play() }
    }
  }

  private func stopPlayback() {
    wantsPlay = false
    living.stop()
    ring.stop()
    lamp.layer.removeAnimation(forKey: "lamp")
    statusObservation = nil
    loopTask?.cancel()
    loopTask = nil
    looper?.disableLooping()
    looper = nil
    queue?.pause()
    queue?.removeAllItems()
    playerView.videoLayer.player = nil
    queue = nil
    playerView.isHidden = true
    configuredURL = nil
    cover.alpha = 1
  }

  private func pulseLamp() {
    guard !lamp.isHidden, lamp.layer.animation(forKey: "lamp") == nil,
      !UIAccessibility.isReduceMotionEnabled
    else { return }
    let anim = CABasicAnimation(keyPath: "opacity")
    anim.fromValue = 0.35
    anim.toValue = 1
    anim.duration = 0.9
    anim.autoreverses = true
    anim.repeatCount = .infinity
    lamp.layer.add(anim, forKey: "lamp")
  }
}

private final class LivingBadge: UIView {
  private let meter = VoiceMeter()
  override init(frame: CGRect) {
    super.init(frame: frame)
    isUserInteractionEnabled = false
    isAccessibilityElement = false
    backgroundColor = UIColor.black.withAlphaComponent(0.38)
    layer.borderWidth = 1.5
    layer.borderColor = UIColor.white.cgColor
    layer.cornerCurve = .continuous
    clipsToBounds = true
    let title = UILabel()
    title.text = "Session"
    title.textColor = .white
    title.font = TotiTheme.font(15, title: true)
    title.adjustsFontForContentSizeCategory = true
    title.adjustsFontSizeToFitWidth = true
    title.minimumScaleFactor = 0.7
    title.isAccessibilityElement = false
    meter.translatesAutoresizingMaskIntoConstraints = false
    title.translatesAutoresizingMaskIntoConstraints = false
    addSubview(meter)
    addSubview(title)
    NSLayoutConstraint.activate([
      heightAnchor.constraint(greaterThanOrEqualToConstant: 28),
      meter.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
      meter.centerYAnchor.constraint(equalTo: centerYAnchor),
      meter.widthAnchor.constraint(equalToConstant: 12),
      meter.heightAnchor.constraint(equalToConstant: 14),
      title.leadingAnchor.constraint(equalTo: meter.trailingAnchor, constant: 6),
      title.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),
      title.topAnchor.constraint(equalTo: topAnchor, constant: 2),
      title.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -2),
    ])
  }

  required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }

  override func layoutSubviews() {
    super.layoutSubviews()
    layer.cornerRadius = bounds.height / 2
  }

  func start() { meter.start() }
  func stop() { meter.stop() }
}

private final class VoiceMeter: UIView {
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

  func stop() {
    bars.forEach { $0.removeAnimation(forKey: "level") }
  }
}

extension StackScreen {
  @discardableResult
  func videoGrid(
    _ videos: [LocalVideo], duration: Bool = true, plays: Bool = false,
    onCreator: ((LocalVideo) -> Void)? = nil,
    onSelect: @escaping (LocalVideo) -> Void
  ) -> [VideoTile] {
    guard !videos.isEmpty else {
      content.addArrangedSubview(label("Your next favorite voice is waiting.", 17, TotiTheme.muted))
      return []
    }
    var tiles: [VideoTile] = []
    let columns = traitCollection.preferredContentSizeCategory.isAccessibilityCategory ? 1 : 2
    let spacing: CGFloat = 10
    for start in stride(from: 0, to: videos.count, by: columns) {
      let row = stack(axis: .horizontal, spacing: spacing)
      row.distribution = .fillEqually
      row.alignment = .fill
      row.setContentCompressionResistancePriority(.required, for: .vertical)
      row.setContentHuggingPriority(.required, for: .vertical)
      for video in videos[start..<min(start + columns, videos.count)] {
        let tile = VideoTile()
        tile.configure(video, store: store, showDuration: duration, plays: plays)
        tile.onTap = { onSelect(video) }
        if let onCreator {
          tile.onAvatar = { onCreator(video) }
        }
        row.addArrangedSubview(tile)
        tiles.append(tile)
      }
      if row.arrangedSubviews.count < columns { row.addArrangedSubview(UIView()) }
      content.addArrangedSubview(row)
      // Height follows the row width. A tile aspect constraint can lose to the stack and drop a row.
      let height = row.heightAnchor.constraint(
        equalTo: content.widthAnchor,
        multiplier: 1.25 / CGFloat(columns),
        constant: -(spacing * 1.25 * CGFloat(columns - 1) / CGFloat(columns)))
      height.priority = .required
      height.isActive = true
    }
    return tiles
  }
}
final class MusicDiscoveryController: StackScreen, UIScrollViewDelegate {
  private let modes = BubbleTrack(titles: ["Live", "Shorts"], barHeight: 36, lockedWidth: 188)
  private let atmosphere = LiveAtmosphere()
  private var query = ""
  private var selectedGenre: MusicGenre?
  private var shorts: VideoFeedController?
  private var createButton: UIButton?
  private var searchButton: UIButton?
  private var liveTiles: [VideoTile] = []
  private var revealedModes = false
  private var tileSync: DispatchWorkItem?
  override func build() {
    super.build()
    insertAtmosphere(atmosphere)
    title = "Toti"
    modes.onSelect = { [weak self] _ in self?.changeMode() }
    navigationItem.titleView = modes
    navigationItem.leftBarButtonItem = barButton(totiMark())
    let search = iconButton(.search, "Search") { [weak self] in self?.toggleSearch() }
    searchButton = search
    navigationItem.rightBarButtonItem = barButton(search)
    let create = iconButton(.plus, "Create") { [weak self] in self?.create() }
    create.backgroundColor = TotiTheme.coral
    create.rounded(26)
    createButton = create
    view.addSubview(create)
    NSLayoutConstraint.activate([
      create.trailingAnchor.constraint(
        equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -12),
      create.bottomAnchor.constraint(
        equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -14),
      create.widthAnchor.constraint(equalToConstant: 52),
      create.heightAnchor.constraint(equalToConstant: 52),
    ])
    // The list is pinned to the page keyboard guide. Ignore the dock inset so cards pass under it.
    pinListUnderDock()
    scroll.contentInset.bottom = 80
    scroll.delegate = self
    let refresh = UIRefreshControl()
    refresh.addAction(
      UIAction { [weak self] _ in
        guard let self else { return }
        Task {
          await self.store.refreshLiveRecommendations()
          refresh.endRefreshing()
          self.refresh()
        }
      }, for: .valueChanged)
    scroll.refreshControl = refresh
    NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification).sink {
      [weak self] _ in
      self?.liveTiles.forEach { $0.setPlaying(false) }
    }.store(in: &tokens)
    NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification).sink {
      [weak self] _ in self?.syncLiveTiles()
    }.store(in: &tokens)
  }
  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    revealModeControl()
  }
  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    revealModeControl()
    scheduleLiveTiles()
  }
  override func viewWillDisappear(_ animated: Bool) {
    super.viewWillDisappear(animated)
    liveTiles.forEach { $0.setPlaying(false) }
  }
  override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()
    atmosphere.frame = coverFrame()
    let clearance = 80 + view.safeAreaInsets.bottom
    if abs(scroll.contentInset.bottom - clearance) > 0.5 {
      scroll.contentInset.bottom = clearance
      var indicators = scroll.verticalScrollIndicatorInsets
      indicators.bottom = view.safeAreaInsets.bottom
      scroll.verticalScrollIndicatorInsets = indicators
    }
    revealModeControl()
    scheduleLiveTiles()
    if let createButton { view.bringSubviewToFront(createButton) }
  }
  /// The navigation bar can leave a custom title at zero size until the next touch.
  private func revealModeControl() {
    let size = modes.intrinsicContentSize
    guard size.width > 1, size.height > 1 else { return }
    if modes.bounds.width > 1 {
      revealedModes = true
      return
    }
    modes.frame = CGRect(origin: .zero, size: size)
    guard !revealedModes else { return }
    revealedModes = true
    navigationItem.titleView = modes
  }
  private func scheduleLiveTiles() {
    tileSync?.cancel()
    let work = DispatchWorkItem { [weak self] in self?.syncLiveTiles() }
    tileSync = work
    DispatchQueue.main.async(execute: work)
  }
  func scrollViewDidScroll(_ scrollView: UIScrollView) { syncLiveTiles() }
  override func refresh() {
    guard isViewLoaded else { return }
    clear()

    content.addArrangedSubview(label("THE LISTENING ROOM", 12, TotiTheme.plum))
    heading("Good music.\nBetter company.")
    content.addArrangedSubview(label("Intimate sessions. Voices worth finding.", 16, TotiTheme.muted))
    let availableGenres = MusicGenre.allCases.filter { genre in
      store.discoveryVideos.contains { $0.bundledClip?.genre == genre }
    }
    if let selectedGenre, !availableGenres.contains(selectedGenre) {
      self.selectedGenre = nil
    }
    let selectedIndex = selectedGenre.flatMap { availableGenres.firstIndex(of: $0) }.map { $0 + 1 } ?? 0
    let genres = BubbleTrack(titles: ["For you"] + availableGenres.map(\.title), index: selectedIndex, barHeight: 42)
    genres.onSelect = { [weak self] index in
      self?.selectedGenre = index == 0 ? nil : availableGenres[index - 1]
      self?.refresh()
    }
    content.addArrangedSubview(genres)
    let videos = store.discoveryVideos.filter {
      (selectedGenre == nil || $0.bundledClip?.genre == selectedGenre)
        && (query.isEmpty || ($0.title + $0.creatorName(profile: store.library.profile) + $0.musicDescription)
          .localizedCaseInsensitiveContains(query))
    }
    if videos.isEmpty {
      content.addArrangedSubview(label("No sessions match. Try another genre or search.", 16, TotiTheme.muted))
    }
    liveTiles = videoGrid(videos, duration: false, plays: true, onCreator: { [weak self] video in
      guard let self else { return }
      let creator = CreatorProfile.from(
        video: video, profile: self.store.library.profile, coverURL: self.store.coverURL(video))
      self.push(CreatorController(store: self.store, creator: creator))
    }) { [weak self] video in
      guard let self else { return }
      self.presentScreen(
        VideoFeedController(store: self.store, videos: videos, initial: video.id, live: true),
        full: true)
    }
    scheduleLiveTiles()
  }
  private func tabHost() -> TotiTabController? {
    var node: UIViewController? = parent
    while let current = node {
      if let tabs = current as? TotiTabController { return tabs }
      node = current.parent
    }
    return nil
  }
  private func create() {
    let screen = CreationController(store: store, kind: modes.index == 0 ? .live : .shortVideo)
    guard let createButton else {
      presentScreen(screen, full: true)
      return
    }
    presentExpanded(from: createButton, screen)
  }
  private func changeMode() {
    if let nav = navigationController {
      if modes.index == 1 {
        let appearance = UINavigationBarAppearance()
        appearance.configureWithTransparentBackground()
        nav.navigationBar.standardAppearance = appearance
        nav.navigationBar.scrollEdgeAppearance = appearance
        nav.navigationBar.compactAppearance = appearance
        nav.navigationBar.compactScrollEdgeAppearance = appearance
      } else {
        TotiNavigation.style(nav)
      }
    }
    modes.setOnDark(modes.index == 1)
    shorts?.willMove(toParent: nil)
    shorts?.view.removeFromSuperview()
    shorts?.removeFromParent()
    shorts = nil
    createButton?.isHidden = false
    tabHost()?.setCommentOverlayActive(false)
    scroll.isHidden = modes.index == 1
    atmosphere.isHidden = modes.index == 1
    guard modes.index == 1 else {
      refresh()
      return
    }
    liveTiles.forEach { $0.setPlaying(false) }
    let child = VideoFeedController(
      store: store, videos: store.shortsDiscoveryVideos, initial: nil, live: false, discovery: true)
    child.onCommentChrome = { [weak self] open in
      self?.createButton?.isHidden = open
      self?.tabHost()?.setCommentOverlayActive(open)
    }
    shorts = child
    addChild(child)
    view.addSubview(child.view)
    child.view.pin(to: view)
    child.didMove(toParent: self)
    if let createButton { view.bringSubviewToFront(createButton) }
  }
  private func toggleSearch() {
    if let shorts {
      shorts.openSearch(from: searchButton)
      return
    }
    guard let searchButton else { return }
    if activeSearch != nil {
      activeSearch?.dismiss()
      return
    }
    expandSearch(from: searchButton, placeholder: "Search artists and sessions") { [weak self] text in
      self?.query = text
      self?.refresh()
    } onClose: { [weak self] in
      self?.query = ""
      self?.refresh()
    }
  }
  private func syncLiveTiles() {
    let active =
      modes.index == 0 && view.window != nil && presentedViewController == nil && activeSearch == nil
    let visible = scroll.bounds
    for tile in liveTiles {
      let frame = tile.convert(tile.bounds, to: scroll)
      tile.setPlaying(active && frame.intersects(visible))
    }
  }
}
