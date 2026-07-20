import Flutter
import TikTokBusinessSDK
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    #if !targetEnvironment(simulator)
      configureTikTokAppEvents()
    #endif
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  override func applicationDidBecomeActive(_ application: UIApplication) {
    super.applicationDidBecomeActive(application)
    NSLog("KapiNote TikTok: applicationDidBecomeActive")
    #if !targetEnvironment(simulator)
      TikTokBusiness.requestTrackingAuthorization()
    #endif
    trackTikTokLaunchEvent()
  }

  private func configureTikTokAppEvents() {
    guard
      let appId = Bundle.main.object(forInfoDictionaryKey: "TikTokAppEventsAppID") as? String,
      let appSecret = Bundle.main.object(forInfoDictionaryKey: "TikTokAppEventsAppSecret") as? String,
      let tiktokAppId = Bundle.main.object(forInfoDictionaryKey: "TikTokAppEventsTikTokAppID") as? String,
      let config = TikTokConfig(accessToken: appSecret, appId: appId, tiktokAppId: tiktokAppId)
    else {
      NSLog("KapiNote TikTok: missing SDK configuration in Info.plist")
      return
    }

    NSLog("KapiNote TikTok: configuring SDK appId=%@ tiktokAppId=%@", appId, tiktokAppId)
    config.setDelayForATTUserAuthorizationInSeconds(30)

    TikTokBusiness.initializeSdk(config) { success, error in
      if !success, let error {
        NSLog("TikTok App Events SDK initialization failed: %@", error.localizedDescription)
      } else {
        NSLog("KapiNote TikTok: SDK initialized successfully")
        self.trackTikTokLaunchEvent()
      }
    }
  }

  private func trackTikTokLaunchEvent() {
    guard TikTokBusiness.isInitialized() else {
      NSLog("KapiNote TikTok: launch event skipped because SDK is not initialized")
      return
    }

    let event = TikTokBaseEvent(eventName: TTEventName.launchAPP.rawValue)
    TikTokBusiness.trackTTEvent(event)
    TikTokBusiness.explicitlyFlush()
    NSLog(
      "KapiNote TikTok: LaunchAPP event sent and flushed. trackingEnabled=%@ userTrackingEnabled=%@ debugMode=%@ sdkVersion=%@",
      TikTokBusiness.isTrackingEnabled() ? "true" : "false",
      TikTokBusiness.isUserTrackingEnabled() ? "true" : "false",
      TikTokBusiness.isDebugMode() ? "true" : "false",
      TikTokBusiness.getSDKVersion()
    )
  }
}
