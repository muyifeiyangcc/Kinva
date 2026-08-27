import Foundation

enum BPackageAPIError: LocalizedError {
    case bPackageMissingBaseURL
    case bPackageInvalidResponse
    case bPackageHTTP(Int, String)
    case bPackageBusiness(String, String?)
    case bPackageMissingResult
    case bPackageMissingAdjustAdID

    var errorDescription: String? {
        switch self {
        case .bPackageMissingBaseURL: return "尚未配置测试接口地址"
        case .bPackageInvalidResponse: return "服务端响应格式无效"
        case .bPackageHTTP(let bPackageCode, let bPackageBody): return "HTTP \(bPackageCode)：\(bPackageBody)"
        case .bPackageBusiness(let bPackageCode, let bPackageMessage): return "业务失败 \(bPackageCode)：\(bPackageMessage ?? "")"
        case .bPackageMissingResult: return "响应缺少 result/data"
        case .bPackageMissingAdjustAdID: return "暂时无法获取 Adjust ID，请稍后重试"
        }
    }
}

final class BPackageAPIClient {
    let bPackageConfiguration: BPackageConfiguration
    private let bPackageSession: URLSession
    private let bPackageStorage: BPackageStorage
    private let bPackageCrypto: BPackageCrypto

    init(bPackageConfiguration: BPackageConfiguration,
         bPackageSession: URLSession = .shared,
         bPackageStorage: BPackageStorage = .bPackageShared) throws {
        try bPackageConfiguration.bPackageValidate()
        self.bPackageConfiguration = bPackageConfiguration
        self.bPackageSession = bPackageSession
        self.bPackageStorage = bPackageStorage
        bPackageCrypto = try BPackageCrypto(bPackageKey: bPackageConfiguration.bPackageAESKey,
                                             bPackageIV: bPackageConfiguration.bPackageAESIV)
    }

    /// 3.2.2：该接口的非 0000 不是网络异常，而是明确进入 A 包的路由结果。
    func bPackageOpen() async throws -> BPackageOpenResponse {
        let bPackageFields = bPackageConfiguration.bPackageFields
        let bPackageBody: [String: Any] = [
            bPackageFields.bPackageUseSimCard: 1,
            bPackageFields.bPackageDebug: bPackageConfiguration.bPackageDebugFlag
        ]
        BPackageLogger.bPackageShared.bPackageLog("启动参数", "仅发送 \(bPackageFields.bPackageUseSimCard)=1、\(bPackageFields.bPackageDebug)=\(bPackageConfiguration.bPackageDebugFlag)")
        let bPackageEnvelope = try await bPackageRequestEnvelope(
            bPackagePath: bPackageConfiguration.bPackageOpenPath,
            bPackageBody: bPackageBody
        )
        guard bPackageEnvelope.bPackageCode == "0000" else {
            return BPackageOpenResponse(bPackageCode: bPackageEnvelope.bPackageCode,
                                        bPackageMessage: bPackageEnvelope.bPackageMessage,
                                        bPackageResult: nil)
        }
        let bPackageResult = try bPackageDecodePayload(bPackageEnvelope.bPackagePayload, bPackageType: BPackageOpenResult.self)
        return BPackageOpenResponse(bPackageCode: bPackageEnvelope.bPackageCode,
                                    bPackageMessage: bPackageEnvelope.bPackageMessage,
                                    bPackageResult: bPackageResult)
    }

    func bPackageLogin(bPackageAdjustAdID: String = "") async throws -> BPackageLoginResult {
        let bPackageFields = bPackageConfiguration.bPackageFields
        let bPackageSavedPassword = bPackageStorage.bPackagePassword
        let bPackageNormalizedAdjustAdID = bPackageAdjustAdID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !bPackageNormalizedAdjustAdID.isEmpty else { throw BPackageAPIError.bPackageMissingAdjustAdID }
        var bPackageBody: [String: Any] = [
            bPackageFields.bPackageAdjustAdid: bPackageNormalizedAdjustAdID,
            bPackageFields.bPackageDeviceNo: bPackageStorage.bPackageStableDeviceID(bPackageAppID: bPackageConfiguration.bPackageAppID)
        ]
        if !bPackageSavedPassword.isEmpty { bPackageBody[bPackageFields.bPackagePassword] = bPackageSavedPassword }
        BPackageLogger.bPackageShared.bPackageLog("登录参数", bPackageSavedPassword.isEmpty
            ? "首次登录：不发送 password；只发送 AdjustAdid(a)、deviceNo(n)"
            : "再次登录：发送 Keychain 保存的 password(d)、AdjustAdid(a)、deviceNo(n)")
        return try await bPackageSend(
            bPackagePath: bPackageConfiguration.bPackageLoginPath,
            bPackageBody: bPackageBody,
            bPackageType: BPackageLoginResult.self
        )
    }

