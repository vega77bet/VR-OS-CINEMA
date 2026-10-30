import Foundation
import CoreGraphics

enum VideoLayout: String, CaseIterable {
    case flat, halfSBS, fullSBS, halfOU, fullOU

    var title: String {
        switch self {
        case .flat: return "2D"
        case .halfSBS: return "Half SBS"
        case .fullSBS: return "Full SBS"
        case .halfOU: return "Half cima/baixo"
        case .fullOU: return "Full cima/baixo"
        }
    }
    var isStereo: Bool { self != .flat }

    /// Explicit file tags are useful hints. An ordinary 1920×1080 frame may be
    /// either 2D or half-packed 3D, so dimensions alone must never force 3D.
    static func suggested(for name: String) -> VideoLayout? {
        let words = name.uppercased().components(separatedBy: CharacterSet.alphanumerics.inverted).filter { !$0.isEmpty }
        let tags = Set(words)
        if tags.contains("FSBS") || tags.contains("FULLSBS") || (tags.contains("FULL") && tags.contains("SBS")) { return .fullSBS }
        if tags.contains("FOU") || tags.contains("FTB") || (tags.contains("FULL") && (tags.contains("OU") || tags.contains("TAB") || tags.contains("TB"))) { return .fullOU }
        if !tags.isDisjoint(with: ["HSBS", "SBS", "HALFSBS"]) { return .halfSBS }
        if !tags.isDisjoint(with: ["HOU", "HTB", "OU", "TAB", "TB", "HALFOU"]) { return .halfOU }
        return nil
    }

    /// Normalized coordinates use a top-left origin, matching decoded video.
    func crop(rightEye: Bool, swapped: Bool) -> CGRect {
        let second = rightEye != swapped
        switch self {
        case .flat: return CGRect(x: 0, y: 0, width: 1, height: 1)
        case .halfSBS, .fullSBS: return CGRect(x: second ? 0.5 : 0, y: 0, width: 0.5, height: 1)
        case .halfOU, .fullOU: return CGRect(x: 0, y: second ? 0.5 : 0, width: 1, height: 0.5)
        }
    }

    func eyeAspect(frame: CGSize) -> Double {
        let aspect = Double(frame.width / max(frame.height, 1))
        switch self {
        case .fullSBS: return aspect / 2
        case .fullOU: return aspect * 2
        default: return aspect
        }
    }
}

enum CinemaAmbience: String, CaseIterable {
    case classic, portal, blackout
    var title: String {
        switch self {
        case .classic: return "Clássico"
        case .portal: return "Portal"
        case .blackout: return "Sala escura"
        }
    }
}

struct ProjectionSettings {
    var layout: VideoLayout = .flat
    var swapEyes = false
    var aspectOverride: Double? = nil
    // Small horizontal alignment adjustment, not invented depth or 2D-to-3D.
    var alignment = 0.0
    var eyeDistance = 0.064
    var screenDistance = 0.0
    var curved = true
    var ambience: CinemaAmbience = .classic
    var ambientLight = true
    var brightness = 1.0

    func aspect(frame: CGSize) -> Double { aspectOverride ?? layout.eyeAspect(frame: frame) }

    func uv(_ point: CGPoint, rightEye: Bool, frame: CGSize, transform: CGAffineTransform) -> CGPoint {
        let crop = layout.crop(rightEye: rightEye, swapped: swapEyes)
        let shift = layout.isStereo ? min(max(alignment, -0.0075), 0.0075) : 0
        let margin = abs(shift)
        let x = margin + point.x * (1 - 2 * margin) + (rightEye ? -shift : shift)
        // Track orientation is independent of the packing format. Convert the
        // selected part of the displayed image back to the decoder's native UV.
        let bounds = CGRect(origin: .zero, size: frame).applying(transform)
        // Linear filtering at an SBS/OU split must not sample a texel from the
        // other eye. Keep the outer UVs at the centers of the selected texels.
        let insetX = min(crop.width / 4, 0.5 / max(bounds.width, 1))
        let insetY = min(crop.height / 4, 0.5 / max(bounds.height, 1))
        let displayed = CGPoint(x: crop.minX + insetX + x * (crop.width - 2 * insetX),
                                y: crop.minY + insetY + point.y * (crop.height - 2 * insetY))
        let oriented = CGPoint(x: bounds.minX + displayed.x * bounds.width, y: bounds.minY + displayed.y * bounds.height)
        let raw = oriented.applying(transform.inverted())
        return CGPoint(x: raw.x / max(frame.width, 1), y: raw.y / max(frame.height, 1))
    }
}

enum MovieTime {
    static func label(_ seconds: Double) -> String {
        guard seconds.isFinite, seconds >= 0 else { return "--:--" }
        let total = Int(min(seconds, 359999))
        return total >= 3600 ? String(format: "%d:%02d:%02d", total / 3600, total / 60 % 60, total % 60)
                            : String(format: "%d:%02d", total / 60, total % 60)
    }
}
