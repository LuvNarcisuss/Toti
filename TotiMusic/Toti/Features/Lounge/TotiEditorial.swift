import Combine
import Foundation
import UIKit

/// Authored editorial identities stay separate from real Guest replies and reactions.
struct OnlineEditorialPost: Decodable, Identifiable {
    let id: UUID
    let title: String
    let body: String
    let topic: String
    let photo_asset: String?
    let created_at: String
    var liked: Bool? = nil
    var saved: Bool? = nil
    var like_count: Int? = nil
    var save_count: Int? = nil
    var comment_count: Int? = nil
}

struct EditorialActivityComment: Decodable, Identifiable {
    let id: UUID
    let author_id: UUID
    let body: String
    let created_at: String
    let profile: [String: JSONValue]?
}

struct EditorialCommentCursor: Decodable {
    let created_at: String
    let id: UUID
    var payload: [String: JSONValue] {
        ["before_created_at": .string(created_at), "before_id": .string(id.uuidString)]
    }
}

struct EditorialActivitySnapshot: Decodable {
    let post: OnlineEditorialPost
    let comments: [EditorialActivityComment]
    let next_cursor: EditorialCommentCursor?
}

@MainActor extension AppStore {
    var likedEditorialPosts: [OnlineEditorialPost] {
        ((try? TotiEditorialPreferences.visiblePosts(onlineEditorialPosts)) ?? []).filter { $0.liked == true }
    }

    var savedEditorialPosts: [OnlineEditorialPost] {
        ((try? TotiEditorialPreferences.visiblePosts(onlineEditorialPosts)) ?? []).filter { $0.saved == true }
    }

    func applyEditorialActivity(_ snapshot: EditorialActivitySnapshot) {
        guard isOnlineMode else { return }
        if let index = onlineEditorialPosts.firstIndex(where: { $0.id == snapshot.post.id }) {
            onlineEditorialPosts[index] = snapshot.post
        }
        for comment in snapshot.comments {
            guard let body = comment.profile,
                  onlineRecords["profile"]?.contains(where: { $0.id == comment.author_id }) != true else { continue }
            // Embedded authors fill directory gaps without overwriting a versioned profile used for editing.
            onlineRecords["profile", default: []].append(OnlineRecord(id: comment.author_id,
                owner_id: comment.author_id, kind: "profile", parent_id: nil, body: body,
                version: 1, created_at: comment.created_at, updated_at: comment.created_at))
        }
        objectWillChange.send()
    }
}


/// Stable presentation identities for authored content, never authentication records.
struct TotiEditorialAuthor {
    let id: String
    let name: String
    let portraitAsset: String
    let biography: String

    static let publisher = TotiEditorialAuthor(id: "toti", name: "Toti", portraitAsset: "TotiMark",
                                             biography: "Music stories and prompts from Toti.")
    static let catalog: [String: TotiEditorialAuthor] = [
        "16f40c60-5dc2-4db5-bf99-000000000001": .init(id: "ava-bennett", name: "Ava Bennett", portraitAsset: "EditorialAvaMusic", biography: "Quiet records, warm vocals and songs worth another listen."),
        "16f40c60-5dc2-4db5-bf99-000000000002": .init(id: "ethan-cole", name: "Ethan Cole", portraitAsset: "EditorialEthanMusic", biography: "Small sounds, first lines and unfinished melodies."),
        "16f40c60-5dc2-4db5-bf99-000000000003": .init(id: "chloe-reed", name: "Chloe Reed", portraitAsset: "EditorialChloeMusic", biography: "Finding the space where different sounds belong together."),
        "16f40c60-5dc2-4db5-bf99-000000000004": .init(id: "emily-hayes", name: "Emily Hayes", portraitAsset: "EditorialEmilyMusic", biography: "Harmony, arrangement and room for the next voice."),
        "16f40c60-5dc2-4db5-bf99-000000000005": .init(id: "grace-miller", name: "Grace Miller", portraitAsset: "EditorialGraceMusic", biography: "Concert memories and little details after the last song."),
        "16f40c60-5dc2-4db5-bf99-000000000006": .init(id: "sophie-brooks", name: "Sophie Brooks", portraitAsset: "EditorialSophieMusic", biography: "Listening closely and sharing musical ideas."),
    ]
}

/// Fixed editorial figures are presentation metadata, never real member engagement.
extension TotiEditorialAuthor {
    var presentationStatistics: CreatorStatistics? {
        Self.presentationFigures[id] ?? Self.voiceFigures[id]
    }

    private static let presentationFigures: [String: CreatorStatistics] = [
        "ava-bennett": .init(likes: 86, saves: 19, following: 34, followers: 127),
        "ethan-cole": .init(likes: 64, saves: 27, following: 52, followers: 93),
        "chloe-reed": .init(likes: 39, saves: 8, following: 68, followers: 74),
        "emily-hayes": .init(likes: 112, saves: 36, following: 41, followers: 186),
        "grace-miller": .init(likes: 153, saves: 14, following: 87, followers: 241),
        "sophie-brooks": .init(likes: 47, saves: 12, following: 29, followers: 82),
    ]
}

extension OnlineEditorialPost {
    var editorialAuthor: TotiEditorialAuthor {
        TotiEditorialAuthor.catalog[id.uuidString.lowercased()] ?? TotiEditorialAuthor.voicePostAuthors[id.uuidString.lowercased()] ?? .publisher
    }
}

