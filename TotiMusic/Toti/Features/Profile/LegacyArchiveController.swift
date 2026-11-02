import CryptoKit
import UIKit

/// Reads the original snapshot as bytes. It intentionally never constructs the
/// legacy repository, whose load method performs migration and orphan cleanup.
@MainActor
final class LegacyArchiveController: UITableViewController {
    private let store: AppStore
    private let accountID: UUID?
    private let generation: Int
    private var notes: [InspirationNote] = []
    private var posts: [LoungePost] = []
    private var failure: String?
    private var importing = false

    init(store: AppStore) {
        self.store = store
        accountID = TotiBackend.shared.accountID
        generation = TotiBackend.shared.generation
        super.init(style: .insetGrouped)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Local archive"
        view.backgroundColor = TotiTheme.background
        tableView.backgroundColor = TotiTheme.background
        let url = URL.applicationSupportDirectory.appendingPathComponent(TotiIdentity.storageDirectory, isDirectory: true)
            .appendingPathComponent("library-v1.json")
        do {
            if FileManager.default.fileExists(atPath: url.path) {
                let data = try Data(contentsOf: url, options: .mappedIfSafe)
                let library = try JSONDecoder().decode(LocalLibrary.self, from: data)
                notes = library.notebook?.notes ?? []
                posts = (library.lounge?.posts ?? []).filter { $0.author.isLocalOwner && !$0.isEditorial }
            }
        } catch {
            failure = "The archive could not be read. Its files have been kept unchanged."
        }
    }

    override func numberOfSections(in tableView: UITableView) -> Int { 2 }
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        section == 0 ? notes.count : posts.count
    }
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        section == 0 ? "Private notes" : "Your posts and drafts"
    }
    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        if section == 0 {
            return failure ?? "Select one item to review before copying it to your account. Original files stay on this device."
        }
        return "Review one post at a time before copying it as a private cloud draft. Photos require explicit confirmation. Historical chats and wallet credits are not transferred."
    }
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .subtitle, reuseIdentifier: nil)
        cell.backgroundColor = UIColor.white
        cell.textLabel?.textColor = TotiTheme.ink
        cell.detailTextLabel?.textColor = TotiTheme.muted
        cell.textLabel?.numberOfLines = 2
        if indexPath.section == 0 {
            cell.textLabel?.text = notes[indexPath.row].displayTitle
            cell.detailTextLabel?.text = "Private note · Review before upload"
        } else {
            let post = posts[indexPath.row]
            cell.textLabel?.text = String(post.body.prefix(100))
            cell.detailTextLabel?.text = (post.photoJPEG == nil && post.photoAsset == nil) ? "Copy as a private draft" : "Contains a photo · Review before upload"
        }
        cell.accessoryType = .disclosureIndicator
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard !importing, accountID == TotiBackend.shared.accountID, generation == TotiBackend.shared.generation else { return }
        if indexPath.section == 1 {
            let post = posts[indexPath.row]
            if post.photoJPEG != nil || post.photoAsset != nil {
                let bytes = post.photoJPEG ?? post.photoAsset.flatMap { UIImage(named: $0)?.jpegData(compressionQuality: 0.9) }
                guard let bytes, let prepared = LoungePhotoImport.normalizedJPEG(bytes), let image = UIImage(data: prepared) else {
                    showMessage("Photo could not be prepared", "This item has not been uploaded. Its original remains in your local archive. Choose a different item or try again.")
                    return
                }
                let preview = ArchivePhotoConsentController(store: store, image: image, body: post.body) { [weak self] in
                    guard let self else { return }
                    Task { @MainActor in await self.copyItem(indexPath, preparedPhoto: prepared) }
                }
                let nav = TotiNavigationController(rootViewController: preview)
                TotiNavigation.style(nav)
                TotiNavigation.prepare(nav, in: view.window?.bounds ?? view.bounds)
                present(nav, animated: true)
                return
            }
        }
        let preview = indexPath.section == 0 ? notes[indexPath.row].body : posts[indexPath.row].body
        let alert = UIAlertController(title: "Copy this item to your account?",
            message: "Only this selected item will be uploaded. The original stays on this device.\n\n" + String(preview.prefix(600)), preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Copy to my account", style: .default) { [weak self] _ in
            Task { @MainActor in await self?.copyItem(indexPath) }
        })
        present(alert, animated: true)
    }

    private func copyItem(_ index: IndexPath, preparedPhoto: Data? = nil) async {
        guard !importing, let accountID, accountID == TotiBackend.shared.accountID,
              generation == TotiBackend.shared.generation else { return }
        importing = true
        defer { importing = false }
        let result: Bool
        if index.section == 0 {
            var note = notes[index.row]
            note.id = importID(account: accountID, source: note.id, kind: "note")
            result = await store.saveNotebookNote(note)
        } else {
            var post = posts[index.row]
            guard (post.photoJPEG == nil && post.photoAsset == nil) || preparedPhoto != nil else { return }
            post.photoJPEG = preparedPhoto
            post.mediaRevisionID = nil
            post.mediaStatus = nil
            post.mediaFeedback = nil
            post.id = importID(account: accountID, source: post.id, kind: "post")
            post.author = store.onlineCreator(accountID)
            post.voiceRoomID = nil
            post.photoAsset = nil
            post.isEditorial = false
            result = await store.saveLoungePost(post, asDraft: true)
        }
        guard generation == TotiBackend.shared.generation else { return }
        showMessage(result ? "Copied to your account" : "Could not copy", result
            ? "Your original item remains in the local archive." : store.lastSaveError ?? "Please try again.")
    }

    private func importID(account: UUID, source: UUID, kind: String) -> UUID {
        var bytes = Array(SHA256.hash(data: Data((account.uuidString + ":" + kind + ":" + source.uuidString).utf8)).prefix(16))
        bytes[6] = (bytes[6] & 0x0f) | 0x50
        bytes[8] = (bytes[8] & 0x3f) | 0x80
        let text = bytes.map { String(format: "%02x", $0) }.joined()
        let groups = [String(text.prefix(8)), String(text.dropFirst(8).prefix(4)), String(text.dropFirst(12).prefix(4)),
                      String(text.dropFirst(16).prefix(4)), String(text.dropFirst(20))]
        return UUID(uuidString: groups.joined(separator: "-"))!
    }

    private func showMessage(_ title: String, _ message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}

