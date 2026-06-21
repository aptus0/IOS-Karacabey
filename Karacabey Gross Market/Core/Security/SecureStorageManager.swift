import Foundation

final class SecureStorageManager {
    static let shared = SecureStorageManager()
    private init() {}

    // Zararsız tercihler için UserDefaults, hassas veriler için Keychain kullan
    private let defaults = UserDefaults.standard

    func setBool(_ value: Bool, forKey key: String) {
        defaults.set(value, forKey: key)
    }

    func getBool(forKey key: String) -> Bool {
        defaults.bool(forKey: key)
    }

    func setString(_ value: String, forKey key: String) {
        defaults.set(value, forKey: key)
    }

    func getString(forKey key: String) -> String? {
        defaults.string(forKey: key)
    }

    func remove(forKey key: String) {
        defaults.removeObject(forKey: key)
    }
}

enum SecureStorageKey {
    static let hasSeenOnboarding  = "hasSeenOnboarding"
    static let selectedCity        = "selectedCity"
    static let isBiometricEnabled  = "isBiometricEnabled"
    static let notificationsEnabled = "notificationsEnabled"
    static let lastSelectedAddressId = "lastSelectedAddressId"
}