@MainActor
extension StackScreen {
    func appendTotiEditorial(to target: UIStackView, showsHeading: Bool = true, authorID: String? = nil, workTiles: Bool = false, onlyFollowed: Bool = false, onlySaved: Bool = false, onlyLiked: Bool = false, matching query: String = "", topic: String? = nil) {
        guard store.isOnlineMode else { return }
        if let error = store.onlineEditorialError {
            appendOnlineRetry(to: target, error: "Toti editorial could not be loaded. " + error)
        }
        guard !store.onlineEditorialPosts.isEmpty else { return }
        let visible: [OnlineEditorialPost]
        do { visible = try TotiEditorialPreferences.visiblePosts(store.onlineEditorialPosts, onlyFollowed: onlyFollowed) }
        catch {
            target.addArrangedSubview(label("Editorial preferences could not be read. Reopen this page to try again.", 14, TotiTheme.muted))
            return
        }
        let posts = visible.filter {
            (authorID == nil || $0.editorialAuthor.id == authorID) && (!onlySaved || $0.saved == true) && (!onlyLiked || $0.liked == true)
                && (topic == nil || $0.topic == topic)
                && (query.isEmpty || ($0.title + " " + $0.body + " " + $0.editorialAuthor.name).localizedCaseInsensitiveContains(query))
        }
        guard !posts.isEmpty else { return }
        if showsHeading {
            target.addArrangedSubview(label("From Toti", 24, title: true))
            target.addArrangedSubview(label("Official music prompts and illustrative photography. Pictured people are not member accounts.", 12, TotiTheme.muted))
        }
        let epoch = TotiBackend.shared.generation
        let allowedArtwork: Set<String> = [
            "MusicStudioBackdrop", "Portrait2", "Portrait3",
            "LoungeVinylListening", "LoungePianoMelody", "LoungeGuitarRehearsal",
            "LoungeStudioMixing", "LoungeConcertLights", "LoungeMusicCorner"
        ]
        var tiles: [UIView] = []
        for post in posts {
            let writer = post.editorialAuthor
            let title = label(post.title, workTiles ? 18 : 23, title: true)
            let excerpt = label(post.body, workTiles ? 15 : 17)
            excerpt.numberOfLines = workTiles ? 3 : 0
            var views: [UIView] = [label("TOTI EDITORIAL · " + post.topic.uppercased(), workTiles ? 10 : 11, TotiTheme.plum), title]
            let openPost: () -> Void = { [weak self] in
                guard let self, self.isAccountContextCurrent, epoch == TotiBackend.shared.generation else { return }
                let asset = post.photo_asset.flatMap { allowedArtwork.contains($0) ? $0 : nil } ?? "MusicStudioBackdrop"
                self.push(TotiEditorialDetailController(store: self.store, post: post, asset: asset))
            }
            if let asset = post.photo_asset, allowedArtwork.contains(asset), let image = UIImage(named: asset) {
                let photo = TotiPhoto()
                photo.image = image
                if workTiles {
                    photo.translatesAutoresizingMaskIntoConstraints = false
                    photo.heightAnchor.constraint(equalTo: photo.widthAnchor, multiplier: 1.1).isActive = true
                    photo.rounded(14)
                } else { photo.height(220) }
                photo.isAccessibilityElement = true
                photo.accessibilityLabel = "Illustrative Toti editorial photograph"
                if workTiles { views.append(photo) }
                else {
                    views.append(totiCoverButton(photo, label: "Read " + post.title,
                        identifier: "lounge.editorial.cover." + post.id.uuidString, action: openPost))
                }
            }
            views.append(excerpt)
            views.append(label(postDetailCounts(likes: post.like_count ?? 0, saves: post.save_count ?? 0, replies: post.comment_count ?? 0), 12, TotiTheme.muted))
            if workTiles {
                let preview = totiCoverButton(stack(views, spacing: 10), label: "Read " + post.title,
                    identifier: "lounge.editorial.cover." + post.id.uuidString, action: openPost)
                views = [preview]
            } else {
                views.append(actionButton("Write about this", icon: .plus) { [weak self] in
                    guard let self, self.isAccountContextCurrent, epoch == TotiBackend.shared.generation else { return }
                    self.presentScreen(LoungeComposerController(store: self.store, initialText: post.body), full: true)
                })
            }
            let portrait = TotiPhoto(asset: writer.portraitAsset, size: workTiles ? 36 : 22, round: true)
            let authorName = label(writer.name, workTiles ? 15 : 11, workTiles ? TotiTheme.plum : .white, title: true)
            authorName.numberOfLines = 2
            authorName.lineBreakMode = .byTruncatingTail
            var authorCopy: [UIView] = [authorName]
            if workTiles { authorCopy.append(label("Editorial author", 12, TotiTheme.muted)) }
            let identity = stack([portrait, stack(authorCopy, spacing: 3)], axis: .horizontal, spacing: workTiles ? 10 : 5)
            identity.alignment = .center
            identity.isUserInteractionEnabled = false
            identity.accessibilityElementsHidden = true
            let author = UIControl()
            author.addSubview(identity)
            identity.pin(to: author)
            author.heightAnchor.constraint(greaterThanOrEqualToConstant: 44).isActive = true
            author.isAccessibilityElement = true
            author.accessibilityLabel = "View " + writer.name + "'s profile"
            author.accessibilityTraits = .button
            author.accessibilityIdentifier = "lounge.editorial.author." + post.id.uuidString
            author.addAction(UIAction { [weak self] _ in
                guard let self, self.isAccountContextCurrent, epoch == TotiBackend.shared.generation else { return }
                if let profile = self as? TotiEditorialProfileController, profile.author.id == writer.id {
                    self.scroll.setContentOffset(.zero, animated: !UIAccessibility.isReduceMotionEnabled)
                } else {
                    self.push(TotiEditorialProfileController(store: self.store, author: writer))
                }
            }, for: .touchUpInside)
            if !workTiles {
                let card = UIView()
                card.layer.cornerRadius = 16
                card.layer.cornerCurve = .continuous
                card.clipsToBounds = true
                // Two half-width columns retain the former cover proportions at roughly one-quarter area.
                card.translatesAutoresizingMaskIntoConstraints = false
                card.heightAnchor.constraint(equalTo: card.widthAnchor, multiplier: 1.5).isActive = true
                card.accessibilityIdentifier = "lounge.editorial.card." + post.id.uuidString
                let asset = post.photo_asset.flatMap { allowedArtwork.contains($0) ? $0 : nil } ?? "MusicStudioBackdrop"
                let background = TotiPhoto(asset: asset)
                background.setContentHuggingPriority(UILayoutPriority(1), for: .vertical)
                background.setContentCompressionResistancePriority(UILayoutPriority(1), for: .vertical)
                background.setContentCompressionResistancePriority(UILayoutPriority(1), for: .horizontal)
                card.addSubview(background)
                background.pin(to: card)
                let shade = UIView()
                shade.backgroundColor = UIColor.black.withAlphaComponent(0.52)
                shade.isUserInteractionEnabled = false
                card.addSubview(shade)
                shade.pin(to: card)
                let space = UIView()
                space.heightAnchor.constraint(greaterThanOrEqualToConstant: 0).isActive = true
                let heading = label(post.title, 18, .white, title: true)
                heading.numberOfLines = 2
                let summary = label(post.body, 12, .white)
                summary.numberOfLines = 2
                let preview = totiCoverButton(stack([
                    space,
                    label("TOTI EDITORIAL", 9, .white),
                    heading, summary,
                    label(postDetailCounts(likes: post.like_count ?? 0, saves: post.save_count ?? 0, replies: post.comment_count ?? 0), 9, .white),
                ], spacing: 6), label: "Read " + post.title,
                    identifier: "lounge.editorial.cover." + post.id.uuidString, action: openPost)
                let create = iconButton(.plus, "Write about this") { [weak self] in
                    guard let self, self.isAccountContextCurrent, epoch == TotiBackend.shared.generation else { return }
                    self.presentScreen(LoungeComposerController(store: self.store, initialText: post.body), full: true)
                }
                create.contentHorizontalAlignment = .right
                let footer = stack([author, create], axis: .horizontal, spacing: 6)
                footer.distribution = .fillEqually
                footer.alignment = .center
                let overlay = stack([preview, footer], spacing: 8)
                card.addSubview(overlay)
                overlay.pin(to: card, insets: UIEdgeInsets(top: 10, left: 10, bottom: 10, right: 10))
                tiles.append(card)
                continue
            }
            views.append(author)
            let card = UIView()
            card.backgroundColor = UIColor.white.withAlphaComponent(0.9)
            card.layer.cornerRadius = 24
            card.layer.cornerCurve = .continuous
            card.layer.borderWidth = 1
            card.layer.borderColor = TotiTheme.line.withAlphaComponent(0.7).cgColor
            let column = stack(views, spacing: 14)
            card.addSubview(column)
            let inset: CGFloat = workTiles ? 12 : 18
            column.pin(to: card, insets: UIEdgeInsets(top: inset, left: inset, bottom: inset, right: inset))
            if workTiles { tiles.append(card) } else { target.addArrangedSubview(card) }
        }
        totiProfileGrid(tiles, to: target, singleColumn: workTiles && traitCollection.preferredContentSizeCategory.isAccessibilityCategory)
    }
}

/// A cover owns its tap target; image and caption subviews cannot swallow touches.
@MainActor
func totiCoverButton(_ cover: UIView, label: String, identifier: String, action: @escaping () -> Void) -> UIControl {
    let button = UIControl()
    cover.isUserInteractionEnabled = false
    cover.accessibilityElementsHidden = true
    button.addSubview(cover)
    cover.pin(to: button)
    button.isAccessibilityElement = true
    button.accessibilityLabel = label
    button.accessibilityIdentifier = identifier
    button.accessibilityTraits = .button
    button.addAction(UIAction { _ in action() }, for: .touchUpInside)
    return button
}

// Full editorial discussion presentation is defined below.

/// Author-specific editorial works remain separate from authenticated member profiles.
final class TotiEditorialProfileController: StackScreen {
    let author: TotiEditorialAuthor

