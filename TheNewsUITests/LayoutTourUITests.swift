import XCTest

/// Walks every screen in portrait and landscape and keeps a screenshot of
/// each, so layout regressions on iPhone and iPad show up in the test report.
final class LayoutTourUITests: XCTestCase {
    private static let timeout: TimeInterval = 8
    private static let maxSwipes = 10

    override func setUp() {
        continueAfterFailure = false
    }

    override func tearDown() async throws {
        await MainActor.run { XCUIDevice.shared.orientation = .portrait }
    }

    @MainActor
    func testEveryScreenInLandscape() {
        tour(.landscapeLeft, tag: "landscape")
    }

    @MainActor
    func testEveryScreenInPortrait() {
        tour(.portrait, tag: "portrait")
    }

    /// Regression: rotating on the reader used to rebuild the WebView for the
    /// same WebPage, which WebKit traps on (app crashed on device).
    @MainActor
    func testRotatingWhileReadingKeepsTheReaderAlive() {
        XCUIDevice.shared.orientation = .portrait
        let app = launch("standard")
        tap("open-general", app)
        tap("source-bbc-news", app)
        tap("article-0", app)
        XCTAssertTrue(element("article-web", app).waitForExistence(timeout: Self.timeout))

        for orientation in [UIDeviceOrientation.landscapeLeft, .portrait, .landscapeRight, .portrait] {
            XCUIDevice.shared.orientation = orientation
            XCTAssertTrue(element("article-web", app).waitForExistence(timeout: Self.timeout), "Reader gone after rotating to \(orientation.rawValue)")
            XCTAssertEqual(app.state, .runningForeground, "App died after rotating to \(orientation.rawValue)")
        }
    }

    // MARK: - Tour

    @MainActor
    private func tour(_ orientation: UIDeviceOrientation, tag: String) {
        XCUIDevice.shared.orientation = orientation

        let app = launch("standard")
        XCTAssertTrue(element("category-wall", app).waitForExistence(timeout: Self.timeout))
        snap("\(tag)-01-home", app)

        tap("settings-button", app)
        XCTAssertTrue(element("settings-close", app).waitForExistence(timeout: Self.timeout))
        snap("\(tag)-02-settings", app)
        tap("settings-close", app)

        tap("open-general", app)
        XCTAssertTrue(element("source-bbc-news", app).waitForExistence(timeout: Self.timeout))
        snap("\(tag)-03-sources", app)

        tap("source-bbc-news", app)
        XCTAssertTrue(element("article-0", app).waitForExistence(timeout: Self.timeout))
        snap("\(tag)-04-articles", app)

        tap("article-0", app)
        XCTAssertTrue(element("article-web", app).waitForExistence(timeout: Self.timeout))
        snap("\(tag)-05-web", app)

        for _ in 0..<3 { app.navigationBars.buttons.firstMatch.tap() }
        tap("search-button", app)
        let field = element("search-field", app)
        XCTAssertTrue(field.waitForExistence(timeout: Self.timeout))
        snap("\(tag)-06-search-empty", app)
        field.tap()
        field.typeText("verge")
        XCTAssertTrue(element("result-source-the-verge", app).waitForExistence(timeout: Self.timeout))
        snap("\(tag)-07-search-sources", app)
        tap("tab-articles", app)
        XCTAssertTrue(element("result-article-0", app).waitForExistence(timeout: Self.timeout))
        snap("\(tag)-08-search-articles", app)
        app.terminate()

        let failing = launch("failure")
        tap("open-general", failing)
        XCTAssertTrue(element("retry-button", failing).waitForExistence(timeout: Self.timeout))
        snap("\(tag)-09-error", failing)
        failing.terminate()

        let onboarding = launch("onboarding")
        XCTAssertTrue(element("key-field", onboarding).waitForExistence(timeout: Self.timeout))
        snap("\(tag)-10-onboarding", onboarding)
    }

    // MARK: - Helpers

    @MainActor
    private func launch(_ scenario: String) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting"]
        app.launchEnvironment = ["STUB_SCENARIO": scenario]
        app.launch()
        return app
    }

    @MainActor
    private func element(_ id: String, _ app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any)[id].firstMatch
    }

    @MainActor
    private func tap(_ id: String, _ app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
        let target = element(id, app)
        XCTAssertTrue(target.waitForExistence(timeout: Self.timeout), "Missing \(id)", file: file, line: line)
        var swipes = 0
        while !target.isHittable, swipes < Self.maxSwipes {
            app.swipeUp(velocity: .slow)
            swipes += 1
        }
        target.tap()
    }

    @MainActor
    private func snap(_ name: String, _ app: XCUIApplication) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
