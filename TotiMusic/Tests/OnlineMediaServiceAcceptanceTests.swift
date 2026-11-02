import XCTest
import UIKit
import Supabase
@testable import toti

@MainActor
final class OnlineMediaServiceAcceptanceTests: XCTestCase {
    func testGeneratedMediaPrivacyReviewRenderingAndCleanup() async throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["TOTI_LIVE_MEDIA_ACCEPTANCE"] == "1",
                          "Requires explicit authorization for disposable image publication and cleanup.")
        let run = try XCTUnwrap(ProcessInfo.processInfo.environment["TOTI_GUEST_ACCEPTANCE"])
        _ = try XCTUnwrap(UUID(uuidString: run))
        let owner = TotiBackend.shared
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("TotiMediaAcceptance-" + run, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let otherKey = "media-acceptance-other-" + run
        let other = TotiBackend(storageKey: otherKey, journalRoot: root.appendingPathComponent("Other"))
        defer {
            try? TotiKeychainStorage().remove(key: otherKey)
            try? FileManager.default.removeItem(at: root)
        }
        do {
            try await owner.signInAsGuest(agreementVersion: "media-acceptance-generated-fixture-not-user-consent")
            try await other.signInAsGuest(agreementVersion: "media-acceptance-generated-fixture-not-user-consent")
            let account = try XCTUnwrap(owner.accountID), otherAccount = try XCTUnwrap(other.accountID)
            let post = UUID()
            let jpeg = try generatedJPEG(color: TotiTheme.coral)
            let avatar = try generatedJPEG(color: .systemPurple)
            let submitted = try await owner.mutateWithMedia(action: "post.save", entityID: post,
                payload: ["body": .string("Disposable generated image acceptance"), "topic": .string("Making music"),
                          "isDraft": .bool(false), "expected_version": .number(0)], jpeg: jpeg, kind: "post")
            XCTAssertEqual(submitted.entity_id, post)
            let pendingPost = try await owner.page(kind: "post", parentID: post)
            let postRow = try XCTUnwrap(pendingPost.records.first)
            let postRevision = try XCTUnwrap(postRow.body["media_revision_id"]?.stringValue.flatMap(UUID.init(uuidString:)))
            XCTAssertEqual(postRow.body["media_status"]?.stringValue, "pending")
            let privatePreview = try await owner.mediaImage(revisionID: postRevision)
            XCTAssertNotNil(UIImage(data: privatePreview))
            try privatePreview.write(to: root.appendingPathComponent("post.jpg"), options: [.atomic, .completeFileProtection])
            let unseen = try await other.page(kind: "post", parentID: post)
            XCTAssertTrue(unseen.records.isEmpty)
            await assertMediaDenied(other, revision: postRevision)
            let beforeProfile = try await owner.page(kind: "profile", parentID: account)
            let beforeVersion = try XCTUnwrap(beforeProfile.records.first?.version)
            _ = try await owner.mutateWithMedia(action: "profile.save", entityID: account,
                payload: ["displayName": .string("Generated media acceptance"), "biography": .string(""),
                          "expected_version": .number(Double(beforeVersion))], jpeg: avatar, kind: "avatar")
            let pendingProfile = try await owner.page(kind: "profile", parentID: account)
            let profileRow = try XCTUnwrap(pendingProfile.records.first)
            let avatarRevision = try XCTUnwrap(profileRow.body["avatar_pending_media_revision_id"]?.stringValue.flatMap(UUID.init(uuidString:)))
            let avatarPreview = try await owner.mediaImage(revisionID: avatarRevision)
            try avatarPreview.write(to: root.appendingPathComponent("avatar.jpg"), options: [.atomic, .completeFileProtection])
            await assertMediaDenied(other, revision: avatarRevision)
            print("MEDIA_REVIEW_READY post=\(postRevision.uuidString) avatar=\(avatarRevision.uuidString)")
            print("MEDIA_PREVIEW_DIRECTORY \(root.path)")
            var approved = false
            for _ in 0..<90 {
                let page = try await owner.page(kind: "post", parentID: post)
                if page.records.first?.body["media_status"]?.stringValue == "approved" { approved = true; break }
                try await Task.sleep(nanoseconds: 2_000_000_000)
            }
            XCTAssertTrue(approved, "An operator must inspect and review only the generated fixtures.")
            let published = try await other.page(kind: "post", parentID: post)
            XCTAssertEqual(published.records.first?.body["media_status"]?.stringValue, "approved")
            let visiblePhoto = try await other.mediaImage(revisionID: postRevision)
            XCTAssertNotNil(UIImage(data: visiblePhoto))
            let visibleAvatar = try await other.mediaImage(revisionID: avatarRevision)
            XCTAssertNotNil(UIImage(data: visibleAvatar))
            let store = AppStore()
            let refreshed = await store.refreshOnline()
            XCTAssertTrue(refreshed)
            let creator = store.onlineCreator(account)
            XCTAssertEqual(TotiPhoto.mediaRevision(in: creator.avatarAsset), avatarRevision)
            XCTAssertEqual(store.onlineEditorialPosts.count, 6)
            let photo = TotiPhoto(asset: creator.avatarAsset, size: 96, round: true)
            let window = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first?.windows.first)
            window.addSubview(photo)
            defer { photo.removeFromSuperview() }
            for _ in 0..<30 {
                if photo.image?.size.width == 96 { break }
                try await Task.sleep(nanoseconds: 500_000_000)
            }
            XCTAssertEqual(photo.image?.size.width, 96, "The real remote avatar must reach the UIKit image view.")
            let avatarImage = try XCTUnwrap(photo.image)
            let attachment = XCTAttachment(image: avatarImage)
            attachment.name = "Approved generated remote avatar"
            attachment.lifetime = .keepAlways
            add(attachment)
            let editedProfile = try await owner.page(kind: "profile", parentID: account)
            let editedVersion = try XCTUnwrap(editedProfile.records.first?.version)
            let replacement = try await owner.mutateWithMedia(action: "profile.save", entityID: account,
                payload: ["displayName": .string("Generated media acceptance"), "biography": .string(""),
                          "expected_version": .number(Double(editedVersion))], jpeg: generatedJPEG(color: .systemBlue), kind: "avatar")
            XCTAssertEqual(replacement.entity_id, account)
            let replacementProfile = try await owner.page(kind: "profile", parentID: account)
            let replacing = try XCTUnwrap(replacementProfile.records.first)
            XCTAssertEqual(replacing.body["avatar_media_revision_id"]?.stringValue?.lowercased(), avatarRevision.uuidString.lowercased())
            let replacementID = try XCTUnwrap(replacing.body["avatar_pending_media_revision_id"]?.stringValue.flatMap(UUID.init(uuidString:)))
            let foreignProfile = try await other.page(kind: "profile", parentID: account)
            XCTAssertNil(foreignProfile.records.first?.body["avatar_pending_media_revision_id"])
            await assertMediaDenied(other, revision: replacementID)
            let blue = try await owner.mediaImage(revisionID: replacementID)
            try blue.write(to: root.appendingPathComponent("replacement.jpg"), options: [.atomic, .completeFileProtection])
            print("MEDIA_REPLACEMENT_REVIEW_READY revision=\(replacementID.uuidString)")
            var rejected = false
            for _ in 0..<90 {
                let page = try await owner.page(kind: "profile", parentID: account)
                if page.records.first?.body["avatar_media_status"]?.stringValue == "rejected" { rejected = true; break }
                try await Task.sleep(nanoseconds: 2_000_000_000)
            }
            XCTAssertTrue(rejected)
            let afterRejection = try await owner.page(kind: "profile", parentID: account)
            XCTAssertEqual(afterRejection.records.first?.body["avatar_media_revision_id"]?.stringValue?.lowercased(), avatarRevision.uuidString.lowercased())
            XCTAssertFalse(afterRejection.records.first?.body["avatar_media_feedback"]?.stringValue?.isEmpty ?? true)
            _ = try await owner.mutate(action: "block.set", entityID: otherAccount, payload: ["enabled": .bool(true)])
            await assertMediaDenied(other, revision: postRevision)
            await assertMediaDenied(other, revision: avatarRevision)
            try await other.deleteAccount()
            try await owner.deleteAccount()
            XCTAssertFalse(owner.isAuthenticated)
            XCTAssertFalse(other.isAuthenticated)
        } catch {
            if other.accountID != nil { try? await other.deleteAccount() }
            if owner.accountID != nil { try? await owner.deleteAccount() }
            throw error
        }
    }

    private func assertMediaDenied(_ service: TotiBackend, revision: UUID) async {
        do {
            _ = try await service.mediaImage(revisionID: revision)
            XCTFail("Another account must not receive unapproved, blocked or private media.")
        } catch { }
    }

    private func generatedJPEG(color: UIColor) throws -> Data {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let image = UIGraphicsImageRenderer(size: CGSize(width: 96, height: 96), format: format).image { context in
            color.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 96, height: 96))
            UIColor.white.setFill()
            context.fill(CGRect(x: 24, y: 24, width: 48, height: 48))
        }
        return try XCTUnwrap(image.jpegData(compressionQuality: 0.8))
    }
}
