import PhotosUI
import UIKit
import UniformTypeIdentifiers

final class CreationController: StackScreen, PHPickerViewControllerDelegate {
  let kind: CreationKind
  private let name = field("Title"), caption = field("Tell us about your sound")
  private let mediaLabel = label("", 14, TotiTheme.muted)
  private let category = StudioChoice(items: PartyCategory.allCases.map(\.title))
  private let consent = StudioSwitch()
  private var temporaryVideo: URL?, coverData: Data?, selecting = false
  init(store: AppStore, kind: CreationKind) {
    self.kind = kind
    super.init(store: store, title: kind.title)
  }
  required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }
  override func build() {
    super.build()
    content.addArrangedSubview(
      label(
        kind == .live ? "Share the next session." : "Every voice tells a story.", 27, title: true))
    content.addArrangedSubview(name)
    content.addArrangedSubview(caption)
    content.addArrangedSubview(category)
    content.addArrangedSubview(
      actionButton(
        kind == .live ? "Choose a cover" : "Choose a music video",
        icon: kind == .live ? .photo : .shorts
      ) { [weak self] in self?.chooseMedia() })
    content.addArrangedSubview(mediaLabel)
    if kind == .shortVideo {
      content.addArrangedSubview(
        label("Music videos up to 3 minutes and 250 MB.", 13, TotiTheme.muted))
    }
    let row = stack(
      [label("This is music content and I have permission to share it.", 14), consent],
      axis: .horizontal)
    row.alignment = .center
    consent.accessibilityLabel = "This is music content and I have permission to share it."
    content.addArrangedSubview(row)
    content.addArrangedSubview(
      actionButton("Submit for review", icon: .send, primary: true) { [weak self] in
        self?.submitContent()
      })
    mediaLabel.text =
      kind == .live ? "Choose a cover for your session." : "Choose your video to continue."
  }
  private func chooseMedia() {
    guard !selecting, !store.isBusy else { return }
    var configuration = PHPickerConfiguration(photoLibrary: .shared())
    configuration.filter = kind == .live ? .images : .videos
    configuration.selectionLimit = 1
    configuration.preferredAssetRepresentationMode = .current
    let picker = PHPickerViewController(configuration: configuration)
    picker.delegate = self
    present(picker, animated: true)
  }
  func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
    picker.dismiss(animated: true)
    guard let provider = results.first?.itemProvider else { return }
    selecting = true
    mediaLabel.text = "Opening media…"
    if kind == .live {
      provider.loadDataRepresentation(forTypeIdentifier: UTType.image.identifier) {
        [weak self] data, error in
        Task { @MainActor in
          guard let self else { return }
          self.selecting = false
          guard let data, data.count <= 30 * 1024 * 1024, UIImage(data: data) != nil else {
            self.mediaLabel.text = "Choose another photo."
            return
          }
          self.coverData = data
          self.mediaLabel.text = "Cover selected"
        }
      }
    } else {
      provider.loadFileRepresentation(forTypeIdentifier: UTType.movie.identifier) {
        [weak self] url, error in
        var destination: URL?
        var failure: String?
        do {
          guard let url else { throw LocalLibraryError.importFailed }
          let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
          guard size <= 250 * 1024 * 1024 else { throw LocalLibraryError.videoTooLarge }
          let target = FileManager.default.temporaryDirectory.appendingPathComponent(
            "toti-upload-" + UUID().uuidString
          ).appendingPathExtension(url.pathExtension)
          try FileManager.default.copyItem(at: url, to: target)
          destination = target
        } catch {
          failure =
            (error as? LocalLibraryError)?.errorDescription
            ?? "This video could not be opened. Please choose another video."
        }
        Task { @MainActor in
          guard let self else {
            if let destination { try? FileManager.default.removeItem(at: destination) }
            return
          }
          self.selecting = false
          if let destination {
            if let old = self.temporaryVideo { try? FileManager.default.removeItem(at: old) }
            self.temporaryVideo = destination
            self.mediaLabel.text = "Video selected"
          } else {
            self.mediaLabel.text = failure ?? "This video could not be opened."
          }
        }
      }
    }
  }
  private func submitContent() {
    guard consent.isOn else {
      message("Please confirm this is music content that you have permission to share.")
      return
    }
    guard CreationValidation.valid(title: name.text ?? "", caption: caption.text ?? "") else {
      message(
        "Write a title up to 80 characters and a description up to 500 characters in English.")
      return
    }
    guard !selecting, !store.isBusy, kind == .live || temporaryVideo != nil else {
      message("Choose a music video first.")
      return
    }
    isModalInPresentation = true
    Task {
      let id = await store.queueCreation(
        kind: kind, title: name.text ?? "", caption: caption.text ?? "",
        category: PartyCategory.allCases[max(0, category.index)],
        videoURL: temporaryVideo, coverData: coverData)
      isModalInPresentation = false
      if id != nil {
        dismissCollapsed()
      } else {
        message(store.lastSaveError ?? "Your content could not be saved. Please try again.")
      }
    }
  }
  deinit { if let temporaryVideo { try? FileManager.default.removeItem(at: temporaryVideo) } }
}
