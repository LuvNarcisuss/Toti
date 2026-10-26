import Combine
import ImageIO
import PhotosUI
import UIKit
import UniformTypeIdentifiers

@MainActor
private func loungePaper(_ views: [UIView], spacing: CGFloat = 14) -> UIView {
    let paper = UIView()
    paper.backgroundColor = UIColor.white.withAlphaComponent(0.9)
    paper.layer.cornerRadius = 24
    paper.layer.cornerCurve = .continuous
    paper.layer.borderWidth = 1
    paper.layer.borderColor = TotiTheme.line.withAlphaComponent(0.7).cgColor
    let column = stack(views, spacing: spacing)
    paper.addSubview(column)
    column.pin(to: paper, insets: UIEdgeInsets(top: 18, left: 18, bottom: 18, right: 18))
    return paper
}

@MainActor
private func loungePhoto(_ post: LoungePost) -> UIImageView? {
    let image = post.photoJPEG.flatMap(UIImage.init(data:)) ?? post.photoAsset.flatMap(UIImage.init(named:))
    guard let image else { return nil }
    let view = UIImageView(image: image)
    view.contentMode = .scaleAspectFill
    view.rounded(18)
    view.height(210)
    view.isAccessibilityElement = true
    view.accessibilityLabel = post.isEditorial ? "Illustrative studio photograph" : "Photo attached to post"
    return view
}

@MainActor
private func loungeAuthor(_ post: LoungePost, store: AppStore, action: @escaping () -> Void) -> UIView {
    let row = stack([
        roundPortrait(asset: post.author.avatarAsset, size: 44, personID: post.author.id, image: post.author.isLocalOwner ? store.ownerAvatarImage() : nil),
        stack([label(post.author.name, 15, title: true), label(post.createdAt.formatted(date: .abbreviated, time: .omitted), 12, TotiTheme.muted)], spacing: 3),
        UIView()
    ], axis: .horizontal, spacing: 10)
    row.alignment = .center
    row.isUserInteractionEnabled = false
    let button = UIControl()
    button.addSubview(row)
    row.pin(to: button)
    button.heightAnchor.constraint(greaterThanOrEqualToConstant: 44).isActive = true
    button.addAction(UIAction { _ in action() }, for: .touchUpInside)
    button.isAccessibilityElement = true
    button.accessibilityLabel = "View " + post.author.name + "'s profile"
    button.accessibilityTraits = .button
    return button
}

final class LoungeController: StackScreen {
    private let cards = UIStackView()
    private var filter = 0
    private var topic: LoungeTopic?
    private var query = ""