    func bPackageVerifyPayment(bPackageTransactionID: String,
                               bPackageReceipt: String,
                               bPackageCallbackResult: String) async throws {
        let bPackageFields = bPackageConfiguration.bPackageFields
        try await bPackageSendAcknowledgement(bPackagePath: bPackageConfiguration.bPackagePaymentPath, bPackageBody: [
            bPackageFields.bPackageTransactionID: bPackageTransactionID,
            bPackageFields.bPackageReceipt: bPackageReceipt,
            bPackageFields.bPackageCallbackResult: bPackageCallbackResult
        ])
    }

    func bPackageReportAdjust(bPackageResult: String,
                              bPackageType: BPackageEventType,
                              bPackageAdID: String) async throws {
        let bPackageFields = bPackageConfiguration.bPackageFields
        let bPackageNormalizedAdjustAdID = bPackageAdID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !bPackageNormalizedAdjustAdID.isEmpty else { throw BPackageAPIError.bPackageMissingAdjustAdID }
        try await bPackageSendAcknowledgement(bPackagePath: bPackageConfiguration.bPackageAdjustPath, bPackageBody: [
            bPackageFields.bPackageAdjustResult: bPackageResult,
            bPackageFields.bPackageEventType: bPackageType.rawValue,
            bPackageFields.bPackageEventDeviceID: bPackageStorage.bPackageStableDeviceID(bPackageAppID: bPackageConfiguration.bPackageAppID),
            bPackageFields.bPackageEventAdid: bPackageNormalizedAdjustAdID
        ])
    }

    private struct BPackageRawEnvelope {
        let bPackageCode: String
        let bPackageMessage: String?
        let bPackagePayload: Any?
    }

    private func bPackageSend<T: Decodable>(bPackagePath: String,
                                             bPackageBody: [String: Any],
                                             bPackageType: T.Type) async throws -> T {
        let bPackageEnvelope = try await bPackageRequestEnvelope(bPackagePath: bPackagePath, bPackageBody: bPackageBody)
        guard bPackageEnvelope.bPackageCode == "0000" else {
            throw BPackageAPIError.bPackageBusiness(bPackageEnvelope.bPackageCode, bPackageEnvelope.bPackageMessage)
        }
        return try bPackageDecodePayload(bPackageEnvelope.bPackagePayload, bPackageType: bPackageType)
    }

    private func bPackageSendAcknowledgement(bPackagePath: String, bPackageBody: [String: Any]) async throws {
        let bPackageEnvelope = try await bPackageRequestEnvelope(bPackagePath: bPackagePath, bPackageBody: bPackageBody)
        guard bPackageEnvelope.bPackageCode == "0000" else {
            throw BPackageAPIError.bPackageBusiness(bPackageEnvelope.bPackageCode, bPackageEnvelope.bPackageMessage)
        }
    }

    private func bPackageRequestEnvelope(bPackagePath: String,
                                         bPackageBody: [String: Any]) async throws -> BPackageRawEnvelope {
        guard let bPackageBaseURL = bPackageConfiguration.bPackageBaseURL else { throw BPackageAPIError.bPackageMissingBaseURL }
        guard let bPackageURL = URL(string: bPackagePath, relativeTo: bPackageBaseURL)?.absoluteURL else {
            throw BPackageAPIError.bPackageInvalidResponse
        }
        let bPackageJSON = try JSONSerialization.data(withJSONObject: bPackageBody, options: [.sortedKeys])
        let bPackageClearRequest = String(decoding: bPackageJSON, as: UTF8.self)
        let bPackageEncrypted = try bPackageCrypto.bPackageEncrypt(bPackageClearRequest)
        var bPackageRequest = URLRequest(url: bPackageURL)
        bPackageRequest.httpMethod = "POST"
        bPackageRequest.httpBody = Data(bPackageEncrypted.utf8)
        let bPackageRequestHeaders = bPackageHeaders()
        bPackageRequestHeaders.forEach { bPackageRequest.setValue($1, forHTTPHeaderField: $0) }
        bPackageLogRequest(
            bPackageURL: bPackageURL,
            bPackagePath: bPackagePath,
            bPackageHeaders: bPackageRequestHeaders,
            bPackageClear: bPackageClearRequest,
            bPackageEncrypted: bPackageEncrypted,
            bPackageBodyKeys: bPackageBody.keys.sorted()
        )
        let bPackageStarted = Date()
        let (bPackageData, bPackageResponse) = try await bPackageSession.data(for: bPackageRequest)
        guard let bPackageHTTP = bPackageResponse as? HTTPURLResponse else { throw BPackageAPIError.bPackageInvalidResponse }
        let bPackageRaw = String(decoding: bPackageData, as: UTF8.self)
        bPackageLogHTTPResponse(
            bPackageElapsedMilliseconds: Int(Date().timeIntervalSince(bPackageStarted) * 1000),
            bPackageStatusCode: bPackageHTTP.statusCode,
            bPackageRaw: bPackageRaw
        )
        guard 200..<300 ~= bPackageHTTP.statusCode else {
            throw BPackageAPIError.bPackageHTTP(bPackageHTTP.statusCode, bPackageRaw)
        }
        guard let bPackageObject = try JSONSerialization.jsonObject(with: bPackageData) as? [String: Any] else {
            throw BPackageAPIError.bPackageInvalidResponse
        }
        let bPackageCode: String
        if let bPackageText = bPackageObject["code"] as? String { bPackageCode = bPackageText }
        else if let bPackageNumber = bPackageObject["code"] as? NSNumber { bPackageCode = String(format: "%04d", bPackageNumber.intValue) }
        else { bPackageCode = "" }
        return BPackageRawEnvelope(bPackageCode: bPackageCode,
                                   bPackageMessage: bPackageObject["message"] as? String,
                                   bPackagePayload: bPackageObject["result"] ?? bPackageObject["data"])
    }

