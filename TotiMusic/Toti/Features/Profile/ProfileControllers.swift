import PhotosUI
import UIKit
import UniformTypeIdentifiers

final class MeController: StackScreen, UIScrollViewDelegate {
  private enum Collection: Int, CaseIterable {
    case works, liked, saved, drafts, about
    var title: String { ["Works", "Liked", "Saved", "Drafts", "About"][rawValue] }
    var reaction: String? { self == .liked ? "like" : self == .saved ? "save" : nil }
  }
  private var selection = Collection.works
  private var reactionPosts: [LoungePost] = []
  private var reactionCursor: String?
  private var reactionLoading = false
  private var reactionError: String?
  private var collectionRevision = 0
  private var memberCollectionCounts: [String: Int] = [:]
  private var countsLoading = false
  private var collectionRefreshTimer: Timer?
  private let profileHeader = stack(spacing: 18)
  private let body = stack(spacing: 18)
  private let categorySlot = UIView()
  private let categoryChrome = UIView()
  private let categoryWash = StudioCanvas()
  private var categories: StudioChoice?
  private var categoryPins: [NSLayoutConstraint] = []

  override func build() {
    super.build()
    title = "Me"
    navigationItem.leftBarButtonItem = barButton(totiMark())
    navigationItem.rightBarButtonItem = barButton(iconButton(.settings, "Settings") { [weak self] in
      guard let self, self.isAccountContextCurrent else { return }
      self.push(SettingsController(store: self.store))
    })
    scroll.delegate = self
    scroll.accessibilityIdentifier = "profile.me"
    content.addArrangedSubview(profileHeader)
    categorySlot.heightAnchor.constraint(equalToConstant: 44).isActive = true
    content.addArrangedSubview(categorySlot)
    content.addArrangedSubview(body)
    categoryChrome.clipsToBounds = true
    categoryChrome.isHidden = true
    categoryChrome.addSubview(categoryWash)
    scroll.addSubview(categoryChrome)
    let tabs = StudioChoice(items: Collection.allCases.map(\.title), index: selection.rawValue)
    tabs.accessibilityIdentifier = "profile.categories"
    tabs.onChange = { [weak self] next in
      guard let self, self.isAccountContextCurrent else { return }
      guard let collection = Collection(rawValue: next) else { return }
      self.selection = collection
      self.collectionRevision += 1
      self.reactionPosts = []; self.reactionCursor = nil; self.reactionLoading = false; self.reactionError = nil
      self.fillBody()
      self.loadReactions(reset: true)
      self.placeCategoryBar()
    }
    categories = tabs
    placeCategories(pinned: false)
  }

  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    if isViewLoaded {
      refresh()
      refreshCollectionCounts()
      if selection.reaction != nil {
        collectionRevision += 1; reactionLoading = false
        loadReactions(reset: true)
      }
    }
  }
  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    refreshVisibleCollection()
    collectionRefreshTimer?.invalidate()
    collectionRefreshTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
      Task { @MainActor [weak self] in self?.refreshVisibleCollection() }
    }
  }
  override func viewWillDisappear(_ animated: Bool) {
    super.viewWillDisappear(animated)
    collectionRefreshTimer?.invalidate()
    collectionRefreshTimer = nil
  }
  private func refreshVisibleCollection() {
    guard isAccountContextCurrent, store.isOnlineMode, !store.isBusy,
          !reactionLoading, UIApplication.shared.applicationState == .active else { return }
    Task { [weak self] in
      guard let self else { return }
      _ = await self.store.refreshOnline()
      guard self.isAccountContextCurrent, self.viewIfLoaded?.window != nil else { return }
      self.loadReactions(reset: true)
      self.refreshCollectionCounts()
    }
  }
  override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()
    placeCategoryBar()
  }
  func scrollViewDidScroll(_ scrollView: UIScrollView) { placeCategoryBar() }

  override func refresh() {
    guard isViewLoaded, isAccountContextCurrent else { return }
    profileHeader.arrangedSubviews.forEach { $0.removeFromSuperview() }
    let photo = TotiPhoto(size: 92, round: true)
    store.configureOwnerAvatar(photo)
    let owner = store.onlineOwnerProfile ?? CreatorProfile.signedIn(store.library.profile)
    profileHeader.addArrangedSubview(totiProfileIdentityCard(
      photo: photo, name: store.library.profile.displayName,
      biography: store.library.profile.biography, eyebrow: "YOUR MUSIC SPACE",
      metrics: profileMetrics(owner, store: store)))
    if store.isOnlineMode, let review = avatarReviewPreview(store.library.profile) { profileHeader.addArrangedSubview(review) }
    let actions = stack(axis: .horizontal, spacing: 10)
    actions.distribution = .fillEqually
    actions.addArrangedSubview(actionButton("Wallet", icon: .diamond, tone: .coral, compact: true) { [weak self] in
      guard let self, self.isAccountContextCurrent else { return }
      self.push(WalletController(store: self.store))
    })
    profileHeader.addArrangedSubview(actions)
    fillBody()
    placeCategoryBar()
  }

  private func fillBody() {
    updateCollectionTitles()
    body.arrangedSubviews.forEach { $0.removeFromSuperview() }
    if let error = store.onlineReadError { body.addArrangedSubview(label(error, 14, TotiTheme.dangerInk)) }
    if selection == .about {
      body.addArrangedSubview(profilePaper([
        label("Your private corner", 23, TotiTheme.plum, title: true),
        label("Keep your ideas close, and share them when you are ready.", 15, TotiTheme.muted),
        actionButton("My notebook", icon: .notebook) { [weak self] in
          guard let self, self.isAccountContextCurrent else { return }
          self.push(NotebookController(store: self.store))
        },
      ]))
      body.addArrangedSubview(label("Your voice rooms", 22, TotiTheme.plum, title: true))
      for room in store.library.roomDrafts {
        body.addArrangedSubview(actionButton(room.title, icon: .voice) { [weak self] in
          guard let self, self.isAccountContextCurrent else { return }
          self.presentScreen(PartyCreationController(store: self.store, draft: room))
        })
      }
      body.addArrangedSubview(actionButton("Create a voice room", icon: .voice) { [weak self] in
        guard let self, self.isAccountContextCurrent else { return }
        self.presentScreen(PartyCreationController(store: self.store))
      })
      return
    }
    let reactionCollection = selection.reaction != nil
    let posts = selection == .works ? store.loungePosts.filter { $0.author.isLocalOwner && !$0.isEditorial }
      : reactionCollection ? (store.isOnlineMode ? reactionPosts.filter { !store.isCreatorBlocked($0.author.id) && !store.isContentReported($0.id.uuidString, kind: .post) } : (selection == .liked ? store.likedLoungePosts : store.savedLoungePosts)) : store.loungeDrafts
    let editorialCount = selection == .saved ? store.savedEditorialPosts.count : selection == .liked ? store.likedEditorialPosts.count : 0
    if reactionCollection {
      if reactionLoading { body.addArrangedSubview(label("Loading posts…", 14, TotiTheme.muted)) }
      if let error = reactionError { body.addArrangedSubview(label(error, 14, TotiTheme.dangerInk)) }
    }
    if selection == .drafts { body.addArrangedSubview(label(totiProfileCollectionCount(posts.count, noun: "draft", suffix: store.isOnlineMode ? "loaded" : "on this device"), 12, TotiTheme.muted)) }
    if selection == .saved { appendTotiEditorial(to: body, showsHeading: false, workTiles: true, onlySaved: true) }
    if selection == .liked { appendTotiEditorial(to: body, showsHeading: false, workTiles: true, onlyLiked: true) }
    if reactionLoading && posts.isEmpty && editorialCount == 0 { return }
    if reactionError != nil && posts.isEmpty && editorialCount == 0 { return }
    if posts.isEmpty && editorialCount == 0 {
      let title = selection == .liked ? "Find your favorites here." : selection == .saved ? "Keep what inspires you." : selection == .drafts ? "A little room to finish." : "Create your first post."
      let detail = selection == .liked ? "Like a post in Lounge to find it here. Unlike it to remove it from this collection." : selection == .saved ? "Save posts from Lounge to find them here."
        : selection == .drafts ? "Posts you save as drafts stay private until you publish them."
        : "Share a song, a concert moment or an idea. Your published posts will appear here."
      let icon: TotiIcon = selection == .liked ? .heartOutline : selection == .saved ? .bookmark : selection == .drafts ? .notebook : .plus
      let artwork = UIImageView(image: icon.image(TotiTheme.plum, size: 44))
      artwork.contentMode = .scaleAspectFit
      artwork.translatesAutoresizingMaskIntoConstraints = false
      artwork.widthAnchor.constraint(equalToConstant: 52).isActive = true
      artwork.height(52)
      artwork.isAccessibilityElement = false
      let emptyHeader = stack([artwork, label(title, 23, TotiTheme.plum, title: true)], axis: .horizontal, spacing: 14)
      emptyHeader.alignment = .center
      var rows: [UIView] = [emptyHeader, label(detail, 15, TotiTheme.muted)]
      if !reactionCollection { rows.append(writeButton(title: selection == .works ? "Create your first post" : "Write a post")) }
      body.addArrangedSubview(profilePaper(rows))
    } else {
      let tiles = posts.map { post in
        profilePostCard(post, store: store, openAuthor: { [weak self] in
          guard let self else { return }
          openProfileAuthor(post.author, from: self)
        }) { [weak self] in self?.openPost(post) }
      }
      totiProfileGrid(tiles, to: body, singleColumn: traitCollection.preferredContentSizeCategory.isAccessibilityCategory)
      if !reactionCollection { body.addArrangedSubview(writeButton()) }
    }
    if reactionCursor != nil {
      let more = actionButton("Load more " + selection.title.lowercased() + " posts", icon: .refresh) { [weak self] in self?.loadReactions(reset: false) }
      more.isEnabled = !reactionLoading; body.addArrangedSubview(more)
    }
  }
  private func loadReactions(reset: Bool) {
    guard isViewLoaded, isAccountContextCurrent, store.isOnlineMode,
          let kind = selection.reaction, !reactionLoading, reset || reactionCursor != nil else { return }
    if reset { reactionCursor = nil }
    reactionLoading = true; reactionError = nil; fillBody()
    let revision = collectionRevision
    let cursor = reset ? nil : reactionCursor
    Task { [weak self] in
      guard let self, self.isAccountContextCurrent else { return }
      do {
        let page = try await self.store.loadProfileReactionPage(kind: kind, cursor: cursor)
        let editorial = try await TotiBackend.shared.editorialPosts()
        guard self.isAccountContextCurrent, self.collectionRevision == revision, self.selection.reaction == kind else { return }
        if reset { self.reactionPosts = page.posts }
        else { self.reactionPosts += page.posts.filter { post in !self.reactionPosts.contains(where: { $0.id == post.id }) } }
        self.reactionCursor = page.next
        self.reactionLoading = false
        self.store.onlineEditorialPosts = editorial
        self.fillBody()
        self.refreshCollectionCounts()
      } catch {
        guard self.isAccountContextCurrent, self.collectionRevision == revision else { return }
        self.reactionLoading = false
        self.reactionError = "These posts could not be loaded. Check your connection and try again."
        self.fillBody()
      }
    }
  }
  private func updateCollectionTitles() {
    let ownPosts = store.loungePosts.filter { $0.author.isLocalOwner && !$0.isEditorial }.count
    let ownerID = TotiBackend.shared.accountID?.uuidString ?? ""
    let works = store.isOnlineMode ? store.onlineProfileMetric("post_count", creatorID: ownerID) : ownPosts
    let liked = store.isOnlineMode ? memberCollectionCounts["like"] : store.likedLoungePosts.count
    let saved = store.isOnlineMode ? memberCollectionCounts["save"] : store.savedLoungePosts.count
    func title(_ name: String, _ count: Int?, editorial: Int = 0) -> String {
      name + " (" + (count.map { String($0 + editorial) } ?? "—") + ")"
    }
    categories?.updateTitles([
      title("Works", works), title("Liked", liked, editorial: store.likedEditorialPosts.count),
      title("Saved", saved, editorial: store.savedEditorialPosts.count), "Drafts", "About",
    ])
  }
  private func refreshCollectionCounts() {
    guard isAccountContextCurrent, store.isOnlineMode, !countsLoading else { return }
    countsLoading = true
    Task { [weak self] in
      guard let self else { return }
      defer { self.countsLoading = false }
      do {
        var counts: [String: Int] = [:]
        for kind in ["like", "save"] {
          var ids = Set<UUID>()
          var cursor: String?
          var seenCursors = Set<String>()
          repeat {
            let page = try await TotiBackend.shared.profileReactions(kind: kind, cursor: cursor)
            guard self.isAccountContextCurrent else { return }
            ids.formUnion(page.records.filter { !self.store.isContentReported($0.id.uuidString, kind: .post) }.map(\.id))
            cursor = page.next_cursor
            if let cursor, !seenCursors.insert(cursor).inserted { throw TotiBackendError.invalidResponse }
          } while cursor != nil
          counts[kind] = ids.count
        }
        guard self.isAccountContextCurrent else { return }
        self.memberCollectionCounts = counts
        self.updateCollectionTitles()
      } catch {
        // Keep acknowledged counts; an unread collection is shown as unknown instead of zero.
      }
    }
  }
  private func writeButton(title: String = "Write a post") -> UIView {
    actionButton(title, icon: .plus, primary: true) { [weak self] in
      guard let self, self.isAccountContextCurrent else { return }
      self.presentScreen(LoungeComposerController(store: self.store), full: true)
    }
  }
  private func openPost(_ post: LoungePost) {
    guard isAccountContextCurrent else { return }
    if post.isDraft { presentScreen(LoungeComposerController(store: store, post: post), full: true) }
    else if store.isOnlineMode, store.loungePost(post.id) == nil {
      Task { [weak self] in
        guard let self else { return }
        await self.store.loadOnlineThread(kind: "comment", parentID: post.id.uuidString)
        guard self.isAccountContextCurrent else { return }
        if self.store.loungePost(post.id) != nil { self.push(LoungeDetailController(store: self.store, postID: post.id)) }
        else { self.message("This post is no longer available.") }
      }
    } else { push(LoungeDetailController(store: store, postID: post.id)) }
  }
  private func placeCategories(pinned: Bool) {
    guard let categories else { return }
    let host = pinned ? categoryChrome : categorySlot
    guard categories.superview !== host else { return }
    NSLayoutConstraint.deactivate(categoryPins)
    categories.removeFromSuperview()
    host.addSubview(categories)
    categories.translatesAutoresizingMaskIntoConstraints = false
    categoryPins = [
      categories.leadingAnchor.constraint(equalTo: host.leadingAnchor, constant: pinned ? 16 : 0),
      categories.trailingAnchor.constraint(equalTo: host.trailingAnchor, constant: pinned ? -16 : 0),
      categories.topAnchor.constraint(equalTo: host.topAnchor),
      categories.bottomAnchor.constraint(equalTo: host.bottomAnchor),
    ]
    NSLayoutConstraint.activate(categoryPins)
  }
  private func placeCategoryBar() {
    guard categorySlot.bounds.height > 0, scroll.bounds.width > 0 else { return }
    let slot = categorySlot.convert(categorySlot.bounds, to: scroll)
    if slot.minY < scroll.contentOffset.y {
      categoryChrome.isHidden = false
      categoryChrome.frame = CGRect(x: 0, y: scroll.contentOffset.y, width: scroll.bounds.width, height: 44)
      categoryWash.frame = categoryChrome.convert(coverFrame(), from: view)
      scroll.bringSubviewToFront(categoryChrome)
      placeCategories(pinned: true)
      categoryChrome.layoutIfNeeded()
    } else {
      placeCategories(pinned: false)
      categoryChrome.isHidden = true
    }
  }
}

