import SceneKit
import UIKit

/// This scene is used unchanged by the app and the native screenshot tests.
final class CinemaScene {
    let scene = SCNScene()
    let materials = CinemaMaterials()
    let cameraRig = SCNNode()
    let centerEye = SCNNode()
    let leftEye = SCNNode()
    let rightEye = SCNNode()
    private(set) var view: RoomView = .seat
    private(set) var darkness = 0.0
    private(set) var yaw = 0.0
    private(set) var pitch = 0.0
    private(set) var heightOffset = 0.0
    private(set) var seatNodes: [SCNNode] = []
    private var accents: [(SCNMaterial, CGFloat, Int)] = []
    private var lamps: [(SCNLight, CGFloat, Int)] = []
    private var baseOrientation = simd_quatf()
    private var basePosition = SIMD3<Float>(repeating: 0)

    init() {
        scene.background.contents = UIColor.black
        scene.lightingEnvironment.contents = Textures.environment()
        scene.lightingEnvironment.intensity = 0.55
        buildCameras()
        buildArchitecture()
        buildSeating()
        buildScreen()
        buildLighting()
        setView(.seat)
        applyDarkness(0)
    }

    private func buildCameras() {
        scene.rootNode.addChildNode(cameraRig)
        for (eye, x) in [(centerEye, 0.0), (leftEye, -0.032), (rightEye, 0.032)] {
            let camera = SCNCamera()
            camera.zNear = 0.06
            camera.zFar = 90
            camera.projectionDirection = .horizontal
            camera.fieldOfView = 86
            camera.wantsHDR = true
            camera.wantsExposureAdaptation = false
            camera.exposureOffset = 0
            camera.bloomIntensity = 0.10
            camera.bloomThreshold = 0.95
            camera.bloomBlurRadius = 6
            camera.vignettingIntensity = 0.12
            camera.vignettingPower = 0.6
            // Avoid expensive screen-space effects in the binocular renderer.
            camera.screenSpaceAmbientOcclusionIntensity = 0
            eye.camera = camera
            eye.position = SCNVector3(x, 0, 0)
            cameraRig.addChildNode(eye)
        }
        centerEye.name = "center-eye"
        leftEye.name = "left-eye"
        rightEye.name = "right-eye"
    }

    func setView(_ view: RoomView) {
        self.view = view
        heightOffset = 0
        yaw = 0
        pitch = 0
        let position: SCNVector3
        let target: SCNVector3
        switch view {
        case .seat:
            position = SCNVector3(0, CinemaLayout.defaultEyeHeight, CinemaLayout.defaultEyeZ)
            target = SCNVector3(0, CinemaLayout.screenCenterY, CinemaLayout.screenZ)
        case .room:
            position = SCNVector3(-0.9, 6.4, 11.1)
            target = SCNVector3(0, 3.9, -8.4)
        case .chair:
            // Front three-quarter view of the first row's central chair.
            position = SCNVector3(1.8, 1.7, -7.9)
            target = SCNVector3(0, 0.92, -5.4)
        }
        cameraRig.position = position
        // look(at:) reuses the node's current worldUp and accumulates roll
        // when switching viewpoints. Always rebuild against the room's vertical.
        cameraRig.look(at: target, up: SCNVector3(0, 1, 0), localFront: SCNVector3(0, 0, -1))
        for eye in [centerEye, leftEye, rightEye] { eye.camera?.fieldOfView = view == .chair ? 60 : 86 }
        basePosition = cameraRig.simdPosition
        baseOrientation = cameraRig.simdOrientation
        updateCamera()
    }

    func look(yaw: Double, pitch: Double) {
        self.yaw = CinemaLayout.clamp(yaw, -.pi, .pi)
        self.pitch = CinemaLayout.clamp(pitch, -0.78, 0.78)
        updateCamera()
    }

    func setHeight(_ offset: Double) {
        heightOffset = CinemaLayout.clamp(offset, -0.25, 1.25)
        updateCamera()
    }

    private func updateCamera() {
        cameraRig.simdPosition = basePosition + SIMD3(0, Float(heightOffset), 0)
        let horizontal = simd_quatf(angle: Float(yaw), axis: SIMD3(0, 1, 0))
        let vertical = simd_quatf(angle: Float(pitch), axis: SIMD3(1, 0, 0))
        cameraRig.simdOrientation = horizontal * baseOrientation * vertical
    }

    private func accent(_ color: UIColor, group: Int, intensity: CGFloat = 1) -> SCNMaterial {
        let material = CinemaMaterials.glow(color, intensity: intensity)
        accents.append((material, intensity, group))
        return material
    }

