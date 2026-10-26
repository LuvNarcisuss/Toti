import AVFoundation
import Foundation
import ImageIO
import UIKit

actor LocalLibraryRepository {
    private let root: URL
    private var media: URL { root.appendingPathComponent("Media", isDirectory: true) }
    private var snapshotURL: URL { root.appendingPathComponent("library-v1.json") }

    init(root: URL) { self.root = root }

    func load() throws -> LocalLibrary {
        try finishPendingAccountDeletion()
        try migrateExistingLibraryIfNeeded()
        try prepareDirectory()
        let data: Data
        do {
            data = try Data(contentsOf: snapshotURL)
        } catch let error as NSError where error.domain == NSCocoaErrorDomain && error.code == NSFileReadNoSuchFileError {
            let empty = LocalLibrary()
            removeOrphanedMedia(library: empty)
            return empty
        } catch {
            throw LocalLibraryError.unreadableLibrary
        }
        let library: LocalLibrary
        do { library = try JSONDecoder().decode(LocalLibrary.self, from: data) }
        catch { throw LocalLibraryError.unreadableLibrary }
        guard library.schemaVersion == 1 else { throw LocalLibraryError.unsupportedVersion }
        guard Set(library.videos.map(\.id)).count == library.videos.count,
              Set(library.roomDrafts.map(\.id)).count == library.roomDrafts.count,
              library.videos.allSatisfy({ ["mp4", "mov", "m4v"].contains($0.fileExtension)
                  && $0.duration.isFinite && $0.duration > 0 && $0.duration <= 1_800 }),
              library.roomDrafts.allSatisfy({ [4, 6, 8].contains($0.seatCount) }) else {
            throw LocalLibraryError.unreadableLibrary
        }
        let submissions = library.submissions ?? []
        let videoIDs = Set(library.videos.map(\.id))
        let pendingVideoIDs = submissions.compactMap(\.videoID)
        guard Set(submissions.map(\.id)).count == submissions.count,
              Set(pendingVideoIDs).count == pendingVideoIDs.count,
              submissions.allSatisfy({ submission in
                  switch submission.kind {
                  case .live: return submission.videoID == nil
                  case .shortVideo: return submission.videoID.map { videoIDs.contains($0) } == true && !submission.hasCover
                  }
              }) else { throw LocalLibraryError.unreadableLibrary }
        if let book = library.phraseBook {
            let catalogIDs = Set(DancePhraseCatalog.phrases.map(\.id))
            if book.validationError(catalogIDs: catalogIDs) != nil {
                throw LocalLibraryError.unreadableLibrary
            }
        }
        removeOrphanedMedia(library: library)
        return library
    }

    func save(_ library: LocalLibrary) throws {
        do {
            try prepareDirectory()
            let data = try JSONEncoder().encode(library)
            try data.write(to: snapshotURL, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        } catch { throw LocalLibraryError.storageUnavailable }
    }

    private var walletURL: URL { root.appendingPathComponent("wallet-v1.json") }

    /// A missing wallet file is an empty ledger. A present file that cannot be read is left in place.
    func loadWallet() throws -> WalletLedger {
        let data: Data
        do {
            data = try Data(contentsOf: walletURL)
        } catch let error as NSError where error.domain == NSCocoaErrorDomain && error.code == NSFileReadNoSuchFileError {
            return .empty
        } catch {
            throw LocalLibraryError.unreadableLibrary
        }
        let ledger: WalletLedger
        do { ledger = try JSONDecoder().decode(WalletLedger.self, from: data) }
        catch { throw LocalLibraryError.unreadableLibrary }
        guard ledger.isValid else { throw LocalLibraryError.unreadableLibrary }
        return ledger
    }

    func saveWallet(_ ledger: WalletLedger) throws {
        guard ledger.isValid else { throw LocalLibraryError.storageUnavailable }
        do {
            try prepareDirectory()
            let data = try JSONEncoder().encode(ledger)
            try data.write(to: walletURL, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        } catch { throw LocalLibraryError.storageUnavailable }
    }

    // A durable marker prevents interrupted deletion from restoring an old library.
    private var deletionMarker: URL {
        root.deletingLastPathComponent().appendingPathComponent(".Toti-account-deletion.pending")
    }

    func deleteLocalAccount() throws {
        do {
            try FileManager.default.createDirectory(at: root.deletingLastPathComponent(), withIntermediateDirectories: true)
            try Data("delete-local-account-v1".utf8).write(to: deletionMarker,
                options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
            try finishPendingAccountDeletion()
        } catch { throw LocalLibraryError.accountDeletionFailed }
    }

    private func finishPendingAccountDeletion() throws {
        let manager = FileManager.default
        guard manager.fileExists(atPath: deletionMarker.path) else { return }
        do {
            // This is only Application Support/Toti, never Photos or bundled resources.
            if manager.fileExists(atPath: root.path) { try manager.removeItem(at: root) }
            try prepareDirectory()
            try save(LocalLibrary())
            // Keep the fresh root so legacy migration cannot bring deleted data back.
            try manager.removeItem(at: deletionMarker)
        } catch { throw LocalLibraryError.accountDeletionFailed }
    }

    /// The caller owns the temporary transfer file and removes it even on failure.
    func importVideo(from source: URL) async throws -> LocalVideo {
        try prepareDirectory()
        let size = try source.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
        guard size > 0 else { throw LocalLibraryError.invalidVideo }
        guard size <= 250 * 1_024 * 1_024 else { throw LocalLibraryError.videoTooLarge }
        let asset = AVURLAsset(url: source)
        let duration = try await asset.load(.duration).seconds
        let tracks = try await asset.loadTracks(withMediaType: .video)
        guard !tracks.isEmpty, duration.isFinite, duration > 0, duration <= 1_800 else {
            throw LocalLibraryError.invalidVideo
        }
        try Task.checkCancellation()
        let suppliedExtension = source.pathExtension.lowercased()
        let ext = ["mp4", "mov", "m4v"].contains(suppliedExtension) ? suppliedExtension : "mov"
        let video = LocalVideo(id: UUID(), title: "Untitled moment", fileExtension: ext,
                               duration: duration, importedAt: Date(), isSaved: false)
        let destination = media.appendingPathComponent("\(video.id.uuidString).\(ext)")
        let cover = media.appendingPathComponent("\(video.id.uuidString).jpg")
        do {
            try FileManager.default.copyItem(at: source, to: destination)
            try FileManager.default.setAttributes([.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication],
                                                  ofItemAtPath: destination.path)
            let generator = AVAssetImageGenerator(asset: asset)
            generator.appliesPreferredTrackTransform = true
            generator.maximumSize = CGSize(width: 900, height: 1_200)
            let frame = try await generator.image(at: CMTime(seconds: min(0.25, duration / 2), preferredTimescale: 600))
            guard let data = UIImage(cgImage: frame.image).jpegData(compressionQuality: 0.8) else {
                throw LocalLibraryError.importFailed
            }
            try Task.checkCancellation()
            try data.write(to: cover, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
            return video
        } catch {
            try? FileManager.default.removeItem(at: destination)
            try? FileManager.default.removeItem(at: cover)
            throw error
        }
    }

    func removeMedia(for video: LocalVideo) {
        // Only delete this app's copies. The original Photos item is never touched.
        try? FileManager.default.removeItem(at: media.appendingPathComponent("\(video.id.uuidString).\(video.fileExtension)"))
        try? FileManager.default.removeItem(at: media.appendingPathComponent("\(video.id.uuidString).jpg"))
    }

    func importSubmissionCover(_ data: Data, id: UUID) throws {
        try prepareDirectory()
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: 1200
        ]
        guard data.count <= 30 * 1_024 * 1_024,
              let source = CGImageSourceCreateWithData(data as CFData, nil),
              let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary),
              let jpeg = UIImage(cgImage: image).jpegData(compressionQuality: 0.85) else {
            throw CreationError.coverUnavailable
        }
        try jpeg.write(to: media.appendingPathComponent("\(id.uuidString).jpg"),
                       options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
    }

    func removeSubmissionCover(_ id: UUID) {
        try? FileManager.default.removeItem(at: media.appendingPathComponent("\(id.uuidString).jpg"))
    }

    /// Writes a pending portrait. The current portrait stays until `promoteProfileAvatar`.
    func storeProfileAvatar(_ data: Data) throws {
        try prepareDirectory()
        let jpeg = try jpegThumbnail(data, maxPixel: 800)
        let next = media.appendingPathComponent("profile-avatar-next.jpg")
        do {
            try jpeg.write(to: next, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        } catch {
            throw LocalLibraryError.storageUnavailable
        }
    }

    func promoteProfileAvatar() throws {
        let manager = FileManager.default
        let next = media.appendingPathComponent("profile-avatar-next.jpg")
        let current = media.appendingPathComponent("profile-avatar.jpg")
        guard manager.fileExists(atPath: next.path) else { throw LocalLibraryError.storageUnavailable }
        do {
            if manager.fileExists(atPath: current.path) {
                if let backup = try manager.replaceItemAt(current, withItemAt: next) {
                    try? manager.removeItem(at: backup)
                }
            } else {
                try manager.moveItem(at: next, to: current)
            }
            try manager.setAttributes(
                [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication],
                ofItemAtPath: current.path)
        } catch {
            throw LocalLibraryError.storageUnavailable
        }
    }

    func discardPendingProfileAvatar() {
        try? FileManager.default.removeItem(at: media.appendingPathComponent("profile-avatar-next.jpg"))
    }

    private func jpegThumbnail(_ data: Data, maxPixel: Int) throws -> Data {
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixel,
        ]
        guard data.count <= 30 * 1_024 * 1_024,
            let source = CGImageSourceCreateWithData(data as CFData, nil),
            let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary),
            let jpeg = UIImage(cgImage: image).jpegData(compressionQuality: 0.85)
        else { throw LocalLibraryError.photoUnavailable }
        return jpeg
    }

    private func removeOrphanedMedia(library: LocalLibrary) {
        // A terminated import can leave an unreferenced copy. Only inspect this
        // app-owned folder after a snapshot has been successfully read.
        let referenced = Set(library.videos.flatMap { ["\($0.id.uuidString).\($0.fileExtension)", "\($0.id.uuidString).jpg"] })
            .union((library.submissions ?? []).filter(\.hasCover).map { "\($0.id.uuidString).jpg" })
            .union((library.phraseBook?.phrases ?? []).flatMap { phrase -> [String] in
                var files: [String] = []
                if let video = phrase.lesson?.localVideo {
                    files += ["\(video.id.uuidString).\(video.fileExtension)", "\(video.id.uuidString).jpg"]
                }
                if let id = phrase.lesson?.coverID { files.append("\(id.uuidString).jpg") }
                return files
            })
        guard let files = try? FileManager.default.contentsOfDirectory(at: media, includingPropertiesForKeys: nil) else { return }
        for file in files where !referenced.contains(file.lastPathComponent) {
            if file.lastPathComponent == "profile-avatar.jpg"
                || file.lastPathComponent == "profile-avatar-next.jpg"
            {
                continue
            }
            guard UUID(uuidString: file.deletingPathExtension().lastPathComponent) != nil,
                  ["mp4", "mov", "m4v", "jpg"].contains(file.pathExtension) else { continue }
            try? FileManager.default.removeItem(at: file)
        }
    }

    /// Rename an earlier app-owned library within the current sandbox only.
    /// A different bundle identifier has a separate container and cannot be migrated here.
    private func migrateExistingLibraryIfNeeded() throws {
        let manager = FileManager.default
        guard !manager.fileExists(atPath: root.path) else { return }
        let parent = root.deletingLastPathComponent()
        guard manager.fileExists(atPath: parent.path) else { return }
        let folders = try manager.contentsOfDirectory(at: parent,
            includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey], options: [.skipsHiddenFiles])
        let candidates = try folders.filter { folder in
            let values = try folder.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
            return folder.lastPathComponent == "TotiMusic"
                && values.isDirectory == true && values.isSymbolicLink != true
                && manager.fileExists(atPath: folder.appendingPathComponent("library-v1.json").path)
        }
        guard !candidates.isEmpty else { return }
        // Ambiguous or unreadable data must not be silently replaced with an empty library.
        guard candidates.count == 1, let previous = candidates.first else {
            throw LocalLibraryError.unreadableLibrary
        }
        let data = try Data(contentsOf: previous.appendingPathComponent("library-v1.json"))
        let library = try JSONDecoder().decode(LocalLibrary.self, from: data)
        guard library.schemaVersion == 1 else { throw LocalLibraryError.unsupportedVersion }
        // Same-volume directory move preserves media, viewing history and local state together.
        try manager.moveItem(at: previous, to: root)
    }

    private func prepareDirectory() throws {
        do {
            try FileManager.default.createDirectory(at: media, withIntermediateDirectories: true,
                attributes: [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication])
        } catch { throw LocalLibraryError.storageUnavailable }
    }
}
