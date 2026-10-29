import UIKit
import SceneKit

final class CinemaViewController: UIViewController {
    let cinema = CinemaScene()
    private var renderers: [SCNView] = []
    private var huds: [CinemaHUD] = []
    private var stereo = false
    private var dark = false
    private var hiddenHUD = false
    private var transition = LightTransition()
    private var displayLink: CADisplayLink?
    private var dragStart = CGPoint.zero
    private var lookStart = CGPoint.zero
    private var lastSettled = true
    private var active = false
    private var rememberedIdleTimer = false
    private let phase = UILabel()

    override var prefersStatusBarHidden: Bool { true }
    override var prefersHomeIndicatorAutoHidden: Bool { true }
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask { .landscape }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        phase.isAccessibilityElement = true
        phase.accessibilityIdentifier = "lighting.phase"
        phase.text = "lounge"
        phase.textColor = .clear
        phase.font = .systemFont(ofSize: 1)
        phase.frame = CGRect(x: 1, y: 1, width: 2, height: 2)
        buildViewports()
        NotificationCenter.default.addObserver(self, selector: #selector(suspend), name: UIApplication.willResignActiveNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(resume), name: UIApplication.didBecomeActiveNotification, object: nil)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        rememberedIdleTimer = UIApplication.shared.isIdleTimerDisabled
        UIApplication.shared.isIdleTimerDisabled = true
        resume()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        suspend()
        UIApplication.shared.isIdleTimerDisabled = rememberedIdleTimer
    }

    deinit {
        displayLink?.invalidate()
        NotificationCenter.default.removeObserver(self)
    }

    private func buildViewports() {
        renderers.forEach { $0.removeFromSuperview() }
        huds.forEach { $0.removeFromSuperview() }
        renderers.removeAll()
        huds.removeAll()
        for eye in 0..<(stereo ? 2 : 1) {
            let renderer = SCNView(frame: .zero, options: nil)
            renderer.backgroundColor = .black
            renderer.scene = cinema.scene
            renderer.pointOfView = stereo ? (eye == 0 ? cinema.leftEye : cinema.rightEye) : cinema.centerEye
            renderer.preferredFramesPerSecond = 60
            renderer.antialiasingMode = .multisampling2X
            renderer.isPlaying = active
            renderer.autoenablesDefaultLighting = false
            renderer.allowsCameraControl = false
            renderer.accessibilityIdentifier = stereo ? "viewport.eye.\(eye)" : "viewport.mono"
            let pan = UIPanGestureRecognizer(target: self, action: #selector(pan(_:)))
            renderer.addGestureRecognizer(pan)
            let tap = UITapGestureRecognizer(target: self, action: #selector(toggleHUD))
            tap.require(toFail: pan)
            renderer.addGestureRecognizer(tap)
            view.addSubview(renderer)
            renderers.append(renderer)
            let hud = CinemaHUD(compact: stereo)
            hud.onAction = { [weak self] action in self?.perform(action) }
            hud.alpha = hiddenHUD ? 0 : 1
            view.addSubview(hud)
            huds.append(hud)
        }
        view.addSubview(phase)
        updateHUD()
        view.setNeedsLayout()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let gap: CGFloat = stereo ? 2 : 0
        let width = (view.bounds.width - gap) / CGFloat(renderers.count)
        for i in renderers.indices {
            let frame = CGRect(x: CGFloat(i) * (width + gap), y: 0, width: width, height: view.bounds.height)
            renderers[i].frame = frame
            huds[i].frame = frame
        }
    }

    private func perform(_ action: String) {
        switch action {
        case "seat": cinema.setView(.seat)
        case "room": cinema.setView(.room)
        case "chair": cinema.setView(.chair)
        case "height":
            cinema.setHeight(cinema.heightOffset >= 0.74 ? 0 : cinema.heightOffset + 0.25)
        case "stereo":
            stereo.toggle()
            cinema.setView(.seat)
            hiddenHUD = false
            buildViewports()
        case "session":
            dark.toggle()
            lastSettled = false
            transition.move(to: dark ? 1 : 0, at: CACurrentMediaTime(), reducedMotion: UIAccessibility.isReduceMotionEnabled)
            cinema.showSessionArtwork(dark)
            phase.text = "transition"
            setHUDHidden(false)
        default: break
        }
        updateHUD()
    }

    @objc private func pan(_ gesture: UIPanGestureRecognizer) {
        if gesture.state == .began {
            dragStart = gesture.translation(in: view)
            lookStart = CGPoint(x: cinema.yaw, y: cinema.pitch)
        }
        let translation = gesture.translation(in: view)
        cinema.look(yaw: Double(lookStart.x) - Double(translation.x - dragStart.x) * 0.0035,
                    pitch: Double(lookStart.y) - Double(translation.y - dragStart.y) * 0.0035)
    }

    @objc private func toggleHUD() { setHUDHidden(!hiddenHUD) }

    private func setHUDHidden(_ hidden: Bool) {
        hiddenHUD = hidden
        let duration = UIAccessibility.isReduceMotionEnabled ? 0 : 0.28
        UIView.animate(withDuration: duration) { self.huds.forEach { $0.alpha = hidden ? 0 : 1 } }
    }

    private func updateHUD() { huds.forEach { $0.update(dark: dark, settled: lastSettled, currentView: cinema.view) } }

    @objc private func tick(_ link: CADisplayLink) {
        if !lastSettled {
            cinema.applyDarkness(transition.value(at: link.timestamp))
            if transition.isFinished(at: link.timestamp) {
                lastSettled = true
                phase.text = dark ? "screening" : "lounge"
                updateHUD()
                if dark && !UIAccessibility.isVoiceOverRunning { setHUDHidden(true) }
            }
        }
    }

    @objc private func suspend() {
        active = false
        displayLink?.invalidate()
        displayLink = nil
        renderers.forEach { $0.isPlaying = false }
    }

    @objc private func resume() {
        guard viewIfLoaded?.window != nil else { return }
        active = true
        renderers.forEach { $0.isPlaying = true }
        guard displayLink == nil else { return }
        // A weak proxy prevents CADisplayLink from retaining the controller.
        let proxy = DisplayLinkProxy(owner: self)
        let link = CADisplayLink(target: proxy, selector: #selector(DisplayLinkProxy.fire(_:)))
        link.preferredFramesPerSecond = 60
        link.add(to: .main, forMode: .common)
        displayLink = link
    }

    private final class DisplayLinkProxy: NSObject {
        weak var owner: CinemaViewController?
        init(owner: CinemaViewController) { self.owner = owner }
        @objc func fire(_ link: CADisplayLink) { owner?.tick(link) }
    }
}
