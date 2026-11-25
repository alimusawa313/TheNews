import XCTest

/// End-to-end flows against deterministic stub data (no network, no key).
final class TheNewsUITests: XCTestCase {
    private static let timeout: TimeInterval = 8
    private static let maxSwipes = 14

    override func setUp() {
        continueAfterFailure = false
    }

    // MARK: - Positive flows

    @MainActor
    func testPosterToSourcesToArticlesToWebView() {
        let app = launch("standard")
        XCTAssertTrue(element("category-wall", app).waitForExistence(timeout: Self.timeout))
        snap("01-home", app)
        tap("open-general", app)
        XCTAssertTrue(element("source-bbc-news", app).waitForExistence(timeout: Self.timeout))
        snap("02-sources", app)
        tap("source-bbc-news", app)
        XCTAssertTrue(element("article-0", app).waitForExistence(timeout: Self.timeout))
        snap("03-articles", app)
        tap("article-0", app)
        XCTAssertTrue(element("article-web", app).waitForExistence(timeout: Self.timeout))
        snap("04-web", app)
    }

    @MainActor
    func testPosterWallPagesBetweenCategories() {
        let app = launch("standard")
        XCTAssertTrue(element("open-general", app).waitForExistence(timeout: Self.timeout))
        // Phones page vertically; the iPad wall is a horizontal carousel.
        if UIDevice.current.userInterfaceIdiom == .pad { app.swipeLeft() } else { app.swipeUp() }
        XCTAssertTrue(element("open-business", app).waitForExistence(timeout: Self.timeout))
        snap("05-home-business", app)
        tap("open-business", app)
        XCTAssertTrue(element("source-bloomberg", app).waitForExistence(timeout: Self.timeout))
    }

    @MainActor
    func testEndlessScrollingOnSourcesAndArticles() {
        let app = launch("standard")
        tap("open-general", app)
        swipeUntilExists("end-of-list", app)
        XCTAssertTrue(element("source-the-washington-post", app).exists)
        app.swipeDown(); app.swipeDown(); app.swipeDown()
        tap("source-bbc-news", app)
        swipeUntilExists("article-25", app)
    }

    @MainActor
    func testSearchFindsSourcesAndArticles() {
        let app = launch("standard")
        tap("search-button", app)
        let field = element("search-field", app)
        XCTAssertTrue(field.waitForExistence(timeout: Self.timeout))
        field.tap()
        field.typeText("verge")
        XCTAssertTrue(element("result-source-the-verge", app).waitForExistence(timeout: Self.timeout))
        snap("06-search-sources", app)
        tap("tab-articles", app)
        XCTAssertTrue(element("result-article-0", app).waitForExistence(timeout: Self.timeout))
        snap("07-search-articles", app)
    }

    @MainActor
    func testSettingsOpensAndCloses() {
        let app = launch("standard")
        tap("settings-button", app)
        XCTAssertTrue(element("settings-close", app).waitForExistence(timeout: Self.timeout))
        snap("08-settings", app)
        tap("settings-close", app)
        XCTAssertTrue(element("settings-close", app).waitForNonExistence(timeout: Self.timeout))
    }

    // MARK: - Negative flows

    @MainActor
    func testOfflineShowsPosterErrorWithRetry() {
        let app = launch("failure")
        tap("open-general", app)
        XCTAssertTrue(element("retry-button", app).waitForExistence(timeout: Self.timeout))
        snap("09-error", app)
        tap("retry-button", app)
        XCTAssertTrue(element("retry-button", app).waitForExistence(timeout: Self.timeout))
    }

    @MainActor
    func testEmptyCategoryShowsEmptyPoster() {
        let app = launch("empty")
        tap("open-general", app)
        XCTAssertTrue(element("empty-state", app).waitForExistence(timeout: Self.timeout))
        snap("10-empty", app)
    }

    @MainActor
    func testFailedNextPageRecoversWithInlineRetry() {
        let app = launch("flakyPagination")
        tap("open-general", app)
        tap("source-bbc-news", app)
        XCTAssertTrue(element("article-0", app).waitForExistence(timeout: Self.timeout))
        swipeUntilExists("load-more-retry", app)
        snap("11-load-more-error", app)
        tap("load-more-retry", app)
        swipeUntilExists("article-25", app)
    }

    @MainActor
    func testSearchWithNoMatches() {
        let app = launch("standard")
        tap("search-button", app)
        let field = element("search-field", app)
        XCTAssertTrue(field.waitForExistence(timeout: Self.timeout))
        field.tap()
        field.typeText("qqqzzz")
        XCTAssertTrue(element("empty-state", app).waitForExistence(timeout: Self.timeout))
        snap("12-search-empty", app)
    }

    @MainActor
    func testMalformedKeyIsRejectedThenDemoWorks() {
        let app = launch("onboarding")
        let field = element("key-field", app)
        XCTAssertTrue(field.waitForExistence(timeout: Self.timeout))
        field.tap()
        field.typeText("not-a-key")
        tap("connect-button", app)
        XCTAssertTrue(element("key-error", app).waitForExistence(timeout: Self.timeout))
        snap("13-onboarding-error", app)
        tap("demo-button", app)
        XCTAssertTrue(element("category-wall", app).waitForExistence(timeout: Self.timeout))
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
    private func swipeUntilExists(_ id: String, _ app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
        let target = element(id, app)
        var swipes = 0
        while !target.waitForExistence(timeout: 1), swipes < Self.maxSwipes {
            app.swipeUp()
            swipes += 1
        }
        XCTAssertTrue(target.exists, "Never found \(id)", file: file, line: line)
    }

    @MainActor
    private func snap(_ name: String, _ app: XCUIApplication) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
