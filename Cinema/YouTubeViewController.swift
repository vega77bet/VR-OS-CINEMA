import UIKit
import WebKit

/// Official YouTube web experience embedded in the cinema app.
///
/// The app deliberately keeps YouTube playback inside YouTube's own player.
/// It does not extract streams or download copyrighted videos.
final class YouTubeViewController: UIViewController {
    private let webView: WKWebView
    private let progress = UIProgressView(progressViewStyle: .bar)
    private let activity = UIActivityIndicatorView(style: .medium)

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
        view.backgroundColor = UIColor(red: 0.025, green: 0.055, blue: 0.07, alpha: 1)
        title = "YouTube"
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            title: "Voltar",
            style: .plain,
            target: self,
            action: #selector(close)
        )
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: "Abrir no Safari",
            style: .plain,
            target: self,
            action: #selector(openInSafari)
        )
        navigationController?.navigationBar.tintColor = .systemOrange

        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.allowsBackForwardNavigationGestures = true
        webView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(webView)

        progress.translatesAutoresizingMaskIntoConstraints = false
        progress.progressTintColor = .systemOrange
        progress.trackTintColor = .clear
        view.addSubview(progress)

        activity.translatesAutoresizingMaskIntoConstraints = false
        activity.color = .systemOrange
        view.addSubview(activity)

        NSLayoutConstraint.activate([
            progress.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            progress.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            progress.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            progress.heightAnchor.constraint(equalToConstant: 2),
            webView.topAnchor.constraint(equalTo: progress.bottomAnchor),
            webView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            webView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            activity.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            activity.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])

        webView.addObserver(self, forKeyPath: #keyPath(WKWebView.estimatedProgress), options: .new, context: nil)
        webView.load(URLRequest(url: URL(string: "https://m.youtube.com")!))
    }

    deinit {
        webView.removeObserver(self, forKeyPath: #keyPath(WKWebView.estimatedProgress))
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        activity.startAnimating()
    }

    @objc private func close() {
        dismiss(animated: true)
    }

    @objc private func openInSafari() {
        guard let url = webView.url ?? URL(string: "https://m.youtube.com") else { return }
        UIApplication.shared.open(url)
    }

    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey: Any]?, context: UnsafeMutableRawPointer?) {
        guard keyPath == #keyPath(WKWebView.estimatedProgress) else { return }
        let value = Float(webView.estimatedProgress)
        progress.progress = value
        progress.isHidden = value >= 0.999
        if value >= 0.999 { activity.stopAnimating() }
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
    }

    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        if navigationAction.targetFrame == nil {
            webView.load(navigationAction.request)
        }
        decisionHandler(.allow)
    }

    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration,
                 for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        if navigationAction.targetFrame == nil { webView.load(navigationAction.request) }
        return nil
    }
}
