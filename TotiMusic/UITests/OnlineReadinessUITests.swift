import XCTest

final class OnlineReadinessUITests: XCTestCase {
    func testOnlineWalletShowsAllPackagesWithoutEnablingPurchases() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["TOTI_LIVE_GUEST_ACCEPTANCE"] == "1",
                          "Requires authorized disposable guest creation and cleanup.")
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchEnvironment["TOTI_GUEST_ACCEPTANCE"] = UUID().uuidString
        app.launch()
        XCTAssertTrue(app.buttons["Get started"].waitForExistence(timeout: 30))
        app.buttons["Get started"].tap()
        app.buttons["Agree to the agreements"].tap()
        app.buttons["Log in"].tap()
        XCTAssertTrue(app.buttons["Me"].waitForExistence(timeout: 60))
        addTeardownBlock {
            if app.buttons["Back"].exists {
                app.buttons["Back"].tap()
            }
            app.buttons["Me"].tap()
            app.buttons["Settings"].tap()
            let delete = app.buttons["Delete account"].firstMatch
            for _ in 0..<6 {
                if delete.isHittable { break }
                app.swipeUp()
            }
            XCTAssertTrue(delete.isHittable)
            delete.tap()
            let confirmation = app.buttons.matching(identifier: "Delete account")
                .allElementsBoundByIndex.first { $0.isHittable }
            XCTAssertNotNil(confirmation)
            confirmation?.tap()
            XCTAssertTrue(app.buttons["Log in"].waitForExistence(timeout: 60),
                          "The disposable wallet acceptance guest must be deleted.")
            app.terminate()
        }
        app.buttons["Me"].tap()
        app.buttons["Wallet"].tap()
        let balance = app.staticTexts["wallet.balance"]
        XCTAssertTrue(balance.waitForExistence(timeout: 10))
        XCTAssertEqual(balance.value as? String, "Balance unavailable")
        let notice = app.staticTexts["wallet.payments.unavailable"]
        XCTAssertTrue(notice.exists)
        XCTAssertTrue(notice.label.contains("Purchases and gifts are temporarily unavailable"))
        XCTAssertFalse(app.buttons["wallet.catalog.retry"].exists)
        capture(app, "Online wallet balance and payment notice")
        let tiers = [(400, "$0.99"), (800, "$1.99"), (2450, "$4.99"),
                     (5150, "$9.99"), (10800, "$19.99"), (29400, "$49.99"), (63700, "$99.99")]
        XCTAssertEqual(app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "wallet.package.")).count, 7)
        for (amount, price) in tiers {
            let package = app.buttons["wallet.package.\(amount)"]
            XCTAssertTrue(package.exists)
            XCTAssertFalse(package.isEnabled)
            XCTAssertTrue(package.label.contains(price + " USD"))
            XCTAssertTrue(package.label.contains("Unavailable"))
        }
        app.swipeUp()
        capture(app, "Online wallet package catalog")
        let activity = app.staticTexts["wallet.activity.unavailable"]
        for _ in 0..<4 {
            if activity.isHittable { break }
            app.swipeUp()
        }
        XCTAssertTrue(activity.isHittable)
        XCTAssertTrue(activity.label.contains("Online transaction history is not available yet"))
        XCTAssertFalse(app.staticTexts["No transactions yet."].exists)
        capture(app, "Online wallet final package and activity")
    }

    func testOriginalEntryAndLoginConsentDialog() {
        let app = XCUIApplication()
        app.launchEnvironment["TOTI_GUEST_ACCEPTANCE"] = UUID().uuidString
        app.launch()
        XCTAssertTrue(app.buttons["Get started"].waitForExistence(timeout: 20))
        capture(app, "Original welcome")
        app.buttons["Get started"].tap()
        XCTAssertTrue(app.buttons["Log in"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["Agree to the agreements"].exists)
        XCTAssertTrue(app.links["Terms of Service"].exists)
        XCTAssertTrue(app.links["Privacy Policy"].exists)
        XCTAssertFalse(app.buttons["Continue as guest"].exists)
        XCTAssertFalse(app.buttons["Retry account connection"].exists)
        capture(app, "Original login")
        app.buttons["Log in"].tap()
        XCTAssertTrue(app.buttons["Agree and continue"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Disagree"].exists)
        capture(app, "Login consent confirmation")
        app.buttons["Disagree"].tap()
        XCTAssertTrue(app.buttons["Log in"].exists)
    }
    func testLiveGuestLoginReachesTabsRestoresAndCleansUp() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["TOTI_LIVE_GUEST_ACCEPTANCE"] == "1",
                          "Requires authorized disposable guest creation and cleanup.")
        let app = XCUIApplication()
        let run = UUID().uuidString
        app.launchEnvironment["TOTI_GUEST_ACCEPTANCE"] = run
        app.launch()
        XCTAssertTrue(app.buttons["Get started"].waitForExistence(timeout: 30))
        app.buttons["Get started"].tap()
        app.buttons["Agree to the agreements"].tap()
        app.buttons["Log in"].tap()
        XCTAssertTrue(app.buttons["Lounge"].waitForExistence(timeout: 60), "Real guest login must open the signed-in tabs.")
        capture(app, "Signed-in guest Lounge")
        let editorialTitle = app.staticTexts["Listening together"].firstMatch
        for _ in 0..<6 {
            if editorialTitle.isHittable { break }
            app.swipeUp()
        }
        XCTAssertTrue(editorialTitle.isHittable, "The restored official editorial card must be visible.")
        XCTAssertTrue(app.images["Illustrative Toti editorial photograph"].firstMatch.exists)
        capture(app, "Restored Toti editorial artwork")
        app.terminate()
        app.launch()
        let welcome = app.buttons["Get started"]
        XCTAssertTrue(welcome.waitForExistence(timeout: 10), "A saved guest session must still show the original welcome on cold launch.")
        if welcome.exists {
            capture(app, "Returning guest welcome")
            welcome.tap()
            XCTAssertTrue(app.buttons["Log in"].waitForExistence(timeout: 10))
            app.buttons["Agree to the agreements"].tap()
            app.buttons["Log in"].tap()
        }
        XCTAssertTrue(app.buttons["Lounge"].waitForExistence(timeout: 60), "Relaunch must restore the same secure session.")
        app.buttons["Me"].tap()
        XCTAssertTrue(app.buttons["Settings"].waitForExistence(timeout: 10))
        app.buttons["Settings"].tap()
        let delete = app.buttons["Delete account"].firstMatch
        for _ in 0..<5 {
            if delete.isHittable { break }
            app.swipeUp()
        }
        XCTAssertTrue(delete.isHittable)
        delete.tap()
        let confirm = app.buttons.matching(identifier: "Delete account").allElementsBoundByIndex.first { $0.isHittable }
        XCTAssertNotNil(confirm)
        confirm?.tap()
        XCTAssertTrue(app.buttons["Log in"].waitForExistence(timeout: 60), "Only this disposable guest must be deleted.")
        capture(app, "Disposable guest cleaned up")
        app.terminate()
    }

    private func capture(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}

/// Uses one UUID-scoped guest across runs and deliberately retains it for manual testing.
final class NotebookCallsAcceptanceUITests: XCTestCase {
    private let app = XCUIApplication()

    override func setUpWithError() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["TOTI_LIVE_GUEST_ACCEPTANCE"] == "1",
                          "Requires authorized retained acceptance fixtures.")
        let run = try XCTUnwrap(ProcessInfo.processInfo.environment["TOTI_GUEST_ACCEPTANCE"])
        _ = try XCTUnwrap(UUID(uuidString: run))
        continueAfterFailure = false
        app.launchEnvironment["TOTI_GUEST_ACCEPTANCE"] = run
        app.launchArguments = ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        enter()
    }

    override func tearDownWithError() throws {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Retained notebook and calls acceptance state"
        attachment.lifetime = .keepAlways
        add(attachment)
        if let result = testRun, result.failureCount > 0 {
            let tree = XCTAttachment(string: app.debugDescription)
            tree.name = "Failure accessibility hierarchy"
            tree.lifetime = .keepAlways
            add(tree)
        }
        // Keep the guest and all final fixtures; the coordinator will relaunch this run for the user.
        app.terminate()
    }

    private func enter() {
        app.launch()
        XCTAssertTrue(app.buttons["Get started"].waitForExistence(timeout: 30))
        tap("Get started")
        tap("Agree to the agreements")
        tap("Log in")
        XCTAssertTrue(app.buttons["Notebook"].waitForExistence(timeout: 60))
    }

    private func reveal(_ element: XCUIElement, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(element.waitForExistence(timeout: 15), file: file, line: line)
        for _ in 0..<12 {
            let window = app.windows.element(boundBy: 0)
            let surface = window.scrollViews.allElementsBoundByIndex.max { $0.frame.height < $1.frame.height } ?? window
            let visibleFrame = window.frame.insetBy(dx: 0, dy: 44)
            let center = CGPoint(x: element.frame.midX, y: element.frame.midY)
            // XCTest can throw instead of returning false for an offscreen activation point.
            if visibleFrame.contains(center), element.isHittable { return }
            let above = element.frame.midY < visibleFrame.minY
            surface.coordinate(withNormalizedOffset: CGVector(dx: 0.02, dy: above ? 0.2 : 0.8))
                .press(forDuration: 0.05, thenDragTo: surface.coordinate(withNormalizedOffset: CGVector(dx: 0.02, dy: above ? 0.8 : 0.2)))
        }
        XCTAssertTrue(element.isHittable, file: file, line: line)
    }

    private func tap(_ title: String) {
        let button = app.buttons[title].firstMatch
        reveal(button)
        button.tap()
    }

    private func fill(_ element: XCUIElement, _ text: String, replace: Bool = false) {
        reveal(element)
        element.tap()
        if replace, let previous = element.value as? String {
            element.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: previous.count))
        }
        element.typeText(text)
    }

    func testNotebookWelcomeCreateManageAndRelaunchWithoutFriends() {
        tap("Chats")
        XCTAssertTrue(app.buttons["chats.find-friend"].waitForExistence(timeout: 15))
        XCTAssertFalse(app.buttons["Voice call"].exists)
        XCTAssertFalse(app.buttons["Video call"].exists)
        tap("Notebook")
        XCTAssertTrue(app.buttons["notebook.first-note"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.textFields["Search private notes"].exists)
        tap("notebook.first-note")
        fill(app.textFields["Note title, up to 80 characters"], "Discarded acceptance note")
        tap("Close note")
        XCTAssertTrue(app.alerts["Save your changes?"].waitForExistence(timeout: 5))
        tap("Keep editing")
        XCTAssertEqual(app.textFields["Note title, up to 80 characters"].value as? String, "Discarded acceptance note")
        tap("Close note")
        tap("Discard")
        XCTAssertTrue(app.buttons["notebook.first-note"].waitForExistence(timeout: 10))
        tap("notebook.choose-prompt")
        tap("Opening lyric")
        XCTAssertEqual(app.textFields["Note title, up to 80 characters"].value as? String, "A first line")
        XCTAssertTrue((app.textViews["Note body, up to 10,000 characters"].value as? String ?? "").contains("The room went quiet"))
        tap("Close note")
        tap("Discard")
        tap("New note")
        fill(app.textFields["Note title, up to 80 characters"], "UI Acceptance Melody")
        fill(app.textViews["Note body, up to 10,000 characters"], "A retained private melody for manual testing.")
        tap("Close note")
        tap("Save")
        XCTAssertTrue(app.staticTexts["UI Acceptance Melody"].waitForExistence(timeout: 30))
        XCTAssertFalse(app.buttons["notebook.first-note"].exists)
        tap("Actions for UI Acceptance Melody")
        tap("Pin note")
        XCTAssertTrue(app.staticTexts["PINNED · IDEAS"].waitForExistence(timeout: 30))
        tap("Actions for UI Acceptance Melody")
        tap("Unpin note")
        XCTAssertTrue(app.staticTexts["IDEAS"].waitForExistence(timeout: 30))
        tap("Open note")
        fill(app.textViews["Note body, up to 10,000 characters"], " Edited and retained.")
        tap("Save note")
        XCTAssertTrue(app.staticTexts["Saved to your account · private to you"].waitForExistence(timeout: 30))
        tap("Close note")
        tap("Search private notes")
        fill(app.textFields["Search your private notes"], "no-matching-acceptance-note")
        XCTAssertTrue(app.staticTexts["No matching notes"].waitForExistence(timeout: 10))
        tap("Clear filters")
        XCTAssertFalse(app.keyboards.firstMatch.exists)
        tap("Actions for UI Acceptance Melody")
        tap("Duplicate note")
        let opens = app.buttons.matching(identifier: "Open note")
        let twoNotes = NSPredicate { _, _ in opens.count == 2 }
        expectation(for: twoNotes, evaluatedWith: app)
        waitForExpectations(timeout: 30)
        tap("Actions for UI Acceptance Melody")
        tap("Delete note")
        tap("Keep note")
        XCTAssertEqual(opens.count, 2)
        tap("Actions for UI Acceptance Melody")
        tap("Delete note")
        tap("Delete")
        let oneNote = NSPredicate { _, _ in opens.count == 1 }
        expectation(for: oneNote, evaluatedWith: app)
        waitForExpectations(timeout: 30)
        app.terminate()
        enter()
        tap("Notebook")
        XCTAssertTrue(app.staticTexts["UI Acceptance Melody"].waitForExistence(timeout: 15))
        tap("Search private notes")
        fill(app.textFields["Search your private notes"], "UI Acceptance Melody")
        tap("Close search")
        app.segmentedControls.buttons["Ideas"].tap()
        tap("Open note")
        XCTAssertTrue((app.textViews["Note body, up to 10,000 characters"].value as? String ?? "").contains("Edited and retained."))
        tap("Close note")
    }

    func testNotebookResumeDeleteAndRelaunch() {
        tap("Notebook")
        tap("Actions for UI Acceptance Melody")
        tap("Delete note")
        tap("Delete")
        let titles = app.staticTexts.matching(identifier: "UI Acceptance Melody")
        let oneNote = NSPredicate { _, _ in titles.count == 1 }
        expectation(for: oneNote, evaluatedWith: app)
        waitForExpectations(timeout: 45)
        app.terminate()
        enter()
        tap("Notebook")
        XCTAssertTrue(app.staticTexts["UI Acceptance Melody"].waitForExistence(timeout: 15))
        tap("Search private notes")
        fill(app.textFields["Search your private notes"], "UI Acceptance Melody")
        tap("Close search")
        app.segmentedControls.buttons["Ideas"].tap()
        tap("Open note")
        XCTAssertTrue((app.textViews["Note body, up to 10,000 characters"].value as? String ?? "").contains("Edited and retained."))
        tap("Close note")
    }

    func testNotebookPromptMoodCategorySearchAndPrivatePostDraft() {
        tap("Notebook")
        tap("Try a prompt")
        tap("Chord progression")
        XCTAssertEqual(app.textFields["Note title, up to 80 characters"].value as? String, "A progression to explore")
        let mood = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Mood:")).firstMatch
        reveal(mood)
        mood.tap()
        tap("Reflective")
        tap("Save note")
        XCTAssertTrue(app.staticTexts["Saved to your account · private to you"].waitForExistence(timeout: 30))
        tap("Close note")
        let chords = app.segmentedControls.buttons["Chords"]
        reveal(chords)
        chords.tap()
        XCTAssertTrue(app.staticTexts["A progression to explore"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.staticTexts["UI Acceptance Melody"].exists)
        tap("Search private notes")
        fill(app.textFields["Search your private notes"], "Cmaj7")
        XCTAssertTrue(app.staticTexts["A progression to explore"].waitForExistence(timeout: 10))
        tap("Close search")
        tap("Open note")
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Reflective")).firstMatch.exists)
        tap("Turn into a post")
        tap("Open post draft")
        XCTAssertTrue(app.textViews["Post text"].waitForExistence(timeout: 10))
        XCTAssertTrue((app.textViews["Post text"].value as? String ?? "").contains("Cmaj7"))
        tap("Save draft")
        tap("Done")
        tap("Close note")
        XCTAssertTrue(app.staticTexts["A progression to explore"].waitForExistence(timeout: 10))
        app.segmentedControls.buttons["All"].tap()
    }

    func testChatComposerWidthAndAttachmentMenu() {
        tap("Chats")
        let partner = app.cells.matching(NSPredicate(format: "label CONTAINS %@", "Acceptance Partner")).firstMatch
        reveal(partner)
        partner.tap()
        let input = app.textFields["Message"]
        XCTAssertTrue(input.waitForExistence(timeout: 15))
        let add = app.buttons["Add attachment"], send = app.buttons["Send"]
        XCTAssertTrue(add.exists)
        XCTAssertTrue(send.exists)
        XCTAssertTrue(add.isEnabled)
        XCTAssertTrue(input.isEnabled)
        XCTAssertGreaterThan(input.frame.width, app.frame.width * 0.5)
        XCTAssertLessThanOrEqual(input.frame.maxX, send.frame.minX)
        XCTAssertLessThanOrEqual(send.frame.maxX, add.frame.minX)
        XCTAssertLessThanOrEqual(add.frame.maxX, app.frame.maxX)
        tap("Add attachment")
        XCTAssertTrue(app.buttons["Photo"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["File"].exists)
        tap("Photo")
        let picker = XCUIApplication(bundleIdentifier: "com.apple.mobileslideshow")
        XCTAssertTrue(app.buttons["Cancel"].waitForExistence(timeout: 5) || picker.exists)
        if app.buttons["Cancel"].exists { tap("Cancel") }
        tap("Add attachment")
        tap("File")
        XCTAssertTrue(app.buttons["Cancel"].waitForExistence(timeout: 10))
        tap("Cancel")
        tap("View photo")
        tap("Close")
        tap("Acceptance notes.txt")
        XCTAssertTrue(app.buttons["Save"].waitForExistence(timeout: 15))
        let export = XCTAttachment(screenshot: app.screenshot())
        export.name = "Private attachment Files export entry"
        export.lifetime = .keepAlways
        self.add(export)
    }

    func testEditorialPostDetailActionsSavedPersistenceAndForward() {
        let postID = "16F40C60-5DC2-4DB5-BF99-000000000006"
        func openSavedPost() {
            tap("Me")
            tap("Saved")
            let cover = app.buttons["lounge.editorial.cover." + postID]
            reveal(cover); cover.tap()
            XCTAssertTrue(app.buttons["editorial.detail.author"].waitForExistence(timeout: 15))
            expectRelationship("Editorial activity is loaded") { self.app.buttons["editorial.detail.like"].isEnabled }
        }
        openSavedPost()
        XCTAssertEqual(app.buttons["editorial.detail.author"].label, "View Sophie Brooks's profile")
        tap("editorial.detail.author")
        XCTAssertTrue(app.scrollViews["editorial.publisher.sophie-brooks"].waitForExistence(timeout: 10))
        tap("Back")
        let like = app.buttons["editorial.detail.like"]
        reveal(like)
        let originalLike = like.label
        like.tap()
        expectRelationship("Like state changes after acknowledgement") { like.isEnabled && like.label != originalLike }
        like.tap()
        expectRelationship("Like state is restored") { like.isEnabled && like.label == originalLike }
        let save = app.buttons["editorial.detail.save"]
        let originalSave = save.label
        save.tap()
        expectRelationship("Save state changes after acknowledgement") { save.isEnabled && save.label != originalSave }
        save.tap()
        expectRelationship("Save state is restored") { save.isEnabled && save.label == originalSave }
        tap("editorial.detail.comment")
        let editor = app.textViews["editorial.reply.editor"]
        let send = app.buttons["editorial.reply.send"]
        XCTAssertFalse(send.isEnabled)
        fill(editor, "Retained UI acceptance: listening together.")
        XCTAssertTrue(send.isEnabled)
        tap("editorial.reply.send")
        expectRelationship("The acknowledged reply clears the unchanged draft") { (editor.value as? String ?? "").isEmpty }
        XCTAssertTrue(app.staticTexts["Retained UI acceptance: listening together."].exists)
        tap("Post options")
        tap("Report post")
        XCTAssertTrue(app.buttons["editorial.report.submit"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["Spam or misleading content"].exists)
        tap("Close")
        tap("editorial.detail.share")
        XCTAssertTrue(app.buttons["Copy post"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["Share…"].exists)
        tap("Acceptance Partner")
        confirmTopmost("Send post")
        XCTAssertTrue(app.staticTexts["Post sent to Acceptance Partner."].waitForExistence(timeout: 60))
        tap("OK"); tap("Close"); tap("Back")
        XCTAssertTrue(app.buttons["lounge.editorial.cover." + postID].waitForExistence(timeout: 10))
        app.terminate(); enter()
        openSavedPost()
        XCTAssertTrue(app.staticTexts["Retained UI acceptance: listening together."].waitForExistence(timeout: 10))
        tap("Back"); tap("Chats")
        let conversation = app.tables["chats.list"].cells.matching(NSPredicate(format: "label BEGINSWITH %@", "Acceptance Partner,")).firstMatch
        XCTAssertTrue(conversation.waitForExistence(timeout: 15))
        conversation.tap()
        let forwarded = app.buttons.matching(identifier: "chat.shared.post." + postID).firstMatch
        reveal(forwarded); forwarded.tap()
        XCTAssertTrue(app.buttons["editorial.detail.author"].waitForExistence(timeout: 10))
        XCTAssertEqual(app.buttons["editorial.detail.author"].label, "View Sophie Brooks's profile")
        let image = XCTAttachment(screenshot: app.screenshot())
        image.name = "Full editorial post opened from a real forwarded message"
        image.lifetime = .keepAlways; add(image)
    }

    func testMemberPostDetailShowsAuthorCountsReplyAndShare() {
        tap("Lounge")
        tap("Read & reply")
        XCTAssertTrue(app.staticTexts["Retained member post acceptance: a quiet piano melody and a new chorus."].waitForExistence(timeout: 15))
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "1 saves")).firstMatch.exists)
        XCTAssertTrue(app.buttons["Edit post"].exists)
        XCTAssertTrue(app.buttons["Delete post"].exists)
        let replyAuthor = app.buttons["lounge.comment.author.B00CF06A-DBDC-42D7-A9F9-CE69BA8CC48C"]
        reveal(replyAuthor); replyAuthor.tap()
        XCTAssertTrue(app.staticTexts["Acceptance Partner"].waitForExistence(timeout: 10))
        tap("Back")
        tap("Share")
        XCTAssertTrue(app.buttons["Copy post"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["Share…"].exists)
        tap("Close")
        let image = XCTAttachment(screenshot: app.screenshot())
        image.name = "Member post detail with real counts, reply avatar and share"
        image.lifetime = .keepAlways; add(image)
    }

    func testVoiceMusicPortraitsOpenMatchingCharacterProfiles() {
        tap("Voice")
        let roomID = "C2E04CC7-7E49-594B-A7F1-AEF8007EEA95"
        let cover = app.buttons["voice.room.cover.community-artwork:" + roomID.lowercased()]
        reveal(cover)
        cover.tap()
        let names = ["Avery", "Emma", "Chloe"]
        let firstSeat = app.descendants(matching: .any)
            .matching(identifier: "voice.seat.community-artwork:" + roomID + ":0").firstMatch
        XCTAssertTrue(firstSeat.waitForExistence(timeout: 20))
        let roomImage = XCTAttachment(screenshot: app.screenshot())
        roomImage.name = "Voice room with three distinct music portraits"
        roomImage.lifetime = .keepAlways
        add(roomImage)
        for (index, name) in names.enumerated() {
            let seat = app.descendants(matching: .any)
                .matching(identifier: "voice.seat.community-artwork:" + roomID + ":" + String(index)).firstMatch
            XCTAssertTrue(seat.waitForExistence(timeout: 10))
            XCTAssertTrue(seat.label.hasPrefix(name + ", microphone"))
            seat.tap()
            let portrait = app.images["voice.character.portrait.PortraitVoice" + name]
            XCTAssertTrue(portrait.waitForExistence(timeout: 10))
            XCTAssertEqual(portrait.label, "Portrait of " + name)
            XCTAssertTrue(app.staticTexts["The Pop Lounge"].exists)
            let profileImage = XCTAttachment(screenshot: app.screenshot())
            profileImage.name = "Matching Voice character portrait: " + name
            profileImage.lifetime = .keepAlways
            add(profileImage)
            tap("Back")
            XCTAssertTrue(firstSeat.waitForExistence(timeout: 10))
        }
    }

    func testEditorialAvatarsOpenOnlyTheirAuthorsWorks() {
        tap("Lounge")
        let writers = [("Ava Bennett", "ava-bennett", "000000000001"),
                       ("Ethan Cole", "ethan-cole", "000000000002")]
        for (name, authorID, suffix) in writers {
            let postID = "16F40C60-5DC2-4DB5-BF99-" + suffix
            let avatar = app.buttons["lounge.editorial.author." + postID]
            reveal(avatar)
            XCTAssertEqual(avatar.label, "View " + name + "'s profile")
            avatar.tap()
            let profile = app.scrollViews["editorial.publisher." + authorID]
            XCTAssertTrue(profile.waitForExistence(timeout: 10))
            XCTAssertTrue(app.staticTexts[name].exists)
            XCTAssertTrue(app.staticTexts["Works"].exists)
            XCTAssertTrue(app.buttons["editorial.follow"].exists)
            XCTAssertTrue(app.buttons["editorial.block"].exists)
            XCTAssertFalse(app.buttons["Message"].exists)
            XCTAssertFalse(app.buttons["editorial.message"].exists)
            let follow = app.buttons["editorial.follow"]
            reveal(follow)
            let original = follow.label
            follow.tap()
            XCTAssertFalse(app.buttons["Message"].exists)
            XCTAssertFalse(app.buttons["editorial.message"].exists)
            follow.tap()
            XCTAssertEqual(follow.label, original)
            let covers = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "lounge.editorial.cover."))
            XCTAssertEqual(covers.count, 1)
            let cover = app.buttons["lounge.editorial.cover." + postID]
            reveal(cover)
            cover.tap()
            XCTAssertTrue(app.staticTexts["TOTI EDITORIAL"].waitForExistence(timeout: 10))
            tap("Back")
            XCTAssertTrue(profile.waitForExistence(timeout: 10))
            tap("Back")
            XCTAssertTrue(app.buttons["Search posts"].waitForExistence(timeout: 10))
        }
    }

    private func expectRelationship(_ description: String, _ condition: @escaping () -> Bool) {
        let expectation = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in condition() }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [expectation], timeout: 35), .completed, description)
    }

    private func confirmTopmost(_ title: String) {
        let matches = app.buttons.matching(identifier: title)
        expectRelationship("Visible confirmation button: " + title) {
            matches.allElementsBoundByIndex.contains { $0.isHittable }
        }
        guard let button = matches.allElementsBoundByIndex.first(where: { $0.isHittable }) else {
            XCTFail("No hittable confirmation button: " + title)
            return
        }
        button.tap()
    }

    func testEditorialFollowUnfollowBlockAndUnblock() {
        tap("Me")
        tap("Settings")
        tap("Editorial preferences")
        tap("editorial.preferences.ava-bennett")
        let follow = app.buttons["editorial.follow"]
        reveal(follow)
        let original = follow.label
        if original == "Following" { follow.tap() }
        expectRelationship("Unfollowed editorial author") { follow.label == "Follow" }
        XCTAssertFalse(app.buttons["Message"].exists)
        follow.tap()
        expectRelationship("Editorial follow is saved") { follow.label == "Following" }
        XCTAssertFalse(app.buttons["Message"].exists)
        tap("editorial.block")
        XCTAssertTrue(app.staticTexts["Block Ava Bennett?"].waitForExistence(timeout: 5))
        tap("Cancel")
        XCTAssertEqual(follow.label, "Following")
        tap("editorial.block")
        confirmTopmost("Block")
        expectRelationship("Blocking returns to preferences") { self.app.buttons["editorial.preferences.ava-bennett"].exists }
        tap("editorial.preferences.ava-bennett")
        XCTAssertFalse(follow.isEnabled)
        XCTAssertFalse(app.buttons["Message"].exists)
        XCTAssertFalse(app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "lounge.editorial.cover.")).firstMatch.exists)
        tap("editorial.block")
        XCTAssertTrue(app.staticTexts["Unblock Ava Bennett?"].waitForExistence(timeout: 5))
        confirmTopmost("Unblock")
        expectRelationship("Unblock restores visibility without following") { follow.isEnabled && follow.label == "Follow" }
        XCTAssertFalse(app.buttons["Message"].exists)
        if original == "Following" { follow.tap() }
        expectRelationship("Original editorial follow state restored") { follow.label == original }
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Editorial author: Follow and Block only, no Message"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testRetainedMemberMutualMessageAndBlockUnblock() {
        tap("Chats")
        let partner = app.cells.matching(NSPredicate(format: "label CONTAINS %@", "Acceptance Partner")).firstMatch
        reveal(partner)
        partner.tap()
        tap("Profile")
        expectRelationship("Existing mutual friends show Message") { self.app.buttons["Message"].exists }
        tap("Following")
        expectRelationship("Unfollow hides Message") { self.app.buttons["Follow"].exists && !self.app.buttons["Message"].exists }
        tap("Follow")
        expectRelationship("Restoring mutual follow reveals Message") { self.app.buttons["Message"].exists }
        tap("Message")
        XCTAssertTrue(app.textFields["Message"].waitForExistence(timeout: 15))
        XCTAssertTrue(app.buttons["Voice call"].exists)
        tap("Profile")
        tap("Block")
        XCTAssertTrue(app.staticTexts["Block Acceptance Partner?"].waitForExistence(timeout: 5))
        tap("Cancel")
        XCTAssertTrue(app.buttons["Message"].exists)
        tap("Block")
        confirmTopmost("Block")
        expectRelationship("Blocked member returns to Chats root") { self.app.buttons["Me"].exists }
        tap("Me")
        tap("Settings")
        let blocked = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Blocked")).firstMatch
        reveal(blocked)
        blocked.tap()
        let row = app.buttons["blocked.author.cded9cf8-1182-4802-ac9b-334c1c7d3040"]
        reveal(row)
        row.press(forDuration: 1.1)
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "Unblock ")).firstMatch.waitForExistence(timeout: 5))
        confirmTopmost("Unblock")
        expectRelationship("Member unblocked") { !row.exists }
        tap("Close")
        tap("Back")
        tap("Chats")
        reveal(partner)
        partner.tap()
        tap("Profile")
        expectRelationship("Unblock does not restore mutual following") { self.app.buttons["Follow"].exists && !self.app.buttons["Message"].exists }
        tap("Follow")
        expectRelationship("Outgoing-only follow still hides Message") { self.app.buttons["Following"].exists && !self.app.buttons["Message"].exists }
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Real member: outgoing-only follow cannot Message"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testProfileReceivedMetricsAndReportEntryReadOnly() {
        func verifyMetrics(_ editorial: Bool) {
            let names = ["likes", "saves", "following", "followers"]
            var left: CGFloat = -1
            for name in names {
                let metric = app.descendants(matching: .any).matching(identifier: "profile.metric." + name).firstMatch
                reveal(metric)
                let previousLeft = left
                var measuredLeft = previousLeft
                expectRelationship("Metric has completed layout: " + name) {
                    let frame = metric.frame
                    guard frame.width > 0, frame.height > 0, frame.minX > previousLeft else { return false }
                    measuredLeft = frame.minX
                    return true
                }
                left = measuredLeft
                if editorial {
                    let figures = ["likes": "86", "saves": "19", "following": "34", "followers": "127"]
                    XCTAssertEqual(metric.value as? String, figures[name])
                }
                else if name == "likes" || name == "saves" { XCTAssertEqual(metric.value as? String, "0") }
                else { XCTAssertEqual(metric.value as? String, "1") }
            }
        }
        tap("Me")
        verifyMetrics(false)
        tap("Chats")
        let partner = app.cells.matching(NSPredicate(format: "label CONTAINS %@", "Acceptance Partner")).firstMatch
        reveal(partner)
        partner.tap()
        tap("Profile")
        verifyMetrics(false)
        XCTAssertTrue(app.buttons["Message"].exists)
        tap("Report or block")
        tap("Report profile")
        let submit = app.buttons["Submit report"]
        reveal(submit)
        XCTAssertTrue(submit.exists)
        tap("Close")
        tap("Back")
        tap("Back")
        tap("Me")
        tap("Settings")
        tap("Editorial preferences")
        tap("editorial.preferences.ava-bennett")
        verifyMetrics(true)
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "figures are illustrative")).firstMatch.exists)
        XCTAssertTrue(app.staticTexts["1 post loaded"].exists)
        XCTAssertFalse(app.buttons["Message"].exists)
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "Editorial profile: fixed illustrative figures, no Message"
        shot.lifetime = .keepAlways
        add(shot)
    }

    func testRetainedFriendCallPagesAndLocalControls() {
        addUIInterruptionMonitor(withDescription: "Local camera preview permission") { alert in
            if alert.buttons["Allow"].exists { alert.buttons["Allow"].tap(); return true }
            if alert.buttons["OK"].exists { alert.buttons["OK"].tap(); return true }
            let primary = alert.buttons.matching(NSPredicate(format: "userTestingAttributes CONTAINS %@", "default-button")).firstMatch
            if primary.exists { primary.tap(); return true }
            return false
        }
        tap("Chats")
        let partner = app.cells.matching(NSPredicate(format: "label CONTAINS %@", "Acceptance Partner")).firstMatch
        reveal(partner)
        partner.tap()
        tap("Voice call")
        XCTAssertTrue(app.staticTexts["call.mode"].waitForExistence(timeout: 10))
        XCTAssertEqual(app.staticTexts["call.mode"].label, "Voice call")
        XCTAssertTrue(app.staticTexts["Acceptance Partner"].exists)
        XCTAssertFalse(app.staticTexts["Calls are unavailable"].exists)
        XCTAssertFalse(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "No call has been placed")).firstMatch.exists)
        XCTAssertTrue(app.buttons["Microphone"].isEnabled)
        XCTAssertEqual(app.buttons["Microphone"].value as? String, "On")
        tap("Microphone")
        XCTAssertEqual(app.buttons["Microphone"].value as? String, "Off")
        tap("Microphone")
        XCTAssertEqual(app.buttons["Microphone"].value as? String, "On")
        tap("Speaker")
        XCTAssertEqual(app.buttons["Speaker"].value as? String, "Off")
        tap("Speaker")
        XCTAssertEqual(app.buttons["Speaker"].value as? String, "On")
        let voice = XCTAttachment(screenshot: app.screenshot())
        voice.name = "Voice page and local control state"
        voice.lifetime = .keepAlways
        add(voice)
        tap("End call")
        tap("Video call")
        XCTAssertTrue(app.staticTexts["call.mode"].waitForExistence(timeout: 10))
        XCTAssertEqual(app.staticTexts["call.mode"].label, "Video call")
        XCTAssertFalse(app.staticTexts["Calls are unavailable"].exists)
        XCTAssertTrue(app.buttons["Flip camera"].exists)
        tap("Flip camera")
        tap("Camera options")
        XCTAssertTrue(app.buttons["Try again"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Settings"].exists)
        tap("Cancel")
        tap("Microphone")
        XCTAssertEqual(app.buttons["Microphone"].value as? String, "Off")
        let video = XCTAttachment(screenshot: app.screenshot())
        video.name = "Video page with local camera controls"
        video.lifetime = .keepAlways
        add(video)
        tap("Close")
        XCTAssertTrue(app.buttons["Voice call"].waitForExistence(timeout: 10))
    }
}
