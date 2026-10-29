import XCTest

final class CinemaUITests: XCTestCase {
    func testTourLightingAndBinocularReturn() {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .landscapeLeft
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.buttons["session.toggle"].waitForExistence(timeout: 20))
        expectation(for: NSPredicate { _, _ in app.frame.width > app.frame.height }, evaluatedWith: app)
        waitForExpectations(timeout: 10)
        XCTAssertTrue(app.buttons["session.toggle"].isHittable)
        XCTAssertTrue(app.buttons["seat"].isHittable)
        attach(app, "06-app-sala")
        app.buttons["chair"].tap()
        XCTAssertTrue(app.buttons["session.toggle"].exists)
        app.buttons["room"].tap()
        app.buttons["seat"].tap()
        app.buttons["height"].tap()
        app.buttons["seat"].tap()
        app.buttons["session.toggle"].tap()
        let phase = app.staticTexts["lighting.phase"]
        let finished = NSPredicate(format: "label == 'screening'")
        expectation(for: finished, evaluatedWith: phase)
        waitForExpectations(timeout: 12)
        // Tap outside toolbar brings the hidden HUD back.
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.35)).tap()
        XCTAssertTrue(app.buttons["session.toggle"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.buttons["session.toggle"].label, "Acender luzes")
        app.buttons["session.toggle"].tap()
        expectation(for: NSPredicate(format: "label == 'lounge'"), evaluatedWith: phase)
        waitForExpectations(timeout: 12)
        app.buttons["stereo"].tap()
        XCTAssertEqual(app.buttons.matching(identifier: "stereo.eye").count, 2)
        let leftControl = app.buttons.matching(identifier: "stereo.eye").element(boundBy: 0)
        let rightControl = app.buttons.matching(identifier: "stereo.eye").element(boundBy: 1)
        XCTAssertTrue(leftControl.isHittable)
        XCTAssertTrue(rightControl.isHittable)
        XCTAssertEqual(rightControl.frame.midX - leftControl.frame.midX, app.frame.width / 2, accuracy: 3)
        attach(app, "07-app-binocular")
        app.buttons.matching(identifier: "stereo.eye").element(boundBy: 0).tap()
        XCTAssertTrue(app.buttons["stereo"].waitForExistence(timeout: 5))
        // Reverse a still-running animation, without racing render threads.
        app.buttons["session.toggle"].tap()
        app.buttons["session.toggle"].tap()
        expectation(for: NSPredicate(format: "label == 'lounge'"), evaluatedWith: phase)
        waitForExpectations(timeout: 12)
        app.terminate()
    }

    private func attach(_ app: XCUIApplication, _ name: String) {
        let image = XCTAttachment(screenshot: app.screenshot())
        image.name = name
        image.lifetime = .keepAlways
        add(image)
        let screen = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        screen.name = name + "-full-display"
        screen.lifetime = .keepAlways
        add(screen)
    }
}