/// Consent applies only to the selected preview, never to other archive items.
private final class ArchivePhotoConsentController: StackScreen {
    private let photo: UIImage
    private let body: String
    private let copySelected: () -> Void
    private var confirmed = false

    init(store: AppStore, image: UIImage, body: String, copySelected: @escaping () -> Void) {
        photo = image
        self.body = body
        self.copySelected = copySelected
        super.init(store: store, title: "Review selected photo")
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }

    override func build() {
        super.build()
        let preview = TotiPhoto()
        preview.image = photo
        preview.rounded(18)
        preview.height(240)
        preview.isAccessibilityElement = true
        preview.accessibilityLabel = "Selected local archive photo"
        content.addArrangedSubview(preview)
        content.addArrangedSubview(label(String(body.prefix(1_000)), 16))
        content.addArrangedSubview(label("Only this selected post and photo will be uploaded to your account as a private cloud draft. The photo will be reviewed before it can appear in a published post. Your original archive and Photos files stay on this device.", 15, TotiTheme.muted))
        content.addArrangedSubview(actionButton("Upload selected item as private draft", icon: .check, primary: true) { [weak self] in
            guard let self, self.isAccountContextCurrent, !self.confirmed else { return }
            self.confirmed = true
            self.dismiss(animated: true) { self.copySelected() }
        })
        content.addArrangedSubview(actionButton("Keep in archive", icon: .close) { [weak self] in self?.dismiss(animated: true) })
    }
    override func refresh() { /* Preserve the selected preview while awaiting consent. */ }
}
