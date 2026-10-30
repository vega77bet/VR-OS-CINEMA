import CoreMotion
import UIKit

/// Rotation reported by the phone and expressed in the viewer's camera axes.
/// A cardboard-style viewer provides rotational (3DoF) tracking, not room-scale
/// positional tracking.
struct HeadMotionSample: Equatable {
    let yaw: Double
    let pitch: Double
    let roll: Double
}

enum HeadMotionMapper {
    /// The phone is mounted in landscape inside the viewer. Core Motion's
    /// pitch/roll axes are device axes, so landscape changes which one maps to
    /// looking left/right and looking up/down.
    static func sample(pitch: Double, roll: Double, yaw: Double,
                       interfaceOrientation: UIInterfaceOrientation) -> HeadMotionSample {
        switch interfaceOrientation {
        case .landscapeRight:
            // SceneKit's positive X rotation makes the view look downward.
            // Core Motion reports the opposite sign for the viewer's vertical
            // look direction, so invert the mapped pitch in both orientations.
            // SceneKit's positive Y rotation turns the camera toward the
            // opposite side of the viewer. Invert yaw so turning the head
            // right moves the view right in the VR Box.
            return HeadMotionSample(yaw: pitch, pitch: -roll, roll: yaw)
        default:
            // landscapeLeft is the default orientation used by the viewer.
            // SceneKit's positive Y rotation turns the camera toward the
            // opposite side of the viewer. Invert yaw so turning the head
            // right moves the view right in the VR Box.
            return HeadMotionSample(yaw: -pitch, pitch: roll, roll: yaw)
        }
    }
}

/// Owns the single Core Motion stream used by the app.
final class HeadMotionController {
    private let motion = CMMotionManager()
    private let queue = OperationQueue()
    private let lock = NSLock()
    private var referenceAttitude: CMAttitude?
    private var running = false
    private var orientation: UIInterfaceOrientation = .landscapeLeft
    private var pendingSample: HeadMotionSample?
    private var deliveryScheduled = false

    var onSample: ((HeadMotionSample) -> Void)?

    var isAvailable: Bool { motion.isDeviceMotionAvailable }

    var isRunning: Bool {
        lock.lock()
        defer { lock.unlock() }
        return running
    }

    init() {
        queue.name = "com.vega77bet.vroscinema.head-motion"
        queue.maxConcurrentOperationCount = 1
        queue.qualityOfService = .userInteractive
    }

    @discardableResult
    func start(interfaceOrientation: UIInterfaceOrientation) -> Bool {
#if targetEnvironment(simulator)
        // The simulator cannot provide a physical head pose. Keeping Core
        // Motion off here makes UI automation deterministic; a real iPhone
        // takes the device path below.
        return false
#else
        guard motion.isDeviceMotionAvailable else { return false }

        stop()
        lock.lock()
        orientation = interfaceOrientation
        referenceAttitude = nil
        running = true
        lock.unlock()

        motion.deviceMotionUpdateInterval = 1.0 / 60.0
        motion.showsDeviceMovementDisplay = true
        motion.startDeviceMotionUpdates(using: .xArbitraryCorrectedZVertical,
                                        to: queue) { [weak self] data, error in
            guard let self, error == nil, let data else { return }
            self.consume(data.attitude)
        }
        return true
#endif
    }

    func stop() {
        motion.stopDeviceMotionUpdates()
        lock.lock()
        running = false
        referenceAttitude = nil
        pendingSample = nil
        lock.unlock()
    }

    /// The next valid sample becomes the user's forward direction.
    func recenter() {
        lock.lock()
        referenceAttitude = nil
        lock.unlock()
    }

    private func consume(_ attitude: CMAttitude) {
        lock.lock()
        if referenceAttitude == nil {
            referenceAttitude = attitude.copy() as? CMAttitude
        }
        let reference = referenceAttitude
        let currentOrientation = orientation
        let isActive = running
        lock.unlock()

        guard isActive, let reference else { return }
        guard let relative = attitude.copy() as? CMAttitude else { return }
        // Core Motion explicitly provides this operation for calculating the
        // change from the calibration attitude to the current attitude.
        relative.multiply(byInverseOf: reference)

        let sample = HeadMotionMapper.sample(pitch: relative.pitch,
                                              roll: relative.roll,
                                              yaw: relative.yaw,
                                              interfaceOrientation: currentOrientation)
        enqueue(sample)
    }

    /// Core Motion can produce more samples than the renderer can consume.
    /// Keep only the newest pose and schedule one main-thread delivery so a
    /// slow simulator or a busy scene never builds an unbounded callback queue.
    private func enqueue(_ sample: HeadMotionSample) {
        lock.lock()
        pendingSample = sample
        guard !deliveryScheduled else {
            lock.unlock()
            return
        }
        deliveryScheduled = true
        lock.unlock()

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.lock.lock()
            let latest = self.pendingSample
            self.pendingSample = nil
            self.deliveryScheduled = false
            let isActive = self.running
            self.lock.unlock()

            guard isActive, let latest else { return }
            self.onSample?(latest)
        }
    }
}
