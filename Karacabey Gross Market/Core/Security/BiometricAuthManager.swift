import LocalAuthentication
import Foundation

final class BiometricAuthManager {
    static let shared = BiometricAuthManager()
    private init() {}

    var isAvailable: Bool {
        let context = LAContext()
        var error: NSError?
        return context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error)
    }

    var biometricType: LABiometryType {
        let context = LAContext()
        _ = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
        return context.biometryType
    }

    var displayName: String {
        switch biometricType {
        case .faceID: return "Face ID"
        case .touchID: return "Touch ID"
        default: return "Cihaz Parolası"
        }
    }

    func authenticate(reason: String) async -> Bool {
        guard isAvailable else { return false }
        let context = LAContext()
        context.localizedFallbackTitle = "Parolayı Kullan"
        context.localizedCancelTitle = "Vazgeç"
        do {
            return try await context.evaluatePolicy(
                .deviceOwnerAuthentication,
                localizedReason: reason
            )
        } catch {
            return false
        }
    }
}
