import UIKit
import WebKit

/// Official YouTube experience presented with the cinema's visual language.
///
/// YouTube remains the owner of playback: this screen never extracts media
/// URLs, downloads videos, or attempts to turn a normal video into 3D.
final class YouTubeViewController: UIViewController {
    private let webView: WKWebView
    private let progress = UIProgressView(progressViewStyle: .bar)
    private let activity = UIActivityIndicatorView(style: .medium)
    private let searchField = UITextField()
    private let searchButton = UIButton(type: .system)
    private let pasteButton = UIButton(type: .system)
    private let status = UILabel()
    private let screenCard = UIView()
    private let leftSconce = UIView()
    private let rightSconce = UIView()
    private var observingProgress = false

    init() {
        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = [.video]
        configuration.applicationNameForUserAgent = "VR-OS Cinema"
        webView = WKWebView(frame: .zero, configuration: configuration)
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        configureAppearance()
        configureSearch()
        configureWebView()
        loadHome()
    }

    deinit {
        if observingProgress {
            webView.removeObserver(self, forKeyPath: #keyPath(WKWebView.estimatedProgress))
        }
    }

    private func configureAppearance() {
        view.backgroundColor = Palette.ink
        title = "YouTube · SALA AURORA"
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            title: "Voltar",
            style: .plain,
            target: self,
            action: #selector(close)
        )
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: "Safari",
            style: .plain,
            target: self,
            action: #selector(openInSafari)
        )
        navigationController?.navigationBar.tintColor = Palette.amber
        navigationController?.navigationBar.titleTextAttributes = [
            .foregroundColor: Palette.pearl,
            .font: UIFont.systemFont(ofSize: 14, weight: .semibold)
        ]