    init(store: AppStore, author: TotiEditorialAuthor) {
        self.author = author
        super.init(store: store, title: author.name)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }

    override func build() {
        super.build()
        scroll.accessibilityIdentifier = "editorial.publisher." + author.id
    }

    override func refresh() {
        guard isViewLoaded, isAccountContextCurrent else { return }
        clear()
        let statistics = author.presentationStatistics
        let portrait = TotiPhoto(asset: author.portraitAsset, size: 92, round: true)
        portrait.isAccessibilityElement = true
        portrait.accessibilityLabel = "Portrait of " + author.name
        portrait.accessibilityIdentifier = "voice.character.portrait." + author.portraitAsset
        content.addArrangedSubview(totiProfileIdentityCard(
            photo: portrait,
            name: author.name, biography: author.biography, eyebrow: "EDITORIAL AUTHOR",
            metrics: totiProfileMetrics(TotiProfileMetric.allCases.map { metric in
                (metric.rawValue, statistics.map { metric.value(in: $0) })
            }, illustrative: statistics != nil)))
        let state: TotiEditorialPreferenceState
        do { state = try TotiEditorialPreferences.storage().read() }
        catch {
            content.addArrangedSubview(label("Editorial preferences could not be read. Your saved data has been kept.", 14, TotiTheme.muted))
            content.addArrangedSubview(actionButton("Try again", icon: .refresh) { [weak self] in self?.refresh() })
            return
        }
        let blocked = state.blockedAuthorIDs.contains(author.id)
        content.addArrangedSubview(profileActions(state: state))
        let figureNotice = statistics == nil ? "Community statistics are unavailable." : "The displayed figures are illustrative, not live community activity."
        content.addArrangedSubview(label("Editorial author · " + figureNotice + " Follow and block preferences are saved on this device. Names and biographies are authored; pictured people are not member accounts.", 12, TotiTheme.muted))
        if blocked {
            content.addArrangedSubview(label("This author is blocked. Unblock to see their posts.", 16, TotiTheme.muted))
            return
        }
        let works = store.onlineEditorialPosts.filter { $0.editorialAuthor.id == author.id }
        let categories = StudioChoice(items: ["Works (\(works.count))"])
        categories.accessibilityIdentifier = "editorial.profile.categories"
        content.addArrangedSubview(categories)
        if works.isEmpty, store.onlineEditorialError == nil {
            content.addArrangedSubview(label("New stories will appear here.", 16, TotiTheme.muted))
        }
        appendTotiEditorial(to: content, showsHeading: false, authorID: author.id, workTiles: true)
        installOnlinePullToRefresh(on: scroll)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if isViewLoaded { refresh() }
    }

    private func profileActions(state: TotiEditorialPreferenceState) -> UIView {
        let blocked = state.blockedAuthorIDs.contains(author.id)
        let following = state.followedAuthorIDs.contains(author.id)
        let follow = actionButton(following ? "Following" : "Follow", icon: following ? .check : .plus,
            tone: .coral, compact: true) { [weak self] in self?.toggleFollow() }
        follow.accessibilityIdentifier = "editorial.follow"
        follow.accessibilityValue = following ? "Following on this device" : "Not following"
        follow.isEnabled = !blocked
        follow.alpha = blocked ? 0.45 : 1
        // Editorial identities cannot follow back; unilateral content follows never enable Message.
        let block = iconButton(.block, blocked ? "Unblock" : "Block") { [weak self] in self?.confirmBlock() }
        block.accessibilityIdentifier = "editorial.block"
        block.backgroundColor = TotiTheme.soft
        block.rounded(24)
        let row = stack([follow, block], axis: .horizontal, spacing: 8)
        let widths = [
            block.widthAnchor.constraint(equalTo: row.widthAnchor, multiplier: 0.25, constant: -2),
        ]
        NSLayoutConstraint.activate(widths)
        follow.setContentHuggingPriority(.defaultLow, for: .horizontal)
        if traitCollection.preferredContentSizeCategory.isAccessibilityCategory {
            row.axis = .vertical
            row.alignment = .fill
            NSLayoutConstraint.deactivate(widths)
        }
        return row
    }

    private func toggleFollow() {
        guard isAccountContextCurrent else { return }
        do {
            try TotiEditorialPreferences.storage().update { state in
                guard !state.blockedAuthorIDs.contains(author.id) else { return }
                if state.followedAuthorIDs.contains(author.id) { state.followedAuthorIDs.remove(author.id) }
                else { state.followedAuthorIDs.insert(author.id) }
            }
            store.objectWillChange.send()
            refresh()
        } catch { message("Your follow preference could not be saved. Please try again.") }
    }

    private func confirmBlock() {
        guard isAccountContextCurrent else { return }
        do {
            let blocked = try TotiEditorialPreferences.storage().read().blockedAuthorIDs.contains(author.id)
            confirm((blocked ? "Unblock " : "Block ") + author.name + "?",
                message: blocked ? "Their editorial posts will be visible again. Following is not restored automatically."
                    : "Their editorial posts will be hidden on this device. You can unblock them from Blocked in Settings.",
                destructive: !blocked, button: blocked ? "Unblock" : "Block") { [weak self] in
                guard let self, self.isAccountContextCurrent else { return }
                do {
                    try TotiEditorialPreferences.storage().update { state in
                        if blocked { state.blockedAuthorIDs.remove(self.author.id) }
                        else {
                            state.blockedAuthorIDs.insert(self.author.id)
                            state.followedAuthorIDs.remove(self.author.id)
                        }
                    }
                    self.store.objectWillChange.send()
                    if !blocked, let navigation = self.navigationController, navigation.viewControllers.first !== self {
                        navigation.popViewController(animated: true)
                    } else { self.refresh() }
                } catch { self.message("Your block preference could not be saved. Please try again.") }
            }
        } catch { message("Editorial preferences could not be read. Please try again.") }
    }

}

/// Editorial preferences are account-scoped device data, never member relationships.
struct TotiEditorialRoomReport: Codable, Equatable {
    let title: String
    let reason: ContentReportReason
    let details: String
    let savedAt: Date
}

struct TotiEditorialPreferenceState: Codable, Equatable {
    var followedAuthorIDs: Set<String> = []
    var blockedAuthorIDs: Set<String> = []
    // Optional fields preserve decoding of existing author-only preference files.
    var blockedRoomTitles: [String: String]?
    var roomReports: [String: TotiEditorialRoomReport]?
    // Retain previously saved drafts for compatibility; no editorial messaging route exposes them.
    var drafts: [String: String] = [:]
}

struct TotiEditorialPreferenceStorage {
    enum StorageError: Error { case draftTooLong }
    let fileURL: URL

    func read() throws -> TotiEditorialPreferenceState {
        do {
            return try JSONDecoder().decode(TotiEditorialPreferenceState.self, from: Data(contentsOf: fileURL))
        } catch let error as CocoaError where error.code == .fileReadNoSuchFile {
            return TotiEditorialPreferenceState()
        }
    }

    @discardableResult
    func update(_ mutation: (inout TotiEditorialPreferenceState) -> Void) throws -> TotiEditorialPreferenceState {
        var state = try read()
        mutation(&state)
        guard state.drafts.values.allSatisfy({ $0.count <= 2_000 }) else {
            throw StorageError.draftTooLong
        }
        try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONEncoder().encode(state).write(to: fileURL, options: [.atomic, .completeFileProtection])
        return state
    }
}

@MainActor enum TotiEditorialPreferences {
    static func storage() throws -> TotiEditorialPreferenceStorage {
        guard let account = TotiBackend.shared.accountID else { throw TotiBackendError.sessionRequired }
        let root = URL.applicationSupportDirectory
            .appendingPathComponent(TotiBackendConfiguration.onlineDirectory, isDirectory: true)
            .appendingPathComponent("EditorialPreferences", isDirectory: true)
            .appendingPathComponent(account.uuidString, isDirectory: true)
        return TotiEditorialPreferenceStorage(fileURL: root.appendingPathComponent("preferences-v1.json"))
    }

