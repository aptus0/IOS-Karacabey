import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.openURL) private var openURL
    @State private var showOrders = false
    @State private var showAddresses = false
    @State private var showFavorites = false
    @State private var showCoupons = false
    @State private var showNotifications = false
    @State private var showSettings = false
    @State private var showSupport = false
    @State private var showLegal = false
    @State private var showLogoutAlert = false
    @State private var initialOrderID: String?
    @State private var initialNotificationID: String?

    private let columns = [GridItem(.flexible(), spacing: KGMSpacing.sm), GridItem(.flexible(), spacing: KGMSpacing.sm)]

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: KGMSpacing.base) {
                accountSummaryCard
                orderTrackingCard
                quickChips
                menuGrid
                logoutButton
            }
            .padding(KGMSpacing.base)
            .padding(.bottom, KGMSpacing.xxxl)
        }
        .background(Color.kgmBackground.ignoresSafeArea())
        .navigationTitle("Daha Fazla")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await appState.refreshCurrentUser()
            openPendingRoute()
        }
        .onChange(of: appState.profileRoute) { _, _ in
            openPendingRoute()
        }
        .navigationDestination(isPresented: $showOrders) { OrdersView(initialOrderID: initialOrderID) }
        .navigationDestination(isPresented: $showAddresses) { AddressListView() }
        .navigationDestination(isPresented: $showFavorites) { FavoritesView() }
        .navigationDestination(isPresented: $showCoupons) { CouponsView() }
        .navigationDestination(isPresented: $showNotifications) { NotificationsView(initialNotificationID: initialNotificationID) }
        .navigationDestination(isPresented: $showSettings) { SettingsView() }
        .navigationDestination(isPresented: $showSupport) { SupportView() }
        .navigationDestination(isPresented: $showLegal) { LegalMenuView() }
        .alert("Çıkış Yap", isPresented: $showLogoutAlert) {
            Button("Çıkış Yap", role: .destructive) { appState.logout() }
            Button("İptal", role: .cancel) {}
        } message: {
            Text("Hesabınızdan çıkmak istediğinizden emin misiniz?")
        }
    }

    private var accountSummaryCard: some View {
        HStack(spacing: KGMSpacing.md) {
            ZStack {
                Circle().fill(Color.kgmPrimary.opacity(0.14)).frame(width: 72, height: 72)
                Text(initials)
                    .font(.system(size: 26, weight: .black))
                    .foregroundColor(.kgmPrimary)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(appState.currentUser?.fullName ?? "—")
                    .font(.kgmTitle2)
                    .foregroundColor(.kgmTextPrimary)
                Text(appState.currentUser?.email ?? "")
                    .font(.kgmCaption)
                    .foregroundColor(.kgmTextSecondary)
                    .lineLimit(1)
                Text(appState.currentUser?.phone ?? "")
                    .font(.kgmCaption)
                    .foregroundColor(.kgmTextSecondary)
                HStack(spacing: KGMSpacing.xs) {
                    if appState.currentUser?.isVIPActive == true {
                        Label("VIP · reklamsız", systemImage: "crown.fill")
                            .font(.kgmSmall.weight(.black))
                            .foregroundColor(.kgmWarning)
                    }
                    Text("\(appState.currentUser?.loyaltyPointsValue ?? 0) puan")
                        .font(.kgmSmall.weight(.bold))
                        .foregroundColor(.kgmPrimary)
                }
            }
            Spacer()
        }
        .padding(KGMSpacing.base)
        .background(Color.kgmCard)
        .clipShape(RoundedRectangle(cornerRadius: KGMRadius.card))
        .overlay(RoundedRectangle(cornerRadius: KGMRadius.card).stroke(Color.kgmBorder))
    }

    private var initials: String {
        guard let u = appState.currentUser else { return "—" }
        return String(u.firstName.prefix(1)) + String(u.lastName.prefix(1))
    }

    private func openPendingRoute() {
        guard let route = appState.profileRoute else { return }
        switch route {
        case .orders:
            initialOrderID = nil
            showOrders = true
        case .order(let id):
            initialOrderID = id
            showOrders = true
        case .notifications:
            initialNotificationID = nil
            showNotifications = true
        case .notification(let id):
            initialNotificationID = id
            showNotifications = true
        }
        appState.profileRoute = nil
    }

    private var quickChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: KGMSpacing.sm) {
                chip("Siparişlerim") { showOrders = true }
                chip("Adreslerim") { showAddresses = true }
                chip("Kuponlarım") { showCoupons = true }
                chip("Bildirimler") { showNotifications = true }
                chip("Google Haritalar") { openGoogleMaps() }
            }
            .padding(.horizontal, 1)
        }
    }

    private var menuGrid: some View {
        LazyVGrid(columns: columns, spacing: KGMSpacing.sm) {
            profileCard("Siparişlerim", icon: "bag.fill", color: .kgmPrimary) { showOrders = true }
            profileCard("Adreslerim", icon: "mappin.circle.fill", color: .kgmMapPin) { showAddresses = true }
            profileCard("Kuponlarım", icon: "ticket.fill", color: .kgmDiscount) { showCoupons = true }
            profileCard("Favoriler", icon: "heart.fill", color: .kgmError) { showFavorites = true }
            profileCard("Bildirimler", icon: "bell.fill", color: .kgmInfo) { showNotifications = true }
            profileCard("Google Haritalar", icon: "map.fill", color: .kgmMapPin) { openGoogleMaps() }
            profileCard("Destek", icon: "questionmark.bubble.fill", color: .kgmWarning) { showSupport = true }
            profileCard("Ayarlar", icon: "gearshape.fill", color: .kgmTextSecondary) { showSettings = true }
            profileCard("Yasal", icon: "doc.text.fill", color: .kgmSecurePayment) { showLegal = true }
        }
    }

    private var orderTrackingCard: some View {
        Button { showOrders = true } label: {
            HStack(spacing: KGMSpacing.md) {
                Image(systemName: "shippingbox.and.arrow.backward.fill")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 52, height: 52)
                    .background(Color.kgmPrimary)
                    .clipShape(RoundedRectangle(cornerRadius: KGMRadius.md))

                VStack(alignment: .leading, spacing: 4) {
                    Text("Siparişim Nerede?")
                        .font(.kgmHeadline)
                        .foregroundColor(.kgmTextPrimary)
                    Text("Hazırlık, kargo ve teslimat durumunu görüntüle.")
                        .font(.kgmCaption)
                        .foregroundColor(.kgmTextSecondary)
                        .multilineTextAlignment(.leading)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundColor(.kgmTextMuted)
            }
            .padding(KGMSpacing.base)
            .background(Color.kgmPrimary.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: KGMRadius.card))
            .overlay(RoundedRectangle(cornerRadius: KGMRadius.card).stroke(Color.kgmPrimary.opacity(0.22)))
        }
        .buttonStyle(.plain)
    }

    private func openGoogleMaps() {
        guard let url = URL(string: "https://www.google.com/maps/search/?api=1&query=Karacabey+Gross+Market") else { return }
        openURL(url)
    }

    private var logoutButton: some View {
        Button {
            showLogoutAlert = true
        } label: {
            HStack {
                Image(systemName: "rectangle.portrait.and.arrow.right")
                Text("Çıkış Yap")
            }
            .font(.kgmBodyMedium)
            .foregroundColor(.kgmError)
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background(Color.kgmCard)
            .clipShape(RoundedRectangle(cornerRadius: KGMRadius.card))
            .overlay(RoundedRectangle(cornerRadius: KGMRadius.card).stroke(Color.kgmBorder))
        }
        .buttonStyle(.plain)
    }

    private func chip(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.kgmCaptionMedium)
                .foregroundColor(.kgmPrimary)
                .padding(.horizontal, KGMSpacing.md)
                .frame(height: 36)
                .background(Color.kgmPrimary.opacity(0.10))
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private func profileCard(_ title: String, icon: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: KGMSpacing.md) {
                Image(systemName: icon)
                    .foregroundColor(.white)
                    .frame(width: 38, height: 38)
                    .background(color)
                    .clipShape(RoundedRectangle(cornerRadius: KGMRadius.sm))
                Text(title)
                    .font(.kgmBodyMedium)
                    .foregroundColor(.kgmTextPrimary)
                    .lineLimit(1)
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, minHeight: 118, alignment: .leading)
            .padding(KGMSpacing.md)
            .background(Color.kgmCard)
            .clipShape(RoundedRectangle(cornerRadius: KGMRadius.card))
            .overlay(RoundedRectangle(cornerRadius: KGMRadius.card).stroke(Color.kgmBorder))
        }
        .buttonStyle(.plain)
    }
}
