import Foundation

// Go API users tablosundan dönen yapı.
// Backend: api-go/cmd/api/types.go → type User struct
struct User: Identifiable, Codable, Equatable {
    let id: Int64
    var publicUID: String?
    var customerUID: String?
    var syncVersion: Int64?
    var name: String
    var phone: String?
    var email: String?
    var avatarURL: String?
    var emailVerifiedAt: Date?
    var loyaltyPoints: Int64?
    var loyaltyPointsLifetime: Int64?
    var isVip: Bool?
    var vipStartedAt: Date?
    var vipExpiresAt: Date?
    var adFree: Bool?

    // UI yardımcıları — name'i parçalayarak first/last türetir.
    var fullName: String { name }

    var firstName: String {
        let parts = name.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: true)
        return parts.first.map(String.init) ?? name
    }

    var lastName: String {
        let parts = name.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: true)
        return parts.count > 1 ? String(parts[1]) : ""
    }

    var isEmailVerified: Bool { emailVerifiedAt != nil }

    var loyaltyPointsValue: Int64 { loyaltyPoints ?? 0 }

    var isVIPActive: Bool {
        if adFree == true { return true }
        guard isVip == true else { return false }
        guard let vipExpiresAt else { return true }
        return vipExpiresAt > Date()
    }

    var vipStatusLabel: String {
        isVIPActive ? "VIP müşteri · reklamsız" : "Standart müşteri"
    }
}

// Backend production sürümünde access token + refresh token dönebilir.
// Eski Go API yalnızca token döndürürse mobil tarafı tokenı güvenli geçiş için
// refresh token olarak da saklar.
struct AuthSessionResponse: Codable {
    let user: User
    let token: String
    let refreshToken: String?
    let tokenType: String?
    let expiresAt: Date?
}

struct LoginRequest: Codable {
    let phone: String
    let password: String
    let deviceName: String?
    let cartToken: String?
    let location: String?

    init(phone: String, password: String, deviceName: String? = nil, cartToken: String? = nil, location: String? = nil) {
        self.phone = phone
        self.password = password
        self.deviceName = deviceName
        self.cartToken = cartToken
        self.location = location
    }
}

struct RegisterRequest: Codable {
    let name: String
    let phone: String
    let password: String
    let deviceName: String?
    let cartToken: String?
    let location: String?

    init(name: String, phone: String, password: String, deviceName: String? = nil, cartToken: String? = nil, location: String? = nil) {
        self.name = name
        self.phone = phone
        self.password = password
        self.deviceName = deviceName
        self.cartToken = cartToken
        self.location = location
    }
}