    private func bPackageDecodePayload<T: Decodable>(_ bPackagePayload: Any?, bPackageType: T.Type) throws -> T {
        guard let bPackagePayload else { throw BPackageAPIError.bPackageMissingResult }
        let bPackageData: Data
        if let bPackageCipher = bPackagePayload as? String {
            let bPackageClear = try bPackageCrypto.bPackageDecrypt(bPackageCipher)
            bPackageLogDebugPayload(
                bPackageCategory: "AES",
                bPackageMessage: "解密响应：\(bPackageClear)"
            )
            bPackageData = Data(bPackageClear.utf8)
        } else if JSONSerialization.isValidJSONObject(bPackagePayload) {
            bPackageData = try JSONSerialization.data(withJSONObject: bPackagePayload, options: [.sortedKeys])
            bPackageLogDebugPayload(
                bPackageCategory: "响应明文",
                bPackageMessage: "服务端直接返回：\(String(decoding: bPackageData, as: UTF8.self))"
            )
            BPackageLogger.bPackageShared.bPackageLog("响应", "服务端直接返回 JSON 对象（兼容文档示例）")
        } else {
            throw BPackageAPIError.bPackageInvalidResponse
        }
        return try JSONDecoder().decode(bPackageType, from: bPackageData)
    }

    private func bPackageLogRequest(bPackageURL: URL,
                                    bPackagePath: String,
                                    bPackageHeaders: [String: String],
                                    bPackageClear: String,
                                    bPackageEncrypted: String,
                                    bPackageBodyKeys: [String]) {
        #if DEBUG
        BPackageLogger.bPackageShared.bPackageLog(
            "请求",
            "POST \(bPackageURL.absoluteString)\n路径规则：\(bPackagePath)\nHeaders：\(bPackageHeaders)\n加密前：\(bPackageClear)\n加密后 Hex：\(bPackageEncrypted)"
        )
        #else
        BPackageLogger.bPackageShared.bPackageLog(
            "请求",
            "POST \(bPackageURL.absoluteString)，路径规则：\(bPackagePath)，业务字段：\(bPackageBodyKeys.joined(separator: ","))"
        )
        #endif
    }

    private func bPackageLogHTTPResponse(bPackageElapsedMilliseconds: Int,
                                         bPackageStatusCode: Int,
                                         bPackageRaw: String) {
        #if DEBUG
        BPackageLogger.bPackageShared.bPackageLog(
            "HTTP",
            "耗时 \(bPackageElapsedMilliseconds)ms，状态 \(bPackageStatusCode)，原始响应：\(bPackageRaw)"
        )
        #else
        BPackageLogger.bPackageShared.bPackageLog(
            "HTTP",
            "耗时 \(bPackageElapsedMilliseconds)ms，状态 \(bPackageStatusCode)"
        )
        #endif
    }

    private func bPackageLogDebugPayload(bPackageCategory: String,
                                         bPackageMessage: String) {
        #if DEBUG
        BPackageLogger.bPackageShared.bPackageLog(
            bPackageCategory,
            bPackageMessage
        )
        #endif
    }

    private func bPackageHeaders() -> [String: String] {
        [MARKER("Content-Type"): "application/json",
         MARKER("appVersion"): bPackageConfiguration.bPackageAppVersion,
         MARKER("deviceNo"): bPackageStorage.bPackageStableDeviceID(bPackageAppID: bPackageConfiguration.bPackageAppID),
         MARKER("pushToken"): bPackageStorage.bPackagePushToken,
         MARKER("loginToken"): bPackageStorage.bPackageLoginToken,
         MARKER("appId"): bPackageConfiguration.bPackageAppID]
    }
}
