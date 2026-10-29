import XCTest
import SceneKit
import Metal
@testable import VROSCinema

final class SceneTests: XCTestCase {
    func testRoomGeometryAndEyeSeparation() {
        let room = CinemaScene()
        XCTAssertEqual(room.seatNodes.count, 42)
        XCTAssertEqual(room.scene.rootNode.childNode(withName: "giant-screen", recursively: true)?.position.y,
                       Float(CinemaLayout.screenCenterY))
        XCTAssertEqual(room.rightEye.position.x - room.leftEye.position.x, 0.064, accuracy: 0.000001)
        XCTAssertEqual(room.leftEye.simdOrientation, room.rightEye.simdOrientation)
        for row in 1..<CinemaLayout.rowCount {
            XCTAssertGreaterThan(CinemaLayout.floorHeight(row: row), CinemaLayout.floorHeight(row: row - 1))
        }
        room.look(yaw: 100, pitch: -100)
        XCTAssertEqual(room.yaw, .pi)
        XCTAssertEqual(room.pitch, -0.78)
        room.setHeight(20)
        XCTAssertEqual(room.heightOffset, 1.25)
        room.setView(.seat)
        XCTAssertEqual(room.heightOffset, 0)
        XCTAssertEqual(room.yaw, 0)
    }

    func testViewChangesPreserveLevelHorizon() {
        let room = CinemaScene()
        let original = room.cameraRig.simdOrientation.vector
        for _ in 0..<10 {
            for view in [RoomView.room, .chair, .seat] {
                room.setView(view)
                XCTAssertEqual(room.cameraRig.simdWorldTransform.columns.0.y, 0, accuracy: 0.00001,
                               "Changing views must not accumulate camera roll")
            }
        }
        let restored = room.cameraRig.simdOrientation.vector
        XCTAssertEqual(abs(simd_dot(original, restored)), 1, accuracy: 0.00001)
        XCTAssertEqual(room.centerEye.camera?.fieldOfView, 86)
    }

    func testNativeRenderedGallery() throws {
        let room = CinemaScene()
        let device = try XCTUnwrap(MTLCreateSystemDefaultDevice(), "Metal is required for authentic scene previews")
        let renderer = SCNRenderer(device: device, options: nil)
        renderer.scene = room.scene
        renderer.pointOfView = room.centerEye
        renderer.autoenablesDefaultLighting = false
        renderer.isPlaying = true
        let size = CGSize(width: 1800, height: 1000)
        // Prime pipelines/textures before capturing. All five captures use app scene code.
        _ = renderer.snapshot(atTime: 0, with: CGSize(width: 320, height: 180), antialiasingMode: .none)
        room.setView(.room)
        try save(renderer.snapshot(atTime: 1, with: size, antialiasingMode: .multisampling2X), "01-sala-aurora")
        room.setView(.seat)
        let lobby = renderer.snapshot(atTime: 2, with: size, antialiasingMode: .multisampling2X)
        try save(lobby, "02-vista-da-poltrona")
        room.setView(.chair)
        try save(renderer.snapshot(atTime: 3, with: size, antialiasingMode: .multisampling2X), "03-poltrona-orion")
        room.setView(.seat)
        room.showSessionArtwork(true)
        room.applyDarkness(1)
        let dark = renderer.snapshot(atTime: 4, with: size, antialiasingMode: .multisampling2X)
        try save(dark, "04-luzes-apagadas")
        let lobbyLevel = brightness(lobby), darkLevel = brightness(dark)
        XCTAssertGreaterThan(lobbyLevel, 0.025, "Lobby must be visibly rendered, not black")
        XCTAssertLessThan(darkLevel, lobbyLevel * 0.97, "Session must actually dim the room")
        room.showSessionArtwork(false)
        room.applyDarkness(0)
        renderer.pointOfView = room.leftEye
        let left = renderer.snapshot(atTime: 5, with: CGSize(width: 898, height: 1000), antialiasingMode: .multisampling2X)
        renderer.pointOfView = room.rightEye
        let right = renderer.snapshot(atTime: 5, with: CGSize(width: 898, height: 1000), antialiasingMode: .multisampling2X)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let binocular = UIGraphicsImageRenderer(size: size, format: format).image { context in
            UIColor.black.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            left.draw(in: CGRect(x: 0, y: 0, width: 898, height: 1000))
            right.draw(in: CGRect(x: 902, y: 0, width: 898, height: 1000))
        }
        try save(binocular, "05-binocular")
    }

    private func save(_ image: UIImage, _ name: String) throws {
        let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("CinemaPreviews")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let data = try XCTUnwrap(image.pngData())
        try data.write(to: directory.appendingPathComponent(name + ".png"), options: .atomic)
        let attachment = XCTAttachment(image: image)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func brightness(_ image: UIImage) -> Double {
        guard let cgImage = image.cgImage else { return 0 }
        var bytes = [UInt8](repeating: 0, count: 64 * 36 * 4)
        bytes.withUnsafeMutableBytes { buffer in
            let context = CGContext(data: buffer.baseAddress, width: 64, height: 36, bitsPerComponent: 8, bytesPerRow: 256,
                                    space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
            context.draw(cgImage, in: CGRect(x: 0, y: 0, width: 64, height: 36))
        }
        var total = 0.0
        for i in stride(from: 0, to: bytes.count, by: 4) {
            total += 0.2126 * Double(bytes[i]) + 0.7152 * Double(bytes[i + 1]) + 0.0722 * Double(bytes[i + 2])
        }
        return total / Double(64 * 36) / 255
    }
}
