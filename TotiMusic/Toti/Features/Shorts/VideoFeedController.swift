import AVFoundation
import Combine
import UIKit

private final class CommentSheet: UIView {
  override func layoutSubviews() {
    super.layoutSubviews()
    let path = UIBezierPath(
      roundedRect: bounds, byRoundingCorners: [.topLeft, .topRight],
      cornerRadii: CGSize(width: 22, height: 22))
    let mask = CAShapeLayer()
    mask.path = path.cgPath
    layer.mask = mask
  }
}
private final class PlaybackPageCell: UICollectionViewCell {
  let cover = TotiPhoto()
  override init(frame: CGRect) {
    super.init(frame: frame)
    contentView.addSubview(cover)
    cover.pin(to: contentView)
  }
  required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }
}
final class VideoFeedController: TotiScreen, UICollectionViewDataSource,
  UICollectionViewDelegateFlowLayout, UITextFieldDelegate
{
  private var videos: [LocalVideo], allVideos: [LocalVideo]
  private let initial: UUID?, live: Bool, discovery: Bool
  private let playback = ShortsPlayback()
  private let surface = VideoLayerView(), shade = CAGradientLayer(), dim = UIView()
  private let header = UIStackView(), footer = UIStackView(), rail = UIStackView(),
    feed = UIStackView()
  private let status = UILabel(), spinner = UIActivityIndicatorView(style: .large)
  private let pause = UIButton(type: .custom)
  private var collection: UICollectionView!
  private var currentIndex = 0, appeared = false, firstLayout = true
  private var likeButton: StudioCounter?, saveButton: StudioCounter?, commentButton: StudioCounter?,
    shareButton: StudioCounter?
  private var popLike = false, popSave = false
  private var ticker: Task<Void, Never>?, bulletSequence = 0
  private var lastLaneTime = [Double](repeating: 0, count: 3)
  private let lineHost = FlyingLineHost()
  private var floatingLabels: [UIView] = []
  private weak var ownLiveLine: UIView?
  private var voicedLine: LiveBubble?
  private var voicedLineAt: TimeInterval = 0
  private var shrinkFollow = false
  private var leavingRoom = false
  private var sharing = false
  private var searchText = ""
  private var syncingFeed = false
  private let danmakuField: UITextField = {
    let field = UITextField()
    field.placeholder = "Say something…"
    field.font = TotiTheme.font(15)
    field.textColor = TotiTheme.ink
    field.backgroundColor = .white
    field.layer.cornerRadius = 14
    field.layer.cornerCurve = .continuous
    field.autocorrectionType = .no
    field.spellCheckingType = .no
    field.returnKeyType = .send
    field.accessibilityLabel = "Say something"
    let pad = UIView(frame: CGRect(x: 0, y: 0, width: 12, height: 10))
    field.leftView = pad
    field.leftViewMode = .always
    field.translatesAutoresizingMaskIntoConstraints = false
    field.heightAnchor.constraint(equalToConstant: 40).isActive = true
    field.setContentHuggingPriority(.fittingSizeLevel, for: .horizontal)
    field.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
    return field
  }()
  /// Home hides its create control while the comment sheet covers that corner.
  var onCommentChrome: ((Bool) -> Void)?
  private var commentsOpen = false
  private var commentTransition = false
  private var commentClosing = false
  private var commentHost: UIView?
  private var commentPanel: CommentsController?
  private var videoStage: UIView?
  private var commentBackdrop: UIView?
  private var current: LocalVideo? {
    videos.indices.contains(currentIndex)
      ? store.collectionVideos.first(where: { $0.id == videos[currentIndex].id })
        ?? videos[currentIndex] : nil
  }
  init(store: AppStore, videos: [LocalVideo], initial: UUID?, live: Bool, discovery: Bool = false) {
    self.videos = videos
    allVideos = videos
    self.initial = initial
    self.live = live
    self.discovery = discovery
    super.init(store: store)
  }
  required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }
  override func build() {
    view.backgroundColor = .black
    let flow = UICollectionViewFlowLayout()
    flow.minimumLineSpacing = 0
    flow.scrollDirection = .vertical
    collection = UICollectionView(frame: .zero, collectionViewLayout: flow)
    collection.backgroundColor = .black
    collection.isPagingEnabled = true
    collection.alwaysBounceVertical = true
    collection.contentInsetAdjustmentBehavior = .never
    collection.showsVerticalScrollIndicator = false
    collection.dataSource = self
    collection.delegate = self
    collection.register(PlaybackPageCell.self, forCellWithReuseIdentifier: "page")
    view.addSubview(collection)
    surface.isUserInteractionEnabled = false
    surface.videoLayer.videoGravity = .resizeAspectFill
    if live {
      shade.colors = [
        UIColor(red: 0.02, green: 0.09, blue: 0.07, alpha: 0.74).cgColor,
        UIColor(red: 0.04, green: 0.12, blue: 0.09, alpha: 0.22).cgColor,
        UIColor.clear.cgColor,
        UIColor(red: 0.02, green: 0.07, blue: 0.05, alpha: 0.80).cgColor,
      ]
      shade.locations = [0, 0.26, 0.52, 1]
    } else {
      shade.colors = [
        UIColor.black.withAlphaComponent(0.4).cgColor, UIColor.clear.cgColor,
        UIColor.clear.cgColor,
        UIColor.black.withAlphaComponent(0.65).cgColor,
      ]
      shade.locations = [0, 0.23, 0.6, 1]
    }
    dim.isUserInteractionEnabled = false
    dim.layer.addSublayer(shade)
    view.addSubview(dim)
    lineHost.backgroundColor = .clear
    lineHost.isAccessibilityElement = false
    let linePress = LinePress(target: self, action: #selector(reportFloatingLine(_:)))
    lineHost.addGestureRecognizer(linePress)
    view.addSubview(lineHost)
    for s in [header, footer, rail, feed] {
      s.axis = .vertical
      s.spacing = 9
      view.addSubview(s)
      s.translatesAutoresizingMaskIntoConstraints = false
    }
    header.axis = .horizontal
    header.alignment = .center
    rail.alignment = .center
    rail.spacing = 3
    NSLayoutConstraint.activate([
      header.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
      header.leadingAnchor.constraint(
        equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 12),
      header.trailingAnchor.constraint(
        equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -12),
      footer.leadingAnchor.constraint(
        equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 12),
      footer.bottomAnchor.constraint(equalTo: view.keyboardLayoutGuide.topAnchor, constant: -12),
      footer.trailingAnchor.constraint(
        equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: live ? -12 : -86),
      rail.trailingAnchor.constraint(
        equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -8),
      rail.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16),
      rail.widthAnchor.constraint(equalToConstant: 64),
      feed.leadingAnchor.constraint(equalTo: footer.leadingAnchor),
      feed.bottomAnchor.constraint(equalTo: footer.topAnchor, constant: -14),
      feed.widthAnchor.constraint(equalTo: view.widthAnchor, multiplier: 0.8),
    ])
    feed.isHidden = true
    if live { danmakuField.delegate = self }
    pause.setImage(TotiIcon.pause.image(.white, size: 52), for: .normal)
    pause.backgroundColor = UIColor.black.withAlphaComponent(0.15)
    pause.rounded(38)
    pause.alpha = 0
    pause.accessibilityLabel = "Play or pause"
    if live {
      pause.isHidden = true
      pause.isUserInteractionEnabled = false
    }
    pause.addAction(
      UIAction { [weak self] _ in
        guard let self, !self.live else { return }
        self.playback.togglePlayback()
        self.updatePlayback()
      }, for: .touchUpInside)
    view.addSubview(pause)
    pause.translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([
      pause.centerXAnchor.constraint(equalTo: view.centerXAnchor),
      pause.centerYAnchor.constraint(equalTo: view.centerYAnchor),
      pause.widthAnchor.constraint(equalToConstant: 76),
      pause.heightAnchor.constraint(equalToConstant: 76),
    ])
    collection.addGestureRecognizer(
      UITapGestureRecognizer(target: self, action: #selector(tapVideo)))
    status.textColor = .white
    status.font = TotiTheme.font(15)
    status.numberOfLines = 0
    status.textAlignment = .center
    view.addSubview(status)
    status.translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([
      status.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: 70),
      status.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
      status.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
    ])
    spinner.color = .white
    view.addSubview(spinner)
    spinner.translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([
      spinner.centerXAnchor.constraint(equalTo: view.centerXAnchor),
      spinner.centerYAnchor.constraint(equalTo: view.centerYAnchor),
    ])
    playback.objectWillChange.receive(on: DispatchQueue.main).sink { [weak self] _ in
      self?.updatePlayback()
    }.store(in: &tokens)
    NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification).sink {
      [weak self] _ in self?.suspend()
    }.store(in: &tokens)
    NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification).sink {
      [weak self] _ in self?.resume()
    }.store(in: &tokens)
    store.shortsSocial.$latestBullet.compactMap { $0 }.receive(on: DispatchQueue.main).sink {
      [weak self] bullet in
      guard let self, bullet.videoID == self.current?.id else { return }
      if self.live {
        self.fly(bullet.text, own: true, reportName: "You", reportText: bullet.text)
      } else {
        self.fly(bullet.text)
      }
    }.store(in: &tokens)
    let refresh = UIRefreshControl()
    refresh.tintColor = .white
    refresh.addAction(
      UIAction { [weak self] _ in
        guard let self else { return }
        Task {
          if self.live {
            await self.store.refreshLiveRecommendations()
          } else {
            await self.store.refreshShortsRecommendations()
          }
          self.allVideos = self.live ? self.store.discoveryVideos : self.store.shortsDiscoveryVideos
          self.videos = self.allVideos
          self.currentIndex = 0
          self.collection.reloadData()
          self.collection.setContentOffset(.zero, animated: false)
          self.selectCurrent()
          refresh.endRefreshing()
        }
      }, for: .valueChanged)
    if discovery || live { collection.refreshControl = refresh }
  }
  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    if !discovery { navigationController?.setNavigationBarHidden(true, animated: false) }
  }
  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    appeared = true
    selectCurrent()
    resume()
  }
  override func viewWillDisappear(_ animated: Bool) {
    super.viewWillDisappear(animated)
    let leaving = isBeingDismissed || navigationController?.isBeingDismissed == true
      || isMovingFromParent
    if live, !leaving {
      playback.setActive(true)
      return
    }
    appeared = false
    suspend()
    if leaving {
      if sharing { dismissCard() }
      playback.stop()
      surface.videoLayer.player = nil
    }
    if !discovery { navigationController?.setNavigationBarHidden(false, animated: false) }
  }
  override func willMove(toParent parent: UIViewController?) {
    super.willMove(toParent: parent)
    if parent == nil, commentsOpen { closeComments(animated: false) }
  }
  override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()
    let frame = coverFrame()
    collection.frame = frame
    lineHost.frame = view.bounds
    if commentsOpen, let stage = videoStage {
      let full = commentStageFrame()
      commentBackdrop?.frame = full
      if !commentTransition {
        let videoFrame = compactVideoFrame(in: full)
        stage.frame = videoFrame
        surface.frame = stage.bounds
        dim.frame = stage.bounds
        commentHost?.frame = commentPanelFrame(video: videoFrame, full: full)
      }
      stage.clipsToBounds = true
      commentHost?.clipsToBounds = true
    } else if dim.superview === view {
      dim.frame = frame
    }
    CATransaction.begin()
    CATransaction.setDisableActions(true)
    shade.frame = dim.bounds
    CATransaction.commit()
    layoutLiveLines()
    if collection.bounds.width > 0,
      abs(collection.collectionViewLayout.collectionViewContentSize.width - collection.bounds.width)
        > 1
    {
      collection.collectionViewLayout.invalidateLayout()
    }
    if firstLayout, !videos.isEmpty, collection.bounds.height > 1 {
      firstLayout = false
      currentIndex = initial.flatMap { id in videos.firstIndex(where: { $0.id == id }) } ?? 0
      collection.scrollToItem(
        at: IndexPath(item: currentIndex, section: 0), at: .centeredVertically, animated: false)
      selectCurrent()
    }
  }
  override func refresh() {
    guard isViewLoaded, collection != nil else { return }
    if !syncingFeed {
      if discovery {
        reconcileDiscovery()
      } else if let video = current, store.hidesVideo(video, live: live) {
        leavingRoom = true
        playback.stop()
        suspend()
      }
    }
    dropReportedLines()
    guard !leavingRoom, let video = current else { return }
    let counts = store.shortsSocial.counts(for: video)
    let likeCount = live ? store.shortsSocial.liveLikeCount(for: video) : counts.likes
    let liked = !live && store.shortsSocial.liked.contains(video.id)
    setReaction(
      likeButton, outline: .heartOutline, filled: .heartFill, count: "\(likeCount)",
      selected: liked, pop: popLike)
    popLike = false
    setReaction(
      saveButton, outline: .star, filled: .starFill, count: "\(counts.saves)",
      selected: video.isSaved, pop: popSave)
    popSave = false
    setCaption(commentButton, "\(counts.comments)")
    setCaption(shareButton, "\(counts.shares)")
  }
  func openSearch(from source: UIView?) {
    if activeSearch != nil {
      activeSearch?.dismiss()
      return
    }
    pauseIfShort()
    header.isHidden = true
    expandSearch(
      from: source ?? view, placeholder: "Search artists and sessions", dark: true
    ) { [weak self] text in
      self?.applyQuery(text)
    } onClose: { [weak self] in
      guard let self else { return }
      self.header.isHidden = false
      self.applyQuery("")
      self.resume()
    }
  }
  private func applyQuery(_ text: String) {
    searchText = text
    videos = visibleVideos(from: allVideos)
    currentIndex = 0
    collection.reloadData()
    collection.setContentOffset(.zero, animated: false)
    selectCurrent()
  }
  /// Home Shorts keeps its own list. A report or block removes that film here; removing it in Settings brings it back.
  private func reconcileDiscovery() {
    guard discovery, !syncingFeed, collection != nil else { return }
    let source = live ? store.discoveryVideos : store.shortsDiscoveryVideos
    let allowed = Set(source.map(\.id))
    let known = Set(allVideos.map(\.id))
    let restored = source.filter { !known.contains($0.id) }
    let removed = allVideos.contains { !allowed.contains($0.id) }
    guard removed || !restored.isEmpty else { return }
    syncingFeed = true
    defer { syncingFeed = false }
    let previous = videos.indices.contains(currentIndex) ? videos[currentIndex].id : nil
    allVideos.removeAll { !allowed.contains($0.id) }
    allVideos.append(contentsOf: restored)
    videos = visibleVideos(from: allVideos)
    if let previous, let index = videos.firstIndex(where: { $0.id == previous }) {
      currentIndex = index
    } else {
      currentIndex = min(max(0, currentIndex), max(0, videos.count - 1))
    }
    collection.reloadData()
    if videos.indices.contains(currentIndex), collection.bounds.height > 1 {
      collection.scrollToItem(
        at: IndexPath(item: currentIndex, section: 0), at: .centeredVertically, animated: false)
    }
    selectCurrent()
  }
  private func visibleVideos(from source: [LocalVideo]) -> [LocalVideo] {
    source.filter { video in
      !store.hidesVideo(video, live: live)
        && (searchText.isEmpty
          || (video.title + video.creatorName(profile: store.library.profile))
            .localizedCaseInsensitiveContains(searchText))
    }
  }
  func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int)
    -> Int
  { videos.count }
  func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath)
    -> UICollectionViewCell
  {
    let cell =
      collectionView.dequeueReusableCell(withReuseIdentifier: "page", for: indexPath)
      as! PlaybackPageCell
    cell.cover.load(store.coverURL(videos[indexPath.item]))
    return cell
  }
  func collectionView(
    _ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout,
    sizeForItemAt indexPath: IndexPath
  ) -> CGSize { collectionView.bounds.size }
  func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
    currentIndex = min(
      max(0, Int(round(scrollView.contentOffset.y / max(1, scrollView.bounds.height)))),
      max(0, videos.count - 1))
    selectCurrent()
  }
  func scrollViewWillBeginDragging(_ scrollView: UIScrollView) { pauseIfShort() }
  func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
    if !decelerate { resume() }
  }
  private func selectCurrent() {
    guard let video = current else {
      playback.stop()
      status.text = "No videos found."
      header.arrangedSubviews.forEach { $0.removeFromSuperview() }
      footer.arrangedSubviews.forEach { $0.removeFromSuperview() }
      rail.arrangedSubviews.forEach { $0.removeFromSuperview() }
      header.addArrangedSubview(label("No videos found", 16, .white))
      var find: UIButton!
      find = iconButton(.search, "Search", color: .white) { [weak self] in
        self?.openSearch(from: find)
      }
      header.addArrangedSubview(find)
      if !discovery {
        header.addArrangedSubview(
          iconButton(.close, "Close", color: .white) { [weak self] in self?.dismiss(animated: true)
          })
      }
      return
    }
    attachSurfaceToCurrentCell()
    playback.select(video, url: store.videoURL(video))
    surface.videoLayer.player = playback.player
    store.shortsSocial.prepareComments(for: video)
    Task { await store.recordVideoViewed(video.id) }
    let playingID = video.id
    buildHUD(video)
    refresh()
    if !leavingRoom, videos.contains(where: { $0.id == playingID }) {
      resume()
    }
  }
  private func buildHUD(_ video: LocalVideo) {
    [header, footer, rail, feed].forEach {
      $0.arrangedSubviews.forEach { $0.removeFromSuperview() }
    }
    lastLaneTime = [0, 0, 0]
    clearFloatingLines()
    let creator = CreatorProfile.from(
      video: video, profile: store.library.profile, coverURL: store.coverURL(video))
    let avatar = UIButton(type: .custom)
    let portrait =
      creator.isLocalOwner
      ? store.ownerAvatarImage() : nil
    avatar.setImage(
      portrait ?? UIImage(named: portraitAsset(creator.avatarAsset, personID: creator.id)),
      for: .normal)
    avatar.imageView?.contentMode = .scaleAspectFill
    avatar.rounded(24)
    avatar.widthAnchor.constraint(equalToConstant: 48).isActive = true
    avatar.height(48)
    avatar.accessibilityLabel = "Open \(creator.name)'s profile"
    avatar.addAction(
      UIAction { [weak self] _ in
        guard let self else { return }
        self.showPanel(CreatorController(store: self.store, creator: creator))
      }, for: .touchUpInside)
    if live {
      let name = label(creator.name, 15, .white, title: true)
      name.numberOfLines = 1
      name.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
      header.addArrangedSubview(avatar)
      header.addArrangedSubview(name)
      let following = store.isFollowingCreator(creator.id)
      if following {
        let mark = iconButton(.check, "Following", size: 18) { [weak self] in
          guard let self else { return }
          Task {
            await self.store.toggleCreatorFollow(creator.id)
            self.buildHUD(video)
          }
        }
        if shrinkFollow, !UIAccessibility.isReduceMotionEnabled {
          mark.transform = CGAffineTransform(scaleX: 0.15, y: 0.15)
          UIView.animate(
            withDuration: 0.42, delay: 0, usingSpringWithDamping: 0.62, initialSpringVelocity: 0.8
          ) { mark.transform = .identity }
        }
        shrinkFollow = false
        header.addArrangedSubview(mark)
      } else {
        let follow = actionButton("Follow", tone: .pink, compact: true) { [weak self] in
          guard let self else { return }
          Task {
            let wasFollowing = self.store.isFollowingCreator(creator.id)
            await self.store.toggleCreatorFollow(creator.id)
            self.shrinkFollow = !wasFollowing && self.store.isFollowingCreator(creator.id)
            self.buildHUD(video)
          }
        }
        follow.setContentHuggingPriority(.required, for: .horizontal)
        shrinkFollow = false
        header.addArrangedSubview(follow)
      }
      let spacer = UIView()
      spacer.setContentHuggingPriority(.fittingSizeLevel, for: .horizontal)
      spacer.setContentCompressionResistancePriority(.fittingSizeLevel, for: .horizontal)
      header.addArrangedSubview(spacer)
      header.addArrangedSubview(
        iconButton(.more, "More", color: .white) { [weak self] in self?.showSafety(video) })
    } else {
      rail.addArrangedSubview(avatar)
      header.addArrangedSubview(label("For you", 18, .white, title: true))
      header.addArrangedSubview(UIView())
    }
    if !discovery {
      header.addArrangedSubview(
        iconButton(.close, "Close", color: .white) { [weak self] in self?.dismiss(animated: true) })
    }
    if !live {
      footer.addArrangedSubview(label("@" + creator.name, 18, .white, title: true))
      let desc = label(video.musicDescription, 14, .white)
      desc.numberOfLines = 3
      footer.addArrangedSubview(desc)
    }
    likeButton = counter(.heartOutline, "Like") { [weak self] in
      guard let self else { return }
      let id = video.id
      if self.live {
        self.floatHeart()
        self.store.shortsSocial.addLiveLike(id)
        return
      }
      let turningOn = !self.store.shortsSocial.liked.contains(id)
      Task {
        guard await self.store.shortsSocial.toggleLike(id) else {
          self.refresh()
          return
        }
        if turningOn { self.floatHeart() }
        self.popLike = true
        self.refresh()
      }
    }
    shareButton = counter(.share, "Share") { [weak self] in
      self?.showVideoShare(video)
    }
    if live {
      footer.axis = .horizontal
      footer.alignment = .center
      footer.spacing = 2
      pack(likeButton)
      pack(shareButton)
      likeButton?.hideCount()
      shareButton?.hideCount()
      footer.addArrangedSubview(danmakuField)
      let send = iconButton(.send, "Send", color: .white, size: 32) { [weak self] in
        self?.sendDanmaku()
      }
      pack(send)
      footer.addArrangedSubview(send)
      let gift = iconButton(.gift, "Send a gift", color: .white, size: 32) { [weak self] in
        guard let self else { return }
        self.presentGifts(for: video)
      }
      pack(gift)
      let pair = stack(axis: .horizontal, spacing: 0)
      pair.alignment = .center
      pair.setContentHuggingPriority(.required, for: .horizontal)
      pair.setContentCompressionResistancePriority(.required, for: .horizontal)
      if let likeButton { pair.addArrangedSubview(likeButton) }
      pair.addArrangedSubview(gift)
      footer.addArrangedSubview(pair)
      if let shareButton { footer.addArrangedSubview(shareButton) }
    } else {
      footer.axis = .vertical
      footer.spacing = 9
      commentButton = counter(.comment, "Comments") { [weak self] in
        self?.openComments(floating: false)
      }
      saveButton = counter(.star, "Save") { [weak self] in
        guard let self else { return }
        let id = video.id
        let wasSaved = self.store.collectionVideos.first(where: { $0.id == id })?.isSaved == true
        Task {
          await self.store.toggleSaved(id)
          let saved = self.store.collectionVideos.first(where: { $0.id == id })?.isSaved == true
          guard saved != wasSaved else {
            self.refresh()
            return
          }
          self.popSave = true
          self.refresh()
        }
      }
      for b in [likeButton, commentButton, saveButton, shareButton].compactMap({ $0 }) {
        rail.addArrangedSubview(b)
      }
      let soundButton = iconButton(
        playback.isMuted ? .mutedIvory : .speakerIvory,
        playback.isMuted ? "Sound off" : "Sound on", color: .white, size: 32
      ) { [weak self] in
        self?.playback.toggleMuted()
        self?.buildHUD(video)
      }
      rail.addArrangedSubview(soundButton)
      rail.addArrangedSubview(
        iconButton(.more, "More", color: .white, size: 32) { [weak self] in
          self?.showSafety(video)
        })
    }
    applyCommentChrome()
  }
  /// Pins a bottom-bar control to the icon width so the field keeps the extra space.
  private func pack(_ view: UIView?) {
    guard let view else { return }
    for constraint in view.constraints where constraint.firstAttribute == .width
      && constraint.relation == .greaterThanOrEqual && constraint.secondItem == nil
    {
      constraint.isActive = false
    }
    view.widthAnchor.constraint(equalToConstant: 36).isActive = true
    view.setContentHuggingPriority(.required, for: .horizontal)
    view.setContentCompressionResistancePriority(.required, for: .horizontal)
    (view as? StudioCounter)?.compressCount()
  }
  private func counter(_ icon: TotiIcon, _ name: String, action: @escaping () -> Void) -> StudioCounter {
    let button = StudioCounter(name: name)
    button.setIcon(icon.image(.white, size: 32))
    button.addAction(UIAction { _ in action() }, for: .touchUpInside)
    return button
  }
  private func setCaption(_ button: StudioCounter?, _ text: String, selected: Bool = false) {
    button?.setCount(text, selected: selected)
  }
  private func setReaction(
    _ button: StudioCounter?, outline: TotiIcon, filled: TotiIcon, count: String, selected: Bool,
    pop: Bool
  ) {
    guard let button else { return }
    applyIcon(button, selected ? filled : outline, count, selected)
    guard pop, !UIAccessibility.isReduceMotionEnabled else { return }
    button.iconView.transform =
      selected
      ? CGAffineTransform(scaleX: 0.15, y: 0.15) : CGAffineTransform(scaleX: 1.2, y: 1.2)
    UIView.animate(
      withDuration: 0.42, delay: 0, usingSpringWithDamping: 0.52, initialSpringVelocity: 0.8,
      options: [.allowUserInteraction, .beginFromCurrentState]
    ) {
      button.iconView.transform = .identity
    }
  }
  private func applyIcon(_ button: StudioCounter, _ icon: TotiIcon, _ count: String, _ selected: Bool) {
    button.setIcon(icon.image(size: 32))
    button.setCount(count, selected: selected)
  }
  func textFieldShouldReturn(_ textField: UITextField) -> Bool {
    sendDanmaku()
    return false
  }
  func textField(
    _ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String
  ) -> Bool {
    guard live, textField === danmakuField, textField.markedTextRange == nil else { return true }
    let current = textField.text ?? ""
    guard let span = Range(range, in: current) else { return true }
    let next = current.replacingCharacters(in: span, with: string)
    if next.count <= 50 || string.isEmpty { return true }
    let base = current.replacingCharacters(in: span, with: "")
    let room = 50 - base.count
    guard room > 0 else { return false }
    textField.text = base + String(string.prefix(room))
    return false
  }
  @objc private func tapVideo() {
    if danmakuField.isFirstResponder {
      danmakuField.resignFirstResponder()
      return
    }
    if commentsOpen {
      closeComments()
      return
    }
    if playback.error != nil {
      playback.stop()
      selectCurrent()
      return
    }
    if live { return }
    pause.alpha = 1
    playback.togglePlayback()
    updatePlayback()
    UIView.animate(withDuration: 0.3, delay: 2, options: [.allowUserInteraction]) { [weak self] in
      self?.pause.alpha = 0
    }
  }
  private func updatePlayback() {
    surface.videoLayer.player = playback.player
    status.text = playback.error.map { $0 + " Tap the video to retry." }
    playback.isLoading ? spinner.startAnimating() : spinner.stopAnimating()
    pause.setImage(
      (playback.isPlaying ? TotiIcon.pause : .play).image(.white, size: 52), for: .normal)
  }
  private func compactVideoFrame(in full: CGRect) -> CGRect {
    let height = min(max(full.height * 0.42, 230), full.height * 0.52)
    return CGRect(x: full.minX, y: full.minY, width: full.width, height: height)
  }
  private func commentPanelFrame(video: CGRect, full: CGRect) -> CGRect {
    let y = video.maxY - 14
    return CGRect(x: full.minX, y: y, width: full.width, height: max(0, full.maxY - y))
  }
  /// Home shorts sit under the tab dock; the sheet has to live on that parent so it can cover Live / Voice / Chats / Me.
  private func discoveryTabHost() -> TotiTabController? {
    guard discovery else { return nil }
    var node: UIViewController? = parent
    while let current = node {
      if let tabs = current as? TotiTabController { return tabs }
      node = current.parent
    }
    return nil
  }
  private func commentOverlay() -> UIView {
    discoveryTabHost()?.view ?? view
  }
  private func commentStageFrame() -> CGRect {
    let overlay = commentOverlay()
    guard let window = view.window else { return overlay.bounds }
    return overlay.convert(window.bounds, from: window)
  }
  private func attachSurfaceToCurrentCell() {
    guard !commentsOpen else { return }
    let index = IndexPath(item: currentIndex, section: 0)
    collection.layoutIfNeeded()
    if collection.cellForItem(at: index) == nil, videos.indices.contains(currentIndex) {
      collection.scrollToItem(at: index, at: .centeredVertically, animated: false)
      collection.layoutIfNeeded()
    }
    guard let cell = collection.cellForItem(at: index) else { return }
    if surface.superview !== cell.contentView {
      surface.removeFromSuperview()
      cell.contentView.addSubview(surface)
      surface.pin(to: cell.contentView)
    }
    surface.videoLayer.player = playback.player
  }
  private func applyCommentChrome() {
    let hidden = commentsOpen
    for item in [header, footer, rail, feed] {
      item.alpha = hidden ? 0 : 1
      item.isUserInteractionEnabled = !hidden
    }
    pause.isUserInteractionEnabled = !hidden
    if hidden { pause.alpha = 0 }
  }
  private func openComments(floating: Bool) {
    guard let video = current, commentPanel == nil, !commentsOpen, presentedViewController == nil,
      activeSearch == nil
    else { return }
    let panel = CommentsController(store: store, video: video, floating: floating)
    let host = CommentSheet()
    host.backgroundColor = TotiTheme.background
    let bar = commentBar(title: floating ? "On the video" : "Comments")
    panel.view.translatesAutoresizingMaskIntoConstraints = false
    bar.translatesAutoresizingMaskIntoConstraints = false
    host.addSubview(panel.view)
    host.addSubview(bar)
    NSLayoutConstraint.activate([
      bar.topAnchor.constraint(equalTo: host.topAnchor),
      bar.leadingAnchor.constraint(equalTo: host.leadingAnchor),
      bar.trailingAnchor.constraint(equalTo: host.trailingAnchor),
      bar.heightAnchor.constraint(equalToConstant: 48),
      panel.view.topAnchor.constraint(equalTo: bar.bottomAnchor),
      panel.view.leadingAnchor.constraint(equalTo: host.leadingAnchor),
      panel.view.trailingAnchor.constraint(equalTo: host.trailingAnchor),
      panel.view.bottomAnchor.constraint(equalTo: host.bottomAnchor),
    ])
    let full = commentStageFrame()
    let videoFrame = compactVideoFrame(in: full)
    let backdrop = UIView(frame: full)
    backdrop.backgroundColor = .black
    let stage = UIView(frame: full)
    stage.backgroundColor = .black
    stage.clipsToBounds = true
    stage.layer.maskedCorners = [.layerMinXMaxYCorner, .layerMaxXMaxYCorner]
    stage.isAccessibilityElement = true
    stage.accessibilityLabel = "Close comments"
    stage.accessibilityTraits = .button
    stage.addGestureRecognizer(
      UITapGestureRecognizer(target: self, action: #selector(closeCommentsTap)))
    commentsOpen = true
    onCommentChrome?(true)
    host.frame = commentPanelFrame(video: videoFrame, full: full).offsetBy(dx: 0, dy: full.height)
    if let tabs = discoveryTabHost() {
      tabs.attachCommentOverlay(panel: panel, backdrop: backdrop, stage: stage, host: host)
    } else {
      addChild(panel)
      view.insertSubview(backdrop, aboveSubview: collection)
      view.insertSubview(stage, aboveSubview: backdrop)
      view.addSubview(host)
      panel.didMove(toParent: self)
    }
    placeForFrameAnimation(surface, in: stage)
    surface.videoLayer.player = playback.player
    placeForFrameAnimation(dim, in: stage)
    host.layoutIfNeeded()
    commentBackdrop = backdrop
    videoStage = stage
    commentHost = host
    commentPanel = panel
    commentTransition = true
    collection.isScrollEnabled = false
    let motion = !UIAccessibility.isReduceMotionEnabled
    UIView.animate(
      withDuration: motion ? 0.46 : 0.01, delay: 0, usingSpringWithDamping: 0.9,
      initialSpringVelocity: 0.35, options: [.allowUserInteraction, .curveEaseInOut]
    ) {
      stage.frame = videoFrame
      stage.layer.cornerRadius = 18
      self.surface.frame = stage.bounds
      self.dim.frame = stage.bounds
      self.shade.frame = stage.bounds
      host.frame = self.commentPanelFrame(video: videoFrame, full: full)
      self.applyCommentChrome()
    } completion: { _ in
      self.commentTransition = false
      self.surface.frame = stage.bounds
      self.dim.frame = stage.bounds
      self.shade.frame = stage.bounds
      self.view.layoutIfNeeded()
      self.keepPlayingWithComments()
    }
    keepPlayingWithComments()
    DispatchQueue.main.async { [weak self] in self?.keepPlayingWithComments() }
  }
  private func placeForFrameAnimation(_ child: UIView, in host: UIView) {
    child.removeFromSuperview()
    child.translatesAutoresizingMaskIntoConstraints = true
    child.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    child.frame = host.bounds
    host.addSubview(child)
  }
  private func keepPlayingWithComments() {
    guard view.window != nil else { return }
    playback.setActive(true)
  }
  private func commentBar(title: String) -> UIView {
    let row = UIView()
    row.backgroundColor = TotiTheme.background
    let grabber = UIView()
    grabber.backgroundColor = TotiTheme.plum.withAlphaComponent(0.28)
    grabber.layer.cornerRadius = 2
    grabber.translatesAutoresizingMaskIntoConstraints = false
    let titleLabel = label(title, 17, TotiTheme.ink, title: true)
    titleLabel.textAlignment = .center
    titleLabel.translatesAutoresizingMaskIntoConstraints = false
    let close = iconButton(.close, "Close") { [weak self] in self?.closeComments() }
    row.addSubview(grabber)
    row.addSubview(titleLabel)
    row.addSubview(close)
    NSLayoutConstraint.activate([
      grabber.topAnchor.constraint(equalTo: row.topAnchor, constant: 4),
      grabber.centerXAnchor.constraint(equalTo: row.centerXAnchor),
      grabber.widthAnchor.constraint(equalToConstant: 40),
      grabber.heightAnchor.constraint(equalToConstant: 4),
      close.trailingAnchor.constraint(equalTo: row.trailingAnchor, constant: -8),
      close.bottomAnchor.constraint(equalTo: row.bottomAnchor, constant: -2),
      titleLabel.leadingAnchor.constraint(equalTo: row.leadingAnchor, constant: 48),
      titleLabel.trailingAnchor.constraint(equalTo: close.leadingAnchor, constant: -8),
      titleLabel.centerYAnchor.constraint(equalTo: close.centerYAnchor),
    ])
    row.addGestureRecognizer(
      UIPanGestureRecognizer(target: self, action: #selector(dragComments(_:))))
    return row
  }
  @objc private func closeCommentsTap() { closeComments() }
  @objc private func dragComments(_ gesture: UIPanGestureRecognizer) {
    guard commentsOpen, !commentClosing, let stage = videoStage, let host = commentHost else {
      return
    }
    let full = commentStageFrame()
    let restVideo = compactVideoFrame(in: full)
    let restPanel = commentPanelFrame(video: restVideo, full: full)
    let drop = max(0, gesture.translation(in: commentOverlay()).y)
    switch gesture.state {
    case .began:
      commentTransition = true
    case .changed:
      host.frame = restPanel.offsetBy(dx: 0, dy: drop)
      var grown = restVideo
      grown.size.height += min(drop * 0.35, full.height - restVideo.height)
      stage.frame = grown
      surface.frame = stage.bounds
      dim.frame = stage.bounds
      shade.frame = stage.bounds
    case .ended, .cancelled:
      if drop > 110 || gesture.velocity(in: view).y > 800 {
        commentTransition = false
        closeComments()
      } else {
        let motion = !UIAccessibility.isReduceMotionEnabled
        UIView.animate(
          withDuration: motion ? 0.32 : 0.01, delay: 0, usingSpringWithDamping: 0.86,
          initialSpringVelocity: 0.4, options: [.allowUserInteraction]
        ) {
          stage.frame = restVideo
          host.frame = restPanel
          self.surface.frame = stage.bounds
          self.dim.frame = stage.bounds
          self.shade.frame = stage.bounds
        } completion: { _ in
          self.commentTransition = false
        }
      }
    default:
      break
    }
  }
  private func closeComments(animated: Bool = true) {
    guard commentsOpen, !commentClosing, let stage = videoStage, let host = commentHost,
      let panel = commentPanel
    else { return }
    commentClosing = true
    commentTransition = true
    let full = commentStageFrame()
    let finish = { [weak self] in
      guard let self else { return }
      self.surface.removeFromSuperview()
      self.dim.removeFromSuperview()
      self.view.insertSubview(self.dim, aboveSubview: self.collection)
      self.dim.frame = self.coverFrame()
      stage.removeFromSuperview()
      panel.willMove(toParent: nil)
      panel.view.removeFromSuperview()
      panel.removeFromParent()
      host.removeFromSuperview()
      self.commentBackdrop?.removeFromSuperview()
      self.videoStage = nil
      self.commentHost = nil
      self.commentPanel = nil
      self.commentBackdrop = nil
      self.commentsOpen = false
      self.onCommentChrome?(false)
      self.commentClosing = false
      self.commentTransition = false
      self.collection.isScrollEnabled = true
      self.applyCommentChrome()
      self.attachSurfaceToCurrentCell()
      self.view.setNeedsLayout()
    }
    let motion = animated && !UIAccessibility.isReduceMotionEnabled
    if !animated {
      finish()
      return
    }
    UIView.animate(
      withDuration: motion ? 0.38 : 0.01, delay: 0, usingSpringWithDamping: 0.92,
      initialSpringVelocity: 0.3, options: [.allowUserInteraction, .curveEaseInOut]
    ) {
      stage.frame = full
      stage.layer.cornerRadius = 0
      self.surface.frame = stage.bounds
      self.dim.frame = stage.bounds
      self.shade.frame = stage.bounds
      host.frame.origin.y = full.maxY
      for item in [self.header, self.footer, self.rail, self.feed] {
        item.alpha = 1
        item.isUserInteractionEnabled = true
      }
      self.pause.isUserInteractionEnabled = true
    } completion: { _ in finish() }
  }
  /// The gift page covers the lower part of the room. The film keeps playing behind it.
  private func presentGifts(for video: LocalVideo) {
    let gifts = GiftsController(store: store, roomID: video.id.uuidString)
    gifts.onSent = { [weak self] gift, count in
      guard let self else { return }
      GiftBurst.show(gift: gift, quantity: count, in: self.view)
    }
    presentScreen(gifts)
    gifts.onDismiss = { [weak self] in
      guard let self else { return }
      if let current = self.current, self.store.hidesVideo(current, live: self.live) {
        if self.live || !self.discovery {
          self.leavingRoom = true
          self.playback.stop()
          self.suspend()
          (self.navigationController ?? self).dismiss(animated: true)
        } else {
          self.reconcileDiscovery()
          self.resume()
        }
        return
      }
      guard !self.leavingRoom else { return }
      self.resume()
    }
  }
  private func showPanel(_ controller: TotiScreen) {
    pauseIfShort()
    presentScreen(controller)
    controller.onDismiss = { [weak self] in
      guard let self else { return }
      if let video = self.current, self.store.hidesVideo(video, live: self.live) {
        if self.live || !self.discovery {
          self.leavingRoom = true
          self.playback.stop()
          self.suspend()
          (self.navigationController ?? self).dismiss(animated: true)
        } else {
          self.reconcileDiscovery()
          self.resume()
        }
        return
      }
      guard !self.leavingRoom else { return }
      self.resume()
    }
  }
  private func showSafety(_ video: LocalVideo) {
    let creator = CreatorProfile.from(
      video: video, profile: store.library.profile, coverURL: store.coverURL(video))
    let safety = SafetyController(
      store: store,
      target: ContentSafetyTarget(
        id: video.id.uuidString, title: video.title, kind: live ? .live : .shortVideo,
        creator: creator))
    if let clip = video.bundledClip {
      safety.recordingInformation = "Recorded music session · " + clip.creator + " / Pexels. "
        + (clip.hasOriginalAudio ? "Original audio included." : "This recording has no audio track.")
    }
    safety.onResolved = { [weak self] in
      guard let self else { return }
      if self.live || !self.discovery {
        self.leavingRoom = true
        self.playback.stop()
        self.suspend()
        (self.navigationController ?? self).dismiss(animated: true)
      } else {
        self.reconcileDiscovery()
        self.resume()
      }
    }
    pauseIfShort()
    presentScreen(safety)
    safety.onDismiss = { [weak self] in
      guard let self, !self.leavingRoom else { return }
      if self.discovery { self.reconcileDiscovery() }
      if let video = self.current, self.store.hidesVideo(video, live: self.live) { return }
      self.resume()
    }
  }
  private func showVideoShare(_ video: LocalVideo) {
    guard !sharing else { return }
    sharing = true
    pauseIfShort()
    let address = "toti://\(live ? "live" : "shorts")/\(video.id.uuidString)"
    let invitation = live ? "Join this music session" : "Listen to this session"
    showContentShare(
      text: "\(invitation): \(video.title)\n\(address)", address: address,
      onShared: { [weak self] in
        guard let self, !self.live else { return }
        Task { [weak self] in
          guard let self else { return }
          if !(await self.store.shortsSocial.recordCompletedShare(for: video.id)) {
            self.message("Your share count could not be saved.")
          }
        }
      },
      onClose: { [weak self] in
        self?.sharing = false
        self?.resume()
      })
  }
  /// A short video pauses for a sheet or a control. A live room keeps playing.
  private func pauseIfShort() {
    guard !live else { return }
    suspend()
  }
  private func suspend() {
    playback.setActive(false)
    ticker?.cancel()
    ticker = nil
    clearFloatingLines()
  }
  private func clearFloatingLines() {
    floatingLabels.forEach {
      $0.layer.removeAllAnimations()
      $0.removeFromSuperview()
    }
    floatingLabels = []
    ownLiveLine = nil
    voicedLine?.layer.removeAllAnimations()
    voicedLine?.removeFromSuperview()
    voicedLine = nil
    voicedLineAt = 0
  }
  private func dropReportedLines() {
    floatingLabels.filter { line in
      guard let line = line as? ReportTarget else { return false }
      return store.isCommentReported(line.reportID)
    }.forEach { line in
      line.layer.removeAllAnimations()
      line.removeFromSuperview()
    }
    floatingLabels.removeAll { line in
      guard let line = line as? ReportTarget else { return false }
      return store.isCommentReported(line.reportID)
    }
    if let voicedLine, store.isCommentReported(voicedLine.reportID) {
      voicedLine.layer.removeAllAnimations()
      voicedLine.removeFromSuperview()
      self.voicedLine = nil
    }
  }
  private func resume() {
    guard !leavingRoom, appeared, current != nil,
      UIApplication.shared.applicationState == .active
    else { return }
    if !live, sharing || presentedViewController != nil || activeSearch != nil { return }
    playback.setActive(true)
    guard ticker == nil else { return }
    ticker = Task { [weak self] in
      while !Task.isCancelled {
        do { try await Task.sleep(for: .seconds(1)) } catch { break }
        guard let self, let video = self.current, self.playback.isPlaying else { continue }
        let burst = self.live ? Int.random(in: 1...3) : Int.random(in: 1...5)
        for _ in 0..<burst {
          let lines =
            MusicDiscussionContent.lines(for: video).map { ($0.name, $0.text) }
            + MusicCommentScript.lines
          guard !lines.isEmpty else { continue }
          let chosen = lines[self.bulletSequence % lines.count]
          let line = (name: chosen.0, text: chosen.1)
          self.bulletSequence += 1
          if self.live {
            self.fly(line.name + ": " + line.text, reportName: line.name, reportText: line.text)
          } else if self.store.shortsSocial.bulletsEnabled {
            self.fly(line.text)
          }
        }
      }
    }
  }
  private func sendDanmaku() {
    let text = (danmakuField.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    let limit = live ? 50 : 80
    guard !text.isEmpty, text.count <= limit, CreationValidation.isEnglish(text) else {
      message(
        live
          ? "Write up to 50 characters in English."
          : "Write up to 80 characters in English.")
      return
    }
    danmakuField.text = ""
    if live {
      fly("You: " + text, own: true, reportName: "You", reportText: text)
      return
    }
    let line = "You: " + text
    if UIAccessibility.isReduceMotionEnabled {
      showStillLine(line)
    } else {
      fly(line, own: true)
    }
  }
  private func showStillLine(_ text: String) {
    let pill = label(text, 15, .white)
    pill.numberOfLines = 1
    pill.backgroundColor = UIColor.black.withAlphaComponent(0.45)
    pill.layer.cornerRadius = 10
    pill.clipsToBounds = true
    pill.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(pill)
    NSLayoutConstraint.activate([
      pill.leadingAnchor.constraint(equalTo: footer.leadingAnchor),
      pill.bottomAnchor.constraint(equalTo: footer.topAnchor, constant: -8),
      pill.widthAnchor.constraint(lessThanOrEqualTo: view.widthAnchor, multiplier: 0.72),
    ])
    UIView.animate(withDuration: 0.3, delay: 1.6, options: [.curveEaseOut, .allowUserInteraction]) {
      pill.alpha = 0
    } completion: { _ in pill.removeFromSuperview() }
  }
  private func floatHeart() {
    let size: CGFloat = 26
    let origin: CGPoint
    if let likeButton, likeButton.window != nil {
      let frame = likeButton.convert(likeButton.bounds, to: view)
      origin = CGPoint(x: frame.midX - size / 2, y: frame.minY - size - 4)
    } else {
      origin = CGPoint(
        x: view.bounds.width - 78, y: view.bounds.height - view.safeAreaInsets.bottom - 96)
    }
    let heart = UIImageView(image: TotiIcon.heartFill.image(size: size))
    heart.isUserInteractionEnabled = false
    heart.frame = CGRect(origin: origin, size: CGSize(width: size, height: size))
    view.addSubview(heart)
    let drift = CGFloat.random(in: -28...16)
    guard !UIAccessibility.isReduceMotionEnabled else {
      UIView.animate(withDuration: 0.25, animations: { heart.alpha = 0 }) { _ in
        heart.removeFromSuperview()
      }
      return
    }
    UIView.animate(
      withDuration: 0.95, delay: 0, options: [.curveEaseOut, .allowUserInteraction],
      animations: {
        heart.transform = CGAffineTransform(translationX: drift, y: -128).scaledBy(x: 1.12, y: 1.12)
        heart.alpha = 0
      }
    ) { _ in heart.removeFromSuperview() }
  }
  private func fly(
    _ text: String, own: Bool = false, reportName: String? = nil, reportText: String? = nil
  ) {
    if live {
      showLiveLine(text, own: own, reportName: reportName, reportText: reportText)
      return
    }
    guard !commentsOpen else { return }
    let reportable = live && reportName != nil && reportName != "You" && reportText != nil
    if !own, UIAccessibility.isReduceMotionEnabled || UIAccessibility.isVoiceOverRunning {
      if reportable {
        showReportableStillLine(text, name: reportName ?? "", body: reportText ?? "")
      }
      return
    }
    if !own {
      guard floatingLabels.count < 14 else { return }
    }
    let now = CACurrentMediaTime()
    let lane = lastLaneTime.firstIndex(where: { $0 <= now }) ?? (own ? 0 : -1)
    guard lane >= 0 else { return }
    let l: UILabel
    if reportable {
      let line = ReportableLine(
        text: text, name: reportName ?? "", body: reportText ?? "", id: UUID().uuidString)
      line.accessibilityCustomActions = [
        UIAccessibilityCustomAction(name: "Report comment") { [weak self, weak line] _ in
          guard let self, let line else { return false }
          self.openLineReport(id: line.reportID, name: line.reportName, text: line.reportText)
          return true
        },
      ]
      l = line
    } else {
      l = label(text, 15, .white)
      l.numberOfLines = 1
      l.isAccessibilityElement = false
    }
    l.layer.shadowColor = UIColor.black.cgColor
    l.layer.shadowOpacity = 0.8
    l.layer.shadowRadius = 2
    l.layer.shadowOffset = .zero
    l.sizeToFit()
    let width = min(l.bounds.width, 600)
    l.frame = CGRect(
      x: view.bounds.width + 8, y: view.safeAreaInsets.top + 80 + CGFloat(lane) * 29, width: width,
      height: 25)
    lineHost.addSubview(l)
    floatingLabels.append(l)
    lastLaneTime[lane] = now + Double(width + 36) / 96
    UIView.animate(
      withDuration: Double(view.bounds.width + width + 16) / 96, delay: 0,
      options: [.curveLinear, .allowUserInteraction]
    ) {
      l.frame.origin.x = -width - 8
    } completion: { [weak self, weak l] _ in
      l?.removeFromSuperview()
      self?.floatingLabels.removeAll { $0 === l }
    }
  }
  /// Live lines stay at the lower left, just above the field. The newest line sits closest to it.
  private func showLiveLine(
    _ text: String, own: Bool = false, reportName: String? = nil, reportText: String? = nil
  ) {
    guard !commentsOpen else { return }
    let reportable = !own && reportName != nil && reportName != "You" && reportText != nil
    if !own, UIAccessibility.isVoiceOverRunning {
      if reportable {
        showReportableStillLine(text, name: reportName ?? "", body: reportText ?? "")
      }
      return
    }
    let name = reportName ?? ""
    let body = reportText ?? text
    let bubble = LiveBubble(
      name: name, body: body, id: UUID().uuidString, reportable: reportable)
    if reportable {
      bubble.accessibilityCustomActions = [
        UIAccessibilityCustomAction(name: "Report comment") { [weak self, weak bubble] _ in
          guard let self, let bubble else { return false }
          self.openLineReport(
            id: bubble.reportID, name: bubble.reportName, text: bubble.reportText)
          return true
        },
      ]
    }
    lineHost.addSubview(bubble)
    floatingLabels.append(bubble)
    if own { ownLiveLine = bubble }
    layoutLiveLines()
    guard bubble.superview != nil else { return }
    guard !UIAccessibility.isReduceMotionEnabled else { return }
    bubble.alpha = 0
    UIView.animate(withDuration: 0.15, delay: 0, options: [.allowUserInteraction]) {
      bubble.alpha = 1
    }
  }
  /// Newest lines sit above the field. Each bubble keeps the height of its words.
  /// The column stays within one third of the screen and keeps at most seven bubbles.
  private func layoutLiveLines() {
    guard live else { return }
    let fieldFrame = danmakuField.convert(danmakuField.bounds, to: lineHost)
    guard fieldFrame.width > 40, fieldFrame.minY > 40, lineHost.bounds.height > 1 else { return }
    let limit = lineHost.bounds.height / 3
    let gap: CGFloat = 6
    let bubbles = floatingLabels.compactMap { $0 as? LiveBubble }
    let visible = Array(bubbles.reversed().prefix(7))
    var y = fieldFrame.minY - 8
    let floorY = y - limit
    var kept = Set<ObjectIdentifier>()
    for bubble in visible {
      let height = bubble.preferredHeight(maxWidth: fieldFrame.width)
      let width = bubble.preferredWidth(maxWidth: fieldFrame.width)
      let nextY = y - height
      if nextY < floorY, !kept.isEmpty { break }
      y = nextY
      bubble.frame = CGRect(x: fieldFrame.minX, y: y, width: width, height: height)
      bubble.layer.cornerRadius = min(16, height / 2)
      y -= gap
      kept.insert(ObjectIdentifier(bubble))
    }
    floatingLabels.removeAll { view in
      guard let bubble = view as? LiveBubble else { return false }
      if kept.contains(ObjectIdentifier(bubble)) { return false }
      bubble.removeFromSuperview()
      return true
    }
    if ownLiveLine?.superview == nil { ownLiveLine = nil }
    if let voicedLine {
      let height = voicedLine.preferredHeight(maxWidth: fieldFrame.width)
      let width = voicedLine.preferredWidth(maxWidth: fieldFrame.width)
      voicedLine.frame = CGRect(
        x: fieldFrame.minX, y: fieldFrame.minY - 8 - height, width: width, height: height)
      voicedLine.layer.cornerRadius = min(16, height / 2)
    }
  }
  /// One still line while motion is reduced or VoiceOver is on, so Report comment stays reachable.
  private func showReportableStillLine(_ text: String, name: String, body: String) {
    let now = CACurrentMediaTime()
    if voicedLine != nil, now - voicedLineAt < 4 { return }
    voicedLine?.removeFromSuperview()
    let line = LiveBubble(name: name, body: body, id: UUID().uuidString, reportable: true)
    line.accessibilityCustomActions = [
      UIAccessibilityCustomAction(name: "Report comment") { [weak self, weak line] _ in
        guard let self, let line else { return false }
        self.openLineReport(id: line.reportID, name: line.reportName, text: line.reportText)
        return true
      },
    ]
    lineHost.addSubview(line)
    voicedLine = line
    voicedLineAt = now
    layoutLiveLines()
  }
  @objc private func reportFloatingLine(_ gesture: LinePress) {
    guard gesture.state == .began, !gesture.reportID.isEmpty else { return }
    openLineReport(id: gesture.reportID, name: gesture.reportName, text: gesture.reportText)
  }
  private func openLineReport(id: String, name: String, text: String) {
    guard name != "You", presentedViewController == nil else { return }
    showPanel(
      SafetyController(
        store: store,
        target: .comment(id: id, name: name, text: text),
        reporting: true))
  }
  deinit { ticker?.cancel() }
}

private protocol ReportTarget: AnyObject {
  var reportID: String { get }
  var reportName: String { get }
  var reportText: String { get }
}

/// One live line: a lime name and white words. Extra words wrap onto a second or third line.
private final class LiveBubble: UIView, ReportTarget {
  let reportID: String
  let reportName: String
  let reportText: String
  private let textLabel = UILabel()
  private let padX: CGFloat = 10
  private let padY: CGFloat = 6

  init(name: String, body: String, id: String, reportable: Bool) {
    reportID = reportable ? id : ""
    reportName = name
    reportText = body
    super.init(frame: .zero)
    backgroundColor = .clear
    isOpaque = false
    layer.cornerCurve = .continuous
    layer.borderWidth = 1
    layer.borderColor = UIColor.white.withAlphaComponent(0.85).cgColor
    clipsToBounds = true
    isUserInteractionEnabled = reportable
    textLabel.numberOfLines = 3
    textLabel.lineBreakMode = .byWordWrapping
    textLabel.adjustsFontForContentSizeCategory = true
    textLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
    textLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)
    textLabel.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
    textLabel.isAccessibilityElement = false
    textLabel.attributedText = LiveBubble.caption(name: name, body: body)
    textLabel.translatesAutoresizingMaskIntoConstraints = false
    addSubview(textLabel)
    let bottom = textLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -padY)
    bottom.priority = .defaultHigh
    NSLayoutConstraint.activate([
      textLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: padX),
      textLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -padX),
      textLabel.topAnchor.constraint(equalTo: topAnchor, constant: padY),
      bottom,
    ])
    isAccessibilityElement = true
    accessibilityLabel = name.isEmpty ? body : name + ", " + body
    if reportable { accessibilityHint = "Report comment" }
  }

  required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }

  func preferredHeight(maxWidth: CGFloat) -> CGFloat {
    let width = max(1, preferredWidth(maxWidth: maxWidth) - padX * 2)
    textLabel.preferredMaxLayoutWidth = width
    textLabel.lineBreakMode = .byWordWrapping
    textLabel.numberOfLines = 3
    let capped = textLabel.sizeThatFits(CGSize(width: width, height: 1200))
    textLabel.numberOfLines = 0
    let full = textLabel.sizeThatFits(CGSize(width: width, height: 1200))
    if full.height <= capped.height + 1 {
      textLabel.numberOfLines = 3
      return max(28, ceil(capped.height) + padY * 2)
    }
    return max(28, ceil(full.height) + padY * 2)
  }

  func preferredWidth(maxWidth: CGFloat) -> CGFloat {
    let cap = max(44, maxWidth)
    let single = ceil(unwrappedWidth()) + padX * 2
    return min(cap, max(44, single))
  }

  private func unwrappedWidth() -> CGFloat {
    guard let text = textLabel.attributedText, text.length > 0 else { return 0 }
    let rect = text.boundingRect(
      with: CGSize(width: 10000, height: 200),
      options: [.usesLineFragmentOrigin, .usesFontLeading],
      context: nil)
    return ceil(rect.width) + 2
  }

  private static func caption(name: String, body: String) -> NSAttributedString {
    let style = NSMutableParagraphStyle()
    style.lineBreakMode = .byWordWrapping
    let result = NSMutableAttributedString()
    if !name.isEmpty {
      result.append(
        NSAttributedString(
          string: name,
          attributes: [
            .font: TotiTheme.font(14, title: true),
            .foregroundColor: TotiTheme.coral,
            .paragraphStyle: style,
          ]))
      result.append(
        NSAttributedString(
          string: "  ·  ",
          attributes: [
            .font: TotiTheme.font(14),
            .foregroundColor: UIColor.white.withAlphaComponent(0.72),
            .paragraphStyle: style,
          ]))
    }
    result.append(
      NSAttributedString(
        string: body,
        attributes: [
          .font: TotiTheme.font(14),
          .foregroundColor: UIColor.white,
          .paragraphStyle: style,
        ]))
    return result
  }
}

