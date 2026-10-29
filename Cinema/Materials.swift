import UIKit
import SceneKit

enum Palette {
    static let ink = UIColor(red: 0.025, green: 0.05, blue: 0.065, alpha: 1)
    static let teal = UIColor(red: 0.035, green: 0.145, blue: 0.17, alpha: 1)
    static let copper = UIColor(red: 0.48, green: 0.29, blue: 0.17, alpha: 1)
    static let amber = UIColor(red: 1, green: 0.69, blue: 0.32, alpha: 1)
    static let ice = UIColor(red: 0.33, green: 0.77, blue: 0.82, alpha: 1)
    static let pearl = UIColor(red: 0.92, green: 0.92, blue: 0.87, alpha: 1)
}

struct StableRandom {
    private var state: UInt64 = 0xA170_2BC9
    mutating func next() -> CGFloat {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return CGFloat((state >> 33) & 0x7FFF_FFFF) / CGFloat(0x7FFF_FFFF)
    }
}

final class CinemaMaterials {
    let upholstery: SCNMaterial
    let shell: SCNMaterial
    let cushion: SCNMaterial
    let copper: SCNMaterial
    let black: SCNMaterial
    let carpet: SCNMaterial
    let wall: SCNMaterial
    let ribs: SCNMaterial
    let floor: SCNMaterial
    let piping: SCNMaterial
    let cupLight: SCNMaterial
    let screen: SCNMaterial
    let loungeArtwork: UIImage
    let sessionArtwork: UIImage

    init() {
        upholstery = Self.pbr(Palette.teal, roughness: 0.94)
        upholstery.diffuse.contents = Textures.leather(quilted: true)
        cushion = Self.pbr(Palette.teal, roughness: 0.91)
        cushion.diffuse.contents = Textures.leather(quilted: false)
        shell = Self.pbr(UIColor(red: 0.03, green: 0.055, blue: 0.07, alpha: 1), roughness: 0.62, metal: 0.15)
        copper = Self.pbr(Palette.copper, roughness: 0.46, metal: 0.68)
        black = Self.pbr(Palette.ink, roughness: 0.7)
        carpet = Self.pbr(UIColor(white: 0.065, alpha: 1), roughness: 1)
        carpet.diffuse.contents = Textures.fabric()
        wall = Self.pbr(UIColor(red: 0.065, green: 0.10, blue: 0.12, alpha: 1), roughness: 0.94)
        ribs = Self.pbr(UIColor(red: 0.11, green: 0.16, blue: 0.18, alpha: 1), roughness: 0.47, metal: 0.3)
        floor = Self.pbr(UIColor(red: 0.04, green: 0.06, blue: 0.075, alpha: 1), roughness: 0.72, metal: 0.05)
        piping = Self.pbr(UIColor(red: 0.27, green: 0.40, blue: 0.40, alpha: 1), roughness: 0.6)
        cupLight = Self.glow(Palette.amber, intensity: 0.65)
        loungeArtwork = Textures.screen(titles: true)
        sessionArtwork = Textures.screen(titles: false)
        screen = Self.glow(.white)
        screen.diffuse.contents = UIColor.black
        screen.emission.contents = loungeArtwork
    }

    static func pbr(_ color: UIColor, roughness: CGFloat, metal: CGFloat = 0) -> SCNMaterial {
        let material = SCNMaterial()
        material.lightingModel = .physicallyBased
        material.diffuse.contents = color
        material.roughness.contents = roughness
        material.metalness.contents = metal
        return material
    }
    static func glow(_ color: UIColor, intensity: CGFloat = 1) -> SCNMaterial {
        let material = SCNMaterial()
        material.lightingModel = .constant
        material.diffuse.contents = UIColor.black
        material.emission.contents = color
        material.emission.intensity = intensity
        return material
    }
}

