import AVFoundation
import Metal
import CoreImage
import UIKit

struct MovieInfo {
    let title: String
    let nativeSize: CGSize
    let transform: CGAffineTransform
    let duration: Double
    let suggestedLayout: VideoLayout?
    var displaySize: CGSize { CGRect(origin: .zero, size: nativeSize).applying(transform).size }
}

/// One decoded frame feeds both eyes. The CV objects stay alive with the Metal
/// texture so Core Video cannot recycle their storage while the GPU reads it.
final class MovieFrame {
    let texture: MTLTexture
    let pixelBuffer: CVPixelBuffer
    let metalBuffer: CVMetalTexture
    init(texture: MTLTexture, pixelBuffer: CVPixelBuffer, metalBuffer: CVMetalTexture) {
        self.texture = texture
        self.pixelBuffer = pixelBuffer
        self.metalBuffer = metalBuffer
    }
}

final class MoviePlayer {
    enum State: String { case empty, loading, ready, playing, paused, ended, failed }
    let player = AVPlayer()
    let device = MTLCreateSystemDefaultDevice()
    private(set) var state: State = .empty
    private(set) var info: MovieInfo?
    private(set) var wantsPlayback = false
    private(set) var errorMessage: String?
    private(set) var currentFrame: MovieFrame?
    var onChange: (() -> Void)?
    var onReady: ((MovieInfo) -> Void)?
    var onFailure: ((String) -> Void)?
    var isLoaded: Bool { info != nil && state != .failed && state != .empty }
    var needsFrames: Bool { isLoaded && (wantsPlayback || awaitingFrame) }
    var currentTime: Double { max(0, player.currentTime().seconds.isFinite ? player.currentTime().seconds : 0) }

    private var output: AVPlayerItemVideoOutput?
    private var textureCache: CVMetalTextureCache?
    private var retainedFrames: [MovieFrame] = []
    private var observations: [NSKeyValueObservation] = []
    private var endObserver: NSObjectProtocol?
    private var failureObserver: NSObjectProtocol?
    private var timeObserver: Any?
    private var loadTask: Task<Void, Never>?
    private var scopedURL: URL?
    private var generation = UUID()
    private var awaitingFrame = false
    private let colorContext = CIContext(options: [.cacheIntermediates: false])

    init() {
        if let device { CVMetalTextureCacheCreate(nil, nil, device, nil, &textureCache) }
        player.actionAtItemEnd = .pause
        timeObserver = player.addPeriodicTimeObserver(forInterval: CMTime(seconds: 0.25, preferredTimescale: 600), queue: .main) { [weak self] _ in
            self?.onChange?()
        }
    }

    deinit {
        loadTask?.cancel()
        player.pause()
        if let timeObserver { player.removeTimeObserver(timeObserver) }
        if let endObserver { NotificationCenter.default.removeObserver(endObserver) }
        if let failureObserver { NotificationCenter.default.removeObserver(failureObserver) }
        scopedURL?.stopAccessingSecurityScopedResource()
    }

    func load(_ url: URL) {
        close()
        let token = generation
        if url.startAccessingSecurityScopedResource() { scopedURL = url }
        state = .loading
        errorMessage = nil
        onChange?()
        let asset = AVURLAsset(url: url)
        loadTask = Task { @MainActor [weak self] in
            do {
                let playable = try await asset.load(.isPlayable)
                let protected = try await asset.load(.hasProtectedContent)
                guard playable && !protected else { throw MovieError.unsupported }
                guard let track = try await asset.loadTracks(withMediaType: .video).first else { throw MovieError.noVideo }
                let (size, transform) = try await track.load(.naturalSize, .preferredTransform)
                let duration = try await asset.load(.duration).seconds
                try Task.checkCancellation()
                guard let self, self.generation == token else { return }
                let info = MovieInfo(title: url.deletingPathExtension().lastPathComponent, nativeSize: size,
                                     transform: transform, duration: duration,
                                     suggestedLayout: VideoLayout.suggested(for: url.lastPathComponent))
                self.install(asset: asset, info: info, token: token)
            } catch is CancellationError { return }
            catch {
                guard let self, self.generation == token else { return }
                self.fail(error.localizedDescription)
            }
        }
    }