    static func visiblePosts(_ posts: [OnlineEditorialPost], onlyFollowed: Bool = false) throws -> [OnlineEditorialPost] {
        let state = try storage().read()
        return posts.filter {
            !state.blockedAuthorIDs.contains($0.editorialAuthor.id)
                && (!onlyFollowed || state.followedAuthorIDs.contains($0.editorialAuthor.id))
        }
    }
}

final class TotiEditorialPreferencesController: StackScreen {
    override func refresh() {
        guard isViewLoaded, isAccountContextCurrent else { return }
        clear()
        title = "Editorial preferences"
        content.addArrangedSubview(label("Follow and block preferences apply to this account on this device. Open an author to change them.", 14, TotiTheme.muted))
        do {
            let state = try TotiEditorialPreferences.storage().read()
            let authors = TotiEditorialAuthor.allAuthors
            for author in authors {
                let blocked = state.blockedAuthorIDs.contains(author.id)
                let following = state.followedAuthorIDs.contains(author.id)
                let row = stack([TotiPhoto(asset: author.portraitAsset, size: 44, round: true),
                    stack([label(author.name, 18, title: true),
                           label(blocked ? "Blocked" : following ? "Following" : "Not following", 13, TotiTheme.muted)], spacing: 4)], axis: .horizontal, spacing: 12)
                row.alignment = .center
                content.addArrangedSubview(totiCoverButton(row, label: "View " + author.name + "'s profile",
                    identifier: "editorial.preferences." + author.id) { [weak self] in
                    guard let self, self.isAccountContextCurrent else { return }
                    self.push(TotiEditorialProfileController(store: self.store, author: author))
                })
            }
        } catch {
            content.addArrangedSubview(label("Editorial preferences could not be read. Your saved data has been kept.", 14, TotiTheme.muted))
            content.addArrangedSubview(actionButton("Try again", icon: .refresh) { [weak self] in self?.refresh() })
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if isViewLoaded { refresh() }
    }
}

/// One detail route for editorial content and its real, authenticated Guest activity.
final class TotiEditorialDetailController: StackScreen, UITextViewDelegate {
    private var post: OnlineEditorialPost
    private let artwork: String
    private let article = stack(), discussion = stack(), editor = UITextView()
    private let counter = UILabel()
    private var sendButton: StudioButton?
    private var comments: [EditorialActivityComment] = []
    private var cursor: EditorialCommentCursor?
    private var loaded = false, busy = false
    private var loadError: String?
    private var pendingComment: (text: String, id: UUID)?

    init(store: AppStore, post: OnlineEditorialPost, asset: String) {
        self.post = post
        artwork = asset
        super.init(store: store, title: "Post")
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }

