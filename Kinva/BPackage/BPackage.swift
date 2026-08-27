import UIKit
import Network

struct BPackageAppearance {
    var bPackageLaunchBackgroundImage: UIImage? = nil
    var bPackageLoginBackgroundImage: UIImage? = nil
    var bPackageWebBackgroundImage: UIImage? = nil
}

@MainActor
final class BPackage {
    static let bPackageShared = BPackage()
    static let bPackageOpenURLNotification = Notification.Name("bPackage.openURL")

    private weak var bPackageNavigationController: UINavigationController?
    private weak var bPackageAPackageViewController: UIViewController?
    private var bPackageCoordinator: BPackageCoordinator?
    private var bPackageAppearance = BPackageAppearance()
    private var bPackageLaunchCover: UIView?
    private var bPackagePendingInstallAttribution: (bPackageResult: String?, bPackageAdID: String)?
    private var bPackageOnAPackageRoute: (() -> Void)?
    private var bPackageNetworkMonitor: NWPathMonitor?
    private let bPackageNetworkMonitorQueue = DispatchQueue(label: "com.network-monitor")
    private var bPackageNetworkIsAvailable = false
    private var bPackageDidBeginInitialRequest = false
    private var bPackageRetryTask: Task<Void, Never>?
    private var bPackageDidStart = false

    private init() {}

    func bPackageStart(bPackageNavigationController: UINavigationController,
                       bPackageConfiguration: BPackageConfiguration,
                       bPackageAPackageViewController: UIViewController,
                       bPackageAppearance: BPackageAppearance,
                       bPackageAnalyticsAdapter: BPackageAnalyticsAdapter,
                       bPackageOnAPackageRoute: @escaping () -> Void) {
        guard !bPackageDidStart else {
            BPackageLogger.bPackageShared.bPackageLog("流程", "BPackage 已启动，忽略重复调用")
            return
        }
        bPackageDidStart = true
        self.bPackageNavigationController = bPackageNavigationController
        self.bPackageAPackageViewController = bPackageAPackageViewController
        self.bPackageAppearance = bPackageAppearance
        self.bPackageOnAPackageRoute = bPackageOnAPackageRoute
        bPackageShowLaunchCover()

        do {
            let bPackageCoordinator = try BPackageCoordinator(
                bPackageConfiguration: bPackageConfiguration,
                bPackageAnalyticsAdapter: bPackageAnalyticsAdapter
            )
            self.bPackageCoordinator = bPackageCoordinator
            if let bPackagePendingInstallAttribution {
                bPackageCoordinator.bPackageEventReporter.bPackageReportInstallFromAttribution(
                    bPackageResult: bPackagePendingInstallAttribution.bPackageResult,
                    bPackageAdID: bPackagePendingInstallAttribution.bPackageAdID
                )
                self.bPackagePendingInstallAttribution = nil
            }
            bPackageStartNetworkMonitoring()
        } catch {
            BPackageLogger.bPackageShared.bPackageLog("启动失败", "BPackage 配置无效：\(error.localizedDescription)")
        }
    }

    func bPackageDidRegisterForRemoteNotifications(bPackageDeviceToken: Data) {
        BPackageStorage.bPackageShared.bPackagePushToken = bPackageDeviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        BPackageLogger.bPackageShared.bPackageLog("推送", "APNs token 已获取并保存")
    }

    /// 必须从 AdjustDelegate.adjustAttributionChanged 回调中调用。
    /// 回调早于 BPackage 初始化时会暂存，初始化完成后再执行 Install 与 ...j。
    func bPackageAdjustAttributionChanged(bPackageResult: String?, bPackageAdID: String) {
        guard let bPackageCoordinator else {
            bPackagePendingInstallAttribution = (bPackageResult, bPackageAdID)
            BPackageLogger.bPackageShared.bPackageLog("Adjust", "归因回调早于 BPackage 初始化，已暂存 Install")
            return
        }
        bPackageCoordinator.bPackageEventReporter.bPackageReportInstallFromAttribution(
            bPackageResult: bPackageResult,
            bPackageAdID: bPackageAdID
        )
    }

    @discardableResult
    func bPackageHandleOpenURL(_ bPackageURL: URL) -> Bool {
        BPackageLogger.bPackageShared.bPackageLog("外部唤起", "已处理 Scheme：\(bPackageURL.scheme ?? "")")
        NotificationCenter.default.post(name: Self.bPackageOpenURLNotification, object: nil,
                                        userInfo: ["bPackageURL": bPackageURL.absoluteString])
        return true
    }

    private func bPackageApplyRoute(_ bPackageRoute: BPackageRoute) {
        bPackageStopNetworkMonitoring()
        bPackageRemoveLaunchCover()
        switch bPackageRoute {
        case .bPackageAPackage:
            BPackageLogger.bPackageShared.bPackageLog("完成", "进入 A 包")
            let bPackageCallback = bPackageOnAPackageRoute
            bPackageOnAPackageRoute = nil
            bPackageCallback?()
        case .bPackageLogin(let bPackageMode):
            bPackageOnAPackageRoute = nil
            bPackageShowQuickLogin(bPackageMode: bPackageMode)
        }
    }

