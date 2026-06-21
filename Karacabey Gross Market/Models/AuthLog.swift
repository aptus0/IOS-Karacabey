import Foundation

enum CustomerAuthLogEvent: String, Codable, CaseIterable {
    case loginSuccess = "login_success"
    case loginFailed = "login_failed"
    case logout
    case tokenRefresh = "token_refresh"
    case passwordResetRequested = "password_reset_requested"
    case registerSuccess = "register_success"
    case accountBlocked = "account_blocked"
}

struct AuthLogEventRequest: Codable {
    let eventType: CustomerAuthLogEvent
    let email: String?
    let phoneE164: String?
    let deviceId: String?
    let deviceName: String?
    let appVersion: String
    let platform: String
    let locale: String
    let timezone: String
    let location: AuthLogLocation?
    let metadata: AuthLogMetadata
}

struct AuthLogLocation: Codable, Hashable {
    let latitude: Double
    let longitude: Double
    let accuracy: Double?
}

struct AuthLogMetadata: Codable, Hashable {
    let buildNumber: String
    let deviceModel: String
    let osVersion: String
    let loginMethod: String?
    let failureReason: String?
    let pushPermissionStatus: String?
    let locationPermissionStatus: String?
}