/// Shared visual language for profile identity; never supplies account statistics.
@MainActor func totiProfileIdentityCard(photo: UIView, name: String, biography: String,
  eyebrow: String, metrics: UIView? = nil) -> UIView {
  let card = UIView()
  card.backgroundColor = TotiTheme.soft
  card.layer.cornerRadius = 28
  card.layer.cornerCurve = .continuous
  card.layer.borderWidth = 1
  card.layer.borderColor = UIColor.white.withAlphaComponent(0.95).cgColor
  card.clipsToBounds = true
  let wash = StudioCanvas()
  card.addSubview(wash)
  wash.pin(to: card)
  let avatar = UIView()
  avatar.backgroundColor = UIColor.white.withAlphaComponent(0.92)
  avatar.layer.cornerRadius = 52
  avatar.layer.borderWidth = 2
  avatar.layer.borderColor = TotiTheme.coral.withAlphaComponent(0.55).cgColor
  avatar.addSubview(photo)
  photo.pin(to: avatar, insets: UIEdgeInsets(top: 6, left: 6, bottom: 6, right: 6))
  let nameLabel = label(name, 28, TotiTheme.plum, title: true)
  let detail = stack([label(eyebrow, 10, TotiTheme.plum), nameLabel], spacing: 8)
  detail.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
  nameLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
  let largeText = UIApplication.shared.preferredContentSizeCategory.isAccessibilityCategory
  let identity = stack([avatar, detail], axis: largeText ? .vertical : .horizontal, spacing: 16)
  identity.alignment = largeText ? .leading : .center
  let rows = stack([identity], spacing: 18)
  if !biography.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
    rows.addArrangedSubview(label(biography, 16, TotiTheme.ink))
  }
  if let metrics { rows.addArrangedSubview(metrics) }
  card.addSubview(rows)
  rows.pin(to: card, insets: UIEdgeInsets(top: 24, left: 20, bottom: 24, right: 20))
  card.accessibilityIdentifier = "profile.identity"
  return card
}