    override func build() {
        super.build()
        scroll.accessibilityIdentifier = "editorial.post." + post.id.uuidString
        navigationItem.rightBarButtonItem = barButton(iconButton(.more, "Post options") { [weak self] in self?.showOptions() })
        article.spacing = 14; discussion.spacing = 12
        content.addArrangedSubview(article)
        content.addArrangedSubview(discussion)
        content.addArrangedSubview(label("Your reply", 22, title: true))
        editor.font = TotiTheme.font(16)
        editor.textColor = TotiTheme.ink; editor.backgroundColor = .white; editor.tintColor = TotiTheme.plum
        editor.textContainerInset = UIEdgeInsets(top: 14, left: 12, bottom: 14, right: 12)
        editor.rounded(16); editor.height(110); editor.delegate = self
        editor.accessibilityLabel = "Write a reply"
        editor.accessibilityIdentifier = "editorial.reply.editor"
        content.addArrangedSubview(editor)
        counter.font = TotiTheme.font(12); counter.textColor = TotiTheme.muted
        content.addArrangedSubview(counter)
        let send = actionButton("Post reply", icon: .send, primary: true) { [weak self] in self?.submit() }
        send.accessibilityIdentifier = "editorial.reply.send"; sendButton = send
        content.addArrangedSubview(send)
        content.addArrangedSubview(label("Replies are free and shared with other members after saving online.", 12, TotiTheme.muted))
        textViewDidChange(editor)
    }
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if !loaded && !busy { perform() }
    }
    override func refresh() {
        guard isViewLoaded, isAccountContextCurrent else { return }
        if let current = store.onlineEditorialPosts.first(where: { $0.id == post.id }) { post = current }
        article.arrangedSubviews.forEach { $0.removeFromSuperview() }
        discussion.arrangedSubviews.forEach { $0.removeFromSuperview() }
        let author = post.editorialAuthor
        guard let preferences = try? TotiEditorialPreferences.storage().read() else {
            article.addArrangedSubview(label("Editorial preferences could not be read. Reopen this post to try again."))
            editor.isEditable = false; sendButton?.isEnabled = false; return
        }
        guard !preferences.blockedAuthorIDs.contains(author.id) else {
            article.addArrangedSubview(label("This author's posts are hidden. Unblock them from Blocked in Settings."))
            editor.isEditable = false; sendButton?.isEnabled = false; return
        }
        editor.isEditable = true
        let portrait = TotiPhoto(asset: author.portraitAsset, size: 44, round: true)
        let identity = stack([portrait, stack([label(author.name, 17, title: true),
            label(editorialDate(post.created_at), 11, TotiTheme.muted)], spacing: 3)], axis: .horizontal, spacing: 10)
        identity.alignment = .center
        let openAuthor = totiCoverButton(identity, label: "View " + author.name + "'s profile",
            identifier: "editorial.detail.author") { [weak self] in
                guard let self, self.isAccountContextCurrent else { return }
                self.push(TotiEditorialProfileController(store: self.store, author: author))
            }
        let follow = actionButton(preferences.followedAuthorIDs.contains(author.id) ? "Following" : "Follow", compact: true) { [weak self] in self?.toggleFollow() }
        follow.accessibilityIdentifier = "editorial.detail.follow"
        let accessibleLayout = traitCollection.preferredContentSizeCategory.isAccessibilityCategory
        let header = stack([openAuthor, follow], axis: accessibleLayout ? .vertical : .horizontal, spacing: 10)
        header.alignment = accessibleLayout ? .fill : .center
        if !accessibleLayout { follow.widthAnchor.constraint(equalToConstant: 110).isActive = true }
        article.addArrangedSubview(header)
        let report = actionButton("Report post", icon: .flag, compact: true) { [weak self] in self?.openReport(targetID: nil) }
        report.accessibilityIdentifier = "post.safety.report"
        let block = actionButton("Block author", icon: .block, compact: true) { [weak self] in self?.blockPostAuthor() }
        block.accessibilityIdentifier = "post.safety.block"
        let safety = stack([report, block], axis: accessibleLayout ? .vertical : .horizontal, spacing: 8)
        safety.distribution = .fillEqually
        article.addArrangedSubview(safety)
        article.addArrangedSubview(label("TOTI EDITORIAL", 11, TotiTheme.plum))
        article.addArrangedSubview(label(post.topic.uppercased(), 12, TotiTheme.muted))
        article.addArrangedSubview(label(post.title, 26, title: true))
        let photo = TotiPhoto(asset: artwork)
        photo.contentMode = .scaleAspectFit; photo.height(280); photo.rounded(18)
        photo.isAccessibilityElement = true; photo.accessibilityLabel = "Photo attached to post"
        article.addArrangedSubview(photo)
        if let credit = editorialPhotoCredit(asset: artwork) {
            article.addArrangedSubview(actionButton("Photo · " + (credit.author ?? "View source"), icon: .info, compact: true) {
                guard let url = URL(string: credit.sourceURL), url.scheme == "https" else { return }
                UIApplication.shared.open(url)
            })
        }
        article.addArrangedSubview(label(post.body, 19))
        let counts = label(postDetailCounts(likes: post.like_count ?? 0, saves: post.save_count ?? 0, replies: post.comment_count ?? 0), 13, TotiTheme.muted)
        counts.accessibilityIdentifier = "editorial.detail.counts"; article.addArrangedSubview(counts)
        let like = actionButton(post.liked == true ? "Liked" : "Like", icon: post.liked == true ? .heartFill : .heartOutline,
                                tone: post.liked == true ? .coral : .quiet, axis: .vertical, compact: true, iconSize: 20) { [weak self] in
            guard let self else { return }; self.perform(action: "like", payload: ["enabled": .bool(self.post.liked != true)])
        }
        like.accessibilityIdentifier = "editorial.detail.like"; like.isEnabled = loaded && !busy
        let save = actionButton(post.saved == true ? "Saved" : "Save", icon: post.saved == true ? .starFill : .bookmark,
                                tone: post.saved == true ? .coral : .quiet, axis: .vertical, compact: true, iconSize: 20) { [weak self] in
            guard let self else { return }; self.perform(action: "save", payload: ["enabled": .bool(self.post.saved != true)])
        }
        save.accessibilityIdentifier = "editorial.detail.save"; save.isEnabled = loaded && !busy
        let reply = actionButton("Comment", icon: .comment, axis: .vertical, compact: true, iconSize: 20) { [weak self] in self?.focusReply() }
        reply.accessibilityIdentifier = "editorial.detail.comment"
        let share = actionButton("Share", icon: .share, axis: .vertical, compact: true, iconSize: 20) { [weak self] in
            guard let self, self.isAccountContextCurrent else { return }
            self.presentScreen(PostShareController(store: self.store,
                content: PostShareContent(id: self.post.id, editorial: true, title: self.post.title, body: self.post.body)))
        }
        share.accessibilityIdentifier = "editorial.detail.share"
        let actions = stack([like, reply, save, share], axis: traitCollection.preferredContentSizeCategory.isAccessibilityCategory ? .vertical : .horizontal, spacing: 5)
        actions.distribution = .fillEqually; article.addArrangedSubview(actions)
        article.addArrangedSubview(label("Editorial story and illustrative photography. The author is not a member account; replies and reactions below are real member activity. Follow preferences stay on this device.", 12, TotiTheme.muted))
        article.addArrangedSubview(actionButton("Report or block", icon: .flag, compact: true) { [weak self] in self?.showOptions() })
        discussion.addArrangedSubview(label("Discussion · \(post.comment_count ?? 0)", 23, title: true))
        if busy { discussion.addArrangedSubview(label("Loading…", 13, TotiTheme.muted)) }
        if let error = loadError {
            discussion.addArrangedSubview(label(error, 14, TotiTheme.dangerInk))
            discussion.addArrangedSubview(actionButton("Try again", icon: .refresh) { [weak self] in self?.perform() })
        } else if loaded && comments.isEmpty { discussion.addArrangedSubview(label("Be the first to add a thought.", 15, TotiTheme.muted)) }
        if let cursor {
            let more = actionButton("Load earlier replies", icon: .refresh) { [weak self] in self?.perform(payload: cursor.payload, earlier: true) }
            more.isEnabled = !busy; discussion.addArrangedSubview(more)
        }
        for comment in comments.reversed() where !store.isCreatorBlocked(comment.author_id.uuidString.lowercased()) {
            discussion.addArrangedSubview(commentCard(comment))
        }
        let refresh = actionButton("Refresh discussion", icon: .refresh, compact: true) { [weak self] in self?.perform() }
        refresh.isEnabled = !busy; discussion.addArrangedSubview(refresh)
        textViewDidChange(editor)
    }
    private func commentCard(_ comment: EditorialActivityComment) -> UIView {
        let creator = store.onlineCreator(comment.author_id)
        let photo = TotiPhoto(asset: creator.avatarAsset, size: 36, round: true)
        if creator.isLocalOwner { store.configureOwnerAvatar(photo) }
        let author = totiCoverButton(stack([photo, label(creator.name, 15, title: true)], axis: .horizontal),
            label: "View " + creator.name + "'s profile", identifier: "editorial.comment.author." + comment.id.uuidString) { [weak self] in
                guard let self, self.isAccountContextCurrent else { return }
                self.push(CreatorController(store: self.store, creator: creator))
            }
        let text = label(comment.body, 16); text.accessibilityIdentifier = "editorial.comment." + comment.id.uuidString
        var rows: [UIView] = [author, text, label(editorialDate(comment.created_at), 11, TotiTheme.muted)]
        if creator.isLocalOwner {
            rows.append(actionButton("Delete reply", icon: .trash, compact: true) { [weak self] in
                self?.confirm("Delete this reply?", message: "This removes your reply from the discussion.", destructive: true, button: "Delete") {
                    self?.perform(action: "delete_comment", payload: ["id": .string(comment.id.uuidString)])
                }
            })
        } else {
            rows.append(actionButton("Reply", icon: .comment, compact: true) { [weak self] in
                guard let self, self.isAccountContextCurrent else { return }
                if self.editor.text.isEmpty { self.editor.text = "@" + creator.name + " " }
                self.textViewDidChange(self.editor); self.focusReply()
            })
            rows.append(actionButton("Report or block", icon: .flag, compact: true) { [weak self] in
                guard let self, self.isAccountContextCurrent else { return }
                self.showCard([actionButton("Report reply", icon: .flag) { [weak self] in
                    self?.dismissCard { self?.openReport(targetID: comment.id) }
                }, actionButton("Block " + creator.name, icon: .block, tone: .danger) { [weak self] in
                    self?.dismissCard {
                        self?.confirm("Block " + creator.name + "?", message: "Their content and messages will be hidden.", destructive: true, button: "Block") {
                            guard let self, self.isAccountContextCurrent else { return }
                            self.save { await self.store.blockCreator(creator) }
                        }
                    }
                }])
            })
        }
        return postDetailPaper(rows)
    }
    private func perform(action: String = "read", payload: [String: JSONValue] = [:], earlier: Bool = false) {
        guard isAccountContextCurrent, !busy else { return }
        busy = true; loadError = nil; refresh()
        let request = action == "read" ? nil : UUID()
        Task { [weak self] in
            guard let self else { return }
            do {
                let result = try await TotiBackend.shared.editorialActivity(postID: self.post.id, action: action, payload: payload, requestID: request)
                guard self.isAccountContextCurrent else { return }
                self.post = result.post
                if action == "read" || action == "comment" || action == "delete_comment" {
                    self.comments = earlier ? self.comments + result.comments.filter { item in !self.comments.contains(where: { $0.id == item.id }) } : result.comments
                    self.cursor = result.next_cursor
                }
                self.loaded = true; self.busy = false
                if action == "comment", self.editor.text.trimmingCharacters(in: .whitespacesAndNewlines) == payload["body"]?.stringValue {
                    self.editor.text = ""; self.pendingComment = nil; self.view.endEditing(true)
                }
                self.store.applyEditorialActivity(result)
                self.refresh()
            } catch {
                guard self.isAccountContextCurrent else { return }
                self.busy = false; self.loadError = error.localizedDescription; self.refresh()
            }
        }
    }
    private func submit() {
        guard isAccountContextCurrent, loaded, !busy else { return }
        let text = (editor.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if let error = LoungeComment.validationError(text) { message(error); return }
        if pendingComment?.text != text { pendingComment = (text, UUID()) }
        guard let pendingComment else { return }
        perform(action: "comment", payload: ["id": .string(pendingComment.id.uuidString), "body": .string(text)])
    }
    func textViewDidChange(_ textView: UITextView) {
        counter.text = "\(textView.text.count) / 500 characters"
        counter.textColor = textView.text.count > 500 ? TotiTheme.dangerInk : TotiTheme.muted
        sendButton?.isEnabled = isAccountContextCurrent && loaded && !busy && LoungeComment.validationError(textView.text) == nil
    }
    private func focusReply() {
        guard isAccountContextCurrent else { return }
        editor.becomeFirstResponder()
        view.layoutIfNeeded()
        scroll.scrollRectToVisible(editor.convert(editor.bounds, to: scroll).insetBy(dx: 0, dy: -20), animated: !UIAccessibility.isReduceMotionEnabled)
    }
    private func toggleFollow() {
        guard isAccountContextCurrent else { return }
        do {
            let id = post.editorialAuthor.id
            try TotiEditorialPreferences.storage().update {
                if !$0.followedAuthorIDs.insert(id).inserted { $0.followedAuthorIDs.remove(id) }
            }
            store.objectWillChange.send(); refresh()
        } catch { message("Your follow preference could not be saved. Please try again.") }
    }
    private func showOptions() {
        guard isAccountContextCurrent else { return }
        let report = actionButton("Report post", icon: .flag) { [weak self] in self?.dismissCard { self?.openReport(targetID: nil) } }
        report.accessibilityIdentifier = "post.options.report"
        let block = actionButton("Block author", icon: .block, tone: .danger) { [weak self] in self?.dismissCard { self?.blockPostAuthor() } }
        block.accessibilityIdentifier = "post.options.block"
        showCard([label("Post options", 22, title: true), report, block,
            actionButton("Close") { [weak self] in self?.dismissCard() }])
    }
    private func blockPostAuthor() {
        guard isAccountContextCurrent else { return }
        confirm("Block this author?", message: "Their editorial posts will be hidden on this device. Unblock them from Blocked in Settings.", destructive: true, button: "Block") { [weak self] in
            guard let self, self.isAccountContextCurrent else { return }
            do {
                let id = self.post.editorialAuthor.id
                try TotiEditorialPreferences.storage().update { $0.blockedAuthorIDs.insert(id); $0.followedAuthorIDs.remove(id) }
                self.store.objectWillChange.send()
                if let navigation = self.navigationController, navigation.viewControllers.first !== self {
                    navigation.popViewController(animated: true)
                } else { self.dismiss(animated: true) }
            } catch { self.message("The block preference could not be saved.") }
        }
    }
    private func openReport(targetID: UUID?) {
        guard isAccountContextCurrent else { return }
        presentScreen(EditorialReportController(store: store, postID: post.id, targetID: targetID))
    }
}

private struct EditorialPhotoCredit: Decodable {
    let title: String
    let author: String?
    let sourceURL: String
}
private func editorialPhotoCredit(asset: String) -> EditorialPhotoCredit? {
    guard let url = Bundle.main.url(forResource: "MediaCredits", withExtension: "json"),
          let data = try? Data(contentsOf: url), let credits = try? JSONDecoder().decode([EditorialPhotoCredit].self, from: data) else { return nil }
    return credits.first { $0.title.hasSuffix(" · " + asset) }
}
private func editorialDate(_ value: String) -> String {
    let parser = ISO8601DateFormatter(); parser.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    let date = parser.date(from: value) ?? ISO8601DateFormatter().date(from: value)
    return date?.formatted(date: .abbreviated, time: .shortened) ?? ""
}
@MainActor private func postDetailPaper(_ rows: [UIView]) -> UIView {
    let paper = UIView(); paper.backgroundColor = UIColor.white.withAlphaComponent(0.9); paper.rounded(20)
    let column = stack(rows, spacing: 10); paper.addSubview(column)
    column.pin(to: paper, insets: UIEdgeInsets(top: 14, left: 14, bottom: 14, right: 14))
    return paper
}

private final class EditorialReportController: StackScreen {
    let postID: UUID
    let targetID: UUID?
    private let details = UITextView()
    private var reason = ContentReportReason.spam
    private var sending = false
    init(store: AppStore, postID: UUID, targetID: UUID?) {
        self.postID = postID; self.targetID = targetID
        super.init(store: store, title: targetID == nil ? "Report post" : "Report reply")
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }
    override func build() {
        super.build()
        content.addArrangedSubview(label("Choose a reason", 22, title: true))
        let reasons = StudioOptions(items: ContentReportReason.allCases.map(\.rawValue))
        reasons.onChange = { [weak self] in self?.reason = ContentReportReason.allCases[$0] }
        content.addArrangedSubview(reasons)
        details.font = TotiTheme.font(16); details.backgroundColor = .white; details.rounded(14); details.height(110)
        details.accessibilityLabel = "Report details, up to 2,000 characters"
        content.addArrangedSubview(details)
        content.addArrangedSubview(label("Reports are submitted privately. Do not include sensitive personal information.", 13, TotiTheme.muted))
        let send = actionButton("Submit report", icon: .flag, primary: true) { [weak self] in self?.submitReport() }
        send.accessibilityIdentifier = "editorial.report.submit"
        content.addArrangedSubview(send)
    }
    private func submitReport() {
        guard isAccountContextCurrent, !sending else { return }
        guard details.text.count <= 2_000 else { message("Use up to 2,000 characters."); return }
        sending = true; view.isUserInteractionEnabled = false
        let note = details.text ?? ""
        Task { [weak self] in
            guard let self else { return }
            do {
                _ = try await TotiBackend.shared.editorialActivity(postID: self.postID, action: "report",
                    payload: ["target_id": .string((self.targetID ?? self.postID).uuidString),
                              "reason": .string(self.reason.rawValue), "details": .string(note)], requestID: UUID())
                guard self.isAccountContextCurrent else { return }
                self.sending = false; self.view.isUserInteractionEnabled = true
                self.message("Report submitted for review.")
            } catch {
                guard self.isAccountContextCurrent else { return }
                self.sending = false; self.view.isUserInteractionEnabled = true
                self.message("Your report could not be submitted. Please try again.")
            }
        }
    }
}

struct PostShareContent {
    let id: UUID
    let editorial: Bool
    let title: String
    let body: String
    var text: String {
        String(title.prefix(120)) + "\n" + String(body.prefix(1_500)) + "\n\ntoti://" + (editorial ? "editorial-post/" : "post/") + id.uuidString.lowercased()
    }
    static func reference(in text: String) -> (id: UUID, editorial: Bool)? {
        guard let line = text.split(separator: "\n").last, let url = URL(string: String(line)),
              url.scheme == "toti", ["post", "editorial-post"].contains(url.host ?? ""),
              url.user == nil, url.password == nil, url.port == nil, url.query == nil, url.fragment == nil,
              url.pathComponents.count == 2, let id = UUID(uuidString: url.lastPathComponent) else { return nil }
        return (id, url.host == "editorial-post")
    }
}

/// Forwarding is a real chat send and retains the existing mutual-follow/block checks.
final class PostShareController: StackScreen {
    private let postContent: PostShareContent
    private var sending = false
    private var waitingForRefresh = false
    init(store: AppStore, content: PostShareContent) {
        postContent = content
        super.init(store: store, title: "Share post")
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }
    override func refresh() {
        guard isViewLoaded, isAccountContextCurrent else { return }
        clear()
        content.addArrangedSubview(label(postContent.title, 22, title: true))
        content.addArrangedSubview(label("Forward to a friend", 20, title: true))
        let friends = store.chatConversations.filter { friend in
            (friend.kind == .group || store.isMutualChat(friend)) && !store.isCreatorBlocked(friend.creator?.id ?? friend.id)
        }
        if sending { content.addArrangedSubview(label(waitingForRefresh ? "Updating contacts…" : "Sending post…", 14, TotiTheme.muted)) }
        if friends.isEmpty {
            content.addArrangedSubview(label("Follow each other in Chats to forward a post to a friend. Existing group chats also appear here.", 14, TotiTheme.muted))
        }
        for friend in friends {
            let button = actionButton(friend.name, icon: .chats) { [weak self] in
                self?.confirm("Forward this post?", message: "Send to " + friend.name + "?", button: "Send post") { self?.forward(to: friend) }
            }
            button.accessibilityIdentifier = "post.forward." + friend.id
            button.isEnabled = !sending
            content.addArrangedSubview(button)
        }
        content.addArrangedSubview(actionButton("Copy post", icon: .share) { [weak self] in
            guard let self, self.isAccountContextCurrent else { return }
            UIPasteboard.general.string = self.postContent.text
            self.message("Copied.")
        })
        content.addArrangedSubview(actionButton("Share…", icon: .share) { [weak self] in
            guard let self, self.isAccountContextCurrent else { return }
            let sheet = UIActivityViewController(activityItems: [self.postContent.text], applicationActivities: nil)
            sheet.popoverPresentationController?.sourceView = self.view
            self.present(sheet, animated: true)
        })
    }
    private func forward(to friend: MusicConversation) {
        guard isAccountContextCurrent, !sending else { return }
        sending = true; waitingForRefresh = store.isBusy; refresh()
        Task { [weak self] in
            guard let self else { return }
            let deadline = Date().addingTimeInterval(20)
            while self.store.isBusy {
                guard self.isAccountContextCurrent, self.view.window != nil else { return }
                if Date() >= deadline {
                    self.finishForward("Contacts are still updating. The post was not sent. Please try again.")
                    return
                }
                do { try await Task.sleep(nanoseconds: 150_000_000) }
                catch { return }
            }
            guard self.isAccountContextCurrent, self.view.window != nil else { return }
            guard let current = self.store.chatConversations.first(where: { $0.id == friend.id }),
                  current.kind == .group || self.store.isMutualChat(current),
                  self.store.canSendChatMessage(current),
                  !self.store.isCreatorBlocked(current.creator?.id ?? current.id) else {
                self.finishForward("This conversation is unavailable. Follow each other or refresh Chats before trying again.")
                return
            }
            self.waitingForRefresh = false; self.refresh()
            let sent = await self.store.sendChatMessage(self.postContent.text, to: current)
            guard self.isAccountContextCurrent else { return }
            self.finishForward(sent ? "Post sent to " + current.name + "." : (self.store.lastSaveError ?? "The post could not be sent. Please try again."))
        }
    }
    private func finishForward(_ status: String) {
        guard isAccountContextCurrent else { return }
        sending = false; waitingForRefresh = false; refresh()
        if view.window != nil { message(status) }
    }

}

@MainActor extension TotiScreen {
    func openSharedPost(id: UUID, editorial: Bool) {
        guard isAccountContextCurrent else { return }
        if editorial {
            guard let post = (try? TotiEditorialPreferences.visiblePosts(store.onlineEditorialPosts))?.first(where: { $0.id == id }) else {
                message("This post is unavailable. Refresh Lounge and try again."); return
            }
            push(TotiEditorialDetailController(store: store, post: post, asset: post.photo_asset ?? "MusicStudioBackdrop"))
        } else {
            guard store.loungePost(id) != nil else {
                if store.isOnlineMode {
                    Task { [weak self] in
                        guard let self else { return }
                        await self.store.loadOnlineThread(kind: "comment", parentID: id.uuidString)
                        guard self.isAccountContextCurrent else { return }
                        if self.store.loungePost(id) != nil { self.push(LoungeDetailController(store: self.store, postID: id)) }
                        else { self.message("This post is no longer available.") }
                    }
                } else { message("This post is no longer available.") }
                return
            }
            push(LoungeDetailController(store: store, postID: id))
        }
    }
}

func postDetailCounts(likes: Int, saves: Int, replies: Int) -> String {
    "\(likes) " + (likes == 1 ? "like" : "likes") + " · \(saves) " + (saves == 1 ? "save" : "saves")
        + " · \(replies) " + (replies == 1 ? "reply" : "replies")
}

// Stable room identities share authored profiles with their published editorial works.
extension TotiEditorialAuthor {
    static let voiceAuthors: [String: TotiEditorialAuthor] = [
        "PortraitVoiceAvery": .init(id: "voice-avery", name: "Avery", portraitAsset: "PortraitVoiceAvery", biography: "Pop hooks, late buses and headphones on the way home."),
        "PortraitVoiceEmma": .init(id: "voice-emma", name: "Emma", portraitAsset: "PortraitVoiceEmma", biography: "Live vocals and the quiet minute before a chorus."),
        "PortraitVoiceChloe": .init(id: "voice-chloe", name: "Chloe", portraitAsset: "PortraitVoiceChloe", biography: "Building a listening shelf, one record at a time."),
        "PortraitVoiceOliver": .init(id: "voice-oliver", name: "Oliver", portraitAsset: "PortraitVoiceOliver", biography: "Soul records, warm bass and unhurried evenings."),
        "PortraitVoiceLiam": .init(id: "voice-liam", name: "Liam", portraitAsset: "PortraitVoiceLiam", biography: "Guitar sketches and songs with room to breathe."),
        "PortraitVoiceJack": .init(id: "voice-jack", name: "Jack", portraitAsset: "PortraitVoiceJack", biography: "Mostly here to listen and discover new voices."),
        "PortraitVoiceSophie": .init(id: "voice-sophie", name: "Sophie", portraitAsset: "PortraitVoiceSophie", biography: "Jazz piano, loose timing and conversations after the set."),
        "PortraitVoiceGrace": .init(id: "voice-grace", name: "Grace", portraitAsset: "PortraitVoiceGrace", biography: "Bass lines, tiny venues and generous rhythm sections."),
        "PortraitVoiceElla": .init(id: "voice-ella", name: "Ella", portraitAsset: "PortraitVoiceElla", biography: "Brass melodies and records for rainy afternoons."),
        "PortraitVoiceMia": .init(id: "voice-mia", name: "Mia", portraitAsset: "PortraitVoiceMia", biography: "Acoustic guitar and words scribbled between chords."),
        "PortraitVoiceRuby": .init(id: "voice-ruby", name: "Ruby", portraitAsset: "PortraitVoiceRuby", biography: "Collecting ideas before sharing a first song."),
        "PortraitVoiceLucy": .init(id: "voice-lucy", name: "Lucy", portraitAsset: "PortraitVoiceLucy", biography: "Folk harmonies, fingerpicking and Sunday rehearsals."),
        "PortraitVoiceHazel": .init(id: "voice-hazel", name: "Hazel", portraitAsset: "PortraitVoiceHazel", biography: "Piano miniatures and small changes in a familiar melody."),
        "PortraitVoiceNoah": .init(id: "voice-noah", name: "Noah", portraitAsset: "PortraitVoiceNoah", biography: "Learning to hear the space between notes."),
        "PortraitVoiceLucas": .init(id: "voice-lucas", name: "Lucas", portraitAsset: "PortraitVoiceLucas", biography: "Strings, acoustic sessions and melodies without a deadline."),
        "PortraitVoiceTheo": .init(id: "voice-theo", name: "Theo", portraitAsset: "PortraitVoiceTheo", biography: "Drum machines, soft synths and sounds from the street."),
        "PortraitVoiceFinn": .init(id: "voice-finn", name: "Finn", portraitAsset: "PortraitVoiceFinn", biography: "Electronic textures and finding a groove in repetition."),
        "PortraitVoiceOwen": .init(id: "voice-owen", name: "Owen", portraitAsset: "PortraitVoiceOwen", biography: "Listening first. A few unfinished ideas for later."),
    ]
    static let voicePostAuthors: [String: TotiEditorialAuthor] = [
        "8cba132e-766b-55e8-a935-6ea3e5559a5d": voiceAuthors["PortraitVoiceAvery"]!,
        "38575e18-05f1-5c01-b465-c085f281b6e8": voiceAuthors["PortraitVoiceAvery"]!,
        "66e80c10-ad26-551a-ae87-0d2838a0ec36": voiceAuthors["PortraitVoiceEmma"]!,
        "b77a95c1-66de-5871-b83a-20586ed0a89e": voiceAuthors["PortraitVoiceOliver"]!,
        "6c5013b1-7ebd-5ed7-9123-826ce2c1fb17": voiceAuthors["PortraitVoiceLiam"]!,
        "ac2b3e08-5e6a-502c-8d5c-b606b373b38e": voiceAuthors["PortraitVoiceLiam"]!,
        "40b53b81-362f-5943-afe5-7ebe2eb56f8a": voiceAuthors["PortraitVoiceSophie"]!,
        "6fa04482-b1e2-5013-a854-c0b6bb0a80df": voiceAuthors["PortraitVoiceSophie"]!,
        "0afb1e84-26af-5718-9f78-bc7ba2d5fb04": voiceAuthors["PortraitVoiceGrace"]!,
        "73f082b2-6926-54f1-b1a0-63631428b5c7": voiceAuthors["PortraitVoiceElla"]!,
        "e95be06f-503a-5adc-b1e9-4c66ccb2ec9d": voiceAuthors["PortraitVoiceMia"]!,
        "da77fe29-1a98-58f7-827a-0bae0f1b68a6": voiceAuthors["PortraitVoiceLucy"]!,
        "e717fbae-9103-5de3-bd85-9def0df97ed3": voiceAuthors["PortraitVoiceLucy"]!,
        "46614ba1-ffad-547f-af28-9b16568a43ba": voiceAuthors["PortraitVoiceHazel"]!,
        "43ab7c40-0eef-531a-a5b6-65cd9e4cbbb3": voiceAuthors["PortraitVoiceLucas"]!,
        "eef6085b-9725-5bcb-89de-cbd2b09645d4": voiceAuthors["PortraitVoiceTheo"]!,
        "baf51159-7f87-5ef1-9585-ca5fa147f4e7": voiceAuthors["PortraitVoiceTheo"]!,
        "67bab46c-38f6-5f73-b829-c503bbc8bcb3": voiceAuthors["PortraitVoiceFinn"]!,
    ]
    static let voiceFigures: [String: CreatorStatistics] = [
        "voice-avery": .init(likes: 23, saves: 3, following: 18, followers: 17),
        "voice-emma": .init(likes: 40, saves: 10, following: 42, followers: 46),
        "voice-chloe": .init(likes: 0, saves: 0, following: 7, followers: 75),
        "voice-oliver": .init(likes: 74, saves: 24, following: 61, followers: 104),
        "voice-liam": .init(likes: 91, saves: 31, following: 29, followers: 133),
        "voice-jack": .init(likes: 0, saves: 0, following: 12, followers: 162),
        "voice-sophie": .init(likes: 125, saves: 45, following: 84, followers: 191),
        "voice-grace": .init(likes: 142, saves: 3, following: 36, followers: 220),
        "voice-ella": .init(likes: 159, saves: 10, following: 23, followers: 9),
        "voice-mia": .init(likes: 176, saves: 17, following: 47, followers: 38),
        "voice-ruby": .init(likes: 0, saves: 0, following: 5, followers: 67),
        "voice-lucy": .init(likes: 20, saves: 31, following: 58, followers: 96),
        "voice-hazel": .init(likes: 37, saves: 38, following: 31, followers: 125),
        "voice-noah": .init(likes: 0, saves: 0, following: 9, followers: 154),
        "voice-lucas": .init(likes: 71, saves: 3, following: 64, followers: 183),
        "voice-theo": .init(likes: 88, saves: 10, following: 73, followers: 212),
        "voice-finn": .init(likes: 105, saves: 17, following: 26, followers: 1),
        "voice-owen": .init(likes: 0, saves: 0, following: 4, followers: 30),
    ]
    static var allAuthors: [TotiEditorialAuthor] {
        Dictionary((Array(catalog.values) + Array(voiceAuthors.values)).map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first }).values.sorted { $0.name < $1.name }
    }
}