    init(store: AppStore) { super.init(store: store, title: "Lounge") }
    required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }
    override func build() {
        super.build()
        navigationItem.leftBarButtonItem = barButton(totiMark())
        navigationItem.rightBarButtonItem = barButton(iconButton(.plus, "Write a post") { [weak self] in self?.compose() })
        let intro = stack([label("GOOD MUSIC. GOOD COMPANY.", 11, TotiTheme.muted), label("Find your people.\nShare your sound.", 31, title: true), label("A place for the songs, stories and little discoveries that bring us together.", 15, TotiTheme.muted)], spacing: 9)
        content.addArrangedSubview(intro)
        content.addArrangedSubview(actionButton("What's on your mind?", icon: .chats, tone: .coral) { [weak self] in self?.compose() })
        let tabs = StudioChoice(items: ["For you", "Following", "Saved"])
        tabs.onChange = { [weak self] index in self?.filter = index; self?.refresh() }
        content.addArrangedSubview(tabs)
        let search = field("Search posts, people and topics")
        search.returnKeyType = .search
        search.clearButtonMode = .whileEditing
        search.addAction(UIAction { [weak self, weak search] _ in self?.query = search?.text ?? ""; self?.refresh() }, for: .editingChanged)
        content.addArrangedSubview(search)
        let topics = StudioChoice(items: ["All"] + LoungeTopic.allCases.map(\.rawValue))
        topics.onChange = { [weak self] index in self?.topic = index == 0 ? nil : LoungeTopic.allCases[index - 1]; self?.refresh() }
        content.addArrangedSubview(topics)
        content.addArrangedSubview(label("Posts and replies are stored on this device.", 12, TotiTheme.muted))
        cards.axis = .vertical
        cards.spacing = 18
        content.addArrangedSubview(cards)
        content.addArrangedSubview(actionButton("My drafts", icon: .bookmark) { [weak self] in
            guard let self else { return }
            self.push(LoungeDraftsController(store: self.store))
        })
    }
    override func refresh() {
        guard isViewLoaded else { return }
        cards.arrangedSubviews.forEach { $0.removeFromSuperview() }
        let source = filter == 2 ? store.savedLoungePosts : store.loungePosts
        let posts = source.filter { post in
            (filter != 1 || store.isFollowingCreator(post.author.id)) && (topic == nil || post.topic == topic) && post.matches(query)
        }
        if posts.isEmpty {
            let text = filter == 1 ? "Follow a writer from their profile to see their posts here." : filter == 2 ? "Save a post to keep its ideas close. Your saved posts will appear here." : "No posts match your search. Try another topic or start the conversation."
            cards.addArrangedSubview(loungePaper([label("A little room for inspiration", 23, title: true), label(text, 15, TotiTheme.muted), actionButton("Write a post", icon: .plus, primary: true) { [weak self] in self?.compose() }]))
        }
        for post in posts { cards.addArrangedSubview(postCard(post)) }
    }
    private func compose() { presentScreen(LoungeComposerController(store: store), full: true) }
    private func postCard(_ post: LoungePost) -> UIView {
        let author = loungeAuthor(post, store: store) { [weak self] in
            guard let self else { return }; self.push(CreatorController(store: self.store, creator: post.author))
        }
        let topic = label(post.topic.rawValue.uppercased(), 11, TotiTheme.plum)
        let body = label(post.body, 18)
        body.numberOfLines = 6
        var views: [UIView] = [author, topic, body]
        if let photo = loungePhoto(post) { views.append(photo) }
        if post.isEditorial { views.append(label("Fictional editorial prompt · illustrative portrait", 11, TotiTheme.muted)) }
        views.append(actionButton("Read & reply", icon: .comment) { [weak self] in
            guard let self else { return }; self.push(LoungeDetailController(store: self.store, postID: post.id))
        })
        let liked = store.library.lounge?.likedPostIDs.contains(post.id) == true
        let saved = store.library.lounge?.savedPostIDs.contains(post.id) == true
        let like = actionButton(liked ? "Liked · 1" : "Like · 0", icon: liked ? .heartFill : .heartOutline, tone: liked ? .coral : .quiet, compact: true) { [weak self] in
            guard let self else { return }; self.save { await self.store.toggleLoungeLike(post.id) }
        }
        let save = actionButton(saved ? "Saved" : "Save", icon: .bookmark, tone: saved ? .coral : .quiet, compact: true) { [weak self] in
            guard let self else { return }; self.save { await self.store.toggleLoungeSave(post.id) }
        }
        let interactions = stack([like, save], axis: traitCollection.preferredContentSizeCategory.isAccessibilityCategory ? .vertical : .horizontal, spacing: 8)
        interactions.distribution = .fillEqually
        views.append(interactions)
        let replyCount = store.loungeComments(for: post.id).count
        views.append(label("\(replyCount) " + (replyCount == 1 ? "reply" : "replies"), 12, TotiTheme.muted))
        return loungePaper(views)
    }
}