/// An odd final item keeps its column width. Accessibility sizes use a single column.
@MainActor func totiProfileGrid(_ tiles: [UIView], to host: UIStackView, singleColumn: Bool) {
  if singleColumn {
    tiles.forEach { host.addArrangedSubview($0) }
    return
  }
  for index in stride(from: 0, to: tiles.count, by: 2) {
    let row = stack(axis: .horizontal, spacing: 12)
    row.distribution = .fillEqually
    row.alignment = .top
    row.addArrangedSubview(tiles[index])
    row.addArrangedSubview(index + 1 < tiles.count ? tiles[index + 1] : UIView())
    host.addArrangedSubview(row)
  }
}

@MainActor private func profilePaper(_ views: [UIView]) -> UIView {
  let card = UIView()
  card.backgroundColor = UIColor.white.withAlphaComponent(0.92)
  card.layer.cornerRadius = 24
  card.layer.cornerCurve = .continuous
  card.layer.borderWidth = 1
  card.layer.borderColor = TotiTheme.line.cgColor
  let column = stack(views, spacing: 16)
  card.addSubview(column)
  column.pin(to: card, insets: UIEdgeInsets(top: 20, left: 18, bottom: 20, right: 18))
  return card
}

@MainActor private func profileMetrics(_ creator: CreatorProfile, store: AppStore) -> UIView {
  let statistics = store.statistics(for: creator)
  return totiProfileMetrics(TotiProfileMetric.allCases.map { metric in
    (metric.rawValue, store.isOnlineMode ? store.onlineProfileMetric(metric.field, creatorID: creator.id)
      : metric.value(in: statistics))
  })
}

@MainActor func totiProfileMetrics(_ values: [(String, Int?)], illustrative: Bool = false) -> UIView {
  let row = stack(axis: .horizontal, spacing: 6)
  row.distribution = .fillEqually
  for (title, numberValue) in values {
    let value = numberValue.map(String.init) ?? "—"
    let number = label(value, 22, TotiTheme.plum, title: true)
    let caption = label(title, 11, TotiTheme.muted)
    number.textAlignment = .center
    caption.textAlignment = .center
    let metric = stack([number, caption], spacing: 4)
    metric.backgroundColor = UIColor.white.withAlphaComponent(0.76)
    metric.layer.cornerRadius = 16
    metric.isLayoutMarginsRelativeArrangement = true
    metric.layoutMargins = UIEdgeInsets(top: 12, left: 4, bottom: 12, right: 4)
    metric.isAccessibilityElement = true
    metric.accessibilityLabel = title
    metric.accessibilityValue = value
    metric.accessibilityIdentifier = "profile.metric." + title.lowercased()
    if illustrative { metric.accessibilityHint = "Illustrative editorial figure. Not live community activity." }
    number.isAccessibilityElement = false
    caption.isAccessibilityElement = false
    row.addArrangedSubview(metric)
  }
  return row
}

