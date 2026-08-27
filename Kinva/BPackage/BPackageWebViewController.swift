import UIKit
import UserNotifications
import WebKit
#if canImport(ScreenShield)
import ScreenShield
#endif

final class BPackageWebViewController: UIViewController, WKNavigationDelegate, WKUIDelegate, WKScriptMessageHandler {
    private let bPackageURL: URL
    private let bPackageAPI: BPackageAPIClient
    private let bPackageEventReporter: BPackageEventReporter
    private let bPackageBackgroundImage: UIImage?
    private let bPackageOnClose: () -> Void
    private var bPackageDidCompleteFirstLoad = false
    private var bPackageDidStartInitialLoad = false
    private var bPackageDidRequestPushPermission = false
    private var bPackageDidStartRecordingProtection = false
    private var bPackageIsClosing = false
    private var bPackagePreviousNavigationBarHidden: Bool?
    private let bPackageProtectedContentView = UIView()
    private var bPackageScreenShieldContainerView: UIView?
    private weak var bPackageWebBackgroundImageView: UIImageView?
    private let bPackageLoadingView = UIView()
    private let bPackageLoadingSpinner = UIActivityIndicatorView(style: .large)
    private let bPackageLoadingLabel = UILabel()
    private let bPackageRetryButton = UIButton(type: .system)
    private let bPackagePaymentOverlay = UIView()
    private let bPackagePaymentSpinner = UIActivityIndicatorView(style: .large)
    private let bPackagePaymentLabel = UILabel()
    private let bPackagePaymentToastView = UIView()
    private let bPackagePaymentToastLabel = UILabel()
    private var bPackagePaymentToastDismissWorkItem: DispatchWorkItem?

    private let bPackageBlockedPaymentSchemes: Set<String> = [
        "squarecash", "cashme", "upi", "phonepe", "paytmmp", "gpay",
        "com.amazon.mobile.shopping", "mobikwik", "freecharge"
    ]

    private lazy var bPackageWebView: WKWebView = {
        let bPackageController = WKUserContentController()
        ["rechargePay", "Close", "openBrowser"].forEach { bPackageController.add(self, name: $0) }
        let bPackageConfig = WKWebViewConfiguration()
        bPackageConfig.userContentController = bPackageController
        bPackageConfig.allowsInlineMediaPlayback = true
        bPackageConfig.mediaTypesRequiringUserActionForPlayback = []
        let bPackageView = WKWebView(frame: .zero, configuration: bPackageConfig)
        bPackageView.navigationDelegate = self
        bPackageView.uiDelegate = self
        bPackageView.isOpaque = false
        bPackageView.backgroundColor = .clear
        bPackageView.scrollView.backgroundColor = .clear
        bPackageView.scrollView.contentInsetAdjustmentBehavior = .never
        bPackageView.scrollView.contentInset = .zero
        bPackageView.scrollView.scrollIndicatorInsets = .zero
        bPackageView.scrollView.bounces = false
        bPackageView.allowsBackForwardNavigationGestures = true
        return bPackageView
    }()

    init(bPackageURL: URL,
         bPackageAPI: BPackageAPIClient,
         bPackageEventReporter: BPackageEventReporter,
         bPackageBackgroundImage: UIImage? = nil,
        bPackageOnClose: @escaping () -> Void) {
        self.bPackageURL = bPackageURL
        self.bPackageAPI = bPackageAPI
        self.bPackageEventReporter = bPackageEventReporter
        self.bPackageBackgroundImage = bPackageBackgroundImage
        self.bPackageOnClose = bPackageOnClose
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        bPackageConfigureWebView()
        bPackageConfigureLoadingView()
        bPackageConfigurePaymentOverlay()
        bPackageConfigurePaymentToast()
        bPackageShowWebLoading(bPackageMessage: "Loading…")
        StoreKit1PurchaseManager.bPackageShared.bPackageConfigure(
            bPackageAPI: bPackageAPI,
            bPackageEventReporter: bPackageEventReporter
        ) { [weak self] bPackageState in self?.bPackageHandlePaymentState(bPackageState) }
        BPackageLogger.bPackageShared.bPackageLog("H5", "WebView 页面已创建，等待进入 Window 后加载业务页面")
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        guard let bPackageNavigationController = navigationController else { return }
        if bPackagePreviousNavigationBarHidden == nil {
            bPackagePreviousNavigationBarHidden = bPackageNavigationController.isNavigationBarHidden
        }
        bPackageNavigationController.setNavigationBarHidden(true, animated: animated)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        guard let bPackageNavigationController = navigationController,
              let bPackagePreviousNavigationBarHidden else { return }
        bPackageNavigationController.setNavigationBarHidden(bPackagePreviousNavigationBarHidden, animated: animated)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        bPackageBeginInitialLoadIfNeeded()
        if !bPackageDidStartRecordingProtection {
            bPackageDidStartRecordingProtection = true
            #if canImport(ScreenShield)
            ScreenShield.shared.protectFromScreenRecording()
            BPackageLogger.bPackageShared.bPackageLog("ScreenShield", "已启用录屏检测；截屏保护由独立 H5 安全容器承担")
            #else
            BPackageLogger.bPackageShared.bPackageLog("ScreenShield", "未安装 ScreenShield，H5 使用普通内容容器")
            #endif
        }
        bPackageRequestPushPermissionIfNeeded()
    }