enum Textures {
    static func image(_ size: CGSize, draw: (CGContext) -> Void) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        return UIGraphicsImageRenderer(size: size, format: format).image { draw($0.cgContext) }
    }

    static func leather(quilted: Bool) -> UIImage {
        image(CGSize(width: 512, height: 512)) { context in
            context.setFillColor(Palette.teal.cgColor)
            context.fill(CGRect(x: 0, y: 0, width: 512, height: 512))
            var rng = StableRandom()
            for _ in 0..<11000 {
                let white: CGFloat = rng.next() > 0.5 ? 1 : 0
                context.setFillColor(UIColor(white: white, alpha: 0.045).cgColor)
                context.fillEllipse(in: CGRect(x: rng.next() * 512, y: rng.next() * 512, width: 1.2, height: 1.2))
            }
            if quilted {
                context.setStrokeColor(UIColor(white: 0, alpha: 0.28).cgColor)
                context.setLineWidth(3)
                for offset in stride(from: -512, through: 1024, by: 128) {
                    context.move(to: CGPoint(x: offset, y: 0))
                    context.addLine(to: CGPoint(x: offset + 512, y: 512))
                    context.move(to: CGPoint(x: offset, y: 0))
                    context.addLine(to: CGPoint(x: offset - 512, y: 512))
                }
                context.strokePath()
                context.setLineDash(phase: 0, lengths: [3, 5])
                context.setLineWidth(1)
                context.setStrokeColor(UIColor(red: 0.34, green: 0.52, blue: 0.51, alpha: 0.7).cgColor)
                for offset in stride(from: -512, through: 1024, by: 128) {
                    context.move(to: CGPoint(x: offset + 3, y: 0))
                    context.addLine(to: CGPoint(x: offset + 515, y: 512))
                    context.move(to: CGPoint(x: offset - 3, y: 0))
                    context.addLine(to: CGPoint(x: offset - 515, y: 512))
                }
                context.strokePath()
            }
        }
    }

    static func fabric() -> UIImage {
        image(CGSize(width: 256, height: 256)) { context in
            context.setFillColor(UIColor(red: 0.055, green: 0.08, blue: 0.09, alpha: 1).cgColor)
            context.fill(CGRect(x: 0, y: 0, width: 256, height: 256))
            for i in stride(from: 0, to: 256, by: 4) {
                context.setStrokeColor(UIColor(white: 0.3, alpha: 0.12).cgColor)
                context.move(to: CGPoint(x: 0, y: i))
                context.addLine(to: CGPoint(x: 256, y: i))
                context.move(to: CGPoint(x: i, y: 0))
                context.addLine(to: CGPoint(x: i, y: 256))
            }
            context.strokePath()
        }
    }

    static func environment() -> UIImage {
        image(CGSize(width: 512, height: 256)) { context in
            let colors = [UIColor(white: 0.16, alpha: 1).cgColor,
                          UIColor(red: 0.07, green: 0.12, blue: 0.14, alpha: 1).cgColor,
                          UIColor(red: 0.035, green: 0.045, blue: 0.06, alpha: 1).cgColor]
            let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors as CFArray, locations: [0, 0.5, 1])!
            context.drawLinearGradient(gradient, start: .zero, end: CGPoint(x: 0, y: 256), options: [])
        }
    }

    /// Original procedural artwork. No external assets or network requests.
    static func screen(titles: Bool) -> UIImage {
        image(CGSize(width: 2048, height: 800)) { context in
            let colors = [UIColor(red: 0.018, green: 0.052, blue: 0.095, alpha: 1).cgColor,
                          UIColor(red: 0.025, green: 0.23, blue: 0.29, alpha: 1).cgColor,
                          UIColor(red: 0.075, green: 0.12, blue: 0.18, alpha: 1).cgColor]
            let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors as CFArray, locations: [0, 0.65, 1])!
            context.drawLinearGradient(gradient, start: .zero, end: CGPoint(x: 2048, y: 800), options: [])
            var rng = StableRandom()
            for _ in 0..<380 {
                let x = rng.next() * 2048, y = rng.next() * 700
                let r = 0.5 + rng.next() * 1.3
                context.setFillColor(UIColor(white: 1, alpha: 0.15 + rng.next() * 0.65).cgColor)
                context.fillEllipse(in: CGRect(x: x, y: y, width: r, height: r))
            }
            // Soft aurora ribbons, built up as translucent curves.
            for i in 0..<64 {
                let t = CGFloat(i) / 64
                context.setLineWidth(3 + t * 8)
                context.setStrokeColor(UIColor(red: 0.21, green: 0.91, blue: 0.79, alpha: 0.009 + 0.014 * (1 - t)).cgColor)
                context.move(to: CGPoint(x: -100, y: 450 + t * 130))
                context.addCurve(to: CGPoint(x: 2160, y: 120 + t * 130),
                                 control1: CGPoint(x: 800, y: -180 + t * 300),
                                 control2: CGPoint(x: 1190, y: 830 - t * 240))
                context.strokePath()
            }
            context.setFillColor(UIColor(red: 0.008, green: 0.027, blue: 0.043, alpha: 1).cgColor)
            context.move(to: CGPoint(x: 0, y: 720))
            context.addCurve(to: CGPoint(x: 2048, y: 660), control1: CGPoint(x: 600, y: 460), control2: CGPoint(x: 1430, y: 800))
            context.addLine(to: CGPoint(x: 2048, y: 800))
            context.addLine(to: CGPoint(x: 0, y: 800))
            context.closePath()
            context.fillPath()
            // Copper orbital ring and a luminous distant moon.
            context.saveGState()
            context.translateBy(x: 1530, y: 340)
            context.rotate(by: -0.36)
            context.setStrokeColor(UIColor(red: 0.86, green: 0.63, blue: 0.38, alpha: 0.68).cgColor)
            context.setLineWidth(1.8)
            context.strokeEllipse(in: CGRect(x: -290, y: -95, width: 580, height: 190))
            context.restoreGState()
            let moon = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: [Palette.pearl.cgColor, Palette.teal.cgColor] as CFArray, locations: [0, 1])!
            context.saveGState()
            context.addEllipse(in: CGRect(x: 1430, y: 240, width: 200, height: 200))
            context.clip()
            context.drawLinearGradient(moon, start: CGPoint(x: 1410, y: 210), end: CGPoint(x: 1615, y: 435), options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
            context.restoreGState()
            if titles {
                let paragraph = NSMutableParagraphStyle()
                paragraph.alignment = .left
                func text(_ string: String, y: CGFloat, size: CGFloat, color: UIColor, spacing: CGFloat, weight: UIFont.Weight) {
                    (string as NSString).draw(in: CGRect(x: 180, y: y, width: 1180, height: 180), withAttributes: [
                        .font: UIFont.systemFont(ofSize: size, weight: weight), .foregroundColor: color,
                        .kern: spacing, .paragraphStyle: paragraph
                    ])
                }
                text("V R — O S   /   C I N E M A", y: 222, size: 22, color: Palette.amber, spacing: 3, weight: .medium)
                text("AURORA", y: 275, size: 110, color: Palette.pearl, spacing: 18, weight: .ultraLight)
                text("O seu lugar em outra dimensão.", y: 425, size: 29, color: Palette.pearl.withAlphaComponent(0.7), spacing: 1, weight: .light)
            }
        }
    }
}
