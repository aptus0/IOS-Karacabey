import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject private var biometricLock = KGMBiometricLockController.shared
    @State private var notificationsEnabled = SecureStorageManager.shared.getBool(forKey: SecureStorageKey.notificationsEnabled)
    @State private var showDeleteAccountAlert = false

    var body: some View {
        List {
            Section("Bildirimler") {
                Toggle("Kampanya Bildirimleri", isOn: $notificationsEnabled)
                    .tint(Color.kgmPrimary)
                    .onChange(of: notificationsEnabled) { _, newValue in
                        SecureStorageManager.shared.setBool(newValue, forKey: SecureStorageKey.notificationsEnabled)
                    }
                Toggle("Sipariş Bildirimleri", isOn: .constant(true))
                    .tint(Color.kgmPrimary)
            }

            if biometricLock.canUseBiometrics {
                Section {
                    Toggle("\(biometricLock.biometricDisplayName) ile girişte doğrula", isOn: Binding(
                        get: { biometricLock.isEnabled },
                        set: { biometricLock.setEnabled($0) }
                    ))
                    .tint(Color.kgmPrimary)

                    Text("Açık olduğunda doğrulama sadece başarılı girişten sonra bir kez sorulur. Uygulama açılışında veya ekran değiştirirken tekrar tekrar Face ID istemez.")
                        .font(.kgmSmall)
                        .foregroundColor(.kgmTextSecondary)
                } header: {
                    Text("Güvenlik")
                }
            }

            Section("Uygulama") {
                HStack {
                    Text("Versiyon")
                    Spacer()
                    Text("\(EnvironmentConfig.appVersion) (\(EnvironmentConfig.buildNumber))")
                        .foregroundColor(.secondary)
                }
                HStack {
                    Text("Ortam")
                    Spacer()
                    Text(EnvironmentConfig.current == .production ? "Canlı" : "Test")
                        .foregroundColor(.secondary)
                }
            }

            Section {
                Button("Önbelleği Temizle") {
                    Task {
                        await MainActor.run {
                            NotificationPermissionManager.shared.clearApplicationBadge()
                        }
                    }
                }
                .foregroundColor(Color.kgmInfo)
            }

            Section {
                Button("Hesabımı Sil") { showDeleteAccountAlert = true }
                    .foregroundColor(Color.kgmSecondary)
            }
        }
        .navigationTitle("Ayarlar")
        .navigationBarTitleDisplayMode(.large)
        .alert("Hesabı Sil", isPresented: $showDeleteAccountAlert) {
            Button("Sil", role: .destructive) { appState.logout() }
            Button("İptal", role: .cancel) {}
        } message: {
            Text("Hesabınız kalıcı olarak silinecek. Bu işlem geri alınamaz.")
        }
    }
}