final class LoungeDraftsController: StackScreen {
    init(store: AppStore) { super.init(store: store, title: "Post drafts") }
    required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }
    override func refresh() {
        guard isViewLoaded else { return }
        clear()
        heading("A thought in progress")
        content.addArrangedSubview(label("Only saved posts appear in the Lounge. Drafts stay here until you're ready.", 15, TotiTheme.muted))
        if store.loungeDrafts.isEmpty { content.addArrangedSubview(label("No drafts yet. Start a post and choose Save draft.")) }
        for post in store.loungeDrafts {
            content.addArrangedSubview(loungePaper([
                label(post.topic.rawValue, 12, TotiTheme.muted),
                label(post.body.isEmpty ? "Untitled draft" : String(post.body.prefix(160)), 18),
                actionButton("Continue writing", icon: .plus) { [weak self] in
                    guard let self else { return }; self.presentScreen(LoungeComposerController(store: self.store, post: post), full: true)
                },
                actionButton("Delete draft", icon: .trash, tone: .danger) { [weak self] in
                    self?.confirm("Delete this draft?", message: "The draft and its attached photo will be removed from this device.", destructive: true, button: "Delete") { [weak self] in
                        guard let self else { return }; self.save { await self.store.deleteLoungePost(post.id) }
                    }
                }
            ]))
        }
        content.addArrangedSubview(actionButton("New post", icon: .plus, primary: true) { [weak self] in
            guard let self else { return }; self.presentScreen(LoungeComposerController(store: self.store), full: true)
        })
    }
}

final class LoungeDetailController: StackScreen, UITextViewDelegate {
    let postID: UUID
    private let postContent = UIStackView()
    private let replyContent = UIStackView()
    private let replyEditor = UITextView()
    private let replyCount = UILabel()
    private var submitting = false

