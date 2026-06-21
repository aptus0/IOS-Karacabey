import SwiftUI
import Combine

private enum DeepLinkedProductListRoute: Identifiable {
    case campaigns(UUID)
    case bestSellers(UUID)
    case newProducts(UUID)

    var id: String {
        switch self {
        case .campaigns(let uuid): return "campaigns-\(uuid.uuidString)"
        case .bestSellers(let uuid): return "best-sellers-\(uuid.uuidString)"
        case .newProducts(let uuid): return "new-products-\(uuid.uuidString)"
        }
    }

    var title: String {
        switch self {
        case .campaigns: return "Kampanyalar"
        case .bestSellers: return "Çok Satanlar"
        case .newProducts: return "Yeni Ürünler"
        }
    }

    var initialDiscountOnly: Bool {
        if case .campaigns = self { return true }
        return false
    }

    var initialBestSellersOnly: Bool {
        if case .bestSellers = self { return true }
        return false
    }

    var initialSearchText: String {
        if case .newProducts = self { return "yeni" }
        return ""
    }
}

struct MainTabView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var cartRepo = CartRepository.shared
    @StateObject private var favRepo  = FavoritesRepository.shared
    @State private var deepLinkedProduct: Product?
    @State private var deepLinkedProductList: DeepLinkedProductListRoute?

    var body: some View {
        TabView(selection: $appState.selectedTab) {
            HomeView()
                .tabItem { Label("Ana Sayfa",  systemImage: "house.fill") }
                .tag(AppTab.home)

            CategoriesView()
                .tabItem { Label("Kategoriler", systemImage: "square.grid.2x2.fill") }
                .tag(AppTab.categories)

            NavigationStack { QuickScanView() }
                .tabItem { Label("Hızlı Sipariş", systemImage: "qrcode.viewfinder") }
                .tag(AppTab.quickOrder)

            NavigationStack { CartView() }
                .tabItem {
                    Label("Sepet", systemImage: "cart.fill")
                }
                .badge(cartRepo.cart.itemCount > 0 ? "\(cartRepo.cart.itemCount)" : nil)
                .tag(AppTab.cart)

            NavigationStack { ProfileView() }
                .tabItem { Label("Daha Fazla", systemImage: "ellipsis.circle.fill") }
                .badge(appState.unreadNotificationCount > 0 ? "\(appState.unreadNotificationCount)" : nil)
                .tag(AppTab.more)
        }
        .tint(Color.kgmPrimary)
        .environmentObject(cartRepo)
        .environmentObject(favRepo)
        .task {
            try? await cartRepo.refreshCart()
            await appState.refreshUnreadNotificationCount()
        }
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 30_000_000_000)
                guard !Task.isCancelled else { return }
                await appState.refreshUnreadNotificationCount()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .kgmPushNotificationReceived)) { _ in
            Task { await appState.refreshUnreadNotificationCount() }
        }
        .onReceive(DeepLinkRouter.shared.$pendingURL.compactMap { $0 }) { url in
            handleDeepLink(url)
        }
        .sheet(item: $deepLinkedProduct) { product in
            NavigationStack { ProductDetailView(product: product) }
                .environmentObject(cartRepo)
                .environmentObject(favRepo)
        }
        .sheet(item: $deepLinkedProductList) { route in
            NavigationStack {
                ProductListView(
                    title: route.title,
                    initialDiscountOnly: route.initialDiscountOnly,
                    initialBestSellersOnly: route.initialBestSellersOnly,
                    initialSearchText: route.initialSearchText
                )
            }
            .environmentObject(cartRepo)
            .environmentObject(favRepo)
        }
    }

    private func handleDeepLink(_ url: URL) {
        let target = ([url.host, url.path].compactMap { $0 })
            .joined(separator: "/")
            .replacingOccurrences(of: "//", with: "/")
            .lowercased()
        let identifier = url.pathComponents.last(where: { $0 != "/" && !$0.isEmpty })
        defer { DeepLinkRouter.shared.consume() }

        if target.contains("campaign") || target.contains("kampanya") {
            appState.selectedTab = .home
            deepLinkedProductList = .campaigns(UUID())
        } else if target.contains("bestseller") || target.contains("best-seller") || target.contains("cok-satan") || target.contains("çok-satan") {
            appState.selectedTab = .home
            deepLinkedProductList = .bestSellers(UUID())
        } else if target.contains("products/new") || target.contains("new-products") || target.contains("yeni-urun") {
            appState.selectedTab = .home
            deepLinkedProductList = .newProducts(UUID())
        } else if target.contains("notification") {
            appState.openProfile(identifier.map(ProfileRoute.notification) ?? .notifications)
        } else if target.contains("order") || target.contains("cargo") || target.contains("shipment") {
            appState.openProfile(identifier.map(ProfileRoute.order) ?? .orders)
        } else if target.contains("cart") || target.contains("checkout") {
            appState.selectedTab = .cart
        } else if target.contains("product"), let identifier {
            appState.selectedTab = .categories
            Task {
                deepLinkedProduct = try? await ProductRepository.shared.getProduct(id: identifier)
            }
        } else if target.contains("categor") {
            appState.selectedTab = .categories
        } else if target.contains("favorite") || target.contains("coupon") || target.contains("support") {
            appState.selectedTab = .more
        } else {
            appState.selectedTab = .home
        }
    }
}