    private func install(asset: AVAsset, info: MovieInfo, token: UUID) {
        guard textureCache != nil else { fail("O renderizador Metal não está disponível."); return }
        self.info = info
        awaitingFrame = true
        let item = AVPlayerItem(asset: asset)
        // Request SDR conversion from AVFoundation; unsupported HDR transfer
        // functions must not be sampled as ordinary sRGB movie textures.
        let output = AVPlayerItemVideoOutput(pixelBufferAttributes: [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferMetalCompatibilityKey as String: true,
            kCVImageBufferColorPrimariesKey as String: kCVImageBufferColorPrimaries_ITU_R_709_2,
            kCVImageBufferTransferFunctionKey as String: kCVImageBufferTransferFunction_ITU_R_709_2,
            kCVImageBufferYCbCrMatrixKey as String: kCVImageBufferYCbCrMatrix_ITU_R_709_2
        ])
        item.add(output)
        self.output = output
        observations = [
            item.observe(\.status, options: [.new]) { [weak self] item, _ in
                DispatchQueue.main.async {
                    guard let self, self.generation == token else { return }
                    if item.status == .failed { self.fail(item.error?.localizedDescription ?? "Não foi possível abrir este vídeo.") }
                    else if item.status == .readyToPlay {
                        self.state = .ready
                        self.onReady?(info)
                        self.onChange?()
                    }
                }
            },
            player.observe(\.timeControlStatus, options: [.new]) { [weak self] player, _ in
                DispatchQueue.main.async {
                    guard let self, self.generation == token, self.isLoaded else { return }
                    if player.timeControlStatus == .playing { self.state = .playing }
                    else if !self.wantsPlayback && self.state != .ended && self.state != .ready { self.state = .paused }
                    self.onChange?()
                }
            }
        ]
        endObserver = NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: item, queue: .main) { [weak self] _ in
            guard let self, self.generation == token else { return }
            self.wantsPlayback = false
            self.state = .ended
            self.onChange?()
        }
        failureObserver = NotificationCenter.default.addObserver(forName: .AVPlayerItemFailedToPlayToEndTime, object: item, queue: .main) { [weak self] note in
            guard let self, self.generation == token else { return }
            self.fail((note.userInfo?[AVPlayerItemFailedToPlayToEndTimeErrorKey] as? Error)?.localizedDescription ?? "A reprodução foi interrompida.")
        }
        player.replaceCurrentItem(with: item)
    }

    func play() {
        guard isLoaded else { return }
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch { fail("Não foi possível ativar o áudio: \(error.localizedDescription)"); return }
        wantsPlayback = true
        if state == .ended { seek(to: 0) }
        player.play()
        onChange?()
    }

    func pause() {
        wantsPlayback = false
        player.pause()
        if isLoaded && state != .ended && state != .ready { state = .paused }
        onChange?()
    }

    func seek(to seconds: Double) {
        guard let info, info.duration.isFinite && info.duration > 0 else { return }
        let value = max(0, min(seconds, max(0, info.duration - 0.01)))
        awaitingFrame = true
        let token = generation
        if state == .ended { state = .paused }
        player.seek(to: CMTime(seconds: value, preferredTimescale: 600), toleranceBefore: .zero, toleranceAfter: .zero) { [weak self] _ in
            DispatchQueue.main.async {
                guard let self, self.generation == token else { return }
                self.onChange?()
            }
        }
        onChange?()
    }

    func close() {
        generation = UUID()
        loadTask?.cancel()
        loadTask = nil
        observations.removeAll()
        if let endObserver { NotificationCenter.default.removeObserver(endObserver) }
        if let failureObserver { NotificationCenter.default.removeObserver(failureObserver) }
        endObserver = nil
        failureObserver = nil
        player.pause()
        player.replaceCurrentItem(with: nil)
        output = nil
        info = nil
        currentFrame = nil
        retainedFrames.removeAll()
        scopedURL?.stopAccessingSecurityScopedResource()
        scopedURL = nil
        wantsPlayback = false
        awaitingFrame = false
        state = .empty
        onChange?()
    }

    @discardableResult
    func updateFrame(hostTime: CFTimeInterval) -> MovieFrame? {
        guard let output, let textureCache else { return nil }
        let time = wantsPlayback ? output.itemTime(forHostTime: hostTime) : player.currentTime()
        guard output.hasNewPixelBuffer(forItemTime: time),
              let pixels = output.copyPixelBuffer(forItemTime: time, itemTimeForDisplay: nil) else { return nil }
        var metal: CVMetalTexture?
        let code = CVMetalTextureCacheCreateTextureFromImage(nil, textureCache, pixels, nil, .bgra8Unorm,
                                                            CVPixelBufferGetWidth(pixels), CVPixelBufferGetHeight(pixels), 0, &metal)
        guard code == kCVReturnSuccess, let metal, let texture = CVMetalTextureGetTexture(metal) else { return nil }
        let frame = MovieFrame(texture: texture, pixelBuffer: pixels, metalBuffer: metal)
        currentFrame = frame
        awaitingFrame = false
        retainedFrames.append(frame)
        if retainedFrames.count > 3 { retainedFrames.removeFirst() }
        return frame
    }

    func averageColor() -> UIColor? {
        guard let currentFrame else { return nil }
        let image = CIImage(cvPixelBuffer: currentFrame.pixelBuffer)
        let average = image.applyingFilter("CIAreaAverage", parameters: [kCIInputExtentKey: CIVector(cgRect: image.extent)])
        var pixel = [UInt8](repeating: 0, count: 4)
        colorContext.render(average, toBitmap: &pixel, rowBytes: 4, bounds: CGRect(x: 0, y: 0, width: 1, height: 1), format: .RGBA8,
                            colorSpace: CGColorSpace(name: CGColorSpace.sRGB))
        return UIColor(red: CGFloat(pixel[0]) / 255, green: CGFloat(pixel[1]) / 255, blue: CGFloat(pixel[2]) / 255, alpha: 1)
    }

    private func fail(_ message: String) {
        player.pause()
        wantsPlayback = false
        state = .failed
        errorMessage = message
        onChange?()
        onFailure?(message)
    }

    private enum MovieError: LocalizedError {
        case unsupported, noVideo
        var errorDescription: String? {
            switch self {
            case .noVideo: return "Este arquivo não contém uma faixa de vídeo."
            case .unsupported: return "Este vídeo é protegido ou usa um formato que o iPhone não consegue reproduzir. Tente MP4/MOV com H.264 ou HEVC."
            }
        }
    }
}