@MainActor private func openProfileAuthor(_ author: CreatorProfile, from screen: StackScreen) {
  guard screen.isAccountContextCurrent else { return }
  if let profile = screen as? CreatorController, profile.creator.id == author.id {
    profile.scroll.setContentOffset(.zero, animated: !UIAccessibility.isReduceMotionEnabled)
    return
  }
  screen.push(CreatorController(store: screen.store, creator: author))
}

@MainActor private func profilePostCard(_ post: LoungePost, store: AppStore,
  openAuthor: @escaping () -> Void, action: @escaping () -> Void) -> UIView {
  let card = UIView()
  card.backgroundColor = UIColor.white.withAlphaComponent(0.92)
  card.layer.cornerRadius = 24
  card.layer.cornerCurve = .continuous
  card.layer.borderWidth = 1
  card.layer.borderColor = TotiTheme.line.cgColor
  card.clipsToBounds = true
  let button = UIControl()
  let column = stack(spacing: 10)
  let top = label(post.isDraft ? "PRIVATE DRAFT" : post.topic.rawValue.uppercased(), 10, TotiTheme.plum)
  column.addArrangedSubview(top)
  if post.mediaRevisionID != nil || post.photoJPEG != nil || post.photoAsset != nil {
    if post.author.isLocalOwner || post.mediaRevisionID == nil || post.mediaStatus == "approved" {
      let photo = TotiPhoto()
      photo.contentMode = .scaleAspectFill
      photo.translatesAutoresizingMaskIntoConstraints = false
      photo.heightAnchor.constraint(equalTo: photo.widthAnchor, multiplier: 1.1).isActive = true
      photo.layer.cornerRadius = 16
      if let bytes = post.photoJPEG { photo.image = UIImage(data: bytes) }
      else if let revision = post.mediaRevisionID { photo.configure(asset: "remote-media:" + revision.uuidString) }
      else { photo.configure(asset: post.photoAsset) }
      column.addArrangedSubview(photo)
    }
  }
  if post.author.isLocalOwner, let review = mediaReviewNotice(status: post.mediaStatus, feedback: post.mediaFeedback) {
    column.addArrangedSubview(review)
  }
  let excerpt = label(post.body.isEmpty ? "Untitled draft" : post.body, 16, TotiTheme.ink)
  excerpt.numberOfLines = 3
  column.addArrangedSubview(excerpt)
  let footer = post.isDraft ? "Continue writing" : "\(store.loungeLikeCount(post.id)) likes · \(store.loungeCommentCount(post.id)) replies"
  column.addArrangedSubview(label(footer, 11, TotiTheme.plum))
  column.isUserInteractionEnabled = false
  column.accessibilityElementsHidden = true
  button.addSubview(column)
  column.pin(to: button)
  button.isAccessibilityElement = true
  button.accessibilityTraits = .button
  button.accessibilityIdentifier = "profile.post." + post.id.uuidString
  button.accessibilityLabel = (post.isDraft ? "Continue draft, " : "Read post, ") + String(post.body.prefix(180)) + ", " + post.author.name
  button.addAction(UIAction { _ in action() }, for: .touchUpInside)
  let photo = TotiPhoto(asset: post.author.avatarAsset, size: 36, round: true)
  if post.author.isLocalOwner { store.configureOwnerAvatar(photo) }
  let metadata = stack([
    label(post.author.name, 14, TotiTheme.plum, title: true),
    label(post.updatedAt.formatted(date: .abbreviated, time: .omitted), 12, TotiTheme.muted),
  ], spacing: 3)
  let authorRow = stack([photo, metadata, UIView()], axis: .horizontal, spacing: 10)
  authorRow.alignment = .center
  authorRow.isUserInteractionEnabled = false
  authorRow.accessibilityElementsHidden = true
  let author = UIControl()
  author.addSubview(authorRow)
  authorRow.pin(to: author)
  author.heightAnchor.constraint(greaterThanOrEqualToConstant: 44).isActive = true
  author.isAccessibilityElement = true
  author.accessibilityTraits = .button
  author.accessibilityLabel = "View " + post.author.name + "'s profile"
  author.accessibilityIdentifier = "profile.post.author." + post.id.uuidString
  author.addAction(UIAction { _ in openAuthor() }, for: .touchUpInside)
  let contents = stack([button, author], spacing: 10)
  card.addSubview(contents)
  contents.pin(to: card, insets: UIEdgeInsets(top: 12, left: 12, bottom: 12, right: 12))
  return card
}

