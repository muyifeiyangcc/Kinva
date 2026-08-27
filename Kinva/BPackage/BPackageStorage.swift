import Foundation
import Security
import UIKit

final class BPackageStorage {
    static let bPackageShared = BPackageStorage()
    private init() {}

    private enum BPackageSecureKey: String {
        case bPackageDeviceID = "devid"
        case bPackageLoginToken = "token"
        case bPackagePassword = "password"
    }

    var bPackageDeviceID: String { get { bPackageRead(.bPackageDeviceID) ?? "" } set { bPackageSave(newValue, bPackageKey: .bPackageDeviceID) } }
    var bPackageLoginToken: String { get { bPackageRead(.bPackageLoginToken) ?? "" } set { bPackageSave(newValue, bPackageKey: .bPackageLoginToken) } }
    var bPackagePassword: String { get { bPackageRead(.bPackagePassword) ?? "" } set { bPackageSave(newValue, bPackageKey: .bPackagePassword) } }
    var bPackageIsBPackage: Bool { get { UserDefaults.standard.bool(forKey: "bPackage.isBPackage") } set { UserDefaults.standard.set(newValue, forKey: "bPackage.isBPackage") } }
    var bPackagePushToken: String { get { UserDefaults.standard.string(forKey: "bPackage.pushToken") ?? "" } set { UserDefaults.standard.set(newValue, forKey: "bPackage.pushToken") } }
    var bPackageH5URL: String { get { UserDefaults.standard.string(forKey: "bPackage.h5URL") ?? "" } set { UserDefaults.standard.set(newValue, forKey: "bPackage.h5URL") } }
    var bPackageAdjustAdID: String { get { UserDefaults.standard.string(forKey: "bPackage.adjustAdID.v1") ?? "" } set { UserDefaults.standard.set(newValue, forKey: "bPackage.adjustAdID.v1") } }
    var bPackageFacebookAppID: String { get { UserDefaults.standard.string(forKey: "bPackage.facebookAppID") ?? "" } set { UserDefaults.standard.set(newValue, forKey: "bPackage.facebookAppID") } }
    var bPackageFacebookClientToken: String { get { UserDefaults.standard.string(forKey: "bPackage.facebookClientToken") ?? "" } set { UserDefaults.standard.set(newValue, forKey: "bPackage.facebookClientToken") } }
    var bPackageFacebookDisplayName: String { get { UserDefaults.standard.string(forKey: "bPackage.facebookDisplayName") ?? "" } set { UserDefaults.standard.set(newValue, forKey: "bPackage.facebookDisplayName") } }

    func bPackageStableDeviceID(bPackageAppID: String) -> String {
        if !bPackageDeviceID.isEmpty { return bPackageDeviceID }
        let bPackageGeneratedDeviceID =
            (UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString) + bPackageAppID
        bPackageDeviceID = bPackageGeneratedDeviceID
        return bPackageGeneratedDeviceID
    }

    private func bPackageQuery(_ bPackageKey: BPackageSecureKey) -> [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: (Bundle.main.bundleIdentifier ??  "a") + ".bpackage",
         kSecAttrAccount as String: bPackageKey.rawValue]
    }

    private func bPackageSave(_ bPackageValue: String, bPackageKey: BPackageSecureKey) {
        var bPackageQueryValue = bPackageQuery(bPackageKey)
        SecItemDelete(bPackageQueryValue as CFDictionary)
        bPackageQueryValue[kSecValueData as String] = Data(bPackageValue.utf8)
        bPackageQueryValue[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        let bPackageStatus = SecItemAdd(bPackageQueryValue as CFDictionary, nil)
        if bPackageStatus != errSecSuccess { BPackageLogger.bPackageShared.bPackageLog("Keychain", "写入失败 status=\(bPackageStatus)") }
    }

    private func bPackageRead(_ bPackageKey: BPackageSecureKey) -> String? {
        var bPackageQueryValue = bPackageQuery(bPackageKey)
        bPackageQueryValue[kSecReturnData as String] = true
        bPackageQueryValue[kSecMatchLimit as String] = kSecMatchLimitOne
        var bPackageResult: AnyObject?
        guard SecItemCopyMatching(bPackageQueryValue as CFDictionary, &bPackageResult) == errSecSuccess,
              let bPackageData = bPackageResult as? Data else { return nil }
        return String(data: bPackageData, encoding: .utf8)
    }
}