    init(store: AppStore, postID: UUID) {
        self.postID = postID
        super.init(store: store, title: "Conversation")
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }
    override func build() {
        super.build()
        postContent.axis = .vertical; postContent.spacing = 16
        replyContent.axis = .vertical; replyContent.spacing = 12
        content.addArrangedSubview(postContent)
        content.addArrangedSubview(replyContent)
        replyEditor.font = TotiTheme.font(16)
        replyEditor.adjustsFontForContentSizeCategory = true
        replyEditor.backgroundColor = .white
        replyEditor.textColor = TotiTheme.ink
        replyEditor.tintColor = TotiTheme.plum
        replyEditor.textContainerInset = UIEdgeInsets(top: 14, left: 12, bottom: 14, right: 12)
        replyEditor.rounded(16)
        replyEditor.height(120)
        replyEditor.accessibilityLabel = "Write a reply"
        replyEditor.delegate = self
        replyCount.font = TotiTheme.font(12)
        replyCount.textColor = TotiTheme.muted
        content.addArrangedSubview(label("Add your voice", 22, title: true))
        content.addArrangedSubview(replyEditor)
        content.addArrangedSubview(replyCount)
        content.addArrangedSubview(actionButton("Save reply", icon: .send, primary: true) { [weak self] in self?.submitReply() })
        content.addArrangedSubview(label("Replies are free and saved on this device.", 12, TotiTheme.muted))
        textViewDidChange(replyEditor)
    }
    override func refresh() {
        guard isViewLoaded else { return }
        postContent.arrangedSubviews.forEach { $0.removeFromSuperview() }
        replyContent.arrangedSubviews.forEach { $0.removeFromSuperview() }
        let available = store.loungePost(postID)
        // Keep typed input intact if another view updates the shared library.
        for view in content.arrangedSubviews where view !== postContent && view !== replyContent { view.isHidden = available == nil }
        guard let post = available else {
            postContent.addArrangedSubview(loungePaper([label("This post is unavailable", 24, title: true), label("It may have been removed, hidden or written by someone you've blocked.", 15, TotiTheme.muted)]))
            return
        }
        var views: [UIView] = [loungeAuthor(post, store: store) { [weak self] in
            guard let self else { return }; self.push(CreatorController(store: self.store, creator: post.author))
        }, label(post.topic.rawValue.uppercased(), 12, TotiTheme.muted), label(post.body, 20)]
        if let image = loungePhoto(post) { views.append(image) }
        if post.isEditorial { views.append(label("Fictional editorial prompt. Photographs are illustrative artwork, not the writer's identity.", 12, TotiTheme.muted)) }
        if let roomID = post.voiceRoomID {
            if let room = store.loungeVoiceRooms.first(where: { $0.id == roomID }) {
                views.append(actionButton("Join the conversation · " + room.title, icon: .voice, tone: .coral) { [weak self] in
                    guard let self, let current = self.store.loungeVoiceRooms.first(where: { $0.id == roomID }) else { return }
                    self.presentScreen(PartyRoomController(store: self.store, room: current), full: true)
                })
            } else { views.append(label("Linked voice room is unavailable.", 14, TotiTheme.muted)) }
        }
        let liked = store.library.lounge?.likedPostIDs.contains(post.id) == true
        let saved = store.library.lounge?.savedPostIDs.contains(post.id) == true
        let actions = stack([
            actionButton(liked ? "Liked · 1" : "Like · 0", icon: liked ? .heartFill : .heartOutline, tone: liked ? .coral : .quiet) { [weak self] in guard let self else { return }; self.save { await self.store.toggleLoungeLike(post.id) } },
            actionButton(saved ? "Saved" : "Save", icon: .bookmark, tone: saved ? .coral : .quiet) { [weak self] in guard let self else { return }; self.save { await self.store.toggleLoungeSave(post.id) } }
        ], axis: traitCollection.preferredContentSizeCategory.isAccessibilityCategory ? .vertical : .horizontal)
        actions.distribution = .fillEqually
        views.append(actions)
        if post.author.isLocalOwner {
            views.append(actionButton("Edit post", icon: .more) { [weak self] in guard let self else { return }; self.presentScreen(LoungeComposerController(store: self.store, post: post), full: true) })
            views.append(actionButton("Delete post", icon: .trash, tone: .danger) { [weak self] in
                self?.confirm("Delete this post?", message: "This removes the post, its photo and its replies from this device.", destructive: true, button: "Delete") { [weak self] in
                    guard let self else { return }; self.save { await self.store.deleteLoungePost(post.id) }
                }
            })
        } else {
            let gift = actionButton("Give a gift", icon: .gift, tone: .coral) { [weak self] in
                guard let self else { return }
                self.openGifts(GiftContext(surface: .post, sourceID: post.id.uuidString,
                    sourceTitle: "Lounge post", recipients: [GiftRecipient(id: post.author.id, name: post.author.name)]))
            }
            gift.accessibilityIdentifier = "gift.entry.post"
            views.append(gift)
            views.append(actionButton("Report or block", icon: .flag) { [weak self] in
                self?.showSafety(ContentSafetyTarget(id: post.id.uuidString, title: String(post.body.prefix(120)), kind: .post, creator: post.author))
            })
        }
        postContent.addArrangedSubview(loungePaper(views))
        let comments = store.loungeComments(for: postID)
        replyContent.addArrangedSubview(label("Replies · \(comments.count)", 23, title: true))
        if comments.isEmpty { replyContent.addArrangedSubview(label("Be the first to add a thought.", 15, TotiTheme.muted)) }
        for comment in comments {
            let creator = comment.author.isLocalOwner ? CreatorProfile.signedIn(store.library.profile) : comment.author
            let name = actionButton(creator.name, compact: true) { [weak self] in
                guard let self else { return }; self.push(CreatorController(store: self.store, creator: creator))
            }
            var parts: [UIView] = [name, label(comment.body), label(comment.createdAt.formatted(date: .abbreviated, time: .shortened), 11, TotiTheme.muted)]
            if comment.author.isLocalOwner {
                parts.append(actionButton("Delete reply", icon: .trash, compact: true) { [weak self] in
                    self?.confirm("Delete this reply?", message: "This reply will be removed from this device.", destructive: true, button: "Delete") { [weak self] in guard let self else { return }; self.save { await self.store.deleteLoungeComment(comment.id) } }
                })
            } else {
                parts.append(actionButton("Report or block", icon: .flag, compact: true) { [weak self] in
                    self?.showSafety(ContentSafetyTarget(id: comment.id.uuidString, title: String(comment.body.prefix(120)), kind: .comment, creator: comment.author))
                })
            }
            replyContent.addArrangedSubview(loungePaper(parts, spacing: 10))
        }
    }
    private func showSafety(_ target: ContentSafetyTarget) {
        let controller = SafetyController(store: store, target: target)
        controller.onResolved = { [weak self] in self?.refresh() }
        presentScreen(controller)
    }
    func textViewDidChange(_ textView: UITextView) {
        replyCount.text = "\(textView.text.count) / 500 characters"
        replyCount.textColor = textView.text.count > 500 ? TotiTheme.dangerInk : TotiTheme.muted
    }
    private func submitReply() {
        guard !submitting else { return }
        let text = replyEditor.text ?? ""
        submitting = true
        Task {
            let saved = await store.addLoungeComment(text, postID: postID)
            submitting = false
            if saved {
                if replyEditor.text == text { replyEditor.text = ""; textViewDidChange(replyEditor) }
                view.endEditing(true)
                refresh()
            } else { message(store.lastSaveError ?? "Your reply could not be saved. Please try again.") }
        }
    }
}

