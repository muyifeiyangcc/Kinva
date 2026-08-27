//
//  AppDelegate.swift
//  Kinva
//
//  Created by myx mac on 2026/7/31.
//

import UIKit
#if canImport(IQKeyboardManagerSwift)
import IQKeyboardManagerSwift
#endif
#if canImport(AdjustSdk)
import AdjustSdk
#endif
import FBSDKCoreKit
import UserNotifications

@main
class AppDelegate: UIResponder, UIApplicationDelegate, AdjustDelegate {



    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        #if canImport(IQKeyboardManagerSwift)
        IQKeyboardManager.shared.isEnabled = true
        IQKeyboardManager.shared.resignOnTouchOutside = true
        #endif
        ConsumablePurchaseManager.shared.start()
        // MARK: - BPackage Facebook
        APackageBAnalyticsAdapter.bPackageShared.bPackageInitializeFacebook(
            bPackageApplication: application,
            bPackageLaunchOptions: launchOptions
        )

        // MARK: - BPackage Adjust
        let bPackageAppID = BPackageProfile.bPackageConfiguration.bPackageAppID
        let bPackageDeviceID = BPackageStorage.bPackageShared.bPackageStableDeviceID(bPackageAppID: bPackageAppID)
        #if canImport(AdjustSdk)
        Adjust.addGlobalCallbackParameter(bPackageDeviceID, forKey: "ta_distinct_id")
        if let bPackageAdjustConfig = ADJConfig(
            appToken: BPackageThirdPartyProfile.bPackageAdjustAppToken,
            environment: ADJEnvironmentSandbox
        ) {
            bPackageAdjustConfig.delegate = self
            bPackageAdjustConfig.enableSendingInBackground()
            bPackageAdjustConfig.enableCostDataInAttribution()
            Adjust.initSdk(bPackageAdjustConfig)
            Task { _ = await APackageBAnalyticsAdapter.bPackageShared.bPackageResolveAdjustAdID() }
        }
        #endif
        UNUserNotificationCenter.current().delegate = self
        StoreKit1PurchaseManager.bPackageShared.bPackageStartObserving()
        return true
    }

    func adjustAttributionChanged(_ attribution: ADJAttribution?) {
        #if canImport(AdjustSdk)
        Adjust.adid { bPackageAdID in
            Task { @MainActor in
                let bPackageNormalizedAdID = (bPackageAdID ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                APackageBAnalyticsAdapter.bPackageShared.bPackageUpdateAttribution(
                    bPackageAttribution: attribution,
                    bPackageAdID: bPackageNormalizedAdID
                )
                BPackage.bPackageShared.bPackageAdjustAttributionChanged(
                    bPackageResult: APackageBAnalyticsAdapter.bPackageShared.bPackageAttributionResult,
                    bPackageAdID: bPackageNormalizedAdID
                )
            }
        }
        #endif
    }

    func application(_ application: UIApplication,
                     didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        BPackageAppDelegateSupport.bPackageDidRegisterForRemoteNotifications(
            bPackageDeviceToken: deviceToken
        )
    }

    func application(_ application: UIApplication,
                     didFailToRegisterForRemoteNotificationsWithError error: Error) {
        BPackageLogger.bPackageShared.bPackageLog("推送", "APNs 注册失败：\(error.localizedDescription)")
    }

    // MARK: UISceneSession Lifecycle

    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        // Called when a new scene session is being created.
        // Use this method to select a configuration to create the new scene with.
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }

    func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {
        // Called when the user discards a scene session.
        // If any sessions were discarded while the application was not running, this will be called shortly after application:didFinishLaunchingWithOptions.
        // Use this method to release any resources that were specific to the discarded scenes, as they will not return.
    }

    func applicationWillTerminate(_ application: UIApplication) {
        ConsumablePurchaseManager.shared.stop()
        StoreKit1PurchaseManager.bPackageShared.bPackageStopObserving()
    }


}

extension AppDelegate: UNUserNotificationCenterDelegate {
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound, .badge])
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        completionHandler()
    }
}