    private func bPackageStartNetworkMonitoring() {
        guard bPackageNetworkMonitor == nil else { return }
        let bPackageMonitor = NWPathMonitor()
        bPackageMonitor.pathUpdateHandler = { [weak self] bPackagePath in
            let bPackageIsAvailable = bPackagePath.status == .satisfied
            Task { @MainActor [weak self] in
                self?.bPackageHandleNetworkAvailability(bPackageIsAvailable)
            }
        }
        bPackageNetworkMonitor = bPackageMonitor
        bPackageMonitor.start(queue: bPackageNetworkMonitorQueue)
        BPackageLogger.bPackageShared.bPackageLog("网络门禁", "开始监听网络；有网后才请求启动接口")
    }

    private func bPackageHandleNetworkAvailability(_ bPackageIsAvailable: Bool) {
        bPackageNetworkIsAvailable = bPackageIsAvailable
        if bPackageIsAvailable {
            BPackageLogger.bPackageShared.bPackageLog("网络门禁", "网络可用，准备请求启动接口")
            bPackageBeginInitialRequestIfNeeded()
        } else {
            bPackageRetryTask?.cancel()
            bPackageRetryTask = nil
            BPackageLogger.bPackageShared.bPackageLog("网络门禁", "网络不可用，保持启动等待页，不处理 A/B 路由")
        }
    }

    private func bPackageBeginInitialRequestIfNeeded() {
        guard bPackageNetworkIsAvailable,
              !bPackageDidBeginInitialRequest,
              let bPackageCoordinator else { return }
        bPackageDidBeginInitialRequest = true
        Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                let bPackageRoute = try await bPackageCoordinator.bPackageResolveInitialRoute()
                self.bPackageApplyRoute(bPackageRoute)
            } catch {
                self.bPackageDidBeginInitialRequest = false
                BPackageLogger.bPackageShared.bPackageLog(
                    "启动失败",
                    "\(error.localizedDescription)；不误判为 A 包，网络可用时稍后重试"
                )
                self.bPackageScheduleInitialRequestRetry()
            }
        }
    }

    private func bPackageScheduleInitialRequestRetry() {
        guard bPackageNetworkIsAvailable else { return }
        bPackageRetryTask?.cancel()
        bPackageRetryTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 5_000_000_000)
            guard !Task.isCancelled else { return }
            self?.bPackageBeginInitialRequestIfNeeded()
        }
    }

    private func bPackageStopNetworkMonitoring() {
        bPackageRetryTask?.cancel()
        bPackageRetryTask = nil
        bPackageNetworkMonitor?.cancel()
        bPackageNetworkMonitor = nil
        bPackageNetworkIsAvailable = false
    }

    private func bPackageShowQuickLogin(bPackageMode: BPackageLoginMode) {
        guard let bPackageCoordinator, let bPackageNavigationController else { return }
        guard !(bPackageNavigationController.topViewController is BPackageQuickLoginViewController) else {
            BPackageLogger.bPackageShared.bPackageLog("路由", "快速登录页已显示，忽略重复跳转")
            return
        }
        let bPackageLogin = BPackageQuickLoginViewController(bPackageCoordinator: bPackageCoordinator,
                                                             bPackageMode: bPackageMode,
                                                             bPackageBackgroundImage: bPackageAppearance.bPackageLoginBackgroundImage,
                                                             bPackageWebBackgroundImage: bPackageAppearance.bPackageWebBackgroundImage)
        var bPackageStack = bPackageNavigationController.viewControllers.filter {
            !($0 is BPackageQuickLoginViewController) && !($0 is BPackageWebViewController)
        }
        if bPackageStack.isEmpty, let bPackageAPackageViewController { bPackageStack = [bPackageAPackageViewController] }
        bPackageStack.append(bPackageLogin)
        bPackageNavigationController.setViewControllers(bPackageStack, animated: true)
    }

    private func bPackageShowLaunchCover() {
        guard bPackageLaunchCover == nil else { return }
        guard let bPackageContainer = bPackageNavigationController?.view else { return }
        let bPackageCover = UIView(frame: bPackageContainer.bounds)
        bPackageCover.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        bPackageCover.backgroundColor = .systemBackground
        if let bPackageImage = bPackageAppearance.bPackageLaunchBackgroundImage {
            let bPackageImageView = UIImageView(frame: bPackageCover.bounds)
            bPackageImageView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            bPackageImageView.contentMode = .scaleAspectFill
            bPackageImageView.image = bPackageImage
            bPackageCover.addSubview(bPackageImageView)
        }
        let bPackageSpinner = UIActivityIndicatorView(style: .large)
        bPackageSpinner.center = bPackageCover.center
        bPackageSpinner.autoresizingMask = [.flexibleLeftMargin, .flexibleRightMargin, .flexibleTopMargin, .flexibleBottomMargin]
        bPackageSpinner.startAnimating()
        bPackageCover.addSubview(bPackageSpinner)
        bPackageContainer.addSubview(bPackageCover)
        bPackageLaunchCover = bPackageCover
    }

    private func bPackageRemoveLaunchCover() {
        bPackageLaunchCover?.removeFromSuperview()
        bPackageLaunchCover = nil
    }
}
