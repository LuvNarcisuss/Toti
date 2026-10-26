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
        app.launchEnvironment["TOTI_UI_TEST_LIBRARY"] = UUID().uuidString
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
        try await require(dismiss, "exists == true")
        capture("Native StoreKit payment sheet")
        attach(systemUI.debugDescription, name: "Native payment sheet hierarchy")
        // iOS 26 appends whitespace to the product-title accessibility label.
        let title = systemUI.staticTexts.matching(NSPredicate(format: "label MATCHES %@", "^400 Diamonds\\s*$")).firstMatch
        XCTAssertTrue(title.exists)
        XCTAssertTrue(systemUI.staticTexts["$0.99"].exists)
        dismiss.tap()
        try await require(app.staticTexts["Purchase canceled. You have not been charged."], "exists == true")
        capture("Native sheet cancellation")
        app.buttons["OK"].tap()
        try await expectBalance(0)
        try await require(app.buttons["wallet.package.400"], "enabled == true")
        XCTAssertEqual(session.allTransactions().filter { $0.state == .purchased }.count, 0)
    }

    private func openWallet() async throws {
        app.launch()
        try await require(app.buttons["Get started"], "exists == true")
        app.buttons["Get started"].tap()
        try await require(app.buttons["Let's listen"], "exists == true")
        let agreement = app.buttons["Agree to the agreements"]
        if agreement.exists { agreement.tap() }
        app.buttons["Let's listen"].tap()
        try await require(app.buttons["Me"], "exists == true")
        app.buttons["Me"].tap()
        try await require(app.buttons["Wallet"], "exists == true")
        app.buttons["Wallet"].tap()
        try await require(app.staticTexts["wallet.balance"], "exists == true")
    }

    private func expectBalance(_ value: Int) async throws {
        try await require(app.staticTexts["wallet.balance"], "value == '\(value)'")
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
            if element.isHittable { return }
            if element.frame.midY < scroll.frame.minY { scroll.swipeDown() }
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
