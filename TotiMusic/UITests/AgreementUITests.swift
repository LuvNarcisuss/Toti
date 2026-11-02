import XCTest

/// Bundled agreements remain readable when the viewer transport is blocked.
final class AgreementUITests: XCTestCase {
  private let app = XCUIApplication()
  private let titles = ["Toti - Terms of Service", "Toti - Privacy Policy"]

  override func setUpWithError() throws {
    continueAfterFailure = false
    app.launchEnvironment["TOTI_UI_TEST_LIBRARY"] = UUID().uuidString
    app.launchArguments = ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
  }

  override func tearDownWithError() throws {
    capture("Final agreement state")
    if let run = testRun, run.failureCount + run.unexpectedExceptionCount > 0 {
      let tree = XCTAttachment(string: app.debugDescription)
      tree.name = "Agreement accessibility tree"
      tree.lifetime = .keepAlways
      add(tree)
    }
    app.terminate()
  }

  private func capture(_ name: String) {
    let image = XCTAttachment(screenshot: app.screenshot())
    image.name = name
    image.lifetime = .keepAlways
    add(image)
  }

  private func tap(_ button: String) {
    let element = app.buttons[button].firstMatch
    XCTAssertTrue(element.waitForExistence(timeout: 15), button)
    element.tap()
  }

  private func launchLogin() {
    app.launch()
    XCTAssertTrue(app.buttons["Get started"].waitForExistence(timeout: 20))
    tap("Get started")
    XCTAssertTrue(app.buttons["Agree to the agreements"].waitForExistence(timeout: 10))
  }

  private func enterSettings() {
    tap("Agree to the agreements")
    tap("Let's listen")
    tap("Me")
    tap("Settings")
  }

  private func open(_ title: String, settings: Bool) {
    if settings {
      tap(title)
    } else {
      let link = app.links[title].firstMatch
      XCTAssertTrue(link.waitForExistence(timeout: 10), "Login agreement link: \(title)")
      link.tap()
    }
    XCTAssertTrue(app.buttons["Retry"].waitForExistence(timeout: 10))
  }

  private func assertDocument(_ name: String) {
    let date = app.webViews.staticTexts.matching(
      NSPredicate(format: "label CONTAINS %@", "Last updated: October 27, 2026")).firstMatch
    XCTAssertTrue(date.waitForExistence(timeout: 15), "Current bundled document body must load")
    XCTAssertFalse(app.staticTexts["Agreement unavailable"].exists)
    capture(name)
  }

  private func setOffline(_ offline: Bool) {
    let done = expectation(description: "Set agreement transport state")
    let path = offline ? "offline" : "online"
    let url = URL(string: "http://127.0.0.1:18889/control/\(path)")!
    URLSession.shared.dataTask(with: url) { _, response, error in
      XCTAssertNil(error)
      XCTAssertEqual((response as? HTTPURLResponse)?.statusCode, 200)
      done.fulfill()
    }.resume()
    wait(for: [done], timeout: 10)
  }

  private func verifyLocal(settings: Bool) {
    launchLogin()
    if settings { enterSettings() }
    for title in titles {
      open(title, settings: settings)
      assertDocument("\(settings ? "Settings" : "Login") - \(title)")
      tap(settings ? "Back" : "Close")
    }
  }

  private func verifyOffline(settings: Bool) {
    app.launchEnvironment["TOTI_AGREEMENT_TEST_PROXY_PORT"] = "18889"
    setOffline(true)
    defer { setOffline(false) }
    launchLogin()
    if settings { enterSettings() }
    for title in titles {
      open(title, settings: settings)
      assertDocument("Offline - \(settings ? "Settings" : "Login") - \(title)")
      tap("Retry")
      assertDocument("Reopened offline - \(settings ? "Settings" : "Login") - \(title)")
      tap(settings ? "Back" : "Close")
    }
  }

  func testLoginLocalAgreements() { verifyLocal(settings: false) }
  func testSettingsLocalAgreements() { verifyLocal(settings: true) }
  func testLoginOfflineAgreements() { verifyOffline(settings: false) }
  func testSettingsOfflineAgreements() { verifyOffline(settings: true) }
}
