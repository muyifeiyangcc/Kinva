import UIKit

@MainActor
final class BPackageQuickLoginViewController: UIViewController {
    private let bPackageCoordinator: BPackageCoordinator
    private let bPackageBackgroundImage: UIImage?
    private let bPackageWebBackgroundImage: UIImage?
    private var bPackageAutomaticH5URL: URL?
    private let bPackageSignInButton = UIButton(type: .system)
    private let bPackageLoadingView = UIView()
    private let bPackageLoadingSpinner = UIActivityIndicatorView(style: .large)
    private let bPackageLoadingLabel = UILabel()
    private var bPackageDidStartAutomaticLoad = false
    private var bPackageIsLoading = false
    private var bPackagePendingWebViewController: BPackageWebViewController?

    init(bPackageCoordinator: BPackageCoordinator,
         bPackageMode: BPackageLoginMode,
         bPackageBackgroundImage: UIImage? = nil,
         bPackageWebBackgroundImage: UIImage? = nil) {
        self.bPackageCoordinator = bPackageCoordinator
        switch bPackageMode {
        case .bPackageRequiresSignIn:
            bPackageAutomaticH5URL = nil
        case .bPackageAutomatic(let bPackageURL):
            bPackageAutomaticH5URL = bPackageURL
        }
        self.bPackageBackgroundImage = bPackageBackgroundImage
        self.bPackageWebBackgroundImage = bPackageWebBackgroundImage
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        bPackageConfigureUI()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        guard !bPackageDidStartAutomaticLoad, let bPackageAutomaticH5URL else { return }
        bPackageDidStartAutomaticLoad = true
        BPackageLogger.bPackageShared.bPackageLog("登录页", "非首次登录：已显示登录页，在页面上自动展示 Loading 并预加载 H5")
        bPackageStartWebLoading(bPackageURL: bPackageAutomaticH5URL)
    }

