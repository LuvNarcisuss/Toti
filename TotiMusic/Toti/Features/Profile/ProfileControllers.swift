import PhotosUI
import UIKit
import UniformTypeIdentifiers

final class MeController: StackScreen {
  private var selection = 0
  override func build() {
    super.build()
    title = "Me"
    navigationItem.leftBarButtonItem = barButton(totiMark())
    navigationItem.rightBarButtonItem = barButton(iconButton(.settings, "Settings") { [weak self] in
      guard let self else { return }
      self.push(SettingsController(store: self.store))
    })
  }
  override func refresh() {
    guard isViewLoaded else { return }
    clear()
    let photo = TotiPhoto(size: 88, round: true)
    photo.image = store.ownerAvatarImage() ?? UIImage(named: MusicPhotography.creatorAvatar(for: "local-owner"))
    let identity = stack([photo, label(store.library.profile.displayName, 27, title: true),
      label(store.library.profile.biography, 15, TotiTheme.muted)])
    identity.alignment = .center
    content.addArrangedSubview(identity)
    let actions = stack(axis: .horizontal, spacing: 10)
    actions.distribution = .fillEqually
    actions.addArrangedSubview(actionButton("Edit profile", icon: .me, compact: true) { [weak self] in
      guard let self else { return }; self.push(EditProfileController(store: self.store))
    })
    actions.addArrangedSubview(actionButton("Wallet", icon: .diamond, tone: .coral, compact: true) { [weak self] in
      guard let self else { return }; self.push(WalletController(store: self.store))
    })
    content.addArrangedSubview(actions)
    content.addArrangedSubview(actionButton("My notebook · \(store.notebookNotes.count) " + (store.notebookNotes.count == 1 ? "idea" : "ideas"), icon: .notebook) { [weak self] in
      guard let self else { return }; self.push(NotebookController(store: self.store))
    })
    let choices = StudioChoice(items: ["My posts", "Saved", "Drafts"], index: selection)
    choices.onChange = { [weak self] value in self?.selection = value; self?.refresh() }
    content.addArrangedSubview(choices)
    let posts = selection == 0 ? store.loungePosts(for: "local-owner") : selection == 1 ? store.savedLoungePosts : store.loungeDrafts
    content.addArrangedSubview(label("\(posts.count) " + (selection == 2 ? (posts.count == 1 ? "draft" : "drafts") : (posts.count == 1 ? "post" : "posts")) + " · On this device", 12, TotiTheme.muted))
    if posts.isEmpty {
      heading(selection == 1 ? "Keep what inspires you." : "Your next story starts here.")
      content.addArrangedSubview(label(selection == 1 ? "Save posts from Lounge to find them here." : "Share a thought, a concert photo or a musical question.", 16, TotiTheme.muted))
    }
    for post in posts {
      content.addArrangedSubview(profilePostButton(post) { [weak self] in
        guard let self else { return }
        if post.isDraft { self.presentScreen(LoungeComposerController(store: self.store, post: post)) }
        else { self.push(LoungeDetailController(store: self.store, postID: post.id)) }
      })
    }
    content.addArrangedSubview(actionButton("Write a post", icon: .plus, primary: true) { [weak self] in
      guard let self else { return }; self.presentScreen(LoungeComposerController(store: self.store))
    })
    heading("Your voice rooms")
    if store.library.roomDrafts.isEmpty {
      content.addArrangedSubview(label("Create a space for songs and conversation.", 15, TotiTheme.muted))
    }
    for room in store.library.roomDrafts {
      content.addArrangedSubview(actionButton(room.title, icon: .voice) { [weak self] in
        guard let self else { return }; self.presentScreen(PartyCreationController(store: self.store, draft: room))
      })
    }
    content.addArrangedSubview(actionButton("Create a voice room", icon: .voice) { [weak self] in
      guard let self else { return }; self.presentScreen(PartyCreationController(store: self.store))
    })
  }
}

@MainActor private func profilePostButton(_ post: LoungePost, action: @escaping () -> Void) -> UIView {
  let caption = post.body.trimmingCharacters(in: .whitespacesAndNewlines)
  return actionButton(caption.isEmpty ? "Untitled draft" : String(caption.prefix(150)), icon: post.isDraft ? .clock : .lounge, action: action)
}