final class LoungeComposerController: StackScreen, UITextViewDelegate, PHPickerViewControllerDelegate {
    private var post: LoungePost
    private var original: LoungePost
    private var isNew: Bool
    private let editor = UITextView()
    private let counter = UILabel()
    private let attachments = UIStackView()
    private var saving = false
    private var importing = false
    private var importToken = UUID()
    private var saveButton: StudioButton?
    private var draftButton: StudioButton?
    private var previousModalLock = false

    init(store: AppStore, post: LoungePost? = nil, initialText: String = "") {
        let value = post ?? LoungePost(author: .signedIn(store.library.profile), body: initialText, isDraft: true)
        self.post = value
        original = value
        isNew = post == nil
        super.init(store: store, title: post == nil ? "Write a post" : post!.isDraft ? "Continue draft" : "Edit post")
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }
    override func build() {
        super.build()
        navigationItem.leftBarButtonItem = barButton(iconButton(.close, "Close editor") { [weak self] in self?.requestClose() })
        isModalInPresentation = true
        previousModalLock = navigationController?.isModalInPresentation ?? false
        navigationController?.isModalInPresentation = true
        heading("Let a conversation begin.")
        content.addArrangedSubview(label("Posts and replies are stored on this device.", 14, TotiTheme.muted))
        let topics = StudioChoice(items: LoungeTopic.allCases.map(\.rawValue), index: LoungeTopic.allCases.firstIndex(of: post.topic) ?? 0)
        topics.onChange = { [weak self] index in self?.post.topic = LoungeTopic.allCases[index] }
        content.addArrangedSubview(topics)
        editor.text = post.body
        editor.font = TotiTheme.font(19)
        editor.adjustsFontForContentSizeCategory = true
        editor.textColor = TotiTheme.ink
        editor.tintColor = TotiTheme.plum
        editor.backgroundColor = .white
        editor.textContainerInset = UIEdgeInsets(top: 18, left: 14, bottom: 18, right: 14)
        editor.rounded(22)
        editor.height(270)
        editor.accessibilityLabel = "Post text"
        editor.delegate = self
        content.addArrangedSubview(editor)
        counter.font = TotiTheme.font(13)
        counter.numberOfLines = 0
        counter.adjustsFontForContentSizeCategory = true
        content.addArrangedSubview(counter)
        attachments.axis = .vertical
        attachments.spacing = 12
        content.addArrangedSubview(attachments)
        content.addArrangedSubview(actionButton("Choose a photo", icon: .photo) { [weak self] in self?.choosePhoto() })
        content.addArrangedSubview(actionButton("Link a voice room", icon: .voice) { [weak self] in self?.chooseRoom() })
        saveButton = actionButton("Save post", icon: .check, primary: true) { [weak self] in self?.persist(asDraft: false) }
        content.addArrangedSubview(saveButton!)
        if isNew || original.isDraft {
            draftButton = actionButton("Save draft", icon: .bookmark) { [weak self] in self?.persist(asDraft: true) }
            content.addArrangedSubview(draftButton!)
        }
        textViewDidChange(editor)
        renderAttachments()
    }
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.interactivePopGestureRecognizer?.isEnabled = false
    }
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        navigationController?.interactivePopGestureRecognizer?.isEnabled = true
    }
    override func refresh() { /* Shared updates must not replace the user's unsaved input. */ }
    func textViewDidChange(_ textView: UITextView) {
        post.body = textView.text ?? ""
        counter.text = "\(post.body.count) / 1,000 characters" + (post.body.count > 1_000 ? " · Shorten this text before saving a post. You can keep it as a draft." : "")
        counter.textColor = post.body.count > 1_000 ? TotiTheme.dangerInk : TotiTheme.muted
    }
    private var dirty: Bool {
        post.body != original.body || post.topic != original.topic || post.photoJPEG != original.photoJPEG || post.voiceRoomID != original.voiceRoomID || (isNew && !post.body.isEmpty)
    }
    private func requestClose() {
        guard !saving else { return }
        guard dirty || importing else { closeEditor(); return }
        view.endEditing(true)
        let draft = isNew || original.isDraft
        showCard([
            label("Keep your changes?", 23, title: true),
            label("Save your work before leaving, or discard your unsaved changes.", 15, TotiTheme.muted),
            actionButton(draft ? "Save draft" : "Save changes", primary: true) { [weak self] in self?.dismissCard { self?.persist(asDraft: draft) } },
            actionButton("Discard changes", tone: .danger) { [weak self] in self?.dismissCard { self?.closeEditor() } },
            actionButton("Keep editing") { [weak self] in self?.dismissCard() }
        ])
    }
    override func dismissCollapsed() { requestClose() }
    func presentationControllerDidAttemptToDismiss(_ presentationController: UIPresentationController) { requestClose() }
    private func closeEditor() {
        importToken = UUID()
        isModalInPresentation = false
        navigationController?.isModalInPresentation = previousModalLock
        if navigationController?.viewControllers.first === self { super.dismissCollapsed() }
        else { navigationController?.popViewController(animated: true) }
    }
    private func persist(asDraft: Bool) {
        guard !saving else { return }
        guard !importing else { message("Your photo is still being prepared. Please try again in a moment."); return }
        textViewDidChange(editor)
        if let error = post.validationError(asDraft: asDraft) { message(error); return }
        saving = true
        content.isUserInteractionEnabled = false
        editor.isEditable = false
        saveButton?.isEnabled = false; draftButton?.isEnabled = false
        view.endEditing(true)
        Task {
            let success = await store.saveLoungePost(post, asDraft: asDraft)
            saving = false
            content.isUserInteractionEnabled = true
            editor.isEditable = true
            saveButton?.isEnabled = true; draftButton?.isEnabled = true
            if success {
                post.isDraft = asDraft
                original = post
                isNew = false
                draftButton?.isHidden = !asDraft
                showCard([label(asDraft ? "Draft saved" : "Saved on this device", 24, title: true),
                          label(asDraft ? "Find it in My drafts when you're ready to continue." : "Your post is now in your local Lounge.", 15, TotiTheme.muted),
                          actionButton("Done", primary: true) { [weak self] in self?.dismissCard { self?.closeEditor() } }])
            } else {
                showCard([label("Changes weren't saved", 23, title: true), label(store.lastSaveError ?? "Please wait for the current save to finish and try again.", 15, TotiTheme.muted),
                          actionButton("Retry", primary: true) { [weak self] in self?.dismissCard { self?.persist(asDraft: asDraft) } },
                          actionButton("Keep editing") { [weak self] in self?.dismissCard() }])
            }
        }
    }
    private func renderAttachments() {
        attachments.arrangedSubviews.forEach { $0.removeFromSuperview() }
        if importing { attachments.addArrangedSubview(label("Preparing photo…", 14, TotiTheme.muted)) }
        if let photo = loungePhoto(post) {
            attachments.addArrangedSubview(photo)
            attachments.addArrangedSubview(actionButton("Remove photo", icon: .trash) { [weak self] in
                self?.post.photoJPEG = nil; self?.post.photoAsset = nil; self?.renderAttachments()
            })
        }
        if let id = post.voiceRoomID {
            let name = store.loungeVoiceRooms.first { $0.id == id }?.title ?? "Room unavailable"
            attachments.addArrangedSubview(label("Voice room · " + name, 15, TotiTheme.plum))
            attachments.addArrangedSubview(actionButton("Remove room link", icon: .close) { [weak self] in self?.post.voiceRoomID = nil; self?.renderAttachments() })
        }
    }
    private func chooseRoom() {
        guard !saving else { return }
        let selector = LoungeRoomPickerController(store: store) { [weak self] room in
            self?.post.voiceRoomID = room.id
            self?.renderAttachments()
        }
        presentScreen(selector)
    }
    private func choosePhoto() {
        guard !saving, !importing else { return }
        var configuration = PHPickerConfiguration(photoLibrary: .shared())
        configuration.filter = .images
        configuration.selectionLimit = 1
        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = self
        present(picker, animated: true)
    }
    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true)
        guard let provider = results.first?.itemProvider else { return }
        guard let identifier = provider.registeredTypeIdentifiers.first(where: { UTType($0)?.conforms(to: .image) == true }) else { message("That photo couldn't be opened. Please choose another."); return }
        let token = UUID()
        importToken = token
        importing = true
        renderAttachments()
        provider.loadDataRepresentation(forTypeIdentifier: identifier) { [weak self] data, _ in
            let jpeg = data.flatMap(LoungePhotoImport.normalizedJPEG)
            Task { @MainActor [weak self] in
                guard let self, self.importToken == token else { return }
                self.importing = false
                if let jpeg { self.post.photoJPEG = jpeg; self.post.photoAsset = nil }
                else { self.message("This photo couldn't be prepared. Choose an image under 30 MB and try again.") }
                self.renderAttachments()
            }
        }
    }
}

