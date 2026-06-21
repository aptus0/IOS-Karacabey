import Foundation
import Combine
import UIKit
import UserNotifications

extension Notification.Name {
    static let kgmPushNotificationReceived = Notification.Name("kgmPushNotificationReceived")
}

@MainActor
final class NotificationPermissionManager: NSObject, ObservableObject {
    static let shared = NotificationPermissionManager()
    @Published private(set) var authorizationStatus: UNAuthorizationStatus = .notDetermined

    private override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
        configureCategories()
    }

    func refreshStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        authorizationStatus = settings.authorizationStatus
    }

    func requestAuthorization() async throws -> Bool {
        let granted = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound])
        await refreshStatus()
        await syncApplicationBadgeCount()
        if granted {
            registerForRemoteNotificationsIfAuthorized()
        }
        return granted
    }

    func registerForRemoteNotificationsIfAuthorized() {
        guard authorizationStatus == .authorized
                || authorizationStatus == .provisional
                || authorizationStatus == .ephemeral else {
            return
        }
        UIApplication.shared.registerForRemoteNotifications()
    }

    func clearApplicationBadge() {
        updateApplicationBadge(to: 0)
    }

    func updateApplicationBadge(to count: Int) {
        let safeCount = max(0, count)
        UNUserNotificationCenter.current().setBadgeCount(safeCount) { _ in }
    }

    func syncApplicationBadgeCount() async {
        guard KeychainManager.shared.getAccessToken() != nil else {
            updateApplicationBadge(to: 0)
            return
        }

        guard let unreadCount = try? await NotificationRepository.shared.unreadCount() else {
            return
        }

        updateApplicationBadge(to: unreadCount)
    }

    func scheduleWidgetReadyNotificationIfNeeded() async {
        await refreshStatus()
    }

    private func configureCategories() {
        let openAction = UNNotificationAction(
            identifier: "KGM_OPEN",
            title: "Görüntüle",
            options: [.foreground]
        )
        let category = UNNotificationCategory(
            identifier: "KGM_RICH_NOTIFICATION",
            actions: [openAction],
            intentIdentifiers: [],
            options: [.customDismissAction]
        )
        UNUserNotificationCenter.current().setNotificationCategories([category])
    }
}

extension NotificationPermissionManager: UNUserNotificationCenterDelegate {
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        await NotificationPermissionManager.shared.syncApplicationBadgeCount()
        await MainActor.run {
            NotificationCenter.default.post(name: .kgmPushNotificationReceived, object: nil)
        }
        return [.banner, .sound]
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        await NotificationPermissionManager.shared.syncApplicationBadgeCount()
        await MainActor.run {
            NotificationCenter.default.post(name: .kgmPushNotificationReceived, object: nil)
        }
        let userInfo = response.notification.request.content.userInfo
        if let notificationID = userInfo["notification_id"] as? String, !notificationID.isEmpty {
            await DeepLinkRouter.shared.open("kgm://notifications/\(notificationID)")
            return
        }
        let deepLink = (userInfo["deep_link"] as? String) ?? (userInfo["action_url"] as? String)
        await DeepLinkRouter.shared.open(deepLink)
    }
}
