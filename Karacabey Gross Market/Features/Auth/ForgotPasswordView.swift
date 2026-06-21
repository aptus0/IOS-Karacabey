import SwiftUI

struct ForgotPasswordView: View {
    @State private var email = ""
    @State private var isLoading = false
    @State private var isSuccess = false
    @State private var errorMessage: String?
    @Environment(\.dismiss) var dismiss

    var body: some View {
        ScrollView {
            VStack(spacing: KGMSpacing.xl) {
                Spacer(minLength: KGMSpacing.xl)

                ZStack {
                    Circle()
                        .fill(Color.kgmPrimary.opacity(0.1))
                        .frame(width: 80, height: 80)
                    Image(systemName: isSuccess ? "envelope.badge.checkmark.fill" : "lock.open.fill")
                        .font(.system(size: 36))
                        .foregroundColor(Color.kgmPrimary)
                }

                VStack(spacing: KGMSpacing.sm) {
                    Text(isSuccess ? "E-posta Gönderildi" : "Şifremi Sıfırla")
                        .font(.kgmLargeTitle)
                    Text(isSuccess
                         ? "Şifre sıfırlama bağlantısı \(email) adresine gönderildi."
                         : "E-posta adresinizi girin. Şifre sıfırlama bağlantısı göndereceğiz.")
                        .font(.kgmBody)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, KGMSpacing.xl)
                }

                if !isSuccess {
                    VStack(spacing: KGMSpacing.md) {
                        KGMTextField(title: "E-posta", placeholder: "ornek@mail.com", text: $email,
                                     keyboardType: .emailAddress, errorMessage: nil, leadingIcon: "envelope")
                        if let error = errorMessage {
                            Text(error).font(.kgmCaption).foregroundColor(Color.kgmSecondary)
                        }
                        KGMButton("Bağlantı Gönder", isLoading: isLoading, isDisabled: email.isEmpty) {
                            Task { await sendResetLink() }
                        }
                    }
                    .padding(.horizontal, KGMSpacing.base)
                } else {
                    KGMButton("Giriş Yap", style: .outline) { dismiss() }
                        .padding(.horizontal, KGMSpacing.base)
                }
            }
        }
        .navigationTitle("Şifremi Sıfırla")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func sendResetLink() async {
        isLoading = true; errorMessage = nil
        do {
            try await AuthRepository.shared.forgotPassword(email: email)
            isSuccess = true
        } catch {
            errorMessage = error.kgmUserMessage
        }
        isLoading = false
    }
}
