import XCTest
import UIKit
@testable import VROSCinema

final class HeadMotionTests: XCTestCase {
    func testLandscapeLeftMapsPhoneAxesToViewerAxes() {
        let sample = HeadMotionMapper.sample(pitch: 0.4, roll: 0.2, yaw: -0.3,
                                             interfaceOrientation: .landscapeLeft)
        XCTAssertEqual(sample.yaw, -0.4, accuracy: 0.000001)
        XCTAssertEqual(sample.pitch, 0.2, accuracy: 0.000001)
        XCTAssertEqual(sample.roll, -0.3, accuracy: 0.000001)
    }

    func testLandscapeRightMirrorsHorizontalAndVerticalAxes() {
        let sample = HeadMotionMapper.sample(pitch: 0.4, roll: 0.2, yaw: -0.3,
                                             interfaceOrientation: .landscapeRight)
        XCTAssertEqual(sample.yaw, 0.4, accuracy: 0.000001)
        XCTAssertEqual(sample.pitch, -0.2, accuracy: 0.000001)
        XCTAssertEqual(sample.roll, -0.3, accuracy: 0.000001)
    }
}
