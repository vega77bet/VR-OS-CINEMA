import XCTest
import AVFoundation
@testable import VROSCinema

final class MoviePlayerTests: XCTestCase {
    @MainActor
    func testDecodePauseSeekReplayAndClose() async throws {
        let movie = MoviePlayer()
        let bundle = Bundle(for: CinemaViewController.self)
        let url = try XCTUnwrap(bundle.url(forResource: "Aurora-FSBS", withExtension: "mp4"))
        movie.load(url)
        try await wait { movie.state == .ready || movie.state == .failed }
        XCTAssertEqual(movie.state, .ready, movie.errorMessage ?? "")
        XCTAssertEqual(movie.info?.suggestedLayout, .fullSBS)
        try await wait {
            movie.updateFrame(hostTime: CACurrentMediaTime()) != nil
        }
        let first = try XCTUnwrap(movie.currentFrame)
        XCTAssertEqual(first.texture.width, 1280)
        XCTAssertEqual(first.texture.height, 360)
        XCTAssertNotNil(movie.averageColor())
        movie.play()
        try await wait { movie.currentTime > 0.3 }
        movie.updateFrame(hostTime: CACurrentMediaTime())
        XCTAssertTrue(movie.wantsPlayback)
        movie.pause()
        let paused = movie.currentTime
        try await Task.sleep(nanoseconds: 200_000_000)
        XCTAssertEqual(movie.currentTime, paused, accuracy: 0.08)
        movie.seek(to: 4)
        try await wait { abs(movie.currentTime - 4) < 0.1 }
        try await wait { movie.updateFrame(hostTime: CACurrentMediaTime()) != nil }
        XCTAssertFalse(movie.wantsPlayback, "Seeking paused video must not start audio")
        movie.seek(to: 99999)
        try await wait { movie.currentTime > 11 }
        movie.play()
        try await wait { movie.state == .ended }
        movie.play()
        try await wait { movie.currentTime < 2 && movie.wantsPlayback }
        movie.close()
        XCTAssertEqual(movie.state, .empty)
        XCTAssertNil(movie.currentFrame)
        XCTAssertNil(movie.player.currentItem)
    }

    @MainActor
    func testBadFileAndRapidReplacementAreRecoverable() async throws {
        let movie = MoviePlayer()
        movie.load(URL(fileURLWithPath: "/missing/invalid.mp4"))
        try await wait { movie.state == .failed }
        XCTAssertNotNil(movie.errorMessage)
        let url = try XCTUnwrap(Bundle(for: CinemaViewController.self).url(forResource: "Aurora-FSBS", withExtension: "mp4"))
        movie.load(url)
        movie.close()
        try await Task.sleep(nanoseconds: 200_000_000)
        XCTAssertEqual(movie.state, .empty, "A cancelled load must not reinstall the old movie")
        movie.load(url)
        try await wait { movie.state == .ready }
        movie.close()
    }

    @MainActor
    private func wait(_ condition: () -> Bool) async throws {
        let deadline = Date().addingTimeInterval(15)
        while !condition() {
            if Date() > deadline { XCTFail("Movie condition timed out"); throw WaitError.timeout }
            try await Task.sleep(nanoseconds: 30_000_000)
        }
    }
    private enum WaitError: Error { case timeout }
}