        [leftSconce, rightSconce].forEach {
            $0.backgroundColor = Palette.amber.withAlphaComponent(0.74)
            $0.layer.cornerRadius = 3
            $0.layer.shadowColor = Palette.amber.cgColor
            $0.layer.shadowRadius = 18
            $0.layer.shadowOpacity = 0.85
            $0.layer.shadowOffset = .zero
            $0.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview($0)
        }
    }

    private func configureSearch() {
        searchField.translatesAutoresizingMaskIntoConstraints = false
        searchField.backgroundColor = Palette.teal.withAlphaComponent(0.75)
        searchField.textColor = Palette.pearl
        searchField.tintColor = Palette.amber
        searchField.layer.cornerRadius = 13
        searchField.layer.borderWidth = 1
        searchField.layer.borderColor = Palette.ice.withAlphaComponent(0.28).cgColor
        searchField.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 12, height: 1))
        searchField.leftViewMode = .always
        searchField.rightView = UIView(frame: CGRect(x: 0, y: 0, width: 10, height: 1))
        searchField.rightViewMode = .always
        searchField.attributedPlaceholder = NSAttributedString(
            string: "Pesquisar ou colar link do YouTube",
            attributes: [.foregroundColor: Palette.pearl.withAlphaComponent(0.58)]
        )
        searchField.font = .systemFont(ofSize: 14)
        searchField.returnKeyType = .search
        searchField.delegate = self
        searchField.accessibilityIdentifier = "youtube.search"
        view.addSubview(searchField)

        configureButton(searchButton, title: "Buscar", symbol: "magnifyingglass", action: #selector(submitSearch))
        searchButton.accessibilityIdentifier = "youtube.search.button"
        configureButton(pasteButton, title: "Colar", symbol: "doc.on.clipboard", action: #selector(pasteLink))
        pasteButton.accessibilityIdentifier = "youtube.paste.button"

        status.translatesAutoresizingMaskIntoConstraints = false
        status.text = "YOUTUBE ONLINE · reprodução oficial · toque no vídeo para iniciar"
        status.textColor = Palette.amber
        status.font = .systemFont(ofSize: 10, weight: .medium)
        status.numberOfLines = 2
        status.accessibilityIdentifier = "youtube.status"
        view.addSubview(status)
    }

    private func configureButton(_ button: UIButton, title: String, symbol: String, action: Selector) {
        var configuration = UIButton.Configuration.filled()
        configuration.title = title
        configuration.image = UIImage(systemName: symbol)
        configuration.imagePadding = 5
        configuration.baseBackgroundColor = Palette.amber
        configuration.baseForegroundColor = Palette.ink
        configuration.cornerStyle = .capsule
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 9, leading: 12, bottom: 9, trailing: 12)
        button.configuration = configuration
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: action, for: .touchUpInside)
        view.addSubview(button)
    }

    private func configureWebView() {
        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.allowsBackForwardNavigationGestures = true
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        webView.backgroundColor = .black
        webView.isOpaque = false
        webView.layer.cornerRadius = 18
        webView.clipsToBounds = true
        webView.translatesAutoresizingMaskIntoConstraints = false

        screenCard.backgroundColor = .black
        screenCard.layer.cornerRadius = 22
        screenCard.layer.borderWidth = 1
        screenCard.layer.borderColor = Palette.copper.withAlphaComponent(0.8).cgColor
        screenCard.layer.shadowColor = Palette.ice.cgColor
        screenCard.layer.shadowOpacity = 0.26
        screenCard.layer.shadowRadius = 22
        screenCard.layer.shadowOffset = .zero
        screenCard.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(screenCard)
        screenCard.addSubview(webView)

        progress.translatesAutoresizingMaskIntoConstraints = false
        progress.progressTintColor = Palette.amber
        progress.trackTintColor = .clear
        view.addSubview(progress)

        activity.translatesAutoresizingMaskIntoConstraints = false
        activity.color = Palette.amber
        view.addSubview(activity)

        webView.addObserver(self, forKeyPath: #keyPath(WKWebView.estimatedProgress), options: .new, context: nil)
        observingProgress = true

        NSLayoutConstraint.activate([
            searchField.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 18),
            searchField.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 44),
            searchField.trailingAnchor.constraint(equalTo: searchButton.leadingAnchor, constant: -8),
            searchField.heightAnchor.constraint(equalToConstant: 42),
            searchButton.trailingAnchor.constraint(equalTo: pasteButton.leadingAnchor, constant: -8),
            searchButton.centerYAnchor.constraint(equalTo: searchField.centerYAnchor),
            searchButton.widthAnchor.constraint(equalToConstant: 90),
            pasteButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -44),
            pasteButton.centerYAnchor.constraint(equalTo: searchField.centerYAnchor),
            pasteButton.widthAnchor.constraint(equalToConstant: 84),
            status.topAnchor.constraint(equalTo: searchField.bottomAnchor, constant: 8),
            status.leadingAnchor.constraint(equalTo: searchField.leadingAnchor),
            status.trailingAnchor.constraint(equalTo: pasteButton.trailingAnchor),
            leftSconce.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 17),
            leftSconce.centerYAnchor.constraint(equalTo: screenCard.centerYAnchor),
            leftSconce.widthAnchor.constraint(equalToConstant: 6),
            leftSconce.heightAnchor.constraint(equalToConstant: 78),
            rightSconce.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -17),
            rightSconce.centerYAnchor.constraint(equalTo: screenCard.centerYAnchor),
            rightSconce.widthAnchor.constraint(equalToConstant: 6),
            rightSconce.heightAnchor.constraint(equalToConstant: 78),
            screenCard.topAnchor.constraint(equalTo: status.bottomAnchor, constant: 14),
            screenCard.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 34),
            screenCard.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -34),
            screenCard.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -22),
            webView.topAnchor.constraint(equalTo: screenCard.topAnchor, constant: 8),
            webView.leadingAnchor.constraint(equalTo: screenCard.leadingAnchor, constant: 8),
            webView.trailingAnchor.constraint(equalTo: screenCard.trailingAnchor, constant: -8),
            webView.bottomAnchor.constraint(equalTo: screenCard.bottomAnchor, constant: -8),
            progress.topAnchor.constraint(equalTo: screenCard.topAnchor),
            progress.leadingAnchor.constraint(equalTo: screenCard.leadingAnchor),
            progress.trailingAnchor.constraint(equalTo: screenCard.trailingAnchor),
            progress.heightAnchor.constraint(equalToConstant: 2),
            activity.centerXAnchor.constraint(equalTo: screenCard.centerXAnchor),
            activity.centerYAnchor.constraint(equalTo: screenCard.centerYAnchor)
        ])
    }

    private func loadHome() {
        load(URL(string: "https://m.youtube.com")!, status: "YOUTUBE ONLINE · pesquise um vídeo ou cole um link")
    }

    private func load(_ url: URL, status message: String? = nil) {
        if let message { status.text = message }
        webView.load(URLRequest(url: url))
    }

    @objc private func submitSearch() {
        searchField.resignFirstResponder()
        let text = searchField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !text.isEmpty else {
            loadHome()
            return
        }
        if let id = Self.videoID(from: text) {
            let encoded = id.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? id
            load(URL(string: "https://www.youtube-nocookie.com/embed/\(encoded)?playsinline=1&rel=0&modestbranding=1")!,
                 status: "VÍDEO YOUTUBE · toque no player para reproduzir")
            return
        }
        let query = text.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? text
        load(URL(string: "https://m.youtube.com/results?search_query=\(query)")!, status: "RESULTADOS · toque em um vídeo para abrir")
    }

    @objc private func pasteLink() {
        guard let text = UIPasteboard.general.string, !text.isEmpty else {
            status.text = "A área de transferência está vazia."
            return
        }
        searchField.text = text
        submitSearch()
    }

    @objc private func close() { dismiss(animated: true) }

    @objc private func openInSafari() {
        UIApplication.shared.open(webView.url ?? URL(string: "https://m.youtube.com")!)
    }

    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey: Any]?, context: UnsafeMutableRawPointer?) {
        guard keyPath == #keyPath(WKWebView.estimatedProgress) else { return }
        let value = Float(webView.estimatedProgress)
        progress.progress = value
        progress.isHidden = value >= 0.999
        if value >= 0.999 { activity.stopAnimating() }
    }

    private static func videoID(from raw: String) -> String? {
        guard let url = URL(string: raw.trimmingCharacters(in: .whitespacesAndNewlines)) else { return nil }
        let host = (url.host ?? "").lowercased()
        guard host.contains("youtube.com") || host == "youtu.be" || host.hasSuffix(".youtu.be") else { return nil }
        if let id = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.first(where: { $0.name == "v" })?.value,
           !id.isEmpty { return id }
        let parts = url.pathComponents.filter { $0 != "/" }
        guard let marker = parts.firstIndex(where: { ["shorts", "embed", "live"].contains($0.lowercased()) }),
              parts.indices.contains(marker + 1) else { return nil }
        return parts[marker + 1]
    }
}

extension YouTubeViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        submitSearch()
        return true
    }
}

extension YouTubeViewController: WKNavigationDelegate, WKUIDelegate {
    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        progress.isHidden = false
        progress.progress = 0
        activity.startAnimating()
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        activity.stopAnimating()
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        activity.stopAnimating()
        status.text = "Não foi possível carregar o YouTube. Verifique a internet ou use Safari."
    }

    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        if navigationAction.targetFrame == nil { webView.load(navigationAction.request) }
        decisionHandler(.allow)
    }

    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration,
                 for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        if navigationAction.targetFrame == nil { webView.load(navigationAction.request) }
        return nil
    }
}