// Material rooms have no member owner. Their safety preferences stay account-scoped on device.
extension TotiScreen {
    @discardableResult
    func appendEditorialRoomSafety(to content: UIStackView, reporting: Bool) -> Bool {
        guard store.isOnlineMode else { return false }
        do {
            let state = try TotiEditorialPreferences.storage().read()
            let titles = reporting ? (state.roomReports ?? [:]).mapValues(\.title) : (state.blockedRoomTitles ?? [:])
            guard !titles.isEmpty else { return false }
            content.addArrangedSubview(label(reporting ? "Room reports saved on this device" : "Blocked room artwork", 20, title: true))
            for (id, title) in titles.sorted(by: { $0.value < $1.value }) {
                if reporting, let report = state.roomReports?[id] {
                    content.addArrangedSubview(label(title + " · " + report.reason.rawValue + "\nNot submitted for online review.", 14, TotiTheme.muted))
                }
                let action = reporting ? "Remove report" : "Unblock"
                let button = actionButton(action + " · " + title, icon: reporting ? .flag : .block) { [weak self] in
                    guard let self, self.isAccountContextCurrent else { return }
                    self.confirm(action + "?", message: "This room can appear again unless another safety preference hides it. This change stays on this device.", button: action) { [weak self] in
                        guard let self, self.isAccountContextCurrent else { return }
                        do {
                            try TotiEditorialPreferences.storage().update {
                                if reporting { $0.roomReports?[id] = nil }
                                else { $0.blockedRoomTitles?[id] = nil }
                            }
                            self.store.objectWillChange.send()
                            self.refresh()
                        } catch { self.message("Your change could not be saved. Please try again.") }
                    }
                }
                button.accessibilityIdentifier = (reporting ? "voice.report.remove." : "voice.block.remove.") + id
                content.addArrangedSubview(button)
            }
            return true
        } catch {
            content.addArrangedSubview(label("Room safety preferences could not be read. Your saved data has been kept.", 14, TotiTheme.muted))
            return true
        }
    }
}

