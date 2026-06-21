import Foundation

struct AuthInterceptor {
    func adapt(_ request: inout URLRequest, requiresAuth: Bool) throws {
        if let cartToken = KeychainManager.shared.getCartToken(), !cartToken.isEmpty {
            request.setValue(cartToken, forHTTPHeaderField: "X-Cart-Token")
        }

        if let token = KeychainManager.shared.getAccessToken(), !token.isEmpty {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            return
        }

        guard !requiresAuth else {
            throw APIError.unauthorized
        }
    }
}
