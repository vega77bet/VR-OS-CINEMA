import XCTest
@testable import VROSCinema

final class VisualStateTests: XCTestCase {
    func testLightingEndpointsAndSafeGuides() {
        XCTAssertEqual(RoomLighting.at(darkness: 0).front, 1)
        XCTAssertEqual(RoomLighting.at(darkness: 1).sides, 0.012, accuracy: 0.000001)
        XCTAssertEqual(RoomLighting.at(darkness: 1).guides, 0.14, accuracy: 0.000001)
        XCTAssertEqual(RoomLighting.at(darkness: -10), RoomLighting.at(darkness: 0))
        XCTAssertEqual(RoomLighting.at(darkness: 10), RoomLighting.at(darkness: 1))
        var previous = RoomLighting.at(darkness: 0)
        for step in 1...100 {
            let current = RoomLighting.at(darkness: Double(step) / 100)
            XCTAssertLessThanOrEqual(current.front, previous.front)
            XCTAssertLessThanOrEqual(current.sides, previous.sides)
            XCTAssertGreaterThanOrEqual(current.guides, 0.13999)
            previous = current
        }
        XCTAssertLessThan(RoomLighting.at(darkness: 0.4).front, RoomLighting.at(darkness: 0.4).sides)
    }

    func testRapidReversalIsContinuousAndFinishes() {
        var transition = LightTransition()
        transition.move(to: 1, at: 100, reducedMotion: false)
        XCTAssertEqual(transition.value(at: 100), 0)
        let midway = transition.value(at: 101.5)
        XCTAssertGreaterThan(midway, 0)
        XCTAssertLessThan(midway, 1)
        transition.move(to: 0, at: 101.5, reducedMotion: false)
        XCTAssertEqual(transition.value(at: 101.5), midway, accuracy: 0.000001)
        XCTAssertEqual(transition.value(at: 200), 0)
        XCTAssertTrue(transition.isFinished(at: 200))
        transition.move(to: 1, at: 201, reducedMotion: true)
        XCTAssertEqual(transition.value(at: 201), 1)
        XCTAssertTrue(transition.isFinished(at: 201))
    }
}