extension TotiScreen {
    @discardableResult
    func appendBlockedEditorialAuthors(to content: UIStackView) -> Bool {
        guard store.isOnlineMode else { return false }
        do {
            let state = try TotiEditorialPreferences.storage().read()
            let authors = TotiEditorialAuthor.allAuthors.filter { state.blockedAuthorIDs.contains($0.id) }
            guard !authors.isEmpty else { return false }
            content.addArrangedSubview(label("Blocked editorial authors", 20, title: true))
            for author in authors {
                let button = actionButton("Unblock · " + author.name, icon: .block) { [weak self] in
                    guard let self, self.isAccountContextCurrent else { return }
                    self.confirm("Unblock " + author.name + "?", message: "Their editorial posts will appear again on this device. Following is not restored automatically.", button: "Unblock") { [weak self] in
                        guard let self, self.isAccountContextCurrent else { return }
                        do {
                            try TotiEditorialPreferences.storage().update { $0.blockedAuthorIDs.remove(author.id) }
                            self.store.objectWillChange.send(); self.refresh()
                        } catch { self.message("Your change could not be saved. Please try again.") }
                    }
                }
                button.accessibilityIdentifier = "editorial.block.remove." + author.id
                content.addArrangedSubview(button)
            }
            return true
        } catch { return false } // The room preference section already displays a shared-file read error.
    }
}
