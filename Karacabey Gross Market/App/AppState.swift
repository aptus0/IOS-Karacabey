import SwiftUI
import Combine

enum AppTab {
    case home, categories, quickOrder, cart, more
}

enum ProfileRoute: Equatable {
    case orders
    case order(String)
    case notifications
    case notification(String)
}

@MainActor
final class AppState: ObservableObject {
    @Published var isLoggedIn: Bool = false
    @Published var currentUser: User? = nil
    @Published var selectedTab: AppTab = .home
    @Published var cartItemCount: Int = 0
    @Published var showingOnboarding: Bool = false
    @Published var isLoading: Bool = false
    @Published var toastMessage: String? = nil
    @Published var unreadNotificationCount: Int = 0
    @Published var profileRoute: ProfileRoute? = nil
    @Published var requiresUnlock: Bool = false

    init() {
        let hasSeenOnboarding = UserDefaults.standard.bool(forKey: "hasSeenOnboarding")
        showingOnboarding = !hasSeenOnboarding
        isLoggedIn = KeychainManager.shared.getAccessToken() != nil
    }

    func refreshCurrentUser() async {
        guard isLoggedIn else { return }
        currentUser = try? await AuthRepository.shared.getProfile()
    }

    func refreshUnreadNotificationCount() async {
        guard isLoggedIn else {
            unreadNotificationCount = 0
            NotificationPermissionManager.shared.updateApplicationBadge(to: 0)
            return
        }

        guard let count = try? await NotificationRepository.shared.unreadCount() else { return }
        unreadNotificationCount = count
        NotificationPermissionManager.shared.updateApplicationBadge(to: count)
    }

    func openProfile(_ route: ProfileRoute) {
        profileRoute = route
        selectedTab = .more
    }

    func evaluateAppLockIfNeeded() async {
        // Face ID yalnızca başarılı login sonrasında bir kez sorulur.
        // Splash/foreground otomatik kilit döngüsü kapatıldı.
        requiresUnlock = false
    }

    func unlockApp() async {
        requiresUnlock = false
    }

    func logout() {
        Task {
            await AuthRepository.shared.logout()
            isLoggedIn = false
            currentUser = nil
            selectedTab = .home
            cartItemCount = 0
            unreadNotificationCount = 0
            NotificationPermissionManager.shared.updateApplicationBadge(to: 0)
            profileRoute = nil
            requiresUnlock = false
            KGMBiometricLockController.shared.resetLoginPromptAfterLogout()
        }
    }

    func showToast(_ message: String) {
        toastMessage = message
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
            self?.toastMessage = nil
        }
    }
}
