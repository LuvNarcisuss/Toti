import XCTest

/// Runs the shipping controllers against a unique, app-owned DEBUG-only library.
/// Each test keeps its library for relaunch assertions; it never erases the user's library.
final class CommunityUITests: XCTestCase {
  private let app = XCUIApplication()
  private let libraryID = UUID().uuidString

  override func setUpWithError() throws {
    continueAfterFailure = false
    app.launchEnvironment["TOTI_UI_TEST_LIBRARY"] = libraryID
    app.launchArguments = ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
    launchAndEnter()
  }

  override func tearDownWithError() throws {
    capture("Final state")
    if let run = testRun, run.failureCount + run.unexpectedExceptionCount > 0 {
      let hierarchy = XCTAttachment(string: app.debugDescription)
      hierarchy.name = "Failure accessibility tree"
      hierarchy.lifetime = .keepAlways
      add(hierarchy)
    }
    app.terminate()
  }

  private func launchAndEnter() {
    app.launch()
    let ready = XCTNSPredicateExpectation(predicate: NSPredicate { [self] _, _ in
      app.buttons["Get started"].exists || app.buttons["Agree to the agreements"].exists
        || app.buttons["Lounge"].exists
    }, object: nil)
    wait(for: [ready], timeout: 20)
    if app.buttons["Get started"].exists { tap("Get started") }
    if !app.buttons["Lounge"].exists {
      tap("Agree to the agreements")
      if app.buttons["Log in"].waitForExistence(timeout: 5) {
        tap("Log in")
      } else if app.buttons["Agree and continue"].waitForExistence(timeout: 5) {
        tap("Agree and continue")
      } else {
        tap("Let's listen")
      }
    }
    XCTAssertTrue(app.buttons["Lounge"].waitForExistence(timeout: 10))
  }

  private func capture(_ name: String) {
    let attachment = XCTAttachment(screenshot: app.screenshot())
    attachment.name = name
    attachment.lifetime = .keepAlways
    add(attachment)
  }

  private func reveal(_ element: XCUIElement, file: StaticString = #filePath, line: UInt = #line) {
    XCTAssertTrue(element.waitForExistence(timeout: 10), "Element does not exist: \(element)", file: file, line: line)
    for _ in 0..<12 {
      if element.isHittable { return }
      // Keyboard prediction bars also expose ScrollView and can become firstMatch.
      // Restrict navigation to the main application window and its largest scroll region.
      let window = app.windows.element(boundBy: 0)
      let surface = window.scrollViews.allElementsBoundByIndex.max {
        $0.frame.height < $1.frame.height
      } ?? window
      // Returning from drafts preserves the feed's scroll position. The target may be above us.
      let towardTop = element.frame.midY < surface.frame.minY + 20
      // Stay in the outer scroll view's margin: center swipes can be consumed by a UITextView.
      let start = surface.coordinate(withNormalizedOffset: CGVector(dx: 0.02, dy: towardTop ? 0.2 : 0.8))
      let end = surface.coordinate(withNormalizedOffset: CGVector(dx: 0.02, dy: towardTop ? 0.8 : 0.2))
      start.press(forDuration: 0.05, thenDragTo: end)
    }
    XCTFail("Element is not reachable: \(element)", file: file, line: line)
  }

  private func tap(_ title: String, file: StaticString = #filePath, line: UInt = #line) {
    let button = app.buttons[title].firstMatch
    reveal(button, file: file, line: line)
    button.tap()
  }

  private func enter(_ element: XCUIElement, _ value: String) {
    reveal(element)
    element.tap()
    element.typeText(value)
  }

