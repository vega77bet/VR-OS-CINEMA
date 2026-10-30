import SceneKit
import UIKit

enum Geometry {
    @discardableResult
    static func box(_ parent: SCNNode, _ name: String, _ size: SIMD3<Double>, _ position: SIMD3<Double>,
                    _ material: SCNMaterial, radius: Double = 0) -> SCNNode {
        let mesh = SCNBox(width: size.x, height: size.y, length: size.z, chamferRadius: radius)
        mesh.chamferSegmentCount = radius > 0 ? 3 : 1
        mesh.materials = [material]
        let node = SCNNode(geometry: mesh)
        node.name = name
        node.position = SCNVector3(position.x, position.y, position.z)
        parent.addChildNode(node)
        return node
    }

    static func curvedScreen(width: Double, height: Double, radius: Double, segments: Int = 96,
                             texturePoint: (CGPoint) -> CGPoint = { $0 }) -> SCNGeometry {
        precondition(width > 0 && height > 0 && radius > width / 2 && segments >= 2)
        var vertices: [SCNVector3] = [], normals: [SCNVector3] = [], uv: [CGPoint] = [], indices: [Int32] = []
        let arc = asin(width / (2 * radius))
        for row in 0...1 {
            for column in 0...segments {
                let u = Double(column) / Double(segments)
                let angle = (2 * u - 1) * arc
                vertices.append(SCNVector3(radius * sin(angle), (Double(row) - 0.5) * height, radius * (1 - cos(angle))))
                normals.append(SCNVector3(-sin(angle), 0, cos(angle)))
                uv.append(texturePoint(CGPoint(x: u, y: 1 - Double(row))))
            }
        }
        for column in 0..<segments {
            let a = Int32(column), b = a + 1, c = a + Int32(segments + 1), d = c + 1
            indices.append(contentsOf: [a, b, c, b, d, c])
        }
        return SCNGeometry(sources: [SCNGeometrySource(vertices: vertices), SCNGeometrySource(normals: normals),
                                     SCNGeometrySource(textureCoordinates: uv)],
                           elements: [SCNGeometryElement(indices: indices, primitiveType: .triangles)])
    }
}
