import Foundation

enum BPackageLoginMode {
    case bPackageRequiresSignIn
    case bPackageAutomatic(URL)
}

enum BPackageRoute {
    case bPackageAPackage
    case bPackageLogin(BPackageLoginMode)
}

@MainActor
final class BPackageCoordinator {
    let bPackageAPI: BPackageAPIClient
    let bPackageEventReporter: BPackageEventReporter
    private let bPackageStorage = BPackageStorage.bPackageShared
    private let bPackageConfiguration: BPackageConfiguration
    private let bPackageAnalyticsAdapter: BPackageAnalyticsAdapter
    private var bPackageOpenValue: String?

    init(bPackageConfiguration: BPackageConfiguration,
         bPackageAnalyticsAdapter: BPackageAnalyticsAdapter) throws {
        self.bPackageConfiguration = bPackageConfiguration
        self.bPackageAnalyticsAdapter = bPackageAnalyticsAdapter
        bPackageAPI = try BPackageAPIClient(bPackageConfiguration: bPackageConfiguration)
        bPackageEventReporter = BPackageEventReporter(bPackageAPI: bPackageAPI,
                                                      bPackageAdapter: bPackageAnalyticsAdapter)
        (bPackageAnalyticsAdapter as? BPackageAttributionReporterBinding)?
            .bPackageBindEventReporter(bPackageEventReporter)
    }

    func bPackageResolveInitialRoute() async throws -> BPackageRoute {
        BPackageLogger.bPackageShared.bPackageLog("流程", "① 调用 3.2.2 App 启动接口")
        let bPackageResponse = try await bPackageAPI.bPackageOpen()
        guard bPackageResponse.bPackageCode == "0000" else {
            bPackageStorage.bPackageIsBPackage = false
            BPackageLogger.bPackageShared.bPackageLog("路由", "启动 code=\(bPackageResponse.bPackageCode)，直接进入 A 包")
            return .bPackageAPackage
        }
        guard let bPackageOpen = bPackageResponse.bPackageResult else {
            throw BPackageAPIError.bPackageMissingResult
        }
        bPackagePersistFacebookConfiguration(bPackageOpen)
        bPackageOpenValue = bPackageOpen.bPackageOpenValue
        BPackageLogger.bPackageShared.bPackageLog("启动", "loginFlag=\(bPackageOpen.bPackageLoginFlag.map(String.init) ?? "nil")，openValue 是否存在=\(!(bPackageOpen.bPackageOpenValue ?? "").isEmpty)")

        guard let bPackageDomain = bPackageOpen.bPackageOpenValue, !bPackageDomain.isEmpty else {
            bPackageStorage.bPackageIsBPackage = false
            BPackageLogger.bPackageShared.bPackageLog("路由", "code=0000 但 openValue 为空，安全回到 A 包")
            return .bPackageAPackage
        }
        if bPackageOpen.bPackageLoginFlag == 1, !bPackageStorage.bPackageLoginToken.isEmpty {
            let bPackageURL = try bPackageMakeH5URL(bPackageDomain: bPackageDomain,
                                                   bPackageToken: bPackageStorage.bPackageLoginToken)
            bPackageSaveBRoute(bPackageURL)
            BPackageLogger.bPackageShared.bPackageLog("路由", "loginFlag=1 且本地 token 非空，先显示 B 包登录页并自动加载 H5；不调用登录接口")
            return .bPackageLogin(.bPackageAutomatic(bPackageURL))
        }
        bPackageStorage.bPackageIsBPackage = true
        BPackageLogger.bPackageShared.bPackageLog("路由", "loginFlag=0 或本地 token 为空，进入 B 包快速登录页；此时不自动登录")
        return .bPackageLogin(.bPackageRequiresSignIn)
    }