  func testFivePagesAndProfile() {
    for page in ["Lounge", "Voice", "Notebook", "Chats", "Me"] {
      tap(page)
      XCTAssertTrue(app.buttons[page].isSelected, "Selected dock tab must match page")
      XCTAssertFalse(app.buttons["Shorts"].exists)
      XCTAssertFalse(app.buttons["Live"].exists)
      capture(page)
    }
    tap("Edit profile")
    XCTAssertTrue(app.textFields["Name"].waitForExistence(timeout: 5))
    tap("Save")
    tap("Wallet")
    let balance = app.staticTexts["wallet.balance"]
    XCTAssertTrue(balance.waitForExistence(timeout: 5))
    XCTAssertEqual(balance.value as? String, "0", "Opening Wallet must not grant starting credit")
    for amount in [400, 800, 2450, 5150, 10800, 29400, 63700] {
      XCTAssertTrue(app.buttons["wallet.package.\(amount)"].exists)
    }
    XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "Messages and replies are free.")).firstMatch.exists)
    capture("Wallet")
    tap("Back")
    tap("Settings")
    XCTAssertTrue(app.buttons["Media credits"].waitForExistence(timeout: 5))
    capture("Settings")
  }

  func testLoungePostReplyAndPersistence() {
    tap("What's on your mind?")
    enter(app.textViews["Post text"], "UI soundcheck: a rainy afternoon melody.")
    capture("Post keyboard")
    tap("Link a voice room")
    tap("The Pop Lounge")
    XCTAssertTrue(app.staticTexts["Voice room · The Pop Lounge"].exists)
    tap("Save draft")
    tap("Done")
    tap("My drafts")
    tap("Continue writing")
    XCTAssertEqual(app.textViews["Post text"].value as? String, "UI soundcheck: a rainy afternoon melody.")
    tap("Save post")
    tap("Done")
    tap("Back")
    tap("Read & reply")
    tap("Like · 0")
    XCTAssertTrue(app.buttons["Liked · 1"].waitForExistence(timeout: 5))
    tap("Save")
    enter(app.textViews["Write a reply"], "Keep the piano part.")
    tap("Save reply")
    XCTAssertTrue(app.staticTexts["Keep the piano part."].waitForExistence(timeout: 5))
    capture("Post and reply")
    app.terminate()
    launchAndEnter()
    tap("Saved")
    XCTAssertTrue(app.staticTexts["UI soundcheck: a rainy afternoon melody."].waitForExistence(timeout: 5))
    tap("Read & reply")
    XCTAssertTrue(app.buttons["Liked · 1"].exists)
    XCTAssertTrue(app.staticTexts["Keep the piano part."].exists)
  }

  func testNotebookExitSavePinAndConversion() {
    tap("Notebook")
    tap("New note")
    enter(app.textFields["Note title, up to 80 characters"], "UI Rain melody")
    enter(app.textViews["Note body, up to 10,000 characters"], "Rain on the window and a quiet piano chord.")
    capture("Note keyboard")
    tap("Close note")
    XCTAssertTrue(app.alerts["Save your changes?"].waitForExistence(timeout: 5))
    tap("Keep editing")
    let pin = app.switches["Pin this note"]
    reveal(pin)
    pin.tap()
    tap("Save note")
    XCTAssertTrue(app.staticTexts["Saved on this device · private to you"].waitForExistence(timeout: 5))
    tap("Turn into a post")
    tap("Open post draft")
    XCTAssertTrue(app.textViews["Post text"].waitForExistence(timeout: 5))
    XCTAssertTrue((app.textViews["Post text"].value as? String ?? "").contains("UI Rain melody\n\nRain on the window"))
    tap("Save draft")
    tap("Done")
    tap("Close note")
    XCTAssertTrue(app.staticTexts["PINNED · IDEAS"].waitForExistence(timeout: 5))
    capture("Pinned private note")
    app.terminate()
    launchAndEnter()
    tap("Notebook")
    XCTAssertTrue(app.staticTexts["UI Rain melody"].waitForExistence(timeout: 5))
    enter(app.textFields["Search private notes"], "no such note")
    XCTAssertTrue(app.staticTexts["No matching notes"].waitForExistence(timeout: 5))
    tap("Clear filters")
    XCTAssertFalse(app.keyboards.firstMatch.exists, "Clearing search must restore the bottom navigation")
    XCTAssertTrue(app.staticTexts["UI Rain melody"].waitForExistence(timeout: 5))
    tap("Me")
    tap("Drafts")
    XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "UI Rain melody")).firstMatch.exists)
  }

  func testVoiceRoomCreationAndLocalMessage() {
    tap("Voice")
    tap("Jazz")
    let room = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Blue Note Room, Voice party")).firstMatch
    reveal(room)
    room.tap()
    XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "real-time voice is not connected")).firstMatch.waitForExistence(timeout: 5))
    tap("Microphone on")
    XCTAssertTrue(app.buttons["Microphone off"].exists)
    enter(app.textFields["Say something…"], "UI local room message")
    tap("Send")
    XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "UI local room message")).firstMatch.waitForExistence(timeout: 5))
    capture("Voice local message")
    let unexpectedIncoming = XCTNSPredicateExpectation(
      predicate: NSPredicate(format: "count > 1"), object: app.tables.cells)
    unexpectedIncoming.isInverted = true
    wait(for: [unexpectedIncoming], timeout: 4)
    tap("Close")
    tap("Create party")
    enter(app.textFields["Party name"], "UI Piano Room")
    enter(app.textFields["What's the vibe?"], "Quiet piano ideas")
    tap("Jazz")
    tap("Save party")
    XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "UI Piano Room, Voice party")).firstMatch.waitForExistence(timeout: 5))
    capture("Created room")
  }

  func testChatKeyboardAndLocalOutbox() {
    tap("Chats")
    tap("Pinned")
    let row = app.tables.cells.containing(NSPredicate(format: "label CONTAINS %@", "Maya Chen")).firstMatch
    // Cells may expose their combined accessibility label through the static text.
    let message = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "Maya Chen,")).firstMatch
    if row.exists { row.tap() } else { reveal(message); message.tap() }
    enter(app.textFields["Message"], "UI local melody check")
    XCTAssertTrue(app.keyboards.firstMatch.exists)
    XCTAssertLessThanOrEqual(app.textFields["Message"].frame.maxY,
      app.keyboards.firstMatch.frame.minY + 2, "Message field must remain above the keyboard")
    capture("Chat keyboard")
    tap("Send")
    XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "UI local melody check")).firstMatch.waitForExistence(timeout: 5))
    XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "Saved locally · Not delivered")).firstMatch.exists)
    capture("Local outbox")
    app.terminate()
    launchAndEnter()
    tap("Chats")
    XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "UI local melody check")).firstMatch.waitForExistence(timeout: 5))
  }
}
