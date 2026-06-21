import UIKit
import FirebaseCore
import FirebaseMessaging
import FirebaseCrashlytics
import GoogleMobileAds

final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate, MessagingDelegate {
    private(set) static var isFirebaseConfigured = false

    private static var hasGoogleServiceInfo: Bool {
        Bundle.main.url(forResource: "GoogleService-Info", withExtension: "plist") != nil
    }

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil
    ) -> Bool {
        URLCache.shared = URLCache(memoryCapacity: 96 * 1024 * 1024,
                                   diskCapacity: 512 * 1024 * 1024,
                                   diskPath: "kgm-url-cache")

        configureFirebaseIfPossible()
        AppSecurityManager.shared.configureRuntimeProtection()
        AdMobService.shared.start()
        if AppSecurityManager.shared.isDeviceCompromised {
            CrashReporter.record(
                APIError.insecureTransport,
                context: "device_integrity_failed",
                metadata: ["device": "compromised"]
            )
        }
        if AppSecurityManager.shared.isDebuggerAttached {
            CrashReporter.record(
                APIError.insecureTransport,
                context: "debugger_detected",
                metadata: ["build": EnvironmentConfig.buildNumber]
            )
        }
        return true
    }

    private func configureFirebaseIfPossible() {
        guard Self.hasGoogleServiceInfo else {
            Self.isFirebaseConfigured = false
            #if DEBUG
            print("[Firebase] GoogleService-Info.plist bulunamadı. Firebase/FCM devre dışı, uygulama normal çalışacak.")
            #endif
            return
        }

        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
        }

        Self.isFirebaseConfigured = FirebaseApp.app() != nil
        guard Self.isFirebaseConfigured else { return }
        Messaging.messaging().delegate = self
        Crashlytics.crashlytics().setCrashlyticsCollectionEnabled(true)
        CrashReporter.configure()
    }

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        guard Self.isFirebaseConfigured else { return }
        Messaging.messaging().apnsToken = deviceToken
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        #if DEBUG
        print("[Push] APNs kayıt başarısız: \(error.localizedDescription)")
        #endif
    }

    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        guard Self.isFirebaseConfigured else { return }
        guard let fcmToken = fcmToken, !fcmToken.isEmpty else { return }

        Task { @MainActor in
            await DeviceTokenService.shared.register(fcmToken: fcmToken)
        }
    }
}
