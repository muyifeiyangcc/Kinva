import Foundation

struct BPackageFlexibleInt: Decodable {
    let bPackageValue: Int

    init(from decoder: Decoder) throws {
        let bPackageContainer = try decoder.singleValueContainer()
        if let bPackageInteger = try? bPackageContainer.decode(Int.self) {
            bPackageValue = bPackageInteger
        } else if let bPackageText = try? bPackageContainer.decode(String.self), let bPackageInteger = Int(bPackageText) {
            bPackageValue = bPackageInteger
        } else {
            throw DecodingError.dataCorruptedError(in: bPackageContainer, debugDescription: "需要整数或整数字符串")
        }
    }
}

struct BPackageOpenResult: Decodable {
    let bPackageOpenValue: String?
    let bPackageLoginFlag: Int?
    let bPackageFacebookAppID: String?
    let bPackageFacebookClientToken: String?
    let bPackageFacebookDisplayName: String?

    private enum CodingKeys: String, CodingKey {
        case bPackageOpenValue = "openValue"
        case bPackageLoginFlag = "loginFlag"
        case bPackageFacebookAppID = "facebookAppId"
        case bPackageFacebookClientToken = "clientToken"
        case bPackageFacebookDisplayName = "displayName"
    }

    init(from decoder: Decoder) throws {
        let bPackageContainer = try decoder.container(keyedBy: CodingKeys.self)
        bPackageOpenValue = try? bPackageContainer.decode(String.self, forKey: .bPackageOpenValue)
        bPackageLoginFlag = (try? bPackageContainer.decode(BPackageFlexibleInt.self, forKey: .bPackageLoginFlag))?.bPackageValue
        bPackageFacebookAppID = try? bPackageContainer.decode(String.self, forKey: .bPackageFacebookAppID)
        bPackageFacebookClientToken = try? bPackageContainer.decode(String.self, forKey: .bPackageFacebookClientToken)
        bPackageFacebookDisplayName = try? bPackageContainer.decode(String.self, forKey: .bPackageFacebookDisplayName)
    }
}

struct BPackageLoginResult: Decodable {
    let bPackageToken: String?
    let bPackagePassword: String?

    private enum CodingKeys: String, CodingKey { case bPackageToken = "token", bPackagePassword = "password" }
}

struct BPackageOpenResponse {
    let bPackageCode: String
    let bPackageMessage: String?
    let bPackageResult: BPackageOpenResult?
}

enum BPackageEventType: String {
    case bPackageInstall = "Install"
    case bPackageInitiateCheckout = "InitiateCheckout"
    case bPackagePurchase = "Purchase"
}

