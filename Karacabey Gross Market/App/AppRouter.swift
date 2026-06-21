import SwiftUI

struct AppRouter: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var preload = PreloadService.shared
    @State private var showSplash = true
    @State private var splashStartedAt = Date()

    private let minimumSplashDuration: TimeInterval = 5.0

    var body: some View {
        ZStack {
            if showSplash {
                SplashView(
                    progress: preload.progress,
                    statusText: preload.statusText,
                    isUsingCache: preload.isUsingCachedData
                )
                .transition(.opacity)
            } else if appState.showingOnboarding {
                OnboardingView()
                    .transition(.opacity)
            } else if !appState.isLoggedIn {
                NavigationStack {
                    LoginView()
                }
                .transition(.opacity)
            } else {
                MainTabView()
                    .transition(.opacity)
            }

            if appState.requiresUnlock {
                AppLockView {
                    Task { await appState.unlockApp() }
                }
                .transition(.opacity)
            }

            if let toast = appState.toastMessage {
                VStack {
                    Spacer()
                    KGMToast(message: toast)
                        .padding(.bottom, 100)
                }
                .animation(.easeInOut, value: toast)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.25), value: showSplash)
        .animation(.easeInOut(duration: 0.25), value: appState.isLoggedIn)
        .task {
            splashStartedAt = Date()
            await preload.bootstrap()
            await hideSplash()
        }
    }

    @MainActor
    private func hideSplash() async {
        guard showSplash else { return }

        let elapsed = Date().timeIntervalSince(splashStartedAt)
        let remaining = max(0, minimumSplashDuration - elapsed)
        if remaining > 0 {
            try? await Task.sleep(nanoseconds: UInt64(remaining * 1_000_000_000))
        }

        withAnimation {
            showSplash = false
        }
    }
}


private struct AppLockView: View {
    let onUnlock: () -> Void

    var body: some View {
        VStack(spacing: KGMSpacing.base) {
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 52))
                .foregroundColor(.kgmPrimary)
            Text("Uygulama Kilitli")
                .font(.kgmTitle2)
                .foregroundColor(.kgmTextPrimary)
            Text("Face ID, Touch ID veya cihaz parolanızla hızlıca devam edin.")
                .font(.kgmBody)
                .foregroundColor(.kgmTextSecondary)
                .multilineTextAlignment(.center)
            Button(action: onUnlock) {
                Label("Kilidi Aç", systemImage: "faceid")
                    .font(.kgmBodyMedium)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(Color.kgmPrimary)
                    .clipShape(RoundedRectangle(cornerRadius: KGMRadius.card))
            }
            .buttonStyle(.plain)
        }
        .padding(KGMSpacing.lg)
        .frame(maxWidth: 360)
        .background(Color.kgmCard)
        .clipShape(RoundedRectangle(cornerRadius: KGMRadius.lg))
        .shadow(radius: 18)
        .padding(KGMSpacing.base)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.ultraThinMaterial)
    }
}