final class CreatorController: StackScreen {
  let creator: CreatorProfile
  init(store: AppStore, creator: CreatorProfile) {
    self.creator = creator
    super.init(store: store, title: creator.name)
  }
  required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }
  override func refresh() {
    guard isViewLoaded else { return }
    clear()
    let header = stack(
      [
        ownerPortrait(size: 88), label(creator.name, 26, title: true),
      ], axis: .horizontal)
    header.alignment = .center
    content.addArrangedSubview(header)
    let stats = store.statistics(for: creator)
    let row = stack(axis: .horizontal, spacing: 7)
    row.distribution = .fillEqually
    for (name, value) in [
      ("Likes", stats.likes), ("Saves", stats.saves), ("Following", stats.following),
      ("Followers", stats.followers),
    ] {
      let l = label("\(value)\n\(name)", 13)
      l.textAlignment = .center
      row.addArrangedSubview(l)
    }
    content.addArrangedSubview(row)
    content.addArrangedSubview(label(creator.biography))
    if !creator.isLocalOwner {
      content.addArrangedSubview(profileActions())
    }
    content.addArrangedSubview(
      label("IP: " + (creator.ipRegion ?? "Not shared"), 12, TotiTheme.muted))
    let posts = store.loungePosts(for: creator.id)
    heading("Posts (\(posts.count))")
    if posts.isEmpty { content.addArrangedSubview(label("No music stories here yet.", 15, TotiTheme.muted)) }
    for post in posts {
      content.addArrangedSubview(profilePostButton(post) { [weak self] in
        guard let self else { return }
        self.push(LoungeDetailController(store: self.store, postID: post.id))
      })
    }
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
    guard store.isMutualProfile(creator) else { return }
    if let nav = navigationController,
      nav.viewControllers.dropLast().last is ConversationController
    {
      nav.popViewController(animated: true)
      return
    }
    if let person = MusicChatCatalog.people.first(where: { $0.id == creator.id }) {
      push(ConversationController(store: store, conversation: person))
      return
    }
    if store.isCreatorBlocked(creator.id) {
      message("Unblock this person from Blocked in Settings to send a message.")
      return
    }
    Task {
      if await store.openCreatorConversation(creator),
        let conversation = store.chatConversations.first(where: { $0.creator?.id == creator.id })
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
    let photo = TotiPhoto(
      asset: portraitAsset(creator.avatarAsset, personID: creator.id), size: size, round: true)
    if creator.isLocalOwner, let image = store.ownerAvatarImage() {
      photo.image = image
    }
    return photo
  }
}
final class EditProfileController: StackScreen, PHPickerViewControllerDelegate {
  private var name = field("Name"), bio = field("Biography")
  private let portrait = TotiPhoto(size: 96, round: true)
  private var chosenPhoto: Data?
  private var picking = false
  override func build() {
    super.build()
    title = "Edit profile"
    name.text = store.library.profile.displayName
    bio.text = store.library.profile.biography
    portrait.image =
      store.ownerAvatarImage()
      ?? UIImage(named: portraitAsset(nil, personID: "local-owner"))
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
    content.addArrangedSubview(name)
    content.addArrangedSubview(bio)
    content.addArrangedSubview(
      actionButton("Save", icon: .check, primary: true) { [weak self] in
        guard let self else { return }
        var profile = self.store.library.profile
        profile.displayName = self.name.text ?? ""
        profile.biography = self.bio.text ?? ""
        let photo = self.chosenPhoto
        Task {
          if await self.store.saveProfile(profile, avatarJPEG: photo) {
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
    guard !picking, !store.isBusy else { return }
    var configuration = PHPickerConfiguration(photoLibrary: .shared())
    configuration.filter = .images
    configuration.selectionLimit = 1
    configuration.preferredAssetRepresentationMode = .current
    let picker = PHPickerViewController(configuration: configuration)
    picker.delegate = self
    present(picker, animated: true)
  }
  func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
    picker.dismiss(animated: true)
    guard let provider = results.first?.itemProvider else { return }
    picking = true
    provider.loadDataRepresentation(forTypeIdentifier: UTType.image.identifier) {
      [weak self] data, _ in
      let data = data
      Task { @MainActor in
        guard let self else { return }
        self.picking = false
        guard let data, data.count <= 30 * 1024 * 1024, UIImage(data: data) != nil else {
          self.message("Choose another photo.")
          return
        }
        self.chosenPhoto = data
        self.portrait.image = UIImage(data: data)
      }
    }
  }
}
final class SettingsController: StackScreen {
  override func refresh() {
    guard isViewLoaded else { return }
    clear()
    title = "Settings"
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
        "Log out?", message: "Your posts, notes and drafts will stay on this device.",
        button: "Log out"
      ) { self.save { await self.store.logOut() } }
    }
    let delete = actionButton("Delete account", icon: .trash) { [weak self] in
      guard let self else { return }
      self.confirm(
        "Delete account?",
        message:
          "This permanently deletes your profile, posts, notes, imported copies, interactions and drafts from this device. Original files in Photos are kept.",
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
      message: "Their posts, comments and voice rooms can show again. This stays on this device.",
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
      return commentRow(item) // Historical reports remain removable; retired playback has no route.
    case .post:
      return commentRow(item)
    case .party:
      if let room = room(for: item, store: store) {
        return musicRoomCard(room, animated: false, stretches: true)
      }
    case .phrase:
      return commentRow(item) // Preserve removal of an older report without a retired feature route.
    case .comment:
      return commentRow(item)
    }
    return missing(item)
  }

  private static func room(for item: ReportedContentItem, store: AppStore) -> PartyRoom? {
    if let room = MusicRoomCatalog.rooms.first(where: { $0.id == item.contentID }) { return room }
    if let draft = store.library.roomDrafts.first(where: { $0.id.uuidString == item.contentID }) {
      return MusicRoomCatalog.room(from: draft)
    }
    return nil
  }

  private static func commentRow(_ item: ReportedContentItem) -> UIView {
    let photo = roundPortrait(asset: nil, size: 44, personID: item.creatorName)
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
      label("Long press a card to remove it. Reports stay on this device.", 14, TotiTheme.muted))
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


