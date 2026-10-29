import SceneKit
import UIKit

/// Original Orion chair: reclined monocoque, quilted teal insert and copper plinth.
enum ChairFactory {
    static func make(materials m: CinemaMaterials) -> SCNNode {
        let prototype = SCNNode()
        prototype.name = "Orion"
        let body = SCNNode()
        Geometry.box(body, "pedestal", [0.87, 0.14, 0.82], [0, 0.12, 0.12], m.black, radius: 0.06)
        Geometry.box(body, "copper-plinth", [1.12, 0.055, 1.13], [0, 0.24, 0], m.copper, radius: 0.025)
        Geometry.box(body, "shell-base", [1.17, 0.25, 1.08], [0, 0.39, 0], m.shell, radius: 0.10)
        Geometry.box(body, "seat-cushion", [1.02, 0.24, 0.91], [0, 0.61, -0.14], m.cushion, radius: 0.105)
        Geometry.box(body, "seat-piping", [1.035, 0.016, 0.92], [0, 0.60, -0.14], m.piping, radius: 0.006)
        let foot = Geometry.box(body, "sculpted-footrest", [1.0, 0.42, 0.18], [0, 0.38, -0.65], m.cushion, radius: 0.075)
        foot.eulerAngles.x = -0.14
        let back = SCNNode()
        back.position = SCNVector3(0, 0.72, 0.29)
        back.eulerAngles.x = 0.13
        body.addChildNode(back)
        Geometry.box(back, "reclined-shell", [1.15, 1.03, 0.25], [0, 0.43, 0.035], m.shell, radius: 0.12)
        Geometry.box(back, "stitched-back", [0.98, 0.78, 0.17], [0, 0.38, -0.11], m.upholstery, radius: 0.075)
        Geometry.box(back, "lumbar", [0.91, 0.19, 0.20], [0, 0.035, -0.16], m.cushion, radius: 0.085)
        Geometry.box(back, "headrest", [0.94, 0.25, 0.22], [0, 0.88, -0.11], m.cushion, radius: 0.10)
        for side in [-1.0, 1.0] {
            Geometry.box(back, "back-bolster", [0.14, 0.65, 0.19], [side * 0.49, 0.41, -0.12], m.cushion, radius: 0.065)
            Geometry.box(back, "copper-spine", [0.025, 0.68, 0.04], [side * 0.57, 0.44, 0.02], m.copper, radius: 0.01)
            Geometry.box(body, "arm-shell", [0.25, 0.62, 1.08], [side * 0.69, 0.56, -0.01], m.shell, radius: 0.10)
            Geometry.box(body, "arm-pad", [0.265, 0.16, 1.02], [side * 0.69, 0.91, -0.015], m.cushion, radius: 0.075)
            Geometry.box(body, "arm-inlay", [0.012, 0.022, 0.73], [side * 0.822, 0.79, -0.04], m.copper, radius: 0.005)
            let inset = SCNCylinder(radius: 0.072, height: 0.014)
            inset.radialSegmentCount = 20
            inset.materials = [m.black]
            let cup = SCNNode(geometry: inset)
            cup.position = SCNVector3(side * 0.69, 0.998, -0.29)
            body.addChildNode(cup)
            let ring = SCNTorus(ringRadius: 0.077, pipeRadius: 0.006)
            ring.ringSegmentCount = 24
            ring.pipeSegmentCount = 6
            ring.materials = [m.cupLight]
            let rim = SCNNode(geometry: ring)
            rim.position = SCNVector3(side * 0.69, 1.008, -0.29)
            prototype.addChildNode(rim)
        }
        // Inlaid chevron on the headrest, own geometric identity.
        for side in [-1.0, 1.0] {
            let mark = Geometry.box(back, "orion-mark", [0.014, 0.095, 0.012], [side * 0.027, 0.88, -0.226], m.copper, radius: 0.005)
            mark.eulerAngles.z = Float(side * 0.65)
        }
        // Merge opaque chair parts once, then share the geometry between all seats.
        prototype.addChildNode(body.flattenedClone())
        return prototype
    }
}
