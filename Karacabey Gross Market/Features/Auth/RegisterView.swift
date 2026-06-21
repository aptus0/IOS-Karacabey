import SwiftUI
import Combine

@MainActor
final class RegisterViewModel: ObservableObject {
    @Published var firstName = ""
    @Published var lastName = ""
    @Published var phone = ""
    @Published var email = ""
    @Published var password = ""
    @Published var confirmPassword = ""
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var fieldErrors: [String: String] = [String: String]()
    @Published var kvkkAccepted = false

    func register(appState: AppState) async {
        fieldErrors = [:]; errorMessage = nil
        guard validate() else { return }
        isLoading = true
        do {
            let fullName = "\(firstName.trimmingCharacters(in: .whitespaces)) \(lastName.trimmingCharacters(in: .whitespaces))"
                .trimmingCharacters(in: .whitespaces)
            let digits = phone.filter { $0.isNumber }
            let request = RegisterRequest(
                name: fullName,
                phone: digits,
                password: password,
                deviceName: DeviceInfo.current.name,
                cartToken: KeychainManager.shared.getCartToken()
            )
            let (user, _) = try await AuthRepository.shared.register(request: request)
            appState.currentUser = user
            appState.isLoggedIn = true
        } catch {
            errorMessage = error.kgmUserMessage
        }
        isLoading = false
    }

    private func validate() -> Bool {
        var ok = true
        if firstName.trimmingCharacters(in: .whitespaces).isEmpty { fieldErrors["firstName"] = "Ad boş olamaz"; ok = false }
        if lastName.trimmingCharacters(in: .whitespaces).isEmpty  { fieldErrors["lastName"]  = "Soyad boş olamaz"; ok = false }
        let digits = phone.filter { $0.isNumber }
        if digits.count < 10 || !digits.hasPrefix("5") {
            fieldErrors["phone"] = "Geçerli telefon girin (5xx xxx xx xx)"; ok = false
        }
        if !email.isEmpty && !email.contains("@") { fieldErrors["email"] = "Geçerli e-posta giriniz"; ok = false }
        if password.count < 8 { fieldErrors["password"] = "Şifre en az 8 karakter"; ok = false }
        if password != confirmPassword { fieldErrors["confirm"] = "Şifreler eşleşmiyor"; ok = false }
        if !kvkkAccepted { errorMessage = "Devam etmek için KVKK onayı gereklidir."; ok = false }
        return ok
    }
}

struct RegisterView: View {
    @StateObject private var vm = RegisterViewModel()
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss

    var body: some View {
        ScrollView {
            VStack(spacing: KGMSpacing.lg) {
                VStack(spacing: KGMSpacing.xs) {
                    Text("Hesap Oluştur")
                        .font(.kgmLargeTitle)
                    Text("Hızlı alışveriş için üye olun")
                        .font(.kgmBody)
                        .foregroundColor(.secondary)
                }
                .padding(.top, KGMSpacing.xl)

                VStack(spacing: KGMSpacing.md) {
                    HStack(spacing: KGMSpacing.sm) {
                        KGMTextField(title: "Ad", placeholder: "Adınız", text: $vm.firstName, errorMessage: vm.fieldErrors["firstName"])
                        KGMTextField(title: "Soyad", placeholder: "Soyadınız", text: $vm.lastName, errorMessage: vm.fieldErrors["lastName"])
                    }
                    KGMTextField(title: "Telefon", placeholder: "+90 5XX XXX XX XX", text: $vm.phone,
                                 keyboardType: .phonePad, errorMessage: vm.fieldErrors["phone"], leadingIcon: "phone")
                    KGMTextField(title: "E-posta", placeholder: "ornek@mail.com", text: $vm.email,
                                 keyboardType: .emailAddress, errorMessage: vm.fieldErrors["email"], leadingIcon: "envelope")
                    KGMTextField(title: "Şifre", placeholder: "En az 6 karakter", text: $vm.password,
                                 isSecure: true, errorMessage: vm.fieldErrors["password"], leadingIcon: "lock")
                    KGMTextField(title: "Şifre Tekrar", placeholder: "Şifrenizi tekrar girin", text: $vm.confirmPassword,
                                 isSecure: true, errorMessage: vm.fieldErrors["confirm"], leadingIcon: "lock.rotation")
                }
                .padding(.horizontal, KGMSpacing.base)

                Toggle(isOn: $vm.kvkkAccepted) {
                    Text("KVKK Aydınlatma Metni'ni okudum ve kabul ediyorum.")
                        .font(.kgmCaption)
                        .foregroundColor(.secondary)
                }
                .tint(Color.kgmPrimary)
                .padding(.horizontal, KGMSpacing.base)

                if let error = vm.errorMessage {
                    Text(error).font(.kgmCaption).foregroundColor(Color.kgmSecondary)
                        .padding(.horizontal, KGMSpacing.base)
                }

                KGMButton("Kayıt Ol", isLoading: vm.isLoading) {
                    Task { await vm.register(appState: appState) }
                }
                .padding(.horizontal, KGMSpacing.base)
            }
            .padding(.bottom, KGMSpacing.xxxl)
        }
        .navigationTitle("Üye Ol")
        .navigationBarTitleDisplayMode(.inline)
    }
}
