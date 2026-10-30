import UIKit
import SceneKit
import AVFoundation
import UniformTypeIdentifiers

final class CinemaViewController: UIViewController {
    let cinema = CinemaScene()
    private let movie = MoviePlayer()
    private var projection = ProjectionSettings()
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
    private let phase = UILabel()
    private let movieState = UILabel()
    private var lastLightTime = 0.0
    private var lastInteraction = CACurrentMediaTime()

    override var prefersStatusBarHidden: Bool { true }
    override var prefersHomeIndicatorAutoHidden: Bool { true }
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask { .landscape }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        for (label, identifier, value) in [(phase, "lighting.phase", "lounge"), (movieState, "movie.state", "empty")] {
            label.isAccessibilityElement = true
            label.accessibilityIdentifier = identifier
            label.text = value
            label.textColor = .clear
            label.font = .systemFont(ofSize: 1)
            label.frame = CGRect(x: 1, y: 1, width: 2, height: 2)
        }
        headMotion.onSample = { [weak self] sample in self?.applyMotion(sample) }
        movie.onReady = { [weak self] info in
            guard let self else { return }
            self.projection.layout = info.suggestedLayout ?? .flat
            self.projection.swapEyes = false
            self.projection.alignment = 0
            self.configureProjection()
            self.setHUDHidden(false)
        }
        movie.onChange = { [weak self] in
            self?.updateHUD()
            self?.refreshClock()
        }
        movie.onFailure = { [weak self] message in
            guard let self else { return }
            self.cinema.clearMovie()
            self.renderers.forEach { $0.setNeedsDisplay() }
            let alert = UIAlertController(title: "Não foi possível reproduzir", message: message, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            (self.presentedViewController ?? self).present(alert, animated: true)
        }
        buildViewports()
        NotificationCenter.default.addObserver(self, selector: #selector(suspend), name: UIApplication.willResignActiveNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(resume), name: UIApplication.didBecomeActiveNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(audioInterrupted(_:)), name: AVAudioSession.interruptionNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(audioRouteChanged(_:)), name: AVAudioSession.routeChangeNotification, object: nil)
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
        headMotion.stop()
        NotificationCenter.default.removeObserver(self)
    }

    private func buildViewports() {
        renderers.forEach { $0.removeFromSuperview() }
        huds.forEach { $0.removeFromSuperview() }
        renderers.removeAll()
        huds.removeAll()
        for eye in 0..<(stereo ? 2 : 1) {
            var options: [String: Any] = [SCNView.Option.preferredRenderingAPI.rawValue: SCNRenderingAPI.metal.rawValue]
            if let device = movie.device { options[SCNView.Option.preferredDevice.rawValue] = device }
            let renderer = SCNView(frame: .zero, options: options)
            renderer.backgroundColor = .black
            renderer.scene = cinema.scene
            renderer.pointOfView = stereo ? (eye == 0 ? cinema.leftEye : cinema.rightEye) : cinema.centerEye
            renderer.preferredFramesPerSecond = 60
            renderer.antialiasingMode = .multisampling2X
            // One display link latches a movie frame for both eyes, then asks
            // both views to render. Paused/static rooms return to on-demand.
            renderer.isPlaying = false
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
            hud.onSeek = { [weak self] value in
                self?.movie.seek(to: value)
                self?.lastInteraction = CACurrentMediaTime()
                self?.refreshClock()
            }
            hud.alpha = hiddenHUD ? 0 : 1
            view.addSubview(hud)
            huds.append(hud)
        }
        view.addSubview(phase)
        view.addSubview(movieState)
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
        lastInteraction = CACurrentMediaTime()
        switch action {
        case "seat": changeView(.seat)
        case "room": changeView(.room)
        case "chair": changeView(.chair)
        case "height": cinema.setHeight(cinema.heightOffset >= 0.74 ? 0 : cinema.heightOffset + 0.25)
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
            } else { motionEnabled = true; startMotion() }
        case "movie":
            if movie.isLoaded {
                if movie.wantsPlayback { movie.pause() }
                else { if !dark { setDark(true) }; movie.play() }
            } else { chooseMovie() }
        case "settings": showMovieSettings()
        case "back": movie.seek(to: movie.currentTime - 10)
        case "forward": movie.seek(to: movie.currentTime + 10)
        case "session": setDark(!dark)
        default: break
        }
        updateHUD()
        refreshClock()
        renderers.forEach { $0.setNeedsDisplay() }
    }

    private func setDark(_ value: Bool) {
        dark = value
        lastSettled = false
        transition.move(to: value ? 1 : 0, at: CACurrentMediaTime(), reducedMotion: UIAccessibility.isReduceMotionEnabled)
        cinema.showSessionArtwork(value)
        phase.text = "transition"
        setHUDHidden(false)
        refreshClock()
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
        headMotion.recenter()
        cinema.setMotion(yaw: 0, pitch: 0, roll: 0)
    }