    private func buildArchitecture() {
        let root = scene.rootNode
        Geometry.box(root, "foundation", [23.2, 0.3, 29], [0, -0.18, 0.3], materials.floor)
        Geometry.box(root, "ceiling", [23, 0.22, 29], [0, 10.5, 0.3], materials.black)
        Geometry.box(root, "front-wall", [23, 10.5, 0.3], [0, 5.1, -13.65], materials.black)
        Geometry.box(root, "back-wall", [23, 10.5, 0.3], [0, 5.1, 14], materials.wall)
        let guide = accent(Palette.amber, group: 3)
        let ceilingGlow = accent(Palette.ice, group: 2, intensity: 0.5)

        for side in [-1.0, 1.0] {
            Geometry.box(root, "side-wall", [0.3, 10.5, 29], [side * 11.4, 5.1, 0.3], materials.wall)
            Geometry.box(root, "wall-base", [0.18, 0.6, 27.5], [side * 11.17, 0.3, 0.3], materials.ribs)
            for panel in 0..<9 {
                let z = -10.7 + Double(panel) * 2.8
                Geometry.box(root, "acoustic-panel", [0.16, 7.8, 2.3], [side * 11.14, 5.25, z], materials.carpet, radius: 0.055)
                for rib in 0..<5 {
                    Geometry.box(root, "acoustic-flute", [0.10, 7.7, 0.045],
                                 [side * 11.0, 5.25, z - 0.92 + Double(rib) * 0.46], materials.ribs, radius: 0.018)
                }
                let glow = accent(Palette.amber, group: panel < 3 ? 0 : 1)
                // Each sconce sits in a copper channel rather than floating.
                Geometry.box(root, "sconce-channel", [0.16, 5.8, 0.14], [side * 10.95, 5.4, z + 1.30], materials.copper, radius: 0.035)
                Geometry.box(root, "sconce-light", [0.018, 5.55, 0.046], [side * 10.85, 5.4, z + 1.30], glow, radius: 0.008)
                Geometry.box(root, "ceiling-rib", [22.2, 0.12, 0.17], [0, 10.31, z + 1.30], materials.ribs, radius: 0.025)
                Geometry.box(root, "ceiling-edge", [0.04, 0.04, 2.6], [side * 9.8, 10.21, z], ceilingGlow, radius: 0.015)
            }
            Geometry.box(root, "wall-guide", [0.03, 0.025, 25.8], [side * 11.02, 0.72, 0], guide, radius: 0.008)
            // Geometric illuminated door recesses at the back of the room.
            Geometry.box(root, "exit-recess", [0.25, 2.7, 1.65], [side * 11.0, 2.85, 11.6], materials.black, radius: 0.035)
            Geometry.box(root, "exit-top", [0.035, 0.04, 1.65], [side * 10.83, 4.2, 11.6], guide)
        }
        // Fibre optic ceiling dots: static, deterministic and deliberately sparse.
        var random = StableRandom()
        let stars = accent(Palette.pearl, group: 2, intensity: 0.6)
        let constellation = SCNNode()
        for _ in 0..<95 {
            let dot = SCNSphere(radius: 0.008 + Double(random.next()) * 0.01)
            dot.segmentCount = 6
            dot.materials = [stars]
            let node = SCNNode(geometry: dot)
            node.position = SCNVector3(Double(random.next()) * 18 - 9, 10.32, Double(random.next()) * 24 - 12)
            constellation.addChildNode(node)
        }
        root.addChildNode(constellation.flattenedClone())
    }

    private func buildSeating() {
        let prototype = ChairFactory.make(materials: materials)
        let guide = accent(Palette.amber, group: 3, intensity: 0.8)
        for row in 0..<CinemaLayout.rowCount {
            let base = CinemaLayout.floorHeight(row: row)
            let z = CinemaLayout.rowZ(row)
            if base > 0 {
                Geometry.box(scene.rootNode, "tier-\(row)", [18.7, base, 2.8], [0, base / 2, z + 0.55], materials.carpet, radius: 0.02)
                Geometry.box(scene.rootNode, "tier-nosing", [18.7, 0.035, 0.05], [0, base - 0.035, z - 0.84], materials.copper, radius: 0.008)
            }
            for column in 0..<CinemaLayout.seatColumns {
                let chair = prototype.clone()
                chair.name = "orion-r\(row)-c\(column)"
                chair.position = SCNVector3(CinemaLayout.seatX(column), base, z)
                scene.rootNode.addChildNode(chair)
                seatNodes.append(chair)
            }
            for side in [-1.0, 1.0] {
                // Two shallow steps per row in each side aisle.
                for half in 0..<2 {
                    let h = max(0.035, base - 0.18 + Double(half) * 0.18)
                    let stepZ = z - 1.4 + Double(half) * 1.4
                    Geometry.box(scene.rootNode, "aisle-step", [1.5, h, 1.4], [side * 8.6, h / 2, stepZ + 0.7], materials.floor)
                    Geometry.box(scene.rootNode, "step-light", [1.25, 0.016, 0.025], [side * 8.6, h + 0.008, stepZ + 0.10], guide, radius: 0.005)
                }
            }
        }
    }

