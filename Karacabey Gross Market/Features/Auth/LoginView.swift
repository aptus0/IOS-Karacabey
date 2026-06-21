import SwiftUI
import Combine

@MainActor
final class LoginViewModel: ObservableObject {
    @Published var phone = ""
    @Published var password = ""
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var phoneError: String?
    @Published var passwordError: String?

    var isFormValid: Bool { !phone.isEmpty && !password.isEmpty }

    func login(appState: AppState) async {
        phoneError = nil; passwordError = nil; errorMessage = nil
        guard validate() else { return }
        isLoading = true
        do {
            let (user, _) = try await AuthRepository.shared.login(phone: normalizedPhone, password: password)
            appState.currentUser = user
            appState.isLoggedIn = true
            _ = await KGMBiometricLockController.shared.authenticateOnceAfterSuccessfulLogin()
        } catch {
            errorMessage = error.kgmUserMessage
        }
        isLoading = false
    }

    private var normalizedPhone: String {
        phone.filter { $0.isNumber }
    }

    private func validate() -> Bool {
        var valid = true
        let digits = normalizedPhone
        if digits.isEmpty { phoneError = "Telefon boş olamaz"; valid = false }
        else if digits.count < 10 { phoneError = "Geçerli telefon girin (5xx xxx xx xx)"; valid = false }
        if password.isEmpty { passwordError = "Şifre boş olamaz"; valid = false }
        else if password.count < 6 { passwordError = "Şifre en az 6 karakter olmalı"; valid = false }
        return valid
    }
}

struct LoginView: View {
    @StateObject private var vm = LoginViewModel()
    @EnvironmentObject var appState: AppState
    @State private var showRegister = false
    @State private var showForgotPassword = false

    var body: some View {
        ScrollView {
            VStack(spacing: KGMSpacing.xl) {
                Spacer(minLength: KGMSpacing.xxl)

                VStack(spacing: KGMSpacing.sm) {
                    ZStack {
                        Circle()
                            .fill(Color.kgmPrimary.opacity(0.1))
                            .frame(width: 80, height: 80)
                        Image(systemName: "cart.fill")
                            .font(.system(size: 36))
                            .foregroundColor(Color.kgmPrimary)
                    }
                    Text("Karacabey Gross Market")
                        .font(.kgmTitle)
                        .foregroundColor(.primary)
                    Text("Hesabınıza giriş yapın")
                        .font(.kgmBody)
                        .foregroundColor(.secondary)
                }

                VStack(spacing: KGMSpacing.md) {
                    KGMTextField(title: "Telefon", placeholder: "5XX XXX XX XX", text: $vm.phone,
                                 keyboardType: .phonePad, errorMessage: vm.phoneError, leadingIcon: "phone")
                    KGMTextField(title: "Şifre", placeholder: "Şifreniz", text: $vm.password,
                                 isSecure: true, errorMessage: vm.passwordError, leadingIcon: "lock")
                }
                .padding(.horizontal, KGMSpacing.base)

                if let error = vm.errorMessage {
                    HStack(spacing: KGMSpacing.sm) {
                        Image(systemName: "exclamationmark.circle")
                            .foregroundColor(Color.kgmSecondary)
                        Text(error)
                            .font(.kgmCaption)
                            .foregroundColor(Color.kgmSecondary)
                    }
                    .padding(.horizontal, KGMSpacing.base)
                }

                VStack(spacing: KGMSpacing.md) {
                    KGMButton("Giriş Yap", isLoading: vm.isLoading, isDisabled: !vm.isFormValid) {
                        Task { await vm.login(appState: appState) }
                    }
                    .padding(.horizontal, KGMSpacing.base)

                    Button("Şifremi Unuttum") { showForgotPassword = true }
                        .font(.kgmCallout)
                        .foregroundColor(Color.kgmPrimary)
                }

                Divider().padding(.horizontal, KGMSpacing.base)

                VStack(spacing: KGMSpacing.sm) {
                    Text("Hesabınız yok mu?")
                        .font(.kgmBody)
                        .foregroundColor(.secondary)
                    KGMButton("Ücretsiz Kayıt Ol", style: .outline) { showRegister = true }
                        .padding(.horizontal, KGMSpacing.base)
                }
            }
            .padding(.bottom, KGMSpacing.xxxl)
        }
        .navigationBarHidden(true)
        .navigationDestination(isPresented: $showRegister) { RegisterView() }
        .navigationDestination(isPresented: $showForgotPassword) { ForgotPasswordView() }
    }
}