    private func bPackageRequestPushPermissionIfNeeded() {
        guard bPackageDidCompleteFirstLoad, !bPackageDidRequestPushPermission else { return }
        bPackageDidRequestPushPermission = true
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { bPackageGranted, bPackageError in
            if let bPackageError { BPackageLogger.bPackageShared.bPackageLog("推送权限", bPackageError.localizedDescription) }
            if bPackageGranted { DispatchQueue.main.async { UIApplication.shared.registerForRemoteNotifications() } }
        }
    }

    deinit {
        bPackageWebView.configuration.userContentController.removeAllScriptMessageHandlers()
        StoreKit1PurchaseManager.bPackageShared.bPackageDetachUI()
    }

    private func bPackageConfigureWebView() {
        // 安全容器在系统截屏中会隐藏其内容，根视图就是最终截图底色。
        // 使用固定白色，避免深色模式或 systemGroupedBackground 产生灰/黑底。
        view.backgroundColor = .white
        bPackageConfigureProtectedContentContainer()
        if let bPackageBackgroundImage {
            let bPackageImageView = UIImageView(image: bPackageBackgroundImage)
            bPackageWebBackgroundImageView = bPackageImageView
            bPackageImageView.translatesAutoresizingMaskIntoConstraints = false
            bPackageImageView.contentMode = .scaleAspectFill
            bPackageProtectedContentView.addSubview(bPackageImageView)
            NSLayoutConstraint.activate([
                bPackageImageView.leadingAnchor.constraint(equalTo: bPackageProtectedContentView.leadingAnchor),
                bPackageImageView.trailingAnchor.constraint(equalTo: bPackageProtectedContentView.trailingAnchor),
                bPackageImageView.topAnchor.constraint(equalTo: bPackageProtectedContentView.topAnchor),
                bPackageImageView.bottomAnchor.constraint(equalTo: bPackageProtectedContentView.bottomAnchor)
            ])
        }
        bPackageWebView.translatesAutoresizingMaskIntoConstraints = false
        bPackageProtectedContentView.addSubview(bPackageWebView)
        NSLayoutConstraint.activate([
            bPackageWebView.leadingAnchor.constraint(equalTo: bPackageProtectedContentView.leadingAnchor),
            bPackageWebView.trailingAnchor.constraint(equalTo: bPackageProtectedContentView.trailingAnchor),
            bPackageWebView.topAnchor.constraint(equalTo: bPackageProtectedContentView.topAnchor),
            bPackageWebView.bottomAnchor.constraint(equalTo: bPackageProtectedContentView.bottomAnchor)
        ])
    }

