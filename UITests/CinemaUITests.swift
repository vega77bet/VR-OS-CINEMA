import XCTest

final class CinemaUITests: XCTestCase {
    func testStereoMoviePlaybackAndSettings() {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .landscapeLeft
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.buttons["settings"].waitForExistence(timeout: 20))
        app.buttons["settings"].tap()
        XCTAssertTrue(app.buttons["movie.demo"].waitForExistence(timeout: 5))
        app.buttons["movie.demo"].tap()
        let state = app.staticTexts["movie.state"]
        expectation(for: NSPredicate(format: "label == 'ready'"), evaluatedWith: state)
        waitForExpectations(timeout: 20)
        XCTAssertEqual(app.otherElements.matching(identifier: "viewport.eye.0").count, 1)
        let play = app.buttons.matching(identifier: "movie.eye").element(boundBy: 0)
        XCTAssertTrue(play.isHittable)
        XCTAssertEqual(play.label, "Reproduzir filme")
        play.tap()
        expectation(for: NSPredicate(format: "label == 'playing'"), evaluatedWith: state)
        waitForExpectations(timeout: 10)
        XCTAssertTrue(app.sliders.matching(identifier: "movie.progress.eye").element(boundBy: 0).exists)
        // A frame and audio clock must keep advancing after the light fade.
        expectation(for: NSPredicate(format: "label == 'screening'"), evaluatedWith: app.staticTexts["lighting.phase"])
        waitForExpectations(timeout: 10)
        if !play.isHittable { app.coordinate(withNormalizedOffset: CGVector(dx: 0.3, dy: 0.35)).tap() }
        play.tap()
        expectation(for: NSPredicate(format: "label == 'paused'"), evaluatedWith: state)
        waitForExpectations(timeout: 5)
        attach(app, "08-filme-3D-binocular")
        app.buttons.matching(identifier: "settings.eye").element(boundBy: 0).tap()
        let formats = app.segmentedControls["projection.layout"]
        XCTAssertTrue(formats.waitForExistence(timeout: 5))
        if !formats.isHittable { app.scrollViews.firstMatch.swipeUp() }
        formats.buttons["2D"].tap()
        formats.buttons["Full SBS"].tap()
        app.buttons["Concluir"].tap()
        XCTAssertEqual(play.label, "Reproduzir filme")
        // Toggling room lights must preserve the loaded video and its controls.
        app.buttons.matching(identifier: "session.toggle.eye").element(boundBy: 0).tap()
        XCTAssertTrue(app.sliders.matching(identifier: "movie.progress.eye").element(boundBy: 0).exists)
        attach(app, "09-filme-3D-pausado")
        app.terminate()
    }

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
        XCTAssertTrue(app.buttons["motion"].isHittable)
        XCTAssertTrue(app.buttons["movie"].isHittable)
        app.buttons["motion"].tap()
        app.buttons["motion"].tap()
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
