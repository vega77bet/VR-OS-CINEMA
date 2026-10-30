import UIKit
import SceneKit
import AVFoundation
import UniformTypeIdentifiers

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
    private let headMotion = HeadMotionController()
    private var motionEnabled = true
    private var motionAvailable = false
    private var moviePlayer: AVPlayer?
    private var movieEndObserver: NSObjectProtocol?
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
        headMotion.onSample = { [weak self] sample in
            self?.applyMotion(sample)
        }
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
        if let movieEndObserver { NotificationCenter.default.removeObserver(movieEndObserver) }
        moviePlayer?.pause()
        headMotion.stop()
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
            renderer.isPlaying = active && !lastSettled
            renderer.rendersContinuously = false
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
        case "seat": changeView(.seat)
        case "room": changeView(.room)
        case "chair": changeView(.chair)
        case "height":
            cinema.setHeight(cinema.heightOffset >= 0.74 ? 0 : cinema.heightOffset + 0.25)
        case "stereo":
            stereo.toggle()
            changeView(.seat)
            hiddenHUD = false
            buildViewports()
        case "motion":
            if motionEnabled {
                motionEnabled = false
                motionAvailable = false
                headMotion.stop()
                cinema.setMotion(yaw: 0, pitch: 0, roll: 0)
            } else {
                motionEnabled = true
                startMotion()
            }
        case "movie":
            if moviePlayer == nil {
                chooseMovie()
            } else {
                toggleMoviePlayback()
            }
        case "session":
            dark.toggle()
            lastSettled = false
            transition.move(to: dark ? 1 : 0, at: CACurrentMediaTime(), reducedMotion: UIAccessibility.isReduceMotionEnabled)
            cinema.showSessionArtwork(dark)
            phase.text = "transition"
            setHUDHidden(false)
            startAnimationClock()
        default: break
        }
        updateHUD()
        renderers.forEach { $0.setNeedsDisplay() }
    }

    @objc private func pan(_ gesture: UIPanGestureRecognizer) {
        if gesture.state == .began {
            dragStart = gesture.translation(in: view)
            lookStart = CGPoint(x: cinema.yaw, y: cinema.pitch)
        }
        let translation = gesture.translation(in: view)
        cinema.look(yaw: Double(lookStart.x) - Double(translation.x - dragStart.x) * 0.0035,
                    pitch: Double(lookStart.y) - Double(translation.y - dragStart.y) * 0.0035)
        renderers.forEach { $0.setNeedsDisplay() }
    }

    private func changeView(_ view: RoomView) {
        cinema.setView(view)
        // A new viewpoint is also a new comfortable forward direction.
        headMotion.recenter()
        cinema.setMotion(yaw: 0, pitch: 0, roll: 0)
    }

    private func startMotion() {
        let orientation = view.window?.windowScene?.interfaceOrientation ?? .landscapeLeft
        motionAvailable = headMotion.start(interfaceOrientation: orientation)
        if !motionAvailable {
            motionEnabled = false
            cinema.setMotion(yaw: 0, pitch: 0, roll: 0)
        }
        updateHUD()
        renderers.forEach { $0.setNeedsDisplay() }
    }

    private func applyMotion(_ sample: HeadMotionSample) {
        guard motionEnabled, motionAvailable else { return }
        cinema.setMotion(yaw: sample.yaw, pitch: sample.pitch, roll: sample.roll)
        renderers.forEach { $0.setNeedsDisplay() }
    }

    @objc private func toggleHUD() { setHUDHidden(!hiddenHUD) }

    private func setHUDHidden(_ hidden: Bool) {
        hiddenHUD = hidden
        let duration = UIAccessibility.isReduceMotionEnabled ? 0 : 0.28
        UIView.animate(withDuration: duration) { self.huds.forEach { $0.alpha = hidden ? 0 : 1 } }
    }

    private func updateHUD() {
        huds.forEach {
            $0.update(dark: dark, settled: lastSettled, currentView: cinema.view,
                      motionEnabled: motionEnabled, motionAvailable: motionAvailable,
                      movieLoaded: moviePlayer != nil,
                      moviePlaying: moviePlayer?.timeControlStatus == .playing)
        }
    }

    private func chooseMovie() {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.movie], asCopy: true)
        picker.delegate = self
        picker.allowsMultipleSelection = false
        present(picker, animated: true)
    }

    private func toggleMoviePlayback() {
        guard let moviePlayer else { return }
        if moviePlayer.timeControlStatus == .playing {
            moviePlayer.pause()
            updateHUD()
            renderers.forEach { $0.setNeedsDisplay() }
            return
        }
        // Starting a movie also starts the cinema session, fading the house
        // lights down before the first frame becomes the focus of the room.
        if !dark {
            dark = true
            lastSettled = false
            transition.move(to: 1, at: CACurrentMediaTime(), reducedMotion: UIAccessibility.isReduceMotionEnabled)
            phase.text = "transition"
            startAnimationClock()
        }
        moviePlayer.play()
        updateHUD()
        renderers.forEach { $0.setNeedsDisplay() }
    }

    private func installMovie(url: URL) {
        if let movieEndObserver { NotificationCenter.default.removeObserver(movieEndObserver) }
        moviePlayer?.pause()
        let player = AVPlayer(url: url)
        player.actionAtItemEnd = .pause
        moviePlayer = player
        cinema.setScreenVideo(player)
        movieEndObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime, object: player.currentItem, queue: .main
        ) { [weak self] _ in
            self?.updateHUD()
            self?.renderers.forEach { $0.setNeedsDisplay() }
        }
        updateHUD()
        renderers.forEach { $0.setNeedsDisplay() }
    }

    @objc private func tick(_ link: CADisplayLink) {
        if !lastSettled {
            cinema.applyDarkness(transition.value(at: link.timestamp))
            renderers.forEach { $0.setNeedsDisplay() }
            if transition.isFinished(at: link.timestamp) {
                lastSettled = true
                phase.text = dark ? "screening" : "lounge"
                updateHUD()
                if dark && !UIAccessibility.isVoiceOverRunning { setHUDHidden(true) }
                displayLink?.invalidate()
                displayLink = nil
                renderers.forEach { $0.isPlaying = false }
            }
        }
    }

    @objc private func suspend() {
        active = false
        motionAvailable = false
        headMotion.stop()
        displayLink?.invalidate()
        displayLink = nil
        renderers.forEach { $0.isPlaying = false }
    }

    @objc private func resume() {
        guard viewIfLoaded?.window != nil else { return }
        active = true
        if motionEnabled { startMotion() }
        renderers.forEach { $0.setNeedsDisplay() }
        if !lastSettled { startAnimationClock() }
    }

    private func startAnimationClock() {
        guard active && displayLink == nil else { return }
        renderers.forEach { $0.isPlaying = true }
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

extension CinemaViewController: UIDocumentPickerDelegate {
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let url = urls.first else { return }
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback, options: [])
        try? AVAudioSession.sharedInstance().setActive(true)
        installMovie(url: url)
    }

    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {}
}