final class CreatorController: StackScreen {
  let creator: CreatorProfile
  init(store: AppStore, creator: CreatorProfile) {
    self.creator = creator
    super.init(store: store, title: creator.name)
  }
  required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }
  override func refresh() {
    guard isViewLoaded, isAccountContextCurrent else { return }
    clear()
    appendOnlineControls()
    let current = store.isOnlineMode ? UUID(uuidString: creator.id).map { store.onlineCreator($0) } ?? creator : creator
    title = current.name
    content.addArrangedSubview(totiProfileIdentityCard(photo: ownerPortrait(size: 92),
      name: current.name, biography: current.biography, eyebrow: "MUSIC & CONNECTIONS",
      metrics: profileMetrics(current, store: store)))
    if !current.isLocalOwner {
      content.addArrangedSubview(profileActions())
      let safety = actionButton("Report or block", icon: .flag, compact: true) { [weak self] in
        guard let self, self.isAccountContextCurrent else { return }
        let screen = SafetyController(store: self.store, target: ContentSafetyTarget(
          id: current.id, title: current.name, kind: .profile, creator: current))
        screen.onResolved = { [weak self] in
          guard let self, self.isAccountContextCurrent else { return }
          if self.store.isCreatorBlocked(current.id) { self.leaveAfterBlock() }
          else { self.refresh() }
        }
        self.presentScreen(screen)
      }
      safety.accessibilityIdentifier = "profile.safety"
      content.addArrangedSubview(safety)
    }
    if let region = current.ipRegion, !region.isEmpty { content.addArrangedSubview(label("IP: " + region, 12, TotiTheme.muted)) }
    let posts = store.loungePosts(for: creator.id).filter { !$0.isEditorial && !$0.isDraft }
    heading("Works")
    content.addArrangedSubview(label(totiProfileCollectionCount(posts.count, suffix: store.isOnlineMode ? "loaded" : ""), 12, TotiTheme.muted))
    if posts.isEmpty {
      content.addArrangedSubview(profilePaper([
        label("A story is still to come.", 23, TotiTheme.plum, title: true),
        label("Published music posts will appear here.", 15, TotiTheme.muted),
      ]))
    }
    let tiles = posts.map { post in
      profilePostCard(post, store: store, openAuthor: { [weak self] in
        guard let self else { return }
        openProfileAuthor(post.author, from: self)
      }) { [weak self] in
        guard let self, self.isAccountContextCurrent else { return }
        self.push(LoungeDetailController(store: self.store, postID: post.id))
      }
    }
    totiProfileGrid(tiles, to: content, singleColumn: traitCollection.preferredContentSizeCategory.isAccessibilityCategory)

  }

  /// Only mutual follows show Message. Otherwise Follow fills its former space.
  private func profileActions() -> UIView {
    let following = store.followsProfile(creator)
    let mutual = store.isMutualProfile(creator)
    let block = profileIconButton(.block, "Block") { [weak self] in self?.confirmBlock() }
    if !mutual {
      let follow = profileWideButton(
        following ? "Following" : "Follow", icon: following ? .check : .plus
      ) { [weak self] in self?.toggleFollow() }
      let row = stack([follow, block], axis: .horizontal, spacing: 8)
      // Keep Block at its original quarter width and give Follow all remaining width.
      block.widthAnchor.constraint(equalTo: row.widthAnchor, multiplier: 0.25, constant: -4)
        .isActive = true
      row.heightAnchor.constraint(greaterThanOrEqualToConstant: 48).isActive = true
      return row
    }
    let follow: UIView = profileIconButton(.check, "Following") { [weak self] in self?.toggleFollow() }
    let message: UIView = profileWideButton("Message", icon: .chats) { [weak self] in self?.openChat() }
    let row = UIView()
    for item in [follow, message, block] {
      item.translatesAutoresizingMaskIntoConstraints = false
      row.addSubview(item)
    }
    let followShare: CGFloat = 0.25
    let messageShare: CGFloat = 0.5
    NSLayoutConstraint.activate([
      follow.leadingAnchor.constraint(equalTo: row.leadingAnchor),
      follow.topAnchor.constraint(equalTo: row.topAnchor),
      follow.bottomAnchor.constraint(equalTo: row.bottomAnchor),
      message.leadingAnchor.constraint(equalTo: follow.trailingAnchor, constant: 8),
      message.topAnchor.constraint(equalTo: row.topAnchor),
      message.bottomAnchor.constraint(equalTo: row.bottomAnchor),
      block.leadingAnchor.constraint(equalTo: message.trailingAnchor, constant: 8),
      block.trailingAnchor.constraint(equalTo: row.trailingAnchor),
      block.topAnchor.constraint(equalTo: row.topAnchor),
      block.bottomAnchor.constraint(equalTo: row.bottomAnchor),
      follow.widthAnchor.constraint(
        equalTo: row.widthAnchor, multiplier: followShare, constant: -16 * followShare),
      message.widthAnchor.constraint(
        equalTo: row.widthAnchor, multiplier: messageShare, constant: -16 * messageShare),
      row.heightAnchor.constraint(greaterThanOrEqualToConstant: 48),
    ])
    return row
  }
  private func profileWideButton(
    _ title: String, icon: TotiIcon, action: @escaping () -> Void
  ) -> StudioButton {
    let button = actionButton(title, icon: icon, tone: .coral, action: action)
    button.setContentHuggingPriority(.defaultLow, for: .horizontal)
    button.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
    button.caption.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
    return button
  }
  private func profileIconButton(
    _ icon: TotiIcon, _ name: String, action: @escaping () -> Void
  ) -> UIButton {
    let button = UIButton(type: .custom)
    button.setImage(icon.image(TotiTheme.plum, size: 22), for: .normal)
    button.backgroundColor = UIColor.white.withAlphaComponent(0.86)
    button.layer.cornerRadius = 22
    button.layer.cornerCurve = .continuous
    button.layer.borderWidth = 1
    button.layer.borderColor = TotiTheme.line.cgColor
    button.clipsToBounds = true
    button.accessibilityLabel = name
    button.translatesAutoresizingMaskIntoConstraints = false
    button.heightAnchor.constraint(greaterThanOrEqualToConstant: 48).isActive = true
    button.setContentHuggingPriority(.defaultLow, for: .horizontal)
    button.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
    button.addAction(UIAction { _ in action() }, for: .touchUpInside)
    soften(button)
    return button
  }
  private func toggleFollow() {
    if store.isCreatorBlocked(creator.id) {
      message("Unblock this person from Blocked in Settings to follow them.")
      return
    }
    Task { await store.toggleProfileFollow(creator) }
  }
  private func confirmBlock() {
    confirm(
      "Block " + creator.name + "?",
      message:
        "Their posts, comments, voice rooms, and chats will be hidden. You can unblock them from Blocked in Settings.",
      destructive: true, button: "Block"
    ) { [weak self] in
      guard let self else { return }
      Task {
        if await self.store.blockCreator(self.creator) {
          self.leaveAfterBlock()
        } else {
          self.message(self.store.lastSaveError ?? "Please try again.")
        }
      }
    }
  }
  private func leaveAfterBlock() {
    guard let nav = navigationController else {
      dismiss(animated: true)
      return
    }
    let previous = nav.viewControllers.dropLast().last
    if let chat = previous as? ConversationController,
      chat.conversation.id == creator.id || chat.conversation.creator?.id == creator.id
    {
      if nav.viewControllers.count > 2 {
        nav.popToViewController(nav.viewControllers[nav.viewControllers.count - 3], animated: true)
      } else {
        nav.popToRootViewController(animated: true)
      }
      return
    }
    if nav.viewControllers.first === self {
      dismiss(animated: true)
    } else {
      nav.popViewController(animated: true)
    }
  }
  private func openChat() {
    guard isAccountContextCurrent, store.isMutualProfile(creator) else { return }
    if let nav = navigationController,
      nav.viewControllers.dropLast().last is ConversationController
    {
      nav.popViewController(animated: true)
      return
    }
    if !store.isOnlineMode, let person = MusicChatCatalog.people.first(where: { $0.id == creator.id }) {
      push(ConversationController(store: store, conversation: person))
      return
    }
    if store.isCreatorBlocked(creator.id) {
      message("Unblock this person from Blocked in Settings to send a message.")
      return
    }
    Task {
      guard isAccountContextCurrent, store.isMutualProfile(creator) else { return }
      let opened = await store.openCreatorConversation(creator)
      guard isAccountContextCurrent, store.isMutualProfile(creator) else { return }
      if opened, let conversation = store.chatConversations.first(where: { $0.creator?.id == creator.id })
      {
        push(ConversationController(store: store, conversation: conversation))
      } else if store.isCreatorBlocked(creator.id) {
        message("Unblock this person from Blocked in Settings to send a message.")
      } else {
        message(store.lastSaveError ?? "This conversation could not be opened.")
      }
    }
  }
  private func ownerPortrait(size: CGFloat) -> TotiPhoto {
    let current = store.isOnlineMode ? UUID(uuidString: creator.id).map { store.onlineCreator($0) } : nil
    let photo = TotiPhoto(asset: portraitAsset(current?.avatarAsset ?? creator.avatarAsset, personID: creator.id), size: size, round: true)
    if current?.isLocalOwner == true || creator.isLocalOwner { store.configureOwnerAvatar(photo) }
    return photo
  }
}
final class EditProfileController: StackScreen, PHPickerViewControllerDelegate {
  private let entryGeneration = TotiBackend.shared.generation
  private var entryAccountIsCurrent: Bool { !store.isOnlineMode || entryGeneration == TotiBackend.shared.generation }
  private var name = field("Name"), bio = field("Biography")
  private let portrait = TotiPhoto(size: 96, round: true)
  private var editingProfile = LocalProfile()
  private var chosenPhoto: Data?
  private var picking = false
  private var saving = false
  private let photoPreparationStatus = label("", 13, TotiTheme.muted)
  override func build() {
    super.build()
    title = "Edit profile"
    editingProfile = store.library.profile
    name.text = store.library.profile.displayName
    bio.text = store.library.profile.biography
    store.configureOwnerAvatar(portrait)
    portrait.isAccessibilityElement = false
    let ring = UIButton(type: .custom)
    ring.accessibilityLabel = "Change photo"
    ring.backgroundColor = TotiTheme.coral.withAlphaComponent(0.45)
    ring.layer.borderWidth = 2
    ring.layer.borderColor = TotiTheme.plum.cgColor
    ring.layer.cornerRadius = 52
    ring.clipsToBounds = true
    ring.translatesAutoresizingMaskIntoConstraints = false
    ring.addSubview(portrait)
    NSLayoutConstraint.activate([
      ring.widthAnchor.constraint(equalToConstant: 104),
      ring.heightAnchor.constraint(equalToConstant: 104),
      portrait.centerXAnchor.constraint(equalTo: ring.centerXAnchor),
      portrait.centerYAnchor.constraint(equalTo: ring.centerYAnchor),
    ])
    ring.addAction(UIAction { [weak self] _ in self?.choosePhoto() }, for: .touchUpInside)
    soften(ring)
    let change = actionButton("Change photo", icon: .photo) { [weak self] in self?.choosePhoto() }
    let header = stack([ring, change], spacing: 12)
    header.alignment = .center
    content.addArrangedSubview(header)
    photoPreparationStatus.isHidden = true
    content.addArrangedSubview(photoPreparationStatus)
    if store.isOnlineMode {
      content.addArrangedSubview(label("Your current approved avatar stays visible while a replacement is reviewed.", 13, TotiTheme.muted))
      if let review = avatarReviewPreview(store.library.profile) { content.addArrangedSubview(review) }
    }
    content.addArrangedSubview(name)
    content.addArrangedSubview(bio)
    content.addArrangedSubview(
      actionButton("Save", icon: .check, primary: true) { [weak self] in
        guard let self, self.entryAccountIsCurrent else { return }
        guard !self.picking else { self.message("Your photo is still being prepared. Please try again in a moment."); return }
        guard !self.saving, !self.store.isBusy else { return }
        var profile = self.editingProfile
        profile.displayName = self.name.text ?? ""
        profile.biography = self.bio.text ?? ""
        let photo = self.chosenPhoto
        self.saving = true
        self.content.isUserInteractionEnabled = false
        Task {
          guard self.entryAccountIsCurrent else { return }
          let saved = await self.store.saveProfile(profile, avatarJPEG: photo)
          guard self.entryAccountIsCurrent else { return }
          self.saving = false
          self.content.isUserInteractionEnabled = true
          if saved {
            if self.navigationController?.viewControllers.first == self {
              self.dismiss(animated: true)
            } else {
              self.navigationController?.popViewController(animated: true)
            }
          } else {
            self.message(
              self.store.lastSaveError
                ?? "Use a name up to 30 characters and a biography up to 160 characters.")
          }
        }
      })
  }
  private func choosePhoto() {
    guard entryAccountIsCurrent else { return }
    guard !picking, !saving, !store.isBusy else { return }
    var configuration = PHPickerConfiguration(photoLibrary: .shared())
    configuration.filter = .images
    configuration.selectionLimit = 1
    configuration.preferredAssetRepresentationMode = .current
    let picker = PHPickerViewController(configuration: configuration)
    picker.delegate = self
    present(picker, animated: true)
  }
  func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
    guard entryAccountIsCurrent else { picker.dismiss(animated: false); return }
    picker.dismiss(animated: true)
    guard let provider = results.first?.itemProvider else { return }
    picking = true
    photoPreparationStatus.isHidden = false
    photoPreparationStatus.text = "Preparing photo…"
    guard let identifier = provider.registeredTypeIdentifiers.first(where: { UTType($0)?.conforms(to: .image) == true }) else {
      picking = false
      photoPreparationStatus.text = "Photo could not be opened. Choose another photo."
      message("That photo couldn't be opened. Please choose another.")
      return
    }
    provider.loadDataRepresentation(forTypeIdentifier: identifier) {
      [weak self] data, _ in
      let data = data.flatMap(LoungePhotoImport.normalizedJPEG)
      Task { @MainActor in
        guard let self, self.entryAccountIsCurrent else { return }
        self.picking = false
        guard let data else {
          self.photoPreparationStatus.text = "Photo could not be prepared. Your previous selection is kept."
          self.message("Choose another photo.")
          return
        }
        self.chosenPhoto = data
        self.photoPreparationStatus.text = self.store.isOnlineMode ? "Ready to upload when you save. Your replacement will await review." : "Ready to save on this device."
        self.portrait.configure(asset: nil)
        self.portrait.image = UIImage(data: data)
      }
    }
  }
}
@MainActor private func avatarReviewPreview(_ profile: LocalProfile) -> UIView? {
  guard let notice = mediaReviewNotice(status: profile.avatarMediaStatus, feedback: profile.avatarMediaFeedback) else { return nil }
  var views: [UIView] = []
  if let revision = profile.avatarPendingMediaRevisionID {
    let preview = TotiPhoto(asset: "remote-media:" + revision.uuidString, size: 72, round: true)
    preview.isAccessibilityElement = true
    preview.accessibilityLabel = "Your private avatar review preview"
    let row = stack([preview, notice], axis: .horizontal, spacing: 12)
    row.alignment = .center
    views.append(row)
  } else { views.append(notice) }
  return stack(views)
}