    private func buildScreen() {
        let stage = accent(Palette.amber, group: 0, intensity: 0.8)
        Geometry.box(scene.rootNode, "stage", [21.5, 0.38, 2.5], [0, 0.19, -11.9], materials.black, radius: 0.12)
        Geometry.box(scene.rootNode, "stage-inlay", [20.6, 0.025, 0.025], [0, 0.29, -10.64], stage, radius: 0.008)
        for (name, w, h, z, material) in [
            ("screen-surround", CinemaLayout.screenWidth + 0.34, CinemaLayout.screenHeight + 0.34, -0.065, materials.ribs),
            ("screen-velvet", CinemaLayout.screenWidth + 0.18, CinemaLayout.screenHeight + 0.18, -0.025, materials.black),
            ("giant-screen", CinemaLayout.screenWidth, CinemaLayout.screenHeight, 0.0, materials.screen)
        ] {
            let mesh = Geometry.curvedScreen(width: w, height: h, radius: CinemaLayout.screenRadius)
            mesh.materials = [material]
            let node = SCNNode(geometry: mesh)
            node.name = name
            node.position = SCNVector3(0, CinemaLayout.screenCenterY, CinemaLayout.screenZ + z)
            scene.rootNode.addChildNode(node)
        }
    }

    private func addLight(type: SCNLight.LightType, color: UIColor, intensity: CGFloat,
                          at position: SCNVector3, target: SCNVector3? = nil, group: Int, shadow: Bool = false) {
        let light = SCNLight()
        light.type = type
        light.color = color
        light.intensity = intensity
        light.attenuationStartDistance = 4
        light.attenuationEndDistance = 35
        light.spotInnerAngle = 55
        light.spotOuterAngle = 115
        light.castsShadow = shadow
        if shadow {
            light.shadowMapSize = CGSize(width: 1024, height: 1024)
            light.shadowRadius = 4
            light.shadowSampleCount = 8
            light.shadowColor = UIColor.black.withAlphaComponent(0.62)
            light.shadowBias = 0.025
        }
        let node = SCNNode()
        node.light = light
        node.position = position
        scene.rootNode.addChildNode(node)
        if let target = target { node.look(at: target) }
        lamps.append((light, intensity, group))
    }

    private func buildLighting() {
        addLight(type: .ambient, color: UIColor(red: 0.64, green: 0.76, blue: 0.79, alpha: 1), intensity: 140, at: SCNVector3Zero, group: 4)
        addLight(type: .omni, color: Palette.pearl, intensity: 520, at: SCNVector3(0, 8.7, 1), group: 2)
        addLight(type: .spot, color: Palette.amber, intensity: 700, at: SCNVector3(0, 8.8, -7), target: SCNVector3(0, 1.5, 1), group: 0, shadow: true)
        for side in [-1.0, 1.0] {
            addLight(type: .omni, color: Palette.amber, intensity: 340, at: SCNVector3(side * 9.6, 5, -2), group: 1)
            addLight(type: .omni, color: Palette.ice, intensity: 230, at: SCNVector3(side * 8.5, 5.8, 7), group: 2)
        }
        // The screen is the remaining light source in the session preview.
        addLight(type: .spot, color: Palette.ice, intensity: 450, at: SCNVector3(0, 5.5, -10.8), target: SCNVector3(0, 2, 4), group: 5)
    }

    func applyDarkness(_ value: Double) {
        darkness = CinemaLayout.clamp(value, 0, 1)
        let lighting = RoomLighting.at(darkness: darkness)
        let factors = [lighting.front, lighting.sides, lighting.ceiling, lighting.guides, lighting.fill, 1.0]
        SCNTransaction.begin()
        SCNTransaction.animationDuration = 0
        for (material, base, group) in accents { material.emission.intensity = base * CGFloat(factors[group]) }
        for (light, base, group) in lamps { light.intensity = base * CGFloat(factors[group]) }
        materials.cupLight.emission.intensity = CGFloat(0.65 * lighting.guides)
        scene.lightingEnvironment.intensity = CGFloat(0.55 * (0.14 + 0.86 * lighting.fill))
        SCNTransaction.commit()
    }

    func showSessionArtwork(_ active: Bool) {
        materials.screen.emission.contents = active ? materials.sessionArtwork : materials.loungeArtwork
    }
}