    private func startMotion() {
        let orientation = view.window?.windowScene?.interfaceOrientation ?? .landscapeLeft
        motionAvailable = headMotion.start(interfaceOrientation: orientation)
        if !motionAvailable { motionEnabled = false; cinema.setMotion(yaw: 0, pitch: 0, roll: 0) }
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
        if !hidden { lastInteraction = CACurrentMediaTime() }
        let duration = UIAccessibility.isReduceMotionEnabled ? 0 : 0.28
        UIView.animate(withDuration: duration) { self.huds.forEach { $0.alpha = hidden ? 0 : 1 } }
    }

    private func updateHUD() {
        movieState.text = movie.state.rawValue
        huds.forEach {
            $0.update(dark: dark, settled: lastSettled, currentView: cinema.view,
                      motionEnabled: motionEnabled, motionAvailable: motionAvailable,
                      movie: movie, projection: projection)
        }
    }

    private func chooseMovie() {
        movie.pause()
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.movie], asCopy: false)
        picker.delegate = self
        picker.allowsMultipleSelection = false
        present(picker, animated: true)
    }

    private func showMovieSettings() {
        movie.pause()
        let settings = MovieSettingsViewController(settings: projection, info: movie.info, volume: movie.player.volume)
        settings.onChange = { [weak self] value in
            self?.projection = value
            self?.configureProjection()
        }
        settings.onOpen = { [weak self] in self?.chooseMovie() }
        settings.onDemo = { [weak self] in
            guard let self, let url = Bundle.main.url(forResource: "Aurora-FSBS", withExtension: "mp4") else { return }
            self.cinema.clearMovie()
            self.movie.load(url)
        }
        settings.onVolume = { [weak self] volume in self?.movie.player.volume = volume }
        settings.onCloseMovie = { [weak self] in
            guard let self else { return }
            self.movie.close()
            self.cinema.clearMovie()
            self.setDark(false)
        }
        let navigation = UINavigationController(rootViewController: settings)
        navigation.overrideUserInterfaceStyle = .dark
        navigation.modalPresentationStyle = .pageSheet
        present(navigation, animated: true)
    }

    private func configureProjection() {
        guard let info = movie.info else { return }
        cinema.configureMovie(projection, info: info)
        if let frame = movie.currentFrame { cinema.showMovieFrame(frame.texture) }
        if projection.layout.isStereo && !stereo { stereo = true; buildViewports() }
        updateHUD()
        renderers.forEach { $0.setNeedsDisplay() }
        refreshClock()
    }

    @objc private func tick(_ link: CADisplayLink) {
        let now = CACurrentMediaTime()
        if movie.updateFrame(hostTime: link.targetTimestamp) != nil, let frame = movie.currentFrame {
            cinema.showMovieFrame(frame.texture)
            if projection.ambientLight && now - lastLightTime > 0.25 {
                lastLightTime = now
                if let color = movie.averageColor() { cinema.updateMovieLight(color) }
            }
        }
        if !lastSettled {
            cinema.applyDarkness(transition.value(at: now))
            if transition.isFinished(at: now) {
                lastSettled = true
                phase.text = dark ? "screening" : "lounge"
                updateHUD()
                if dark && !movie.isLoaded && !UIAccessibility.isVoiceOverRunning { setHUDHidden(true) }
            }
        }
        if movie.wantsPlayback && !hiddenHUD && now - lastInteraction > 8 && !UIAccessibility.isVoiceOverRunning {
            setHUDHidden(true)
        }
        renderers.forEach { $0.setNeedsDisplay() }
        refreshClock()
    }

    @objc private func suspend() {
        active = false
        movie.pause()
        motionAvailable = false
        headMotion.stop()
        displayLink?.invalidate()
        displayLink = nil
    }

    @objc private func resume() {
        guard viewIfLoaded?.window != nil else { return }
        active = true
        if motionEnabled { startMotion() }
        renderers.forEach { $0.setNeedsDisplay() }
        refreshClock()
    }

    @objc private func audioInterrupted(_ note: Notification) {
        guard let value = note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
              AVAudioSession.InterruptionType(rawValue: value) == .began else { return }
        movie.pause()
        setHUDHidden(false)
    }

    @objc private func audioRouteChanged(_ note: Notification) {
        guard let value = note.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt,
              AVAudioSession.RouteChangeReason(rawValue: value) == .oldDeviceUnavailable else { return }
        movie.pause()
        setHUDHidden(false)
    }

    private func refreshClock() {
        let needed = active && (!lastSettled || movie.needsFrames)
        if !needed { displayLink?.invalidate(); displayLink = nil; return }
        guard displayLink == nil else { return }
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
        cinema.clearMovie()
        movie.load(url)
    }
}
