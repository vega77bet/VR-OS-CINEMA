import UIKit

/// The same compact HUD is duplicated inside each eye in binocular mode.
final class CinemaHUD: UIView {
    var onAction: ((String) -> Void)?
    let status = UILabel()
    let session = UIButton(type: .system)
    private let toolbar = UIStackView()
    private let title = UILabel()
    private var buttons: [String: UIButton] = [:]
    private let backdrop = UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterialDark))
    private let compact: Bool

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
        backdrop.contentView.addSubview(toolbar)

        addButton("seat", symbol: "viewfinder", label: "Centralizar", short: "Centro")
        addButton("room", symbol: "building.2", label: "Ver sala", short: "Sala")
        addButton("chair", symbol: "chair.lounge", label: "Ver poltrona", short: "Poltrona")
        addButton("height", symbol: "arrow.up.and.down", label: "Altura", short: "Altura")
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
            backdrop.bottomAnchor.constraint(equalTo: safeAreaLayoutGuide.bottomAnchor, constant: compact ? -12 : -18),
            backdrop.centerXAnchor.constraint(equalTo: centerXAnchor),
            backdrop.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 8),
            backdrop.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -8),
            toolbar.leadingAnchor.constraint(equalTo: backdrop.contentView.leadingAnchor, constant: compact ? 6 : 12),
            toolbar.trailingAnchor.constraint(equalTo: backdrop.contentView.trailingAnchor, constant: compact ? -6 : -12),
            toolbar.topAnchor.constraint(equalTo: backdrop.contentView.topAnchor, constant: compact ? 5 : 8),
            toolbar.bottomAnchor.constraint(equalTo: backdrop.contentView.bottomAnchor, constant: compact ? -5 : -8)
        ])
        if compact {
            // A viewer is still useful on small iPhones: retain only essential controls.
            buttons["room"]?.isHidden = true
            buttons["chair"]?.isHidden = true
            buttons["height"]?.isHidden = true
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
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 7, leading: compact ? 7 : 10, bottom: 5, trailing: compact ? 7 : 10)
        configuration.preferredSymbolConfigurationForImage = UIImage.SymbolConfiguration(pointSize: compact ? 13 : 16, weight: .light)
        configuration.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var attributes = incoming
            attributes.font = .systemFont(ofSize: compact ? 8 : 9, weight: .medium)
            return attributes
        }
        button.configuration = configuration
        button.accessibilityLabel = label
        button.accessibilityIdentifier = compact ? "\(action).eye" : action
        button.addAction(UIAction { [weak self] _ in self?.onAction?(action) }, for: .touchUpInside)
        buttons[action] = button
        toolbar.addArrangedSubview(button)
    }

    func update(dark: Bool, settled: Bool, currentView: RoomView) {
        status.text = settled ? (dark ? "SESSÃO VISUAL · LUZES APAGADAS" : "SALA AURORA · PRÉVIA VISUAL") : (dark ? "PREPARANDO A SALA…" : "ACENDENDO A SALA…")
        session.configuration?.title = compact ? (dark ? "Acender" : "Luzes") : (dark ? "Acender luzes" : "Iniciar sessão")
        session.configuration?.image = UIImage(systemName: dark ? "sun.max" : "moon.stars")
        session.accessibilityLabel = dark ? "Acender luzes" : "Iniciar sessão"
        buttons["room"]?.tintColor = currentView == .room ? Palette.amber : Palette.pearl
        buttons["chair"]?.tintColor = currentView == .chair ? Palette.amber : Palette.pearl
    }

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let hit = super.hitTest(point, with: event)
        // Pass empty areas to the scene's drag/tap recognizers.
        return hit === self || hit === title || hit === status ? nil : hit
    }
}
