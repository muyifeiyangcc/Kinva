import UIKit

enum BPackageProfile {
    /// 秒级 Unix 时间戳。只有设备当前绝对时间大于该值时，才请求启动接口。
    static let bPackageOpenRequestCutoffTimestamp: TimeInterval = 1787126167

    static var bPackageShouldRequestInitialRoute: Bool {
        Date.now.timeIntervalSince1970 > bPackageOpenRequestCutoffTimestamp
    }

    static var bPackageConfiguration: BPackageConfiguration {
        var bPackageConfig = BPackageConfiguration()
        bPackageConfig.bPackageBaseURL = URL(string: "https://opi.ipcfhdx9.link/")
        bPackageConfig.bPackageAppID = "44332211"
        bPackageConfig.bPackageAESKey = "518486he8pzgbjsk"
        bPackageConfig.bPackageAESIV = "614436p28qzhkjsl"
        bPackageConfig.bPackageDebugFlag = 0
        bPackageConfig.bPackageExternalScheme = "kinva"
        return bPackageConfig
    }

    static var bPackageAppearance: BPackageAppearance {
        BPackageAppearance(
            bPackageLaunchBackgroundImage: UIImage(named: "lau"),
            bPackageLoginBackgroundImage: UIImage(named: "login_bg"),
            bPackageWebBackgroundImage: UIImage(named: "login_bg")
        )
    }
}
