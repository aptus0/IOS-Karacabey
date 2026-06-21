import Foundation
import FirebaseMessaging

@MainActor
final class DeviceTokenService {
    static let shared = DeviceTokenService()
    private let repository = NotificationRepository.shared

    private init() {}

    func currentFCMToken() async -> String? {
        guard AppDelegate.isFirebaseConfigured else { return nil }
        return try? await Messaging.messaging().token()
    }

    func registerCurrentToken() async {
        guard AppDelegate.isFirebaseConfigured else { return }
        guard let token = try? await Messaging.messaging().token(), !token.isEmpty else { return }
        await register(fcmToken: token)
    }

    func register(fcmToken: String) async {
        guard AppDelegate.isFirebaseConfigured else { return }

        let request = DeviceTokenRegistrationRequest(
            platform: "ios",
            token: fcmToken,
            deviceId: DeviceInfo.current.identifier,
            deviceName: DeviceInfo.current.name,
            appVersion: EnvironmentConfig.appVersion,
            locale: Locale.current.identifier,
            timezone: TimeZone.current.identifier
        )
        do {
            try await repository.registerDeviceToken(request)
        } catch {
            #if DEBUG
            print("[DeviceTokenService] Push token kaydı başarısız: \(error)")
            #endif
        }
        await MobileTelemetryService.shared.updatePushToken(fcmToken)
        await LiveActivityManager.shared.registerCurrentPushToStartToken()
    }
}