    func bPackageLoginAndResolveH5() async throws -> URL {
        guard let bPackageDomain = bPackageOpenValue, !bPackageDomain.isEmpty else {
            throw BPackageAPIError.bPackageInvalidResponse
        }
        BPackageLogger.bPackageShared.bPackageLog("流程", "用户点击 Sign In，调用 3.2.3 App 登录接口")
        let bPackageAdjustAdID = await bPackageAnalyticsAdapter.bPackageResolveAdjustAdID()
        guard !bPackageAdjustAdID.isEmpty else { throw BPackageAPIError.bPackageMissingAdjustAdID }
        let bPackageLogin = try await bPackageAPI.bPackageLogin(bPackageAdjustAdID: bPackageAdjustAdID)
        guard let bPackageToken = bPackageLogin.bPackageToken, !bPackageToken.isEmpty else {
            throw BPackageAPIError.bPackageInvalidResponse
        }
        bPackageStorage.bPackageLoginToken = bPackageToken
        if let bPackagePassword = bPackageLogin.bPackagePassword, !bPackagePassword.isEmpty {
            bPackageStorage.bPackagePassword = bPackagePassword
            BPackageLogger.bPackageShared.bPackageLog("持久化", "登录响应 password 已完整保存到 Keychain；下次登录作为 d 参数传入")
        } else if bPackageStorage.bPackagePassword.isEmpty {
            BPackageLogger.bPackageShared.bPackageLog("协议警告", "首次登录没有返回 password，下一次登录无法按文档携带 password(d)")
        }
        let bPackageURL = try bPackageMakeH5URL(bPackageDomain: bPackageDomain, bPackageToken: bPackageToken)
        bPackageSaveBRoute(bPackageURL)
        return bPackageURL
    }

    func bPackageLogout() {
        bPackageStorage.bPackageLoginToken = ""
        BPackageLogger.bPackageShared.bPackageLog("退出登录", "已清除 token；保留 password，返回快速登录页")
    }

    private func bPackagePersistFacebookConfiguration(_ bPackageOpen: BPackageOpenResult) {
        var bPackageDidUpdate = false
        if let bPackageValue = bPackageOpen.bPackageFacebookAppID, !bPackageValue.isEmpty {
            bPackageStorage.bPackageFacebookAppID = bPackageValue
            bPackageDidUpdate = true
        }
        if let bPackageValue = bPackageOpen.bPackageFacebookClientToken, !bPackageValue.isEmpty {
            bPackageStorage.bPackageFacebookClientToken = bPackageValue
            bPackageDidUpdate = true
        }
        if let bPackageValue = bPackageOpen.bPackageFacebookDisplayName, !bPackageValue.isEmpty {
            bPackageStorage.bPackageFacebookDisplayName = bPackageValue
            bPackageDidUpdate = true
        }
        if bPackageDidUpdate {
            BPackageLogger.bPackageShared.bPackageLog("Facebook", "open 接口配置已覆盖持久化值，将在下次 SDK 初始化时使用")
        }
    }

    private func bPackageSaveBRoute(_ bPackageURL: URL) {
        bPackageStorage.bPackageIsBPackage = true
        bPackageStorage.bPackageH5URL = bPackageURL.absoluteString
        BPackageLogger.bPackageShared.bPackageLog("H5", "已生成加密 H5 地址")
    }

    private func bPackageMakeH5URL(bPackageDomain: String, bPackageToken: String) throws -> URL {
        let bPackageCrypto = try BPackageCrypto(bPackageKey: bPackageConfiguration.bPackageAESKey,
                                                bPackageIV: bPackageConfiguration.bPackageAESIV)
        let bPackageJSON = try JSONSerialization.data(withJSONObject: [
            "token": bPackageToken,
            "timestamp": Int(Date().timeIntervalSince1970 * 1000)
        ], options: [.sortedKeys])
        let bPackageEncrypted = try bPackageCrypto.bPackageEncrypt(String(decoding: bPackageJSON, as: UTF8.self))
        guard var bPackageComponents = URLComponents(string: bPackageDomain) else { throw BPackageAPIError.bPackageInvalidResponse }
        var bPackageItems = bPackageComponents.queryItems ?? []
        bPackageItems += [URLQueryItem(name: "openParams", value: bPackageEncrypted),
                          URLQueryItem(name: "appId", value: bPackageConfiguration.bPackageAppID)]
        bPackageComponents.queryItems = bPackageItems
        guard let bPackageURL = bPackageComponents.url else { throw BPackageAPIError.bPackageInvalidResponse }
        return bPackageURL
    }
}
