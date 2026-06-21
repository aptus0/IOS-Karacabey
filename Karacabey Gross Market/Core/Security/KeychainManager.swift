import Foundation
import Security

final class KeychainManager {
    static let shared = KeychainManager()
    private init() {}

    private enum Key: String {
        case accessToken = "com.kgm.accessToken"
        case refreshToken = "com.kgm.refreshToken.v2"
        case accessTokenExpiresAt = "com.kgm.accessTokenExpiresAt"
        case cartToken = "com.kgm.cartToken"
        case legacyRefreshToken = "com.kgm.refreshToken"
    }

    func saveAuthSession(token: String, refreshToken: String? = nil, expiresAt: Date? = nil) {
        saveAccessToken(token)
        // Backend bugün tek token döndürüyor. Ayrı refresh_token gelirse onu, gelmezse mevcut tokenı
        // kontrollü yenileme tokenı olarak saklıyoruz. Token yalnızca Keychain'de tutulur.
        saveRefreshToken(refreshToken?.nilIfBlank ?? token)
        if let expiresAt {
            save(key: Key.accessTokenExpiresAt.rawValue, value: ISO8601DateFormatter().string(from: expiresAt))
        } else {
            delete(key: Key.accessTokenExpiresAt.rawValue)
        }
    }

    func saveAccessToken(_ token: String) {
        save(key: Key.accessToken.rawValue, value: token)
    }

    func getAccessToken() -> String? {
        retrieve(key: Key.accessToken.rawValue)
    }

    func saveRefreshToken(_ token: String) {
        save(key: Key.refreshToken.rawValue, value: token)
        delete(key: Key.legacyRefreshToken.rawValue)
    }

    func getRefreshToken() -> String? {
        retrieve(key: Key.refreshToken.rawValue) ?? retrieve(key: Key.legacyRefreshToken.rawValue)
    }

    func getAccessTokenExpiresAt() -> Date? {
        guard let raw = retrieve(key: Key.accessTokenExpiresAt.rawValue) else { return nil }
        return ISO8601DateFormatter().date(from: raw)
    }

    func shouldRefreshAccessToken(leeway: TimeInterval = 5 * 60) -> Bool {
        guard let expiresAt = getAccessTokenExpiresAt() else { return false }
        return expiresAt.timeIntervalSinceNow <= leeway
    }

    func saveCartToken(_ token: String) {
        save(key: Key.cartToken.rawValue, value: token)
    }

    func getCartToken() -> String? {
        retrieve(key: Key.cartToken.rawValue)
    }

    func clearCartToken() {
        delete(key: Key.cartToken.rawValue)
    }

    func clearAuthSession() {
        delete(key: Key.accessToken.rawValue)
        delete(key: Key.refreshToken.rawValue)
        delete(key: Key.legacyRefreshToken.rawValue)
        delete(key: Key.accessTokenExpiresAt.rawValue)
    }

    func clearAll() {
        clearAuthSession()
    }

    private func save(key: String, value: String) {
        guard let data = value.data(using: .utf8) else { return }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            kSecAttrSynchronizable as String: kCFBooleanFalse as Any
        ]
        SecItemDelete(query as CFDictionary)
        SecItemAdd(query as CFDictionary, nil)
    }

    private func retrieve(key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
            kSecAttrSynchronizable as String: kCFBooleanFalse as Any
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private func delete(key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecAttrSynchronizable as String: kCFBooleanFalse as Any
        ]
        SecItemDelete(query as CFDictionary)
    }
}

private extension String {
    var nilIfBlank: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
