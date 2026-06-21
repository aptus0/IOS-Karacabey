import Foundation
import UIKit

@MainActor
final class AuthRepository {
    static let shared = AuthRepository()
    private let apiClient = APIClient.shared
    private init() {}

    func login(phone: String, password: String) async throws -> (User, String) {
        do {
            let request = LoginRequest(
                phone: phone,
                password: password,
                deviceName: DeviceInfo.current.name,
                cartToken: KeychainManager.shared.getCartToken(),
                location: nil
            )
            let response: AuthSessionResponse = try await apiClient.request(Endpoint.login(request))
            KeychainManager.shared.saveAuthSession(token: response.token, refreshToken: response.refreshToken, expiresAt: response.expiresAt)
            await DeviceTokenService.shared.registerCurrentToken()
            try? await logEvent(.loginSuccess, phone: phone, failureReason: nil)
            return (response.user, response.token)
        } catch {
            try? await logEvent(.loginFailed, phone: phone, failureReason: error.localizedDescription)
            throw error
        }
    }

    func register(request: RegisterRequest) async throws -> (User, String) {
        let response: AuthSessionResponse = try await apiClient.request(Endpoint.register(request))
        KeychainManager.shared.saveAuthSession(token: response.token, refreshToken: response.refreshToken, expiresAt: response.expiresAt)
        await DeviceTokenService.shared.registerCurrentToken()
        try? await logEvent(.registerSuccess, phone: request.phone, failureReason: nil)
        return (response.user, response.token)
    }

    func logout() async {
        try? await logEvent(.logout, phone: nil, failureReason: nil)
        _ = try? await apiClient.request(Endpoint.logout) as EmptyResponse
        KeychainManager.shared.clearAll()
    }

    func forgotPassword(email: String) async throws {
        _ = try await apiClient.request(Endpoint.forgotPassword(email)) as EmptyResponse
        try? await logEvent(.passwordResetRequested, phone: nil, failureReason: nil)
    }

    func getProfile() async throws -> User {
        try await apiClient.request(Endpoint.getProfile)
    }

    func logEvent(_ event: CustomerAuthLogEvent, phone: String?, failureReason: String?) async throws {
        var payload: [String: AnyCodableValue] = [
            "login_method": .string("password"),
            "build_number": .string(EnvironmentConfig.buildNumber),
            "device_model": .string(DeviceInfo.current.model),
            "os_version": .string(DeviceInfo.current.osVersion),
            "locale": .string(Locale.current.identifier),
            "timezone": .string(TimeZone.current.identifier)
        ]
        if let phone, !phone.isEmpty {
            payload["phone"] = .string(phone)
        }
        if let failureReason, !failureReason.isEmpty {
            payload["failure_reason"] = .string(failureReason)
        }

        let request = MobileEventRequest(
            deviceId: DeviceInfo.current.identifier,
            sessionId: UUID().uuidString,
            eventName: event.rawValue,
            screen: "auth",
            appVersion: EnvironmentConfig.appVersion,
            platform: "ios",
            payload: payload,
            occurredAt: Date()
        )
        _ = try await apiClient.request(Endpoint.authLogEvent(request)) as EmptyResponse
    }
}

enum DeviceInfo {
    static let current = DeviceInfoSnapshot(
        identifier: PersistentDeviceID.value,
        name: UIDevice.current.name,
        model: UIDevice.current.model,
        osVersion: UIDevice.current.systemVersion
    )
}

struct DeviceInfoSnapshot {
    let identifier: String
    let name: String
    let model: String
    let osVersion: String
}

enum PersistentDeviceID {
    private static let storageKey = "kgm.persistent.device.id"

    static let value: String = {
        let defaults = UserDefaults.standard
        if let existing = defaults.string(forKey: storageKey), !existing.isEmpty {
            return existing
        }
        let seed = UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString
        defaults.set(seed, forKey: storageKey)
        return seed
    }()
}