final class SettingsController: StackScreen {
  override func refresh() {
    guard isViewLoaded else { return }
    clear()
    title = "Settings"
    if store.isOnlineMode {
      content.addArrangedSubview(actionButton("Local archive", icon: .notebook) { [weak self] in
        guard let self else { return }
        self.push(LegacyArchiveController(store: self.store))
      })
    }
    content.addArrangedSubview(
      actionButton("Edit profile", icon: .me) { [weak self] in
        guard let self else { return }
        self.push(EditProfileController(store: self.store))
      })
    for document in AgreementDocument.allCases {
      content.addArrangedSubview(
        actionButton(document.title, icon: .info) { [weak self] in
          guard let self else { return }
          self.push(AgreementController(store: self.store, document: document))
        })
    }
    content.addArrangedSubview(actionButton("Media credits", icon: .music) { [weak self] in
      guard let self else { return }
      self.push(MediaCreditsController(store: self.store))
    })
    if store.isOnlineMode {
      content.addArrangedSubview(actionButton("Editorial preferences", icon: .me) { [weak self] in
        guard let self, self.isAccountContextCurrent else { return }
        self.push(TotiEditorialPreferencesController(store: self.store))
      })
    }
    let blocked = store.library.contentSafety?.blockedCreators ?? [:]
    let blockedTitle = blocked.isEmpty ? "Blocked" : "Blocked (\(blocked.count))"
    let blockedButton = actionButton(blockedTitle, icon: .block) { [weak self] in
      guard let self else { return }
      self.presentScreen(BlockedCreatorsController(store: self.store))
    }
    content.addArrangedSubview(blockedButton)
    let reports = store.reportedContent()
    let reportedTitle = reports.isEmpty ? "Reported" : "Reported (\(reports.count))"
    let reportedButton = actionButton(reportedTitle, icon: .flag) { [weak self] in
      guard let self else { return }
      self.presentScreen(ReportedContentController(store: self.store))
    }
    content.addArrangedSubview(reportedButton)
    content.setCustomSpacing(44, after: reportedButton)
    let logout = actionButton("Log out", icon: .logout) { [weak self] in
      guard let self else { return }
      self.confirm(
        "Log out?", message: self.store.isOnlineMode ? "This device will leave the session. Guest accounts cannot be recovered after logout. Their cloud content remains until account deletion." : "Your posts, notes and drafts will stay on this device.",
        button: "Log out"
      ) { self.save { await self.store.logOut() } }
    }
    if store.isOnlineMode {
      content.addArrangedSubview(actionButton("Retry pending changes", icon: .refresh) { [weak self] in
        guard let self, self.isAccountContextCurrent else { return }
        self.confirm("Retry pending changes?", message: "Retry changes previously submitted by this account, including messages and deletions. Each confirmed change is applied only once. Account deletion is not retried here.", button: "Retry") {
          self.save { await self.store.retryPendingOnlineChanges() }
        }
      })
    }
    let delete = actionButton("Delete account", icon: .trash) { [weak self] in
      guard let self else { return }
      self.confirm(
        "Delete account?",
        message:
          self.store.isOnlineMode ? "This permanently deletes your online account, posts, notes, rooms and groups you own, including their associated replies and messages. Other members' accounts and independent content are not deleted. Your on-device archive and original Photos files are kept." : "This permanently deletes your profile, posts, notes, imported copies, interactions and drafts from this device. Original files in Photos are kept.",
        destructive: true, button: "Delete account"
      ) { self.save { await self.store.deleteLocalAccount() } }
    }
    for button in [logout, delete] {
      button.widthAnchor.constraint(equalToConstant: 220).isActive = true
    }
    let account = stack([logout, delete], spacing: 14)
    account.alignment = .center
    content.addArrangedSubview(account)
  }
}

