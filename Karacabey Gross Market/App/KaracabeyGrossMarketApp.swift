import SwiftUI
import WidgetKit

@main
struct KaracabeyGrossMarketApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var appState = AppState()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            AppRouter()
                .environmentObject(appState)
                .task {
                    Task(priority: .utility) {
                        await MobileTelemetryService.shared.registerOnLaunch()
                    }

                    WidgetCenter.shared.reloadAllTimelines()

                    await NotificationPermissionManager.shared.refreshStatus()
                    let needsNotificationPermission = await MainActor.run {
                        NotificationPermissionManager.shared.authorizationStatus == .notDetermined
                    }
                    if needsNotificationPermission {
                        _ = try? await NotificationPermissionManager.shared.requestAuthorization()
                    }
                    await appState.refreshUnreadNotificationCount()

                    if AppDelegate.isFirebaseConfigured {
                        await MainActor.run {
                            NotificationPermissionManager.shared.registerForRemoteNotificationsIfAuthorized()
                            LiveActivityManager.shared.startObservingPushToStartTokens()
                        }
                    }
                }
        }
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .active:
                AppSecurityManager.shared.hidePrivacyOverlay()
                Task(priority: .utility) {
                    await MobileTelemetryService.shared.registerOnForeground()
                    await appState.refreshUnreadNotificationCount()
                    PreloadService.shared.refreshInBackground()
                    WidgetCenter.shared.reloadAllTimelines()
                }
            case .inactive, .background:
                AppSecurityManager.shared.showPrivacyOverlay(reason: "Uygulama arka plandayken bilgileriniz gizlenir.")
            @unknown default:
                break
            }
        }
    }
}