private final class LoungeRoomPickerController: StackScreen {
    private let selected: (PartyRoom) -> Void
    init(store: AppStore, selected: @escaping (PartyRoom) -> Void) {
        self.selected = selected
        super.init(store: store, title: "Link a voice room")
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }
    override func refresh() {
        guard isViewLoaded else { return }
        clear()
        heading("Keep the conversation going")
        content.addArrangedSubview(label("Choose an available voice room. Its link will be saved with your post.", 15, TotiTheme.muted))
        if store.loungeVoiceRooms.isEmpty { content.addArrangedSubview(label("No voice rooms are currently available.")) }
        for room in store.loungeVoiceRooms {
            content.addArrangedSubview(actionButton(room.title, icon: .voice) { [weak self] in
                guard let self, let current = self.store.loungeVoiceRooms.first(where: { $0.id == room.id }) else { return }
                self.selected(current)
                self.dismissCollapsed()
            })
        }
    }
}

/// ImageIO applies EXIF orientation while downsampling, without decoding a full-size
/// UIImage. The normalized JPEG then participates in the library's single atomic write.
enum LoungePhotoImport {
    static func normalizedJPEG(_ data: Data) -> Data? {
        guard data.count <= 30 * 1_024 * 1_024,
              let source = CGImageSourceCreateWithData(data as CFData, [kCGImageSourceShouldCache: false] as CFDictionary),
              let thumbnail = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: 1_200,
                kCGImageSourceShouldCacheImmediately: true
              ] as CFDictionary) else { return nil }
        let image = UIImage(cgImage: thumbnail)
        for quality in [0.85, 0.65, 0.45, 0.25] {
            if let jpeg = image.jpegData(compressionQuality: quality), jpeg.count <= 1_048_576 { return jpeg }
        }
        return nil
    }
}
