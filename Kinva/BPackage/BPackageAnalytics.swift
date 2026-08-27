import Foundation

/// A 包已有 Adjust/Facebook SDK 时实现此协议并注入，避免重复初始化 SDK。
protocol BPackageAnalyticsAdapter: AnyObject {
    var bPackageAdjustAdID: String { get }
    var bPackageAttributionResult: String { get }
    func bPackageResolveAdjustAdID() async -> String
    func bPackageTrackAdjustEvent(_ bPackageType: BPackageEventType,
                                  bPackageAmount: Decimal?,
                                  bPackageCurrency: String?)
    func bPackageTrackFacebookPurchase(bPackageAmount: Decimal, bPackageCurrency: String)
}

/// Demo 与正式 BPackage 启动路径共用，用于把 Adjust 归因回调绑定到当前 ...j 上报器。
protocol BPackageAttributionReporterBinding: AnyObject {
    func bPackageBindEventReporter(_ bPackageReporter: BPackageEventReporter)
}

final class BPackageNoopAnalyticsAdapter: BPackageAnalyticsAdapter {
    var bPackageAdjustAdID: String { "" }
    var bPackageAttributionResult: String { "" }
    func bPackageResolveAdjustAdID() async -> String { "" }
    func bPackageTrackAdjustEvent(_ bPackageType: BPackageEventType,
                                  bPackageAmount: Decimal?,
                                  bPackageCurrency: String?) {
        BPackageLogger.bPackageShared.bPackageLog("Analytics", "未注入 Adjust SDK Adapter；已保留后端 ...j 上报，事件=\(bPackageType.rawValue)")
    }
    func bPackageTrackFacebookPurchase(bPackageAmount: Decimal, bPackageCurrency: String) {
        BPackageLogger.bPackageShared.bPackageLog("Facebook", "未注入 Facebook SDK Adapter；Purchase 本地埋点未执行")
    }
}

final class BPackageEventReporter {
    private let bPackageAPI: BPackageAPIClient
    private weak var bPackageAdapter: BPackageAnalyticsAdapter?
    // 使用新版本 Key，避免旧 Demo 曾在普通启动流程写入的标记阻止归因回调。
    private let bPackageInstallKey = "bPackage.adjust.installAttributionReported.v2"

    init(bPackageAPI: BPackageAPIClient, bPackageAdapter: BPackageAnalyticsAdapter) {
        self.bPackageAPI = bPackageAPI
        self.bPackageAdapter = bPackageAdapter
    }

    /// 只能由 AppDelegate 的 adjustAttributionChanged 回调触发，不能由普通启动流程触发。
    func bPackageReportInstallFromAttribution(bPackageResult: String?, bPackageAdID: String) {
        guard !UserDefaults.standard.bool(forKey: bPackageInstallKey) else { return }
        let bPackageNormalizedResult = bPackageResult?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        bPackageAdapter?.bPackageTrackAdjustEvent(.bPackageInstall,
                                                  bPackageAmount: nil,
                                                  bPackageCurrency: nil)
        bPackageSendAdjust(bPackageType: .bPackageInstall,
                           bPackageResult: bPackageNormalizedResult,
                           bPackageAdID: bPackageAdID)
    }

    func bPackageReport(_ bPackageType: BPackageEventType,
                        bPackageAmount: Decimal? = nil,
                        bPackageCurrency: String? = nil) {
        let bPackageAdID = bPackageAdapter?.bPackageAdjustAdID ?? ""
        let bPackageResult = bPackageAdapter?.bPackageAttributionResult.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        bPackageAdapter?.bPackageTrackAdjustEvent(bPackageType,
                                                  bPackageAmount: bPackageAmount,
                                                  bPackageCurrency: bPackageCurrency)
        bPackageSendAdjust(bPackageType: bPackageType,
                           bPackageResult: bPackageResult,
                           bPackageAdID: bPackageAdID)
    }

    private func bPackageSendAdjust(bPackageType: BPackageEventType,
                                    bPackageResult: String,
                                    bPackageAdID: String) {
        let bPackageDescription = bPackageType == .bPackageInitiateCheckout
            ? "只调用后端 ...j，不发送 Adjust SDK"
            : "发送 Adjust SDK，并异步调用后端 ...j"
        BPackageLogger.bPackageShared.bPackageLog("Adjust", "事件 \(bPackageType.rawValue)：\(bPackageDescription)")
        Task { [weak bPackageAdapter] in
            let bPackageResolvedAdID: String
            if bPackageAdID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                bPackageResolvedAdID = await bPackageAdapter?.bPackageResolveAdjustAdID() ?? ""
            } else {
                bPackageResolvedAdID = bPackageAdID
            }
            guard !bPackageResolvedAdID.isEmpty else {
                BPackageLogger.bPackageShared.bPackageLog(
                    "Adjust上报失败",
                    "事件=\(bPackageType.rawValue)，无法取得 Adjust ADID，未发送后端 ...j"
                )
                return
            }
            do {
                try await bPackageAPI.bPackageReportAdjust(bPackageResult: bPackageResult,
                                                           bPackageType: bPackageType,
                                                           bPackageAdID: bPackageResolvedAdID)
                if bPackageType == .bPackageInstall {
                    UserDefaults.standard.set(true, forKey: bPackageInstallKey)
                }
            } catch {
                BPackageLogger.bPackageShared.bPackageLog("Adjust上报失败", "事件=\(bPackageType.rawValue)，\(error.localizedDescription)；不阻塞主流程")
            }
        }
    }

    func bPackageReportPurchase(bPackageAmount: Decimal, bPackageCurrency: String) {
        bPackageReport(.bPackagePurchase,
                       bPackageAmount: bPackageAmount,
                       bPackageCurrency: bPackageCurrency)
        bPackageAdapter?.bPackageTrackFacebookPurchase(bPackageAmount: bPackageAmount,
                                                       bPackageCurrency: bPackageCurrency)
    }
}
