import StoreKit
import StoreKitTest
import XCTest

/// Local StoreKit only. Each test pairs a fresh transaction history with a UUID-scoped app ledger.
@MainActor
final class PurchaseUITests: XCTestCase {
    private let app = XCUIApplication()
    private var session: SKTestSession!

    override func setUp() async throws {
        continueAfterFailure = true
        let file = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "TotiDiamonds", withExtension: "storekit"))
        session = try SKTestSession(contentsOf: file)
        session.resetToDefaultState()
        session.clearTransactions()
        session.disableDialogs = true
        if let guest = ProcessInfo.processInfo.environment["TOTI_PURCHASE_GUEST"], UUID(uuidString: guest) != nil {
            // Reuse an authorized retained Guest; only the test wallet is newly isolated.
            app.launchEnvironment["TOTI_GUEST_ACCEPTANCE"] = guest
            app.launchEnvironment["TOTI_LOCAL_STOREKIT_TESTING"] = "1"
            app.launchEnvironment["TOTI_STOREKIT_TEST_RUN"] = UUID().uuidString
        } else {
            app.launchEnvironment["TOTI_UI_TEST_LIBRARY"] = UUID().uuidString
        }
        app.launchArguments = ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
    }

    override func tearDown() async throws {
        if let run = testRun, run.failureCount + run.unexpectedExceptionCount > 0 {
            capture("Failure screen")
            attach(app.debugDescription, name: "Failure app hierarchy")
            attach(XCUIApplication(bundleIdentifier: "com.apple.springboard").debugDescription, name: "Failure system hierarchy")
        }
        app.terminate()
        session?.clearTransactions()
        session?.resetToDefaultState()
    }

    func testSevenPurchasesPricesCancellationAndRelaunchHistory() async throws {
        try await openWallet()
        try await expectBalance(0)
        let tiers = [(400, "$0.99"), (800, "$1.99"), (2450, "$4.99"), (5150, "$9.99"), (10800, "$19.99"), (29400, "$49.99"), (63700, "$99.99")]
        var balance = 0
        for (amount, price) in tiers {
            let package = app.buttons["wallet.package.\(amount)"]
            try await require(package, "enabled == true")
            XCTAssertTrue(package.label.contains(price), "Expected \(price), got \(package.label)")
            try reveal(package)
            if amount == 400 { capture("Seven loaded StoreKit offers") }
            package.tap()
            try await require(app.buttons["Continue"], "exists == true")
            XCTAssertTrue(app.staticTexts["Price: \(price)"].exists)
            if amount == 400 { capture("Purchase confirmation") }
            app.buttons["Continue"].tap()
            balance += amount
            try await expectBalance(balance)
            try await require(app.buttons["wallet.package.\(amount)"], "enabled == true")
        }
        XCTAssertEqual(balance, 112700)
        XCTAssertEqual(session.allTransactions().filter { $0.state == .purchased }.count, 7)
        capture("Seven completed purchases")
        let first = app.buttons["wallet.package.400"]
        try reveal(first)
        first.tap()
        try await require(app.buttons["Cancel"], "exists == true")
        app.buttons["Cancel"].tap()
        try await expectBalance(112700)
        XCTAssertEqual(session.allTransactions().count, 7)

        if #available(iOS 17.0, *) {
            try await session.setSimulatedError(.generic(.userCancelled), forAPI: .purchase)
            first.tap()
            try await require(app.buttons["Continue"], "exists == true")
            app.buttons["Continue"].tap()
            try await require(app.staticTexts["Purchase canceled. You have not been charged."], "exists == true")
            capture("StoreKit cancellation")
            app.buttons["OK"].tap()
            try await expectBalance(112700)
            session.resetToDefaultState()
            session.disableDialogs = true
        }

        app.terminate()
        try await openWallet()
        try await expectBalance(112700)
        XCTAssertEqual(app.staticTexts.matching(NSPredicate(format: "identifier BEGINSWITH %@", "wallet.activity.")).count, 7)
        capture("Persisted balance and history after relaunch")
    }

    func testPostGiftConfirmationCancellationDebitAndRelaunch() async throws {
        try await openWallet()
        let package = app.buttons["wallet.package.400"]
        try await require(package, "enabled == true")
        try reveal(package)
        package.tap()
        app.buttons["Continue"].tap()
        try await expectBalance(400)
        app.buttons["Back"].tap()
        app.buttons["Lounge"].tap()
        let post = app.buttons["Read & reply"].firstMatch
        try reveal(post)
        post.tap()
        let entry = app.buttons["gift.entry.post"]
        try reveal(entry)
        entry.tap()
        let rose = app.buttons["gift.item.rose"]
        try await require(rose, "exists == true")
        try reveal(rose)
        rose.tap()
        try await require(app.buttons["Spend 10 diamonds"], "exists == true")
        capture("Post gift confirmation and service boundary")
        app.buttons["Cancel"].tap()
        try await require(app.staticTexts["gift.balance"], "value == '400'")
        try reveal(rose)
        rose.tap()
        app.buttons["Spend 10 diamonds"].tap()
        try await require(app.staticTexts["gift.balance"], "value == '390'")
        try await require(app.staticTexts["gift.outcome"], "exists == true")
        capture("Post gift debit and local record")
        app.buttons["Close"].tap()
        app.buttons["Back"].tap()
        app.buttons["Me"].tap()
        app.buttons["Wallet"].tap()
        try await expectBalance(390)
        let activity = app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "Local gift · 1 × Rose")).firstMatch
        XCTAssertTrue(activity.exists)
        app.terminate()
        try await openWallet()
        try await expectBalance(390)
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "Local gift · 1 × Rose")).firstMatch.exists)
        capture("Post gift persists after relaunch")
    }

    func testVoiceRecipientAndInsufficientFundsKeepBalance() async throws {
        try await openWallet()
        app.buttons["Back"].tap()
        app.buttons["Voice"].tap()
        let room = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "The Pop Lounge, Voice party")).firstMatch
        try reveal(room)
        room.tap()
        try await require(app.buttons["Send a gift"], "exists == true")
        app.buttons["Send a gift"].tap()
        try await require(app.buttons["Maya"], "exists == true")
        app.buttons["Maya"].tap()
        XCTAssertEqual(app.staticTexts["gift.recipients"].label, "For: Maya")
        let rose = app.buttons["gift.item.rose"]
        try reveal(rose)
        rose.tap()
        try await require(app.staticTexts["Not enough diamonds"], "exists == true")
        capture("Voice gift selected recipient and insufficient balance")
        app.buttons["Cancel"].tap()
        try await require(app.staticTexts["gift.balance"], "value == '0'")
        XCTAssertTrue(session.allTransactions().isEmpty)
        let topUp = app.buttons["Add diamonds"]
        try reveal(topUp)
        topUp.tap()
        let package = app.buttons["wallet.package.400"]
        try await require(package, "enabled == true")
        try reveal(package)
        package.tap()
        app.buttons["Continue"].tap()
        try await expectBalance(400)
        app.buttons["Back"].tap()
        try await require(app.staticTexts["gift.balance"], "value == '400'")
        let five = app.buttons["5 gifts"]
        try reveal(five)
        five.tap()
        try reveal(rose)
        rose.tap()
        try await require(app.buttons["Spend 50 diamonds"], "exists == true")
        app.buttons["Spend 50 diamonds"].tap()
        try await require(app.staticTexts["gift.balance"], "value == '350'")
        XCTAssertEqual(app.staticTexts["gift.recipients"].label, "For: Maya")
        capture("Voice gift after top up keeps selected recipient")
    }

    func testLargeTextEveryoneConfirmationKeepsCancelAndSpendReachable() async throws {
        app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        try await openWallet()
        let package = app.buttons["wallet.package.400"]
        try await require(package, "enabled == true")
        try reveal(package)
        package.tap()
        app.buttons["Continue"].tap()
        try await expectBalance(400)
        app.buttons["Back"].tap()
        app.buttons["Voice"].tap()
        let room = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "The Pop Lounge, Voice party")).firstMatch
        try reveal(room)
        room.tap()
        app.buttons["Send a gift"].tap()
        let rose = app.buttons["gift.item.rose"]
        try await require(rose, "exists == true")
        try reveal(rose)
        rose.tap()
        try await require(app.alerts["Confirm gift"], "exists == true")
        XCTAssertTrue(app.alerts.buttons["Spend 10 diamonds"].isHittable)
        XCTAssertTrue(app.alerts.buttons["Cancel"].isHittable)
        capture("Large text Everyone gift confirmation")
        app.alerts.buttons["Cancel"].tap()
        try await require(app.staticTexts["gift.balance"], "value == '400'")
    }

    func testNativePaymentSheetShowsProductPriceAndCancelsWithoutCredit() async throws {
        session.disableDialogs = false
        try await openWallet()
        let package = app.buttons["wallet.package.400"]
        try await require(package, "enabled == true")
        try reveal(package)
        package.tap()
        try await require(app.buttons["Continue"], "exists == true")
        app.buttons["Continue"].tap()
        let systemUI = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let dismiss = systemUI.otherElements["payment-sheet"].buttons["dismiss"]
        try await waitForStablePresentation(dismiss, in: systemUI)
        try await require(dismiss, "hittable == true")
        // iOS 26 appends whitespace to the product-title accessibility label.
        let title = systemUI.staticTexts.matching(NSPredicate(format: "label MATCHES %@", "^400 Diamonds\\s*$")).firstMatch
        try await require(title, "hittable == true")
        XCTAssertTrue(systemUI.staticTexts["$0.99"].exists)
        capture("Native StoreKit payment sheet")
        attach(systemUI.debugDescription, name: "Native payment sheet hierarchy")
        dismiss.tap()
        try await require(app.staticTexts["Purchase canceled. You have not been charged."], "exists == true")
        capture("Native sheet cancellation")
        app.buttons["OK"].tap()
        try await expectBalance(0)
        try await require(app.buttons["wallet.package.400"], "enabled == true")
        XCTAssertEqual(session.allTransactions().filter { $0.state == .purchased }.count, 0)
    }

    func testPurchaseAfterStoreKitResetPreservesExistingWallet() async throws {
        try XCTSkipIf(app.launchEnvironment["TOTI_GUEST_ACCEPTANCE"] == nil,
                      "This regression requires the authorized online Guest and its scoped local wallet.")
        try await openWallet()
        let first = app.buttons["wallet.package.400"]
        try await require(first, "enabled == true")
        try reveal(first)
        first.tap()
        try await require(app.buttons["Continue"], "exists == true")
        app.buttons["Continue"].tap()
        try await expectBalance(400)
        let firstID = try XCTUnwrap(session.allTransactions().first?.identifier)
        capture("Existing wallet before StoreKit history reset")

        app.terminate()
        session.clearTransactions()
        try await openWallet()
        try await expectBalance(400)
        let second = app.buttons["wallet.package.800"]
        try await require(second, "enabled == true")
        try reveal(second)
        second.tap()
        try await require(app.buttons["Continue"], "exists == true")
        app.buttons["Continue"].tap()
        try await expectBalance(1200)
        XCTAssertEqual(session.allTransactions().first?.identifier, firstID)
        XCTAssertEqual(app.staticTexts.matching(NSPredicate(format: "identifier BEGINSWITH %@", "wallet.activity.")).count, 2)
        capture("Reused StoreKit identifier credits 800 without losing the existing 400")

        app.terminate()
        try await openWallet()
        try await expectBalance(1200)
        XCTAssertEqual(app.staticTexts.matching(NSPredicate(format: "identifier BEGINSWITH %@", "wallet.activity.")).count, 2)
        capture("Both credits survive relaunch after identifier reuse")
    }

    private func openWallet() async throws {
        app.launch()
        try await require(app.buttons["Get started"], "exists == true")
        app.buttons["Get started"].tap()
        let login = app.buttons[app.launchEnvironment["TOTI_GUEST_ACCEPTANCE"] == nil ? "Let's listen" : "Log in"]
        try await require(login, "exists == true")
        let agreement = app.buttons["Agree to the agreements"]
        if agreement.exists { agreement.tap() }
        login.tap()
        try await require(app.buttons["Me"], "exists == true")
        app.buttons["Me"].tap()
        try await require(app.buttons["Wallet"], "exists == true")
        app.buttons["Wallet"].tap()
        try await require(app.staticTexts["wallet.balance"], "exists == true")
        if app.launchEnvironment["TOTI_GUEST_ACCEPTANCE"] != nil {
            XCTAssertTrue(app.staticTexts["wallet.localTesting.notice"].exists)
            XCTAssertFalse(app.staticTexts["wallet.payments.unavailable"].exists)
        }
    }

    private func expectBalance(_ value: Int) async throws {
        try await require(app.staticTexts["wallet.balance"], "value == '\(value)'")
    }

    private func waitForStablePresentation(_ element: XCUIElement, in application: XCUIApplication) async throws {
        // SpringBoard can expose the sheet while its hit-test coordinates are still animating.
        // Check observable geometry before asking XCTest for a hit point.
        var previousFrame: CGRect?
        var stableSince = ProcessInfo.processInfo.systemUptime
        let expectation = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            guard element.exists else { previousFrame = nil; return false }
            let frame = element.frame
            guard !frame.isEmpty, !frame.isInfinite, !frame.isNull,
                  application.frame.contains(frame) else { previousFrame = nil; return false }
            if previousFrame != frame {
                previousFrame = frame
                stableSince = ProcessInfo.processInfo.systemUptime
                return false
            }
            return ProcessInfo.processInfo.systemUptime - stableSince >= 0.5
        }, object: element)
        let result = await XCTWaiter.fulfillment(of: [expectation], timeout: 30)
        guard result == .completed else {
            XCTFail("The native payment sheet did not reach a stable visible position.")
            throw NSError(domain: "TotiPurchaseUITests", code: 3)
        }
    }

    private func require(_ element: XCUIElement, _ predicate: String) async throws {
        let expectation = XCTNSPredicateExpectation(predicate: NSPredicate(format: predicate), object: element)
        let result = await XCTWaiter.fulfillment(of: [expectation], timeout: 30)
        guard result == .completed else {
            XCTFail("Expected \(predicate): \(element)")
            throw NSError(domain: "TotiPurchaseUITests", code: 1)
        }
    }

    private func reveal(_ element: XCUIElement) throws {
        let scroll = app.scrollViews.firstMatch
        for _ in 0..<8 {
            // Query geometry before tapping: XCTest can throw while computing a
            // hit point for a control whose accessibility snapshot is updating.
            let frame = element.frame
            let viewport = scroll.frame.intersection(app.frame).insetBy(dx: 4, dy: 8)
            if !frame.isEmpty, !frame.isNull, !frame.isInfinite, viewport.contains(frame) { return }
            if frame.midY < viewport.midY { scroll.swipeDown() }
            else { scroll.swipeUp() }
        }
        XCTFail("Purchase control is not reachable: \(element)")
        throw NSError(domain: "TotiPurchaseUITests", code: 2)
    }

    private func capture(_ name: String) {
        // The native payment sheet belongs to SpringBoard and is omitted by app.screenshot().
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func attach(_ text: String, name: String) {
        let attachment = XCTAttachment(string: text)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
