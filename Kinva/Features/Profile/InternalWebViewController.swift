import UIKit
import WebKit

final class InternalWebViewController: UIViewController, WKNavigationDelegate {
    var onBack: (() -> Void)?

    private let pageTitle: String
    private let url: URL
    private let webView = WKWebView(frame: .zero, configuration: WKWebViewConfiguration())
    private let indicator = UIActivityIndicatorView(style: .medium)

    init(title: String, url: URL) {
        pageTitle = title
        self.url = url
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = AppTheme.background
        navigationController?.setNavigationBarHidden(true, animated: false)

        let header = AppHeaderView(title: pageTitle)
        header.titleLabel.font = internalWebRoundedFont(26, weight: .bold)
        header.backButton.setImage(.symbol("arrow.left", size: 23, weight: .bold), for: .normal)
        header.backButton.addTarget(self, action: #selector(backTapped), for: .touchUpInside)

        webView.navigationDelegate = self
        webView.backgroundColor = .white
        webView.scrollView.backgroundColor = .white
        webView.allowsBackForwardNavigationGestures = true

        [header, webView, indicator].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview($0)
        }
        NSLayoutConstraint.activate([
            header.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            header.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            header.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            webView.topAnchor.constraint(equalTo: header.bottomAnchor),
            webView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            webView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            indicator.centerXAnchor.constraint(equalTo: webView.centerXAnchor),
            indicator.centerYAnchor.constraint(equalTo: webView.centerYAnchor)
        ])

        indicator.startAnimating()
        webView.load(URLRequest(url: url))
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        indicator.stopAnimating()
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        showLoadFailure(error)
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        showLoadFailure(error)
    }

    private func showLoadFailure(_ error: Error) {
        indicator.stopAnimating()
        showLocalAlert(title: "Could not load page", message: error.localizedDescription)
    }

    @objc private func backTapped() { onBack?() }
}

private func internalWebRoundedFont(_ size: CGFloat, weight: UIFont.Weight) -> UIFont {
    let base = UIFont.systemFont(ofSize: size, weight: weight)
    guard let descriptor = base.fontDescriptor.withDesign(.rounded) else { return base }
    return UIFont(descriptor: descriptor, size: size)
}
