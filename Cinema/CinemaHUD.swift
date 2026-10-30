import UIKit

/// The same compact HUD is duplicated inside each eye in binocular mode.
final class CinemaHUD: UIView {
    var onAction: ((String) -> Void)?
    var onSeek: ((Double) -> Void)?
    let status = UILabel()
    let session = UIButton(type: .system)
    private let toolbar = UIStackView()
    private let title = UILabel()
    private var buttons: [String: UIButton] = [:]
    private let backdrop = UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterialDark))
    private let compact: Bool
    private let progressRow = UIStackView()
    private let progress = UISlider()
    private let time = UILabel()
    private var duration = 0.0
    private var scrubbing = false

    init(compact: Bool) {
        self.compact = compact
        super.init(frame: .zero)
        backgroundColor = .clear
        title.text = compact ? "VR—OS  /  CINEMA" : "VR—OS   /   CINEMA"
        title.font = .systemFont(ofSize: compact ? 11 : 13, weight: .semibold)
        title.textColor = Palette.pearl
        title.setContentCompressionResistancePriority(.required, for: .vertical)
        title.translatesAutoresizingMaskIntoConstraints = false
        addSubview(title)
        status.text = "SALA AURORA · PRÉVIA VISUAL"
        status.textColor = Palette.amber
        status.font = .systemFont(ofSize: compact ? 8 : 10, weight: .medium)
        status.accessibilityIdentifier = compact ? "room.status.eye" : "room.status"
        status.translatesAutoresizingMaskIntoConstraints = false
        addSubview(status)

        progressRow.axis = .horizontal
        progressRow.alignment = .center
        progressRow.spacing = 8
        progressRow.backgroundColor = Palette.ink.withAlphaComponent(0.9)
        progressRow.layer.cornerRadius = 12
        progressRow.translatesAutoresizingMaskIntoConstraints = false
        addSubview(progressRow)
        for (action, symbol, label) in [("back", "gobackward.10", "Voltar 10 segundos"), ("forward", "goforward.10", "Avançar 10 segundos")] {
            let button = UIButton(type: .system)
            button.setImage(UIImage(systemName: symbol), for: .normal)
            button.tintColor = Palette.pearl
            button.accessibilityLabel = label
            button.accessibilityIdentifier = compact ? "\(action).eye" : action
            button.widthAnchor.constraint(equalToConstant: 34).isActive = true
            button.heightAnchor.constraint(equalToConstant: 38).isActive = true
            button.addAction(UIAction { [weak self] _ in self?.onAction?(action) }, for: .touchUpInside)
            progressRow.addArrangedSubview(button)
        }
        progress.tintColor = Palette.amber
        progress.accessibilityLabel = "Progresso do filme"
        progress.accessibilityIdentifier = compact ? "movie.progress.eye" : "movie.progress"
        progress.addTarget(self, action: #selector(beginScrub), for: .touchDown)
        progress.addTarget(self, action: #selector(endScrub), for: [.touchUpInside, .touchUpOutside])
        progress.addTarget(self, action: #selector(cancelScrub), for: .touchCancel)
        progressRow.addArrangedSubview(progress)
        time.textColor = Palette.pearl
        time.font = .monospacedDigitSystemFont(ofSize: compact ? 8 : 10, weight: .regular)
        time.setContentCompressionResistancePriority(.required, for: .horizontal)
        time.accessibilityIdentifier = compact ? "movie.time.eye" : "movie.time"
        progressRow.addArrangedSubview(time)

        backdrop.layer.cornerRadius = compact ? 19 : 23
        backdrop.clipsToBounds = true
        backdrop.layer.borderWidth = 0.5
        backdrop.layer.borderColor = UIColor.white.withAlphaComponent(0.17).cgColor
        backdrop.translatesAutoresizingMaskIntoConstraints = false
        addSubview(backdrop)
        toolbar.axis = .horizontal
        toolbar.spacing = compact ? 3 : 8
        toolbar.alignment = .center
        toolbar.distribution = .fill
        toolbar.translatesAutoresizingMaskIntoConstraints = false
        let scroll = UIScrollView()
        scroll.translatesAutoresizingMaskIntoConstraints = false
        scroll.showsHorizontalScrollIndicator = false
        backdrop.contentView.addSubview(scroll)
        scroll.addSubview(toolbar)

        addButton("seat", symbol: "viewfinder", label: "Centralizar", short: "Centro")
        addButton("room", symbol: "building.2", label: "Ver sala", short: "Sala")
        addButton("chair", symbol: "chair.lounge", label: "Ver poltrona", short: "Poltrona")
        addButton("height", symbol: "arrow.up.and.down", label: "Altura", short: "Altura")
        addButton("motion", symbol: "gyroscope", label: "Movimento", short: "Movimento")
        addButton("movie", symbol: "film", label: "Filme", short: "Filme")
        addButton("settings", symbol: "slider.horizontal.3", label: "Filme e 3D", short: "3D")
        addButton("stereo", symbol: "view.3d", label: "VR Box", short: "Sair VR")

        var configuration = UIButton.Configuration.filled()
        configuration.title = compact ? "Luzes" : "Iniciar sessão"
        configuration.image = UIImage(systemName: "moon.stars")
        configuration.imagePadding = 6
        configuration.baseBackgroundColor = Palette.pearl
        configuration.baseForegroundColor = Palette.ink
        configuration.cornerStyle = .capsule
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 10, leading: compact ? 10 : 17, bottom: 10, trailing: compact ? 10 : 17)
        configuration.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var result = incoming
            result.font = .systemFont(ofSize: compact ? 10 : 12, weight: .semibold)
            return result
        }
        session.configuration = configuration
        session.accessibilityLabel = "Iniciar sessão"
        session.accessibilityIdentifier = compact ? "session.toggle.eye" : "session.toggle"
        session.addAction(UIAction { [weak self] _ in self?.onAction?("session") }, for: .touchUpInside)
        toolbar.addArrangedSubview(session)

        let horizontal: CGFloat = compact ? 14 : 30
        NSLayoutConstraint.activate([
            title.topAnchor.constraint(equalTo: safeAreaLayoutGuide.topAnchor, constant: compact ? 12 : 20),
            title.leadingAnchor.constraint(equalTo: leadingAnchor, constant: horizontal),
            status.topAnchor.constraint(equalTo: title.bottomAnchor, constant: 6),
            status.leadingAnchor.constraint(equalTo: title.leadingAnchor),
            status.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -14),
            backdrop.bottomAnchor.constraint(equalTo: safeAreaLayoutGuide.bottomAnchor, constant: compact ? -12 : -18),
            backdrop.leadingAnchor.constraint(equalTo: leadingAnchor, constant: compact ? 10 : 24),
            backdrop.trailingAnchor.constraint(equalTo: trailingAnchor, constant: compact ? -10 : -24),
            scroll.leadingAnchor.constraint(equalTo: backdrop.contentView.leadingAnchor, constant: 6),
            scroll.trailingAnchor.constraint(equalTo: backdrop.contentView.trailingAnchor, constant: -6),
            scroll.topAnchor.constraint(equalTo: backdrop.contentView.topAnchor, constant: 5),
            scroll.bottomAnchor.constraint(equalTo: backdrop.contentView.bottomAnchor, constant: -5),
            scroll.heightAnchor.constraint(equalToConstant: compact ? 52 : 58),
            toolbar.leadingAnchor.constraint(equalTo: scroll.contentLayoutGuide.leadingAnchor),
            toolbar.trailingAnchor.constraint(equalTo: scroll.contentLayoutGuide.trailingAnchor),
            toolbar.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor),
            toolbar.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor),
            toolbar.heightAnchor.constraint(equalTo: scroll.frameLayoutGuide.heightAnchor),
            progressRow.leadingAnchor.constraint(equalTo: backdrop.leadingAnchor, constant: 4),
            progressRow.trailingAnchor.constraint(equalTo: backdrop.trailingAnchor, constant: -4),
            progressRow.bottomAnchor.constraint(equalTo: backdrop.topAnchor, constant: -6)
        ])
        if compact {
            // A viewer is still useful on small iPhones: retain only essential controls.
            buttons["room"]?.isHidden = true
            buttons["chair"]?.isHidden = true
            buttons["height"]?.isHidden = true
            buttons["motion"]?.isHidden = true
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func addButton(_ action: String, symbol: String, label: String, short: String) {
        let button = UIButton(type: .system)
        var configuration = UIButton.Configuration.plain()
        configuration.title = compact ? short : label
        configuration.image = UIImage(systemName: symbol)
        configuration.imagePadding = 4
        configuration.imagePlacement = .top
        configuration.baseForegroundColor = Palette.pearl
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 7, leading: compact ? 5 : 7, bottom: 5, trailing: compact ? 5 : 7)
        configuration.preferredSymbolConfigurationForImage = UIImage.SymbolConfiguration(pointSize: compact ? 13 : 16, weight: .light)
        let labelSize: CGFloat = compact ? 8 : 9
        configuration.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var attributes = incoming
            attributes.font = .systemFont(ofSize: labelSize, weight: .medium)
            return attributes
        }
        button.configuration = configuration
        button.accessibilityLabel = label
        button.accessibilityIdentifier = compact ? "\(action).eye" : action
        button.addAction(UIAction { [weak self] _ in self?.onAction?(action) }, for: .touchUpInside)
        buttons[action] = button
        toolbar.addArrangedSubview(button)
    }

    func update(dark: Bool, settled: Bool, currentView: RoomView,
                motionEnabled: Bool, motionAvailable: Bool,
                movie: MoviePlayer, projection: ProjectionSettings) {
        let movieLoaded = movie.isLoaded
        let moviePlaying = movie.wantsPlayback
        let tracking = motionEnabled && motionAvailable ? "MOVIMENTO DA CABEÇA" : "ARRASTE PARA OLHAR"
        let playback = movie.state == .ended ? "FIM DO FILME" : (moviePlaying ? (movie.state == .playing ? "REPRODUZINDO" : "CARREGANDO…") : "PAUSADO")
        let movieStatus = movie.state == .loading ? "ABRINDO FILME…" : (movieLoaded ? "\(projection.layout.title.uppercased()) · \(playback)" : nil)
        status.text = settled ? (movieStatus ?? (dark ? "SESSÃO VISUAL · LUZES APAGADAS · \(tracking)" : "SALA AURORA · \(tracking)")) : (dark ? "PREPARANDO A SALA…" : "ACENDENDO A SALA…")
        session.configuration?.title = compact ? (dark ? "Acender" : "Luzes") : (dark ? "Acender luzes" : "Iniciar sessão")
        session.configuration?.image = UIImage(systemName: dark ? "sun.max" : "moon.stars")
        session.accessibilityLabel = dark ? "Acender luzes" : "Iniciar sessão"
        buttons["room"]?.tintColor = currentView == .room ? Palette.amber : Palette.pearl
        buttons["chair"]?.tintColor = currentView == .chair ? Palette.amber : Palette.pearl
        let motionButton = buttons["motion"]
        motionButton?.tintColor = motionEnabled && motionAvailable ? Palette.amber : Palette.pearl
        motionButton?.configuration?.title = motionEnabled && motionAvailable ? "Movimento" : "Ativar"
        motionButton?.accessibilityLabel = motionEnabled && motionAvailable ? "Desligar movimento da cabeça" : "Ativar movimento da cabeça"
        let movieButton = buttons["movie"]
        movieButton?.tintColor = movieLoaded ? Palette.amber : Palette.pearl
        movieButton?.configuration?.title = movieLoaded ? (moviePlaying ? "Pausar" : "Reproduzir") : "Filme"
        movieButton?.configuration?.image = UIImage(systemName: movieLoaded ? (moviePlaying ? "pause.fill" : "play.fill") : "film")
        movieButton?.accessibilityLabel = movieLoaded ? (moviePlaying ? "Pausar filme" : "Reproduzir filme") : "Escolher filme"
        movieButton?.isEnabled = movie.state != .loading
        progressRow.isHidden = !movieLoaded
        duration = movie.info?.duration ?? 0
        progress.isEnabled = duration.isFinite && duration > 0
        if !scrubbing { progress.value = duration.isFinite && duration > 0 ? Float(movie.currentTime / duration) : 0 }
        time.text = "\(MovieTime.label(movie.currentTime)) / \(MovieTime.label(duration)) "
    }

    @objc private func beginScrub() { scrubbing = true }
    @objc private func endScrub() { scrubbing = false; if duration.isFinite { onSeek?(Double(progress.value) * duration) } }
    @objc private func cancelScrub() { scrubbing = false }

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let hit = super.hitTest(point, with: event)
        // Pass empty areas to the scene's drag/tap recognizers.
        return hit === self || hit === title || hit === status ? nil : hit
    }
}
