import XCTest

final class RouteGuardUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testLoginAndCaptureSimulatorScreenshots() throws {
        let app = XCUIApplication()
        app.launch()

        // 1. Login screen screenshot
        XCTAssertTrue(app.buttons["login_signin_button"].waitForExistence(timeout: 8))
        captureScreenshot(app, name: "ios_01_login")

        // 2. Sign in as Parent
        app.buttons["demo_parent"].tap()
        app.buttons["login_signin_button"].tap()

        // Allow live/fallback tracking screen to load
        sleep(2)
        captureScreenshot(app, name: "ios_02_parent_tracking")

        // 3. Switch to Profile tab -> switch role to Driver -> inspect Driver screen
        let tabBar = app.tabBars.firstMatch
        if tabBar.waitForExistence(timeout: 5) {
            tabBar.buttons.element(boundBy: 2).tap()
            sleep(1)
            captureScreenshot(app, name: "ios_03_profile")
        }
    }

    private func captureScreenshot(_ app: XCUIApplication, name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