private final class BlockedAuthorRow: UIControl {
  let creatorID: String
  init(creator: CreatorProfile) {
    creatorID = creator.id
    super.init(frame: .zero)
    let photo = roundPortrait(asset: creator.avatarAsset, size: 54, personID: creator.id)
    let name = label(creator.name, 17, title: true)
    name.numberOfLines = 1
    name.isUserInteractionEnabled = false
    photo.isUserInteractionEnabled = false
    let row = stack([photo, name], axis: .horizontal, spacing: 12)
    row.alignment = .center
    row.isUserInteractionEnabled = false
    let hairline = UIView()
    hairline.backgroundColor = TotiTheme.plum.withAlphaComponent(0.15)
    hairline.isUserInteractionEnabled = false
    hairline.translatesAutoresizingMaskIntoConstraints = false
    addSubview(row)
    addSubview(hairline)
    row.translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([
      row.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 2),
      row.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -2),
      row.topAnchor.constraint(equalTo: topAnchor, constant: 8),
      row.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -8),
      hairline.leadingAnchor.constraint(equalTo: name.leadingAnchor),
      hairline.trailingAnchor.constraint(equalTo: trailingAnchor),
      hairline.bottomAnchor.constraint(equalTo: bottomAnchor),
      hairline.heightAnchor.constraint(equalToConstant: 1),
      heightAnchor.constraint(greaterThanOrEqualToConstant: 70),
    ])
    isAccessibilityElement = true
    accessibilityLabel = creator.name
    accessibilityHint = "Long press to unblock"
    accessibilityTraits = .button
  }
  required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }
}