    private func bPackageConfigureProtectedContentContainer() {
        #if canImport(ScreenShield)
        let bPackageShieldView = ScreenshotProtectingView(contentView: bPackageProtectedContentView)
        bPackageShieldView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(bPackageShieldView)
        NSLayoutConstraint.activate([
            bPackageShieldView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            bPackageShieldView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            bPackageShieldView.topAnchor.constraint(equalTo: view.topAnchor),
            bPackageShieldView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        if bPackageProtectedContentView.superview != nil {
            bPackageScreenShieldContainerView = bPackageShieldView
            BPackageLogger.bPackageShared.bPackageLog("ScreenShield", "H5 已放入独立安全容器；未修改控制器根 view.layer")
            return
        }

        bPackageShieldView.removeFromSuperview()
        BPackageLogger.bPackageShared.bPackageLog("ScreenShield", "当前系统无法创建安全容器，已降级为正常 H5，避免黑屏")
        #endif

        bPackageProtectedContentView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(bPackageProtectedContentView)
        NSLayoutConstraint.activate([
            bPackageProtectedContentView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            bPackageProtectedContentView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            bPackageProtectedContentView.topAnchor.constraint(equalTo: view.topAnchor),
            bPackageProtectedContentView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    private func bPackageConfigureLoadingView() {
        bPackageLoadingView.translatesAutoresizingMaskIntoConstraints = false
        bPackageLoadingView.backgroundColor = .clear
        bPackageLoadingView.isHidden = true
        bPackageLoadingSpinner.translatesAutoresizingMaskIntoConstraints = false
        bPackageLoadingSpinner.color = .black
        bPackageLoadingLabel.text = "Loading…"
        bPackageLoadingLabel.textColor = .black
        bPackageLoadingLabel.numberOfLines = 0
        bPackageLoadingLabel.textAlignment = .center
        bPackageRetryButton.setTitle("Reload", for: .normal)
        bPackageRetryButton.isHidden = true
        bPackageRetryButton.addTarget(self, action: #selector(bPackageRetryH5), for: .touchUpInside)
        let bPackageLoadingStack = UIStackView(arrangedSubviews: [bPackageLoadingSpinner, bPackageLoadingLabel, bPackageRetryButton])
        bPackageLoadingStack.axis = .vertical
        bPackageLoadingStack.alignment = .center
        bPackageLoadingStack.spacing = 16
        bPackageLoadingStack.translatesAutoresizingMaskIntoConstraints = false
        bPackageProtectedContentView.addSubview(bPackageLoadingView)
        bPackageLoadingView.addSubview(bPackageLoadingStack)
        NSLayoutConstraint.activate([
            bPackageLoadingView.leadingAnchor.constraint(equalTo: bPackageProtectedContentView.leadingAnchor),
            bPackageLoadingView.trailingAnchor.constraint(equalTo: bPackageProtectedContentView.trailingAnchor),
            bPackageLoadingView.topAnchor.constraint(equalTo: bPackageProtectedContentView.topAnchor),
            bPackageLoadingView.bottomAnchor.constraint(equalTo: bPackageProtectedContentView.bottomAnchor),
            bPackageLoadingStack.centerXAnchor.constraint(equalTo: bPackageLoadingView.centerXAnchor),
            bPackageLoadingStack.centerYAnchor.constraint(equalTo: bPackageLoadingView.centerYAnchor),
            bPackageLoadingStack.leadingAnchor.constraint(greaterThanOrEqualTo: bPackageLoadingView.leadingAnchor, constant: 32),
            bPackageLoadingStack.trailingAnchor.constraint(lessThanOrEqualTo: bPackageLoadingView.trailingAnchor, constant: -32)
        ])
    }

    private func bPackageBeginInitialLoadIfNeeded() {
        guard !bPackageDidStartInitialLoad, view.window != nil else { return }
        bPackageDidStartInitialLoad = true
        BPackageLogger.bPackageShared.bPackageLog("H5", "WebView 已进入 Window，开始加载加密业务页面")
        bPackageWebView.load(URLRequest(url: bPackageURL))
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        bPackageLoadingSpinner.stopAnimating()
        bPackageLoadingView.isHidden = true
        bPackageRetryButton.isHidden = true
        guard !bPackageDidCompleteFirstLoad else {
            BPackageLogger.bPackageShared.bPackageLog("H5", "页面重新加载完成")
            return
        }
        bPackageWebBackgroundImageView?.removeFromSuperview()
        BPackageLogger.bPackageShared.bPackageLog("H5", "首次页面加载完成；已移除 H5 Loading 背景，避免透明区域继续显示登录底图")
        bPackageDidCompleteFirstLoad = true
        BPackageLogger.bPackageShared.bPackageLog("H5", "首次页面加载完成，隐藏 Loading 并显示 H5")
        bPackageRequestPushPermissionIfNeeded()
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        BPackageLogger.bPackageShared.bPackageLog("JS Bridge", "收到 \(message.name)")
        switch message.name {
        case "Close":
            guard !bPackageIsClosing else {
                BPackageLogger.bPackageShared.bPackageLog("退出登录", "已在处理 Close，忽略 H5 重复回调")
                return
            }
            bPackageIsClosing = true
            userContentController.removeScriptMessageHandler(forName: "Close")
            bPackageWebView.stopLoading()
            BPackageLogger.bPackageShared.bPackageLog("退出登录", "首次收到 Close，开始单次返回快速登录页")
            bPackageOnClose()
        case "openBrowser":
            if let bPackageBody = message.body as? [String: Any], let bPackageRaw = bPackageBody["url"] as? String {
                bPackageOpenExternalURL(bPackageRaw)
            } else if let bPackageRaw = message.body as? String {
                bPackageOpenExternalURL(bPackageRaw)
            }
        case "rechargePay":
            guard let bPackageBody = message.body as? [String: Any] else { return }
            let bPackageBatchNo = bPackageBody["batchNo"] as? String ?? ""
            let bPackageOrderCode = bPackageBody["orderCode"] as? String ?? ""
            guard !bPackageBatchNo.isEmpty, !bPackageOrderCode.isEmpty else {
                bPackageShowPaymentAlert(bPackageTitle: "Payment Failed", bPackageMessage: "The payment information is incomplete.")
                return
            }
            // 严格要求：用户点击购买、收到有效 rechargePay 时立即触发 InitiateCheckout。
            bPackageEventReporter.bPackageReport(.bPackageInitiateCheckout)
            StoreKit1PurchaseManager.bPackageShared.bPackagePurchase(
                bPackageBatchNo: bPackageBatchNo,
                bPackageOrderCode: bPackageOrderCode
            )
        default:
            break
        }
    }

    private func bPackageConfigurePaymentOverlay() {
        bPackagePaymentOverlay.translatesAutoresizingMaskIntoConstraints = false
        bPackagePaymentOverlay.backgroundColor = UIColor.black.withAlphaComponent(0.55)
        bPackagePaymentOverlay.isHidden = true
        bPackagePaymentLabel.translatesAutoresizingMaskIntoConstraints = false
        bPackagePaymentLabel.textColor = .white
        bPackagePaymentLabel.numberOfLines = 0
        bPackagePaymentLabel.textAlignment = .center
        bPackagePaymentSpinner.translatesAutoresizingMaskIntoConstraints = false
        bPackagePaymentSpinner.color = .white
        bPackageProtectedContentView.addSubview(bPackagePaymentOverlay)
        bPackagePaymentOverlay.addSubview(bPackagePaymentSpinner)
        bPackagePaymentOverlay.addSubview(bPackagePaymentLabel)
        NSLayoutConstraint.activate([
            bPackagePaymentOverlay.leadingAnchor.constraint(equalTo: bPackageProtectedContentView.leadingAnchor),
            bPackagePaymentOverlay.trailingAnchor.constraint(equalTo: bPackageProtectedContentView.trailingAnchor),
            bPackagePaymentOverlay.topAnchor.constraint(equalTo: bPackageProtectedContentView.topAnchor),
            bPackagePaymentOverlay.bottomAnchor.constraint(equalTo: bPackageProtectedContentView.bottomAnchor),
            bPackagePaymentSpinner.centerXAnchor.constraint(equalTo: bPackagePaymentOverlay.centerXAnchor),
            bPackagePaymentSpinner.centerYAnchor.constraint(equalTo: bPackagePaymentOverlay.centerYAnchor, constant: -24),
            bPackagePaymentLabel.topAnchor.constraint(equalTo: bPackagePaymentSpinner.bottomAnchor, constant: 16),
            bPackagePaymentLabel.leadingAnchor.constraint(equalTo: bPackagePaymentOverlay.leadingAnchor, constant: 30),
            bPackagePaymentLabel.trailingAnchor.constraint(equalTo: bPackagePaymentOverlay.trailingAnchor, constant: -30)
        ])
    }

    private func bPackageHandlePaymentState(_ bPackageState: StoreKit1PurchaseManager.BPackageState) {
        switch bPackageState {
        case .bPackageLoading(let bPackageMessage):
            bPackagePaymentOverlay.isHidden = false
            bPackagePaymentLabel.text = bPackageMessage
            bPackagePaymentSpinner.startAnimating()
        case .bPackageSuccess:
            bPackageHidePaymentOverlay()
            bPackageShowPaymentToast(bPackageMessage: "Payment successful")
        case .bPackageFailure(let bPackageMessage):
            bPackageHidePaymentOverlay()
            bPackageShowPaymentAlert(bPackageTitle: "Payment Failed", bPackageMessage: bPackageMessage)
        case .bPackageCancelled:
            bPackageHidePaymentOverlay()
            bPackageShowPaymentToast(bPackageMessage: "Payment cancelled")
        }
    }

    private func bPackageHidePaymentOverlay() {
        bPackagePaymentSpinner.stopAnimating()
        bPackagePaymentOverlay.isHidden = true
    }

    private func bPackageShowPaymentAlert(bPackageTitle: String, bPackageMessage: String) {
        guard presentedViewController == nil else { return }
        let bPackageAlert = UIAlertController(title: bPackageTitle, message: bPackageMessage, preferredStyle: .alert)
        bPackageAlert.addAction(UIAlertAction(title: "OK", style: .default))
        present(bPackageAlert, animated: true)
    }

    private func bPackageConfigurePaymentToast() {
        bPackagePaymentToastView.translatesAutoresizingMaskIntoConstraints = false
        bPackagePaymentToastView.backgroundColor = UIColor.black.withAlphaComponent(0.82)
        bPackagePaymentToastView.layer.cornerRadius = 12
        bPackagePaymentToastView.alpha = 0
        bPackagePaymentToastView.isHidden = true

        bPackagePaymentToastLabel.translatesAutoresizingMaskIntoConstraints = false
        bPackagePaymentToastLabel.textColor = .white
        bPackagePaymentToastLabel.font = .systemFont(ofSize: 15, weight: .semibold)
        bPackagePaymentToastLabel.numberOfLines = 0
        bPackagePaymentToastLabel.textAlignment = .center

        bPackageProtectedContentView.addSubview(bPackagePaymentToastView)
        bPackagePaymentToastView.addSubview(bPackagePaymentToastLabel)
        NSLayoutConstraint.activate([
            bPackagePaymentToastView.centerXAnchor.constraint(equalTo: bPackageProtectedContentView.centerXAnchor),
            bPackagePaymentToastView.bottomAnchor.constraint(equalTo: bPackageProtectedContentView.safeAreaLayoutGuide.bottomAnchor, constant: -64),
            bPackagePaymentToastView.leadingAnchor.constraint(greaterThanOrEqualTo: bPackageProtectedContentView.leadingAnchor, constant: 32),
            bPackagePaymentToastView.trailingAnchor.constraint(lessThanOrEqualTo: bPackageProtectedContentView.trailingAnchor, constant: -32),
            bPackagePaymentToastLabel.leadingAnchor.constraint(equalTo: bPackagePaymentToastView.leadingAnchor, constant: 20),
            bPackagePaymentToastLabel.trailingAnchor.constraint(equalTo: bPackagePaymentToastView.trailingAnchor, constant: -20),
            bPackagePaymentToastLabel.topAnchor.constraint(equalTo: bPackagePaymentToastView.topAnchor, constant: 12),
            bPackagePaymentToastLabel.bottomAnchor.constraint(equalTo: bPackagePaymentToastView.bottomAnchor, constant: -12)
        ])
    }

    private func bPackageShowPaymentToast(bPackageMessage: String) {
        bPackagePaymentToastDismissWorkItem?.cancel()
        bPackagePaymentToastLabel.text = bPackageMessage
        bPackagePaymentToastView.isHidden = false
        bPackageProtectedContentView.bringSubviewToFront(bPackagePaymentToastView)
        UIView.animate(withDuration: 0.2) {
            self.bPackagePaymentToastView.alpha = 1
        }

        let bPackageDismissWorkItem = DispatchWorkItem { [weak self] in
            guard let self else { return }
            UIView.animate(withDuration: 0.2, animations: {
                self.bPackagePaymentToastView.alpha = 0
            }, completion: { _ in
                self.bPackagePaymentToastView.isHidden = true
            })
        }
        bPackagePaymentToastDismissWorkItem = bPackageDismissWorkItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 2, execute: bPackageDismissWorkItem)
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        bPackageHandleWebLoadFailure(error)
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        bPackageHandleWebLoadFailure(error)
    }

    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        BPackageLogger.bPackageShared.bPackageLog("H5错误", "WebContent 进程终止，开始自动恢复")
        bPackageShowWebLoading(bPackageMessage: "页面正在恢复…")
        webView.reload()
    }

    private func bPackageHandleWebLoadFailure(_ bPackageError: Error) {
        let bPackageNSError = bPackageError as NSError
        guard bPackageNSError.domain != NSURLErrorDomain || bPackageNSError.code != NSURLErrorCancelled else { return }
        BPackageLogger.bPackageShared.bPackageLog("H5错误", bPackageError.localizedDescription)
        bPackageLoadingSpinner.stopAnimating()
        bPackageLoadingLabel.text = "页面加载失败\n\(bPackageError.localizedDescription)"
        bPackageRetryButton.isHidden = false
        bPackageLoadingView.isHidden = false
    }

    private func bPackageShowWebLoading(bPackageMessage: String) {
        bPackageLoadingLabel.text = bPackageMessage
        bPackageRetryButton.isHidden = true
        bPackageLoadingView.isHidden = false
        bPackageLoadingSpinner.startAnimating()
    }

    @objc private func bPackageRetryH5() {
        bPackageShowWebLoading(bPackageMessage: "页面加载中…")
        if bPackageWebView.url != nil {
            bPackageWebView.reload()
        } else {
            bPackageWebView.load(URLRequest(url: bPackageURL))
        }
    }

    private func bPackageOpenExternalURL(_ bPackageRaw: String) {
        guard let bPackageURL = URL(string: bPackageRaw) else { return }
        let bPackageScheme = bPackageURL.scheme?.lowercased() ?? ""
        if bPackageBlockedPaymentSchemes.contains(bPackageScheme) {
            return
        }
        UIApplication.shared.open(bPackageURL) { [weak self] bPackageSuccess in
            let bPackagePayload = try? JSONSerialization.data(withJSONObject: ["state": bPackageSuccess ? "success" : "failed", "url": bPackageRaw])
            let bPackageObject = bPackagePayload.flatMap { String(data: $0, encoding: .utf8) } ?? "{}"
            self?.bPackageWebView.evaluateJavaScript("window.dispatchEvent(new CustomEvent('nativeOpenState',{detail:\(bPackageObject)}));")
        }
    }

    func webView(_ webView: WKWebView, decidePolicyFor action: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard let bPackageURL = action.request.url else { decisionHandler(.cancel); return }
        let bPackageScheme = bPackageURL.scheme?.lowercased() ?? ""
        if bPackageURL.host?.lowercased() == "apps.apple.com" || bPackageScheme == "itms-apps" {
            bPackageOpenExternalURL(bPackageURL.absoluteString)
            decisionHandler(.cancel)
        } else if !["http", "https", "file", "about"].contains(bPackageScheme) {
            bPackageOpenExternalURL(bPackageURL.absoluteString)
            decisionHandler(.cancel)
        } else {
            decisionHandler(.allow)
        }
    }

    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration,
                 for action: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        if let bPackageURL = action.request.url {
            let bPackageScheme = bPackageURL.scheme?.lowercased() ?? ""
            if bPackageBlockedPaymentSchemes.contains(bPackageScheme) {
                return nil
            } else if bPackageURL.host?.lowercased() == "apps.apple.com" {
                bPackageOpenExternalURL(bPackageURL.absoluteString)
            } else {
                webView.load(URLRequest(url: bPackageURL))
            }
        }
        return nil
    }

    @available(iOS 15.0, *)
    func webView(_ webView: WKWebView, requestMediaCapturePermissionFor origin: WKSecurityOrigin,
                 initiatedByFrame frame: WKFrameInfo, type: WKMediaCaptureType,
                 decisionHandler: @escaping (WKPermissionDecision) -> Void) {
        decisionHandler(.grant)
    }
}
