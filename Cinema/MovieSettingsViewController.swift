import UIKit

final class MovieSettingsViewController: UIViewController {
    var onChange: ((ProjectionSettings) -> Void)?
    var onOpen: (() -> Void)?
    var onDemo: (() -> Void)?
    var onCloseMovie: (() -> Void)?
    var onVolume: ((Float) -> Void)?
    private var settings: ProjectionSettings
    private let info: MovieInfo?
    private let stack = UIStackView()
    private let volume: Float

    init(settings: ProjectionSettings, info: MovieInfo?, volume: Float) {
        self.settings = settings
        self.info = info
        self.volume = volume
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Filme e 3D"
        view.backgroundColor = Palette.ink
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Concluir", style: .done, target: self, action: #selector(done))
        let scroll = UIScrollView()
        scroll.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scroll)
        stack.axis = .vertical
        stack.spacing = 14
        stack.translatesAutoresizingMaskIntoConstraints = false
        scroll.addSubview(stack)
        NSLayoutConstraint.activate([
            scroll.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
            scroll.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scroll.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: scroll.contentLayoutGuide.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: scroll.contentLayoutGuide.trailingAnchor, constant: -24),
            stack.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor, constant: 18),
            stack.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor, constant: -30),
            stack.widthAnchor.constraint(equalTo: scroll.frameLayoutGuide.widthAnchor, constant: -48)
        ])
        action("Abrir filme em Arquivos", symbol: "folder", id: "movie.open") { [weak self] in self?.finish(self?.onOpen) }
        action("Teste 3D de profundidade", symbol: "view.3d", id: "movie.demo") { [weak self] in self?.finish(self?.onDemo) }
        if let info {
            label("\(info.title)\n\(Int(info.displaySize.width)) × \(Int(info.displaySize.height)) · \(MovieTime.label(info.duration))")
            label(info.suggestedLayout.map { "Sugestão pelo nome: \($0.title). Confirme pela imagem." }
                  ?? "Formato não informado no nome. Confirme abaixo se o filme é 2D, lado a lado ou cima/baixo.")
        }
        label("FORMATO DO ARQUIVO", heading: true)
        segments(["2D", "½ SBS", "Full SBS", "½ ↕", "Full ↕"], selected: VideoLayout.allCases.firstIndex(of: settings.layout) ?? 0, id: "projection.layout") { [weak self] index in
            self?.settings.layout = VideoLayout.allCases[index]
            self?.settings.alignment = 0
            self?.changed()
        }
        label("SBS = imagens lado a lado. ↕ = cima/baixo. Half usa metade da resolução por olho; Full mantém a resolução. Filme 2D continua em 2D.")
        toggle("Trocar olho esquerdo/direito", value: settings.swapEyes, id: "projection.swap") { [weak self] in self?.settings.swapEyes = $0; self?.changed() }
        label("PROPORÇÃO DA IMAGEM", heading: true)
        let aspects: [Double?] = [nil, 16.0 / 9, 2.39, 4.0 / 3]
        segments(["Original", "16:9", "2,39:1", "4:3"], selected: aspects.firstIndex(where: { $0 == settings.aspectOverride }) ?? 0, id: "projection.aspect") { [weak self] index in
            self?.settings.aspectOverride = aspects[index]; self?.changed()
        }
        label("SALA E TELÃO", heading: true)
        segments(CinemaAmbience.allCases.map(\.title), selected: CinemaAmbience.allCases.firstIndex(of: settings.ambience) ?? 0, id: "projection.ambience") { [weak self] index in
            self?.settings.ambience = CinemaAmbience.allCases[index]; self?.changed()
        }
        toggle("Telão curvo", value: settings.curved, id: "projection.curved") { [weak self] in self?.settings.curved = $0; self?.changed() }
        toggle("Luz suave com as cores do filme", value: settings.ambientLight, id: "projection.light") { [weak self] in self?.settings.ambientLight = $0; self?.changed() }
        slider("Distância da poltrona", value: settings.screenDistance, range: -2.0...3.0, id: "projection.distance", display: { String(format: "%+.1f m", $0) }) { [weak self] in self?.settings.screenDistance = $0; self?.changed() }
        slider("Brilho do filme", value: settings.brightness, range: 0.4...1.2, id: "projection.brightness", display: { "\(Int($0 * 100))%" }) { [weak self] in self?.settings.brightness = $0; self?.changed() }
        slider("Volume do filme", value: Double(volume), range: 0...1, id: "movie.volume", display: { "\(Int($0 * 100))%" }) { [weak self] in self?.onVolume?(Float($0)) }
        label("ALINHAMENTO NO VR BOX", heading: true)
        slider("Separação entre os olhos", value: settings.eyeDistance, range: 0.058...0.072, id: "projection.ipd", display: { "\(Int(($0 * 1000).rounded())) mm" }) { [weak self] in self?.settings.eyeDistance = $0; self?.changed() }
        slider("Alinhamento horizontal 3D", value: settings.alignment, range: -0.0075...0.0075, id: "projection.alignment", display: { String(format: "%+.2f%%", $0 * 100) }) { [weak self] in self?.settings.alignment = $0; self?.changed() }
        label("A profundidade vem do filme. O alinhamento é um ajuste pequeno de convergência, com recorte mínimo nas bordas. Faça a configuração antes de colocar o iPhone no VR Box.")
        if info != nil { action("Fechar filme e voltar à sala", symbol: "xmark.circle", id: "movie.close") { [weak self] in self?.finish(self?.onCloseMovie) } }
    }

    private func changed() { onChange?(settings) }
    @objc private func done() { dismiss(animated: true) }
    private func finish(_ action: (() -> Void)?) { dismiss(animated: true, completion: action) }

    private func label(_ text: String, heading: Bool = false) {
        let label = UILabel()
        label.text = text
        label.numberOfLines = 0
        label.textColor = heading ? Palette.amber : Palette.pearl.withAlphaComponent(0.8)
        label.font = .systemFont(ofSize: heading ? 12 : 13, weight: heading ? .semibold : .regular)
        stack.addArrangedSubview(label)
    }
    private func action(_ title: String, symbol: String, id: String, handler: @escaping () -> Void) {
        let button = UIButton(type: .system)
        var config = UIButton.Configuration.tinted()
        config.title = title
        config.image = UIImage(systemName: symbol)
        config.imagePadding = 10
        config.baseForegroundColor = Palette.pearl
        config.baseBackgroundColor = Palette.teal
        config.contentInsets = .init(top: 12, leading: 12, bottom: 12, trailing: 12)
        button.configuration = config
        button.accessibilityIdentifier = id
        button.addAction(UIAction { _ in handler() }, for: .touchUpInside)
        stack.addArrangedSubview(button)
    }
    private func segments(_ names: [String], selected: Int, id: String, handler: @escaping (Int) -> Void) {
        let segmented = UISegmentedControl(items: names)
        segmented.selectedSegmentIndex = selected
        segmented.selectedSegmentTintColor = Palette.teal
        segmented.accessibilityIdentifier = id
        segmented.addAction(UIAction { [weak segmented] _ in if let segmented { handler(segmented.selectedSegmentIndex) } }, for: .valueChanged)
        stack.addArrangedSubview(segmented)
    }
    private func toggle(_ title: String, value: Bool, id: String, handler: @escaping (Bool) -> Void) {
        let row = UIStackView()
        row.axis = .horizontal
        row.spacing = 14
        let text = UILabel()
        text.text = title
        text.font = .systemFont(ofSize: 14)
        text.textColor = Palette.pearl
        text.numberOfLines = 0
        let control = UISwitch()
        control.isOn = value
        control.onTintColor = Palette.teal
        control.accessibilityLabel = title
        control.accessibilityIdentifier = id
        control.addAction(UIAction { [weak control] _ in if let control { handler(control.isOn) } }, for: .valueChanged)
        row.addArrangedSubview(text)
        row.addArrangedSubview(control)
        stack.addArrangedSubview(row)
    }
    private func slider(_ title: String, value: Double, range: ClosedRange<Double>, id: String,
                        display: @escaping (Double) -> String, handler: @escaping (Double) -> Void) {
        let text = UILabel()
        text.text = "\(title) · \(display(value))"
        text.font = .systemFont(ofSize: 14)
        text.textColor = Palette.pearl
        stack.addArrangedSubview(text)
        let slider = UISlider()
        slider.minimumValue = Float(range.lowerBound)
        slider.maximumValue = Float(range.upperBound)
        slider.value = Float(value)
        slider.tintColor = Palette.amber
        slider.accessibilityLabel = title
        slider.accessibilityIdentifier = id
        slider.addAction(UIAction { [weak slider, weak text] _ in
            guard let slider else { return }
            text?.text = "\(title) · \(display(Double(slider.value)))"
            handler(Double(slider.value))
        }, for: .valueChanged)
        stack.addArrangedSubview(slider)
    }
}
