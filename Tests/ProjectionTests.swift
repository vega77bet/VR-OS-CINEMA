import XCTest
import SceneKit
import Metal
@testable import VROSCinema

final class ProjectionTests: XCTestCase {
    func testPackingPreservesAspectAndDoesNotGuessOrdinaryVideos() {
        let hd = CGSize(width: 1920, height: 1080)
        XCTAssertEqual(VideoLayout.halfSBS.eyeAspect(frame: hd), 16.0 / 9, accuracy: 0.0001)
        XCTAssertEqual(VideoLayout.halfOU.eyeAspect(frame: hd), 16.0 / 9, accuracy: 0.0001)
        XCTAssertEqual(VideoLayout.fullSBS.eyeAspect(frame: CGSize(width: 3840, height: 1080)), 16.0 / 9, accuracy: 0.0001)
        XCTAssertEqual(VideoLayout.fullOU.eyeAspect(frame: CGSize(width: 1920, height: 2160)), 16.0 / 9, accuracy: 0.0001)
        XCTAssertNil(VideoLayout.suggested(for: "Cinema-2026-1080p.mp4"))
        XCTAssertNil(VideoLayout.suggested(for: "TABULEIRO.mp4"))
        XCTAssertEqual(VideoLayout.suggested(for: "Filme.H-SBS.mp4"), .halfSBS)
        XCTAssertEqual(VideoLayout.suggested(for: "Filme.Full.SBS.mp4"), .fullSBS)
        XCTAssertEqual(VideoLayout.suggested(for: "Filme.HOU.mp4"), .halfOU)
        XCTAssertEqual(VideoLayout.suggested(for: "Filme.Full.TAB.mp4"), .fullOU)
    }

    func testRotationAndAlignmentStayInsideSelectedEye() {
        var settings = ProjectionSettings()
        settings.layout = .fullSBS
        for shift in [-0.0075, 0, 0.0075] {
            settings.alignment = shift
            for right in [false, true] {
                let crop = settings.layout.crop(rightEye: right, swapped: false)
                for u in [0.0, 0.5, 1.0] {
                    let point = settings.uv(CGPoint(x: u, y: 0.5), rightEye: right, frame: CGSize(width: 1920, height: 1080), transform: .identity)
                    XCTAssertGreaterThanOrEqual(point.x, crop.minX - 0.00001)
                    XCTAssertLessThanOrEqual(point.x, crop.maxX + 0.00001)
                }
            }
        }
        settings.layout = .flat
        let rotated = CGAffineTransform(a: 0, b: 1, c: -1, d: 0, tx: 1080, ty: 0)
        let point = settings.uv(CGPoint(x: 0, y: 0), rightEye: false, frame: CGSize(width: 1920, height: 1080), transform: rotated)
        XCTAssertEqual(point.x, 0, accuracy: 0.00001)
        XCTAssertEqual(point.y, 1, accuracy: 0.00001)
    }

    /// Render actual screen geometry and camera masks, then sample the image.
    /// Red and blue halves must never be shown to the wrong eye.
    func testRenderedEyeIsolationForSBSAndOverUnder() throws {
        let device = try XCTUnwrap(MTLCreateSystemDefaultDevice())
        let room = CinemaScene()
        room.applyDarkness(1)
        let renderer = SCNRenderer(device: device, options: nil)
        renderer.scene = room.scene
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm, width: 128, height: 128, mipmapped: false)
        descriptor.usage = .shaderRead
        let texture = try XCTUnwrap(device.makeTexture(descriptor: descriptor))
        for layout in [VideoLayout.halfSBS, .fullSBS, .halfOU, .fullOU] {
            var bytes = [UInt8](repeating: 0, count: 128 * 128 * 4)
            for y in 0..<128 {
                for x in 0..<128 {
                    let second = layout == .halfOU || layout == .fullOU ? y >= 64 : x >= 64
                    let i = (y * 128 + x) * 4
                    bytes[i] = second ? 255 : 0
                    bytes[i + 2] = second ? 0 : 255
                    bytes[i + 3] = 255
                }
            }
            texture.replace(region: MTLRegionMake2D(0, 0, 128, 128), mipmapLevel: 0, withBytes: bytes, bytesPerRow: 512)
            let info = MovieInfo(title: "Eye isolation", nativeSize: CGSize(width: 128, height: 128), transform: .identity, duration: 1, suggestedLayout: layout)
            var settings = ProjectionSettings()
            settings.layout = layout
            settings.aspectOverride = 16.0 / 9
            for swap in [false, true] {
                settings.swapEyes = swap
                room.configureMovie(settings, info: info)
                room.showMovieFrame(texture)
                for (right, eye) in [(false, room.leftEye), (true, room.rightEye)] {
                    renderer.pointOfView = eye
                    let image = renderer.snapshot(atTime: 0, with: CGSize(width: 480, height: 300), antialiasingMode: .none)
                    let color = sampleCenter(image)
                    let blue = right != swap
                    XCTAssertGreaterThan(blue ? color.b : color.r, 150, "\(layout) right=\(right) swap=\(swap): intended eye missing")
                    XCTAssertLessThan(blue ? color.r : color.b, 65, "Other eye leaked into this camera")
                    if !swap && (layout == .fullSBS || layout == .fullOU) {
                        let attachment = XCTAttachment(image: image)
                        attachment.name = "3D-\(layout.rawValue)-\(right ? "right" : "left")"
                        attachment.lifetime = .keepAlways
                        add(attachment)
                    }
                }
            }
        }
        room.showSessionArtwork(true)
        XCTAssertTrue(room.movieVisible, "Lights must not remove the movie")
        room.clearMovie()
        XCTAssertFalse(room.movieVisible)
    }

    private func sampleCenter(_ image: UIImage) -> (r: UInt8, b: UInt8) {
        var bytes = [UInt8](repeating: 0, count: 4)
        let crop = image.cgImage!.cropping(to: CGRect(x: image.cgImage!.width / 2, y: image.cgImage!.height / 2, width: 1, height: 1))!
        let context = CGContext(data: &bytes, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4,
                                space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        context.draw(crop, in: CGRect(x: 0, y: 0, width: 1, height: 1))
        return (bytes[0], bytes[2])
    }
}
