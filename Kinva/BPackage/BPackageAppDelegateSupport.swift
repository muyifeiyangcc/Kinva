import UIKit

enum BPackageAppDelegateSupport {
    @MainActor
    static func bPackageDidRegisterForRemoteNotifications(bPackageDeviceToken: Data) {
        BPackage.bPackageShared.bPackageDidRegisterForRemoteNotifications(bPackageDeviceToken: bPackageDeviceToken)
    }
}