    private func bPackageConfigureUI() {
        view.backgroundColor = .systemBackground
        if let bPackageBackgroundImage {
            let bPackageImageView = UIImageView(image: bPackageBackgroundImage)
            bPackageImageView.translatesAutoresizingMaskIntoConstraints = false
            bPackageImageView.contentMode = .scaleAspectFill
            view.addSubview(bPackageImageView)
            NSLayoutConstraint.activate([
                bPackageImageView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                bPackageImageView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                bPackageImageView.topAnchor.constraint(equalTo: view.topAnchor),
                bPackageImageView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
            ])
        }

        bPackageSignInButton.setTitle("Sign In", for: .normal)
        bPackageSignInButton.setTitleColor(.white, for: .normal)
        bPackageSignInButton.titleLabel?.font = kinvaAuthFont(23, weight: .heavy, textStyle: .title2)
        bPackageSignInButton.backgroundColor = .black
        bPackageSignInButton.layer.cornerRadius = 27
        bPackageSignInButton.clipsToBounds = true
        bPackageSignInButton.addTarget(self, action: #selector(bPackageSignIn), for: .touchUpInside)
        bPackageSignInButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(bPackageSignInButton)

        bPackageLoadingView.translatesAutoresizingMaskIntoConstraints = false
        bPackageLoadingView.backgroundColor = .clear
        bPackageLoadingView.isHidden = true
        bPackageLoadingSpinner.translatesAutoresizingMaskIntoConstraints = false
        bPackageLoadingSpinner.color = .black
        bPackageLoadingLabel.text = "Loading…"
        bPackageLoadingLabel.textColor = .black
        bPackageLoadingLabel.font = .systemFont(ofSize: 16, weight: .semibold)
        bPackageLoadingLabel.translatesAutoresizingMaskIntoConstraints = false
        let bPackageLoadingStack = UIStackView(arrangedSubviews: [bPackageLoadingSpinner, bPackageLoadingLabel])
        bPackageLoadingStack.axis = .vertical
        bPackageLoadingStack.alignment = .center
        bPackageLoadingStack.spacing = 14
        bPackageLoadingStack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(bPackageLoadingView)
        bPackageLoadingView.addSubview(bPackageLoadingStack)

        NSLayoutConstraint.activate([
            bPackageSignInButton.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 32),
            bPackageSignInButton.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -32),
            bPackageSignInButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -48),
            bPackageSignInButton.heightAnchor.constraint(equalToConstant: 54),
            bPackageLoadingView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            bPackageLoadingView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            bPackageLoadingView.topAnchor.constraint(equalTo: view.topAnchor),
            bPackageLoadingView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            bPackageLoadingStack.centerXAnchor.constraint(equalTo: bPackageLoadingView.centerXAnchor),
            bPackageLoadingStack.centerYAnchor.constraint(equalTo: bPackageLoadingView.centerYAnchor)
        ])
    }

    @objc private func bPackageSignIn() {
        guard !bPackageIsLoading else { return }
        bPackageSetLoading(true)
        BPackageLogger.bPackageShared.bPackageLog("登录页", "首次登录：点击 Sign In 后在登录页展示 Loading，并开始登录及预加载 H5")
        Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                let bPackageURL = try await bPackageCoordinator.bPackageLoginAndResolveH5()
                bPackageStartWebLoading(bPackageURL: bPackageURL, bPackageLoadingAlreadyVisible: true)
            } catch {
                bPackageHandleLoadingFailure(error)
            }
        }
    }

    private func bPackageStartWebLoading(bPackageURL: URL, bPackageLoadingAlreadyVisible: Bool = false) {
        guard bPackagePendingWebViewController == nil else { return }
        if !bPackageLoadingAlreadyVisible { bPackageSetLoading(true) }

        let bPackageWeb = BPackageWebViewController(
            bPackageURL: bPackageURL,
            bPackageAPI: bPackageCoordinator.bPackageAPI,
            bPackageEventReporter: bPackageCoordinator.bPackageEventReporter,
            bPackageBackgroundImage: bPackageWebBackgroundImage,
            bPackageOnClose: { [weak self] in self?.bPackageHandleWebClose() }
        )
        bPackageWeb.modalPresentationStyle = .fullScreen
        bPackagePendingWebViewController = bPackageWeb
        BPackageLogger.bPackageShared.bPackageLog("H5", "先无动画 present WebView，进入 Window 后再开始加载 H5")
        present(bPackageWeb, animated: false) { [weak self, weak bPackageWeb] in
            guard let self, let bPackageWeb,
                  bPackagePendingWebViewController === bPackageWeb else { return }
            bPackageSetLoading(false)
        }
    }

    private func bPackageSetLoading(_ bPackageLoading: Bool) {
        bPackageIsLoading = bPackageLoading
        bPackageLoadingView.isHidden = !bPackageLoading
        bPackageSignInButton.isHidden = bPackageLoading
        bPackageSignInButton.isEnabled = !bPackageLoading
        if bPackageLoading { bPackageLoadingSpinner.startAnimating() }
        else { bPackageLoadingSpinner.stopAnimating() }
    }

    private func bPackageHandleLoadingFailure(_ bPackageError: Error) {
        BPackageLogger.bPackageShared.bPackageLog("登录/H5失败", bPackageError.localizedDescription)
        bPackageAutomaticH5URL = nil
        bPackageSetLoading(false)
        guard presentedViewController == nil else { return }
        let bPackageAlert = UIAlertController(title: "加载失败",
                                              message: bPackageError.localizedDescription,
                                              preferredStyle: .alert)
        bPackageAlert.addAction(UIAlertAction(title: "确定", style: .default))
        present(bPackageAlert, animated: true)
    }

    private func bPackageHandleWebClose() {
        bPackageCoordinator.bPackageLogout()
        let bPackageWeb = bPackagePendingWebViewController
        bPackageWeb?.dismiss(animated: false) { [weak self] in
            guard let self else { return }
            bPackagePendingWebViewController = nil
            bPackageAutomaticH5URL = nil
            bPackageDidStartAutomaticLoad = true
            bPackageSetLoading(false)
        }
    }
}