/// Hit testing follows the drawn frame. A moving line's model frame is already at the end.
private final class FlyingLineHost: UIView {
  func line(at point: CGPoint) -> ReportTarget? {
    for subview in subviews.reversed() {
      guard let line = subview as? ReportTarget, line.reportID.isEmpty == false else { continue }
      guard subview.alpha > 0.01, !subview.isHidden else { continue }
      let frame = subview.layer.presentation()?.frame ?? subview.frame
      if frame.contains(point) { return line }
    }
    return nil
  }
  override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
    guard !isHidden, alpha > 0.01, isUserInteractionEnabled else { return nil }
    return line(at: point) == nil ? nil : self
  }
}

/// Remembers the line under the finger. The line keeps moving during the press.
private final class LinePress: UILongPressGestureRecognizer {
  var reportID = ""
  var reportName = ""
  var reportText = ""
  override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
    reportID = ""
    reportName = ""
    reportText = ""
    if let host = view as? FlyingLineHost, let point = touches.first?.location(in: host),
      let line = host.line(at: point)
    {
      reportID = line.reportID
      reportName = line.reportName
      reportText = line.reportText
    }
    if let event {
      super.touchesBegan(touches, with: event)
    }
  }
}

private final class ReportableLine: UILabel, ReportTarget {
  let reportID: String
  let reportName: String
  let reportText: String
  init(text: String, name: String, body: String, id: String) {
    reportID = id
    reportName = name
    reportText = body
    super.init(frame: .zero)
    self.text = text
    font = TotiTheme.font(15)
    textColor = .white
    numberOfLines = 1
    isUserInteractionEnabled = true
    isAccessibilityElement = true
    accessibilityLabel = text
    accessibilityHint = "Report comment"
    sizeToFit()
  }
  required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }
}
