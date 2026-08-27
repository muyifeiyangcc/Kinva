import Foundation

/// 服务端允许字段名称变化，但每个字段名称最后一个字符必须满足文档约定。
struct BPackageFieldProfile {
    var bPackageUseSimCard = MARKER("useSimCardd")
    var bPackageDebug = MARKER("debugg")
    var bPackageAdjustAdid = MARKER("adjustIDa")
    var bPackagePassword = MARKER("savedPasswordd")
    var bPackageDeviceNo = MARKER("deviceNumbern")
    var bPackageTransactionID = MARKER("transactionIDt")
    var bPackageReceipt = MARKER("receiptPayloadp")
    var bPackageCallbackResult = MARKER("callbackResultc")
    var bPackageAdjustResult = MARKER("attributionResultt")
    var bPackageEventType = MARKER("eventTypee")
    var bPackageEventDeviceID = MARKER("deviceIDd")
    var bPackageEventAdid = MARKER("adjustIDa")

    func bPackageValidate() throws {
        let bPackageRules: [(String, String, Character)] = [
            ("启动-useSimCard", bPackageUseSimCard, "d"), ("启动-debug", bPackageDebug, "g"),
            ("登录-AdjustAdid", bPackageAdjustAdid, "a"), ("登录-password", bPackagePassword, "d"),
            ("登录-deviceNo", bPackageDeviceNo, "n"), ("验单-transactionID", bPackageTransactionID, "t"),
            ("验单-receipt", bPackageReceipt, "p"), ("验单-callbackResult", bPackageCallbackResult, "c"),
            ("Adjust-result", bPackageAdjustResult, "t"), ("Adjust-eventType", bPackageEventType, "e"),
            ("Adjust-deviceId", bPackageEventDeviceID, "d"), ("Adjust-adid", bPackageEventAdid, "a")
        ]
//        for (bPackageName, bPackageValue, bPackageSuffix) in bPackageRules where bPackageValue.last != bPackageSuffix {
//            throw BPackageConfigurationError.bPackageInvalidField("\(bPackageName) 字段必须以 \(bPackageSuffix) 结尾，当前为 \(bPackageValue)")
//        }
    }
}

enum BPackageConfigurationError: LocalizedError {
    case bPackageInvalidPath(String)
    case bPackageInvalidField(String)

    var errorDescription: String? {
        switch self {
        case .bPackageInvalidPath(let bPackageMessage), .bPackageInvalidField(let bPackageMessage): return bPackageMessage
        }
    }
}

struct BPackageConfiguration {
    /// Demo 页面输入；迁移到 A 包时直接填正式接口根地址。
    var bPackageBaseURL: URL? = nil
    var bPackageAppID = "44332211"
    var bPackageAppVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    var bPackageAESKey = "518486he8pzgbjsk"
    var bPackageAESIV = "614436p28qzhkjsl"
    var bPackageDebugFlag = 0

    
    var bPackageOpenPath = "/opi/v1/mobile_open_o"
    var bPackageLoginPath = "/opi/v1/mobile_login_l"
    var bPackagePaymentPath = "/opi/v1/payment_check_p"
    var bPackageAdjustPath = "/opi/v1/adjust_event_j"
    
    
    
    var bPackageFields = BPackageFieldProfile()
    var bPackageExternalScheme: String? = MARKER("kinva")

    static var bPackageTesting = BPackageConfiguration()

    func bPackageValidate() throws {
        guard let bPackageBaseURL,
              bPackageBaseURL.scheme?.lowercased() == "https",
              bPackageBaseURL.host?.isEmpty == false else {
            throw BPackageConfigurationError.bPackageInvalidField("BPackage Base URL 必须是完整 HTTPS 地址")
        }
        guard !bPackageAppID.isEmpty else {
            throw BPackageConfigurationError.bPackageInvalidField("BPackage appId 不能为空")
        }
        guard bPackageAESKey.utf8.count == 16, bPackageAESIV.utf8.count == 16 else {
            throw BPackageConfigurationError.bPackageInvalidField("AES Key/IV 必须各为 16 个 UTF-8 字节")
        }
        if let bPackageExternalScheme {
            guard !bPackageExternalScheme.isEmpty,
                  bPackageExternalScheme == bPackageExternalScheme.lowercased() else {
                throw BPackageConfigurationError.bPackageInvalidField("BPackage Scheme 必须为非空小写值")
            }
        }
        let bPackagePaths: [(String, String, Character)] = [
            ("启动", bPackageOpenPath, "o"), ("登录", bPackageLoginPath, "l"),
            ("验单", bPackagePaymentPath, "p"), ("Adjust", bPackageAdjustPath, "j")
        ]
        for (bPackageName, bPackagePath, bPackageSuffix) in bPackagePaths where bPackagePath.last != bPackageSuffix {
            throw BPackageConfigurationError.bPackageInvalidPath("\(bPackageName)接口路径必须以 \(bPackageSuffix) 结尾：\(bPackagePath)")
        }
        try bPackageFields.bPackageValidate()
    }
}
