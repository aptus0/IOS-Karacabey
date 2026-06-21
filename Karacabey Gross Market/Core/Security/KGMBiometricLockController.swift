import Foundation
import LocalAuthentication
import Combine

@MainActor
final class KGMBiometricLockController: ObservableObject {
    static let shared = KGMBiometricLockController()

    private static let enabledKey = "kgm_biometric_login_enabled"
    private static let loginPromptDoneKey = "kgm_biometric_login_prompt_done_for_session"
    private static let lastLoginPromptAtKey = "kgm_biometric_last_login_prompt_at"

    @Published private(set) var biometricEnabled: Bool
    @Published private(set) var isAuthenticating: Bool = false
    @Published private(set) var lastErrorMessage: String?

    private var promptInFlight = false
    private var promptedInMemory = false

    private init() {
        biometricEnabled = UserDefaults.standard.bool(forKey: Self.enabledKey)
    }

    var isEnabled: Bool { biometricEnabled }

    var canUseBiometrics: Bool {
        var error: NSError?
        let context = LAContext()
        return context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error)
    }

    var biometricDisplayName: String {
        let context = LAContext()
        _ = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
        switch context.biometryType {
        case .faceID: return "Face ID"
        case .touchID: return "Touch ID"
        default: return "Cihaz Parolası"
        }
    }

    func setEnabled(_ enabled: Bool) {
        biometricEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: Self.enabledKey)
        resetLoginPromptForCurrentSession()
        lastErrorMessage = nil
    }

    func disable() {
        setEnabled(false)
    }

    /// Eski app-lock/foreground çağrılarının Face ID döngüsü oluşturmasını engeller.
    func authenticateIfNeeded(reason: String = "") async -> Bool { true }
    func authenticateAfterForegroundIfNeeded(reason: String = "") async -> Bool { true }
    func markAppDidEnterBackground() {}

    /// Sadece başarılı login sonrasında çağrılır; aynı session içinde yalnızca 1 kez prompt açar.
    func authenticateOnceAfterSuccessfulLogin(
        reason: String = "Karacabey Gross Market hesabınıza güvenli giriş için Face ID / Touch ID doğrulaması yapın."
    ) async -> Bool {
        guard biometricEnabled else { return true }

        if promptedInMemory || UserDefaults.standard.bool(forKey: Self.loginPromptDoneKey) {
            promptedInMemory = true
            return true
        }

        guard !promptInFlight, !isAuthenticating else { return true }

        promptInFlight = true
        isAuthenticating = true
        lastErrorMessage = nil

        defer {
            promptInFlight = false
            isAuthenticating = false
        }

        let context = LAContext()
        context.localizedCancelTitle = "İptal"
        context.localizedFallbackTitle = "Parola ile Aç"

        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            lastErrorMessage = "Cihazınızda Face ID, Touch ID veya parola aktif değil."
            return false
        }

        do {
            let success = try await context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason)
            if success {
                promptedInMemory = true
                UserDefaults.standard.set(true, forKey: Self.loginPromptDoneKey)
                UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: Self.lastLoginPromptAtKey)
                UserDefaults.standard.synchronize()
            }
            return success
        } catch {
            lastErrorMessage = "Face ID doğrulaması tamamlanamadı."
            return false
        }
    }

    func resetLoginPromptAfterLogout() {
        promptedInMemory = false
        resetLoginPromptForCurrentSession()
    }

    private func resetLoginPromptForCurrentSession() {
        UserDefaults.standard.set(false, forKey: Self.loginPromptDoneKey)
        UserDefaults.standard.synchronize()
    }
}
