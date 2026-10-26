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
