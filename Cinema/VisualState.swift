import Foundation

/// All distances are metres. Video playback is projected onto the screen
/// material; the room remains fully usable when no movie is selected.
enum CinemaLayout {
    static let screenWidth = 19.6
    static let screenHeight = 7.6
    static let screenRadius = 28.0
    static let screenCenterY = 5.4
    static let screenZ = -12.4
    static let rowCount = 6
    static let seatColumns = 7
    static let rowSpacing = 2.8
    static let rowRise = 0.36
    static let firstRowZ = -5.4
    static let seatSpacing = 2.1
    static let defaultEyeHeight = 3.18
    static let defaultEyeZ = 2.62
    static let motionPitchLimit = 1.35
    static let dimmingDuration = 3.6

    static func floorHeight(row: Int) -> Double { Double(row) * rowRise }
    static func rowZ(_ row: Int) -> Double { firstRowZ + Double(row) * rowSpacing }
    static func seatX(_ column: Int) -> Double { Double(column - 3) * seatSpacing }

    static func clamp(_ value: Double, _ low: Double, _ high: Double) -> Double {
        min(max(value, low), high)
    }
    static func smooth(_ value: Double) -> Double {
        let t = clamp(value, 0, 1)
        return t * t * (3 - 2 * t)
    }
}

struct RoomLighting: Equatable {
    let front: Double
    let sides: Double
    let ceiling: Double
    let guides: Double
    let fill: Double

    static func at(darkness: Double) -> RoomLighting {
        let t = CinemaLayout.clamp(darkness, 0, 1)
        func fade(_ start: Double, _ end: Double, minimum: Double) -> Double {
            1 - (1 - minimum) * CinemaLayout.smooth((t - start) / (end - start))
        }
        return RoomLighting(
            front: fade(0, 0.65, minimum: 0.008),
            sides: fade(0.15, 0.9, minimum: 0.012),
            ceiling: fade(0.05, 0.75, minimum: 0.025),
            guides: fade(0.25, 1, minimum: 0.14),
            fill: fade(0, 1, minimum: 0.08)
        )
    }
}

/// Reversible transitions start at the current value; rapid taps never jump.
struct LightTransition {
    var from: Double = 0
    var target: Double = 0
    var started: TimeInterval = 0
    var duration: TimeInterval = 0

    func value(at time: TimeInterval) -> Double {
        guard duration > 0 else { return target }
        let t = CinemaLayout.smooth((time - started) / duration)
        return from + (target - from) * t
    }
    func isFinished(at time: TimeInterval) -> Bool { time >= started + duration }

    mutating func move(to value: Double, at time: TimeInterval, reducedMotion: Bool) {
        from = self.value(at: time)
        target = CinemaLayout.clamp(value, 0, 1)
        started = time
        duration = reducedMotion ? 0 : CinemaLayout.dimmingDuration * abs(target - from)
    }
}

enum RoomView: Int, CaseIterable {
    case seat, room, chair
    var title: String {
        switch self {
        case .seat: return "Minha poltrona"
        case .room: return "Ver sala"
        case .chair: return "Ver poltrona"
        }
    }
}