final class BlockedCreatorsController: StackScreen {
  override func refresh() {
    guard isViewLoaded else { return }
    clear()
    title = "Blocked"
    let blocked = store.library.contentSafety?.blockedCreators ?? [:]
    if blocked.isEmpty {
      content.addArrangedSubview(label("No blocked creators.", 15, TotiTheme.muted))
      return
    }
    content.addArrangedSubview(
      label("Long press an artist to unblock them.", 14, TotiTheme.muted))
    for creator in blocked.values.sorted(by: { $0.name < $1.name }) {
      let row = BlockedAuthorRow(creator: creator)
      row.accessibilityIdentifier = "blocked.author." + creator.id.lowercased()
      row.addGestureRecognizer(
        UILongPressGestureRecognizer(target: self, action: #selector(longPressAuthor(_:))))
      row.accessibilityCustomActions = [
        UIAccessibilityCustomAction(name: "Unblock") { [weak self] _ in
          self?.askToUnblock(creatorID: row.creatorID)
          return true
        },
      ]
      content.addArrangedSubview(row)
    }
  }
  @objc private func longPressAuthor(_ gesture: UILongPressGestureRecognizer) {
    guard gesture.state == .began, let row = gesture.view as? BlockedAuthorRow else { return }
    askToUnblock(creatorID: row.creatorID)
  }
  private func askToUnblock(creatorID: String) {
    let blocked = store.library.contentSafety?.blockedCreators ?? [:]
    guard let creator = blocked[creatorID] else { return }
    confirm(
      "Unblock " + creator.name + "?",
      message: store.isOnlineMode ? "Their posts, comments and voice rooms can show again in your account." : "Their posts, comments and voice rooms can show again. This stays on this device.",
      button: "Unblock"
    ) { [weak self] in
      guard let self else { return }
      self.save { await self.store.unblockCreator(creator.id) }
    }
  }
}

private final class ReportedCard: UIControl {
  let contentID: String
  let kind: ContentSafetyTarget.Kind
  init(item: ReportedContentItem, store: AppStore) {
    contentID = item.contentID
    kind = item.kind
    super.init(frame: .zero)
    let visual = Self.visual(for: item, store: store)
    visual.isUserInteractionEnabled = false
    addSubview(visual)
    visual.translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([
      visual.leadingAnchor.constraint(equalTo: leadingAnchor),
      visual.trailingAnchor.constraint(equalTo: trailingAnchor),
      visual.topAnchor.constraint(equalTo: topAnchor),
      visual.bottomAnchor.constraint(equalTo: bottomAnchor),
    ])
    isAccessibilityElement = true
    accessibilityLabel = item.kind.rawValue + ", " + item.title
    accessibilityHint = "Long press to remove this report"
    accessibilityTraits = .button
  }
  required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }

  private static func visual(for item: ReportedContentItem, store: AppStore) -> UIView {
    switch item.kind {
    case .live, .shortVideo:
      return commentRow(item, store: store) // Historical reports remain removable; retired playback has no route.
    case .post, .profile:
      return commentRow(item, store: store)
    case .party:
      if let room = room(for: item, store: store) {
        return musicRoomCard(room, animated: false, stretches: true)
      }
    case .phrase:
      return commentRow(item, store: store) // Preserve removal of an older report without a retired feature route.
    case .comment:
      return commentRow(item, store: store)
    }
    return missing(item)
  }

  private static func room(for item: ReportedContentItem, store: AppStore) -> PartyRoom? {
    if let room = store.loungeVoiceRooms.first(where: { $0.id == item.contentID }) { return room }
    if let draft = store.library.roomDrafts.first(where: { $0.id.uuidString == item.contentID }) {
      return MusicRoomCatalog.room(from: draft)
    }
    return nil
  }

  private static func commentRow(_ item: ReportedContentItem, store: AppStore) -> UIView {
    let photo = roundPortrait(asset: store.isOnlineMode ? "TotiMark" : nil, size: 44, personID: item.creatorName)
    let name = label(item.creatorName, 15, TotiTheme.plum, title: true)
    name.numberOfLines = 1
    let body = label(item.title, 16)
    body.numberOfLines = 4
    let text = stack([name, body], spacing: 3)
    let row = stack([photo, text], axis: .horizontal, spacing: 12)
    row.alignment = .top
    return Self.note(row)
  }

  private static func missing(_ item: ReportedContentItem) -> UIView {
    let text = label(item.title + "\n" + item.kind.rawValue, 16, title: true)
    return Self.note(text, fill: TotiTheme.soft)
  }

  private static func note(_ body: UIView, fill: UIColor = UIColor.white.withAlphaComponent(0.9)) -> UIView {
    let box = UIView()
    box.backgroundColor = fill
    box.layer.cornerRadius = 18
    box.layer.cornerCurve = .continuous
    box.clipsToBounds = true
    box.addSubview(body)
    body.translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([
      body.leadingAnchor.constraint(equalTo: box.leadingAnchor, constant: 12),
      body.trailingAnchor.constraint(equalTo: box.trailingAnchor, constant: -12),
      body.topAnchor.constraint(equalTo: box.topAnchor, constant: 12),
      body.bottomAnchor.constraint(lessThanOrEqualTo: box.bottomAnchor, constant: -12),
    ])
    return box
  }
}

final class ReportedContentController: StackScreen {
  override func refresh() {
    guard isViewLoaded else { return }
    clear()
    title = "Reported"
    let reports = store.reportedContent()
    if reports.isEmpty {
      content.addArrangedSubview(label("No reports yet.", 15, TotiTheme.muted))
      return
    }
    content.addArrangedSubview(
      label(store.isOnlineMode ? "Submitted reports remain available for review. A submission does not mean moderation has completed." : "Long press a card to remove it. Reports stay on this device.", 14, TotiTheme.muted))
    let columns = traitCollection.preferredContentSizeCategory.isAccessibilityCategory ? 1 : 2
    let spacing: CGFloat = 12
    for start in stride(from: 0, to: reports.count, by: columns) {
      let row = stack(axis: .horizontal, spacing: spacing)
      row.distribution = .fillEqually
      row.alignment = .fill
      row.setContentCompressionResistancePriority(.required, for: .vertical)
      row.setContentHuggingPriority(.required, for: .vertical)
      for item in reports[start..<min(start + columns, reports.count)] {
        row.addArrangedSubview(reportCard(item))
      }
      if row.arrangedSubviews.count < columns { row.addArrangedSubview(UIView()) }
      content.addArrangedSubview(row)
      // Historical and current report summaries share a consistent card height.
      let height = row.heightAnchor.constraint(
        equalTo: content.widthAnchor,
        multiplier: 1.25 / CGFloat(columns),
        constant: -(spacing * 1.25 * CGFloat(columns - 1) / CGFloat(columns)))
      height.priority = .required
      height.isActive = true
    }
  }
  private func reportCard(_ item: ReportedContentItem) -> ReportedCard {
    let card = ReportedCard(item: item, store: store)
    if store.isOnlineMode {
      card.accessibilityHint = "Submitted report"
      return card
    }
    card.addGestureRecognizer(
      UILongPressGestureRecognizer(target: self, action: #selector(longPressReport(_:))))
    card.accessibilityCustomActions = [
      UIAccessibilityCustomAction(name: "Remove this report") { [weak self] _ in
        self?.askToRemove(contentID: card.contentID, kind: card.kind)
        return true
      },
    ]
    return card
  }
  @objc private func longPressReport(_ gesture: UILongPressGestureRecognizer) {
    guard gesture.state == .began, let row = gesture.view as? ReportedCard else { return }
    askToRemove(contentID: row.contentID, kind: row.kind)
  }
  private func askToRemove(contentID: String, kind: ContentSafetyTarget.Kind) {
    confirm(
      "Remove this report?",
      message: "It can show in the app again. This change stays on this device.",
      button: "Remove report"
    ) { [weak self] in
      guard let self else { return }
      self.save { await self.store.removeReports(contentID: contentID, kind: kind) }
    }
  }
}


