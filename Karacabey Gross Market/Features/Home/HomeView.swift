import SwiftUI

private enum HomeProductRoute: Identifiable, Hashable {
    case all(UUID)
    case category(String, UUID)
    case discounted(UUID)
    case bestSellers(UUID)
    case newProducts(UUID)

    var id: String {
        switch self {
        case .all(let uuid): return "all-\(uuid.uuidString)"
        case .category(let id, let uuid): return "category-\(id)-\(uuid.uuidString)"
        case .discounted(let uuid): return "discounted-\(uuid.uuidString)"
        case .bestSellers(let uuid): return "best-sellers-\(uuid.uuidString)"
        case .newProducts(let uuid): return "new-products-\(uuid.uuidString)"
        }
    }
}

struct HomeView: View {
    @StateObject private var vm = HomeViewModel()
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var cartRepo: CartRepository
    @EnvironmentObject var favRepo: FavoritesRepository
    @State private var navigateToSearch = false
    @State private var selectedCategoryId: String?
    @State private var navigateToCategory = false
    @State private var navigateToAllProducts = false
    @State private var selectedProduct: Product?
    @State private var isDrawerOpen = false
    @State private var storyViewerStartIndex: Int? = nil
    @State private var navigateToScanner = false
    @State private var navigateToNotifications = false
    @State private var productRoute: HomeProductRoute?
    @State private var hiddenHomeProductIds = Set<String>()

    var body: some View {
        NavigationStack {
            ZStack {
                Color.kgmBackground.ignoresSafeArea()

                if shouldShowInitialLoading {
                    KGMHomeSkeletonView()
                } else {
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 0) {
                            headerView
                            searchBarSection
                            if !vm.banners.isEmpty { heroSection }
                            if !vm.categories.isEmpty { categoriesSection }
                            if vm.loyaltySummary != nil { loyaltySection }
                            if !vm.stories.isEmpty { storiesSection }
                            if !vm.discountedProducts.isEmpty { campaignSection }
                            if !vm.recentPurchases.isEmpty { recentPurchasesSection }
                            if !vm.couponOffers.isEmpty { couponOffersSection }
                            if !vm.personalizedRecommendations.products.isEmpty { personalizedRecommendationsSection }
                            if !vm.popularProducts.isEmpty { popularSection }
                            if !vm.allProducts.isEmpty { allProductsSection }
                            if shouldShowEmptyHome { emptyHomeSection }
                            Spacer(minLength: KGMSpacing.xxxl + 24)
                        }
                    }
                    .refreshable {
                        await vm.loadData()
                        await appState.refreshUnreadNotificationCount()
                    }
                }

                if isDrawerOpen {
                    KGMMobileCategoryDrawer(
                        categories: vm.categories,
                        selectedCity: vm.selectedCity,
                        onClose: closeDrawer,
                        onCategory: { category in
                            openCategory(category.id)
                            closeDrawer()
                        },
                        onShortcut: { deepLink in
                            handleHomeShortcut(deepLink)
                            closeDrawer()
                        }
                    )
                    .transition(.opacity)
                    .zIndex(10)
                }
            }
            .navigationBarHidden(true)
            .navigationDestination(isPresented: $navigateToSearch) { SearchView() }
            .navigationDestination(isPresented: $navigateToCategory) {
                if let selectedCategoryId {
                    ProductListView(categoryId: selectedCategoryId)
                }
            }
            .navigationDestination(isPresented: $navigateToAllProducts) {
                ProductListView(title: "Tüm Ürünler")
            }
            .navigationDestination(item: $productRoute) { route in
                switch route {
                case .all:
                    ProductListView(title: "Tüm Ürünler")
                case .category(let categoryId, _):
                    ProductListView(categoryId: categoryId)
                case .discounted:
                    ProductListView(title: "Kampanyalar", initialDiscountOnly: true)
                case .bestSellers:
                    ProductListView(title: "Çok Satanlar", initialBestSellersOnly: true)
                case .newProducts:
                    ProductListView(title: "Yeni Ürünler", initialSearchText: "yeni")
                }
            }
            .navigationDestination(isPresented: $navigateToScanner) {
                QuickScanView()
            }
            .navigationDestination(isPresented: $navigateToNotifications) {
                NotificationsView()
            }
            .navigationDestination(item: $selectedProduct) { product in
                ProductDetailView(product: product)
            }
            .fullScreenCover(isPresented: Binding(
                get: { storyViewerStartIndex != nil },
                set: { if !$0 { storyViewerStartIndex = nil } }
            )) {
                if let idx = storyViewerStartIndex {
                    StoryViewerView(
                        stories: vm.stories,
                        startIndex: .constant(idx),
                        onViewed: { story in vm.markStoryViewed(story.id) }
                    )
                }
            }
        }
        .task { await vm.loadData() }
        .task { await vm.releaseInitialLoadingIfNeeded() }
        .task { await appState.refreshUnreadNotificationCount() }
    }

    private var storiesSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text("Hikayeler")
                    .font(.system(size: 17, weight: .heavy))
                    .foregroundColor(.kgmTextPrimary)
                Text("·")
                    .foregroundColor(.kgmTextMuted)
                Text("Bugünün öne çıkanları")
                    .font(.kgmCaptionMedium)
                    .foregroundColor(.kgmTextSecondary)
                Spacer()
            }
            .padding(.horizontal, KGMSpacing.base)
            .padding(.top, KGMSpacing.md)

            KGMStoryBar(stories: vm.stories) { story in
                guard let idx = vm.stories.firstIndex(where: { $0.id == story.id }) else { return }
                storyViewerStartIndex = idx
            }
        }
        .padding(.bottom, 2)
        .background(
            LinearGradient(
                colors: [Color.kgmCard, Color.kgmPrimary.opacity(0.045)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .overlay(alignment: .bottom) { Rectangle().fill(Color.kgmBorder.opacity(0.75)).frame(height: 1) }
    }

    private var shouldShowInitialLoading: Bool {
        vm.isLoading && !vm.hasLoadedOnce && vm.allProducts.isEmpty && vm.popularProducts.isEmpty && vm.categories.isEmpty
    }

    private var shouldShowEmptyHome: Bool {
        vm.hasLoadedOnce && vm.allProducts.isEmpty && vm.popularProducts.isEmpty && vm.categories.isEmpty
    }

    private var headerView: some View {
        VStack(spacing: 0) {
            HStack(spacing: KGMSpacing.md) {
                iconButton("line.3.horizontal") {
                    withAnimation(.easeInOut(duration: 0.22)) { isDrawerOpen = true }
                }

                KGMWordmark()
                    .frame(maxWidth: .infinity, alignment: .leading)

                Button {
                    navigateToNotifications = true
                } label: {
                    ZStack(alignment: .topTrailing) {
                        iconPlain("bell.fill")
                        if appState.unreadNotificationCount > 0 {
                            Text(appState.unreadNotificationCount > 99 ? "99+" : "\(appState.unreadNotificationCount)")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white)
                                .frame(minWidth: 18, minHeight: 18)
                                .padding(.horizontal, appState.unreadNotificationCount > 9 ? 3 : 0)
                                .background(Color.kgmPrimary)
                                .clipShape(Capsule())
                                .offset(x: 4, y: -4)
                        }
                    }
                }
                .buttonStyle(.plain)

                Button {
                    appState.selectedTab = .cart
                } label: {
                    ZStack(alignment: .topTrailing) {
                        iconPlain("cart.fill")
                        if cartRepo.cart.itemCount > 0 {
                            Text("\(cartRepo.cart.itemCount)")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white)
                                .frame(minWidth: 18, minHeight: 18)
                                .background(Color.kgmPrimary)
                                .clipShape(Circle())
                                .offset(x: 3, y: -3)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, KGMSpacing.base)
            .padding(.top, KGMSpacing.md)
            .padding(.bottom, KGMSpacing.sm)
        }
        .background(Color.kgmBackground)
    }

    private var searchBarSection: some View {
        HStack(spacing: KGMSpacing.sm) {
            Button { navigateToSearch = true } label: {
                HStack(spacing: KGMSpacing.sm) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundColor(.kgmTextMuted)
                    Text("Ürün, kategori veya marka ara...")
                        .font(.kgmBody)
                        .foregroundColor(.kgmTextSecondary)
                        .lineLimit(1)
                    Spacer()
                }
                .padding(.horizontal, KGMSpacing.md)
                .frame(height: 56)
                .background(Color.kgmCardElevated)
                .clipShape(RoundedRectangle(cornerRadius: KGMRadius.md))
                .overlay(RoundedRectangle(cornerRadius: KGMRadius.md).stroke(Color.kgmBorder, lineWidth: 1))
            }
            .buttonStyle(.plain)

            Button { navigateToScanner = true } label: {
                Image(systemName: "qrcode.viewfinder")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 60, height: 56)
                    .background(Color.kgmPrimary)
                    .clipShape(RoundedRectangle(cornerRadius: KGMRadius.md))
                    .shadow(color: Color.kgmPrimary.opacity(0.22), radius: 10, x: 0, y: 5)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, KGMSpacing.base)
        .padding(.bottom, KGMSpacing.md)
        .background(Color.kgmBackground)
    }

    private var heroSection: some View {
        KGMBannerSlider(banners: vm.banners) { banner in
            handleBannerTap(banner)
        }
        .padding(.bottom, KGMSpacing.sm)
    }

    private var emptyHomeSection: some View {
        KGMEmptyStateView(
            icon: "wifi.exclamationmark",
            title: "Ürünler yüklenemedi",
            message: vm.errorMessage ?? "Bağlantıyı kontrol edip tekrar deneyin.",
            buttonTitle: "Tekrar Dene"
        ) {
            Task { await vm.loadData() }
        }
        .frame(minHeight: 320)
        .background(Color.kgmCard)
        .padding(.top, KGMSpacing.sm)
    }

    private var categoriesSection: some View {
        VStack(spacing: KGMSpacing.md) {
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: KGMSpacing.sm) {
                    ForEach(vm.categories.prefix(5)) { category in
                        HomeCategoryTile(category: category) {
                            openCategory(category.id)
                        }
                        .frame(width: 104)
                    }
                    HomeAllCategoriesTile {
                        appState.selectedTab = .categories
                    }
                    .frame(width: 104)
                }
                .padding(.horizontal, KGMSpacing.base)
            }
        }
        .padding(.vertical, KGMSpacing.base)
        .background(Color.kgmCard)
        .padding(.top, KGMSpacing.sm)
    }

    private var displayedDiscountedProducts: [Product] {
        homeProducts(from: vm.discountedProducts, limit: 8)
    }

    private var displayedPopularProducts: [Product] {
        homeProducts(from: vm.popularProducts, limit: 4)
    }

    private var displayedPersonalizedProducts: [Product] {
        homeProducts(from: vm.personalizedRecommendations.products, limit: 12)
    }

    private var displayedAllProducts: [Product] {
        homeProducts(from: vm.allProducts, limit: 24)
    }

    private func homeProducts(from products: [Product], limit: Int) -> [Product] {
        Array(products.filter { !hiddenHomeProductIds.contains($0.id) }.prefix(limit))
    }

    private var campaignSection: some View {
        VStack(alignment: .leading, spacing: KGMSpacing.md) {
            sectionHeader(
                icon: "flame.fill",
                title: "Size Özel Fırsatlar",
                subtitle: "Taze fırsatlar ve indirimli ürünler",
                iconBackground: Color.kgmPrimary,
                actionTitle: "Tümünü Gör"
            ) {
                openDiscountedProducts()
            }

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: KGMSpacing.sm) {
                    ForEach(displayedDiscountedProducts) { product in
                        clearHomeProductCard(product)
                            .frame(width: 190)
                    }
                }
                .padding(.horizontal, KGMSpacing.base)
            }
        }
        .padding(.vertical, KGMSpacing.md)
        .background(Color.kgmBackground)
        .padding(.top, KGMSpacing.sm)
    }


    private var loyaltySection: some View {
        Group {
            if let loyalty = vm.loyaltySummary {
                VStack(alignment: .leading, spacing: KGMSpacing.md) {
                    HStack(alignment: .top, spacing: KGMSpacing.md) {
                        Image(systemName: "crown.fill")
                            .font(.system(size: 19, weight: .black))
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                            .background(Color.kgmPrimary)
                            .clipShape(RoundedRectangle(cornerRadius: 14))

                        VStack(alignment: .leading, spacing: 5) {
                            Text("Mobil Puan")
                                .font(.system(size: 18, weight: .black))
                                .foregroundColor(.kgmTextPrimary)
                            Text("\(loyalty.levelTitle) · \(loyalty.balanceLabel)")
                                .font(.kgmCaptionMedium)
                                .foregroundColor(.kgmTextSecondary)
                                .lineLimit(1)
                        }

                        Spacer()

                        Text(loyalty.nextRewardLabel)
                            .font(.kgmSmall.weight(.bold))
                            .foregroundColor(.kgmPrimary)
                            .padding(.horizontal, 9)
                            .frame(height: 28)
                            .background(Color.kgmPrimary.opacity(0.08))
                            .clipShape(Capsule())
                    }

                    VStack(alignment: .leading, spacing: KGMSpacing.xs) {
                        ProgressView(value: loyalty.progressValue)
                            .tint(.kgmPrimary)
                        HStack {
                            Text(loyalty.spendToNextLabel)
                            Spacer()
                            Text("%\(Int(loyalty.progressPercent.rounded()))")
                        }
                        .font(.kgmSmall)
                        .foregroundColor(.kgmTextMuted)
                    }

                    if !loyalty.rewards.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: KGMSpacing.sm) {
                                ForEach(loyalty.rewards.prefix(3)) { reward in
                                    LoyaltyRewardChip(reward: reward)
                                }
                            }
                        }
                    }
                }
                .padding(KGMSpacing.md)
                .background(Color.kgmCard)
                .clipShape(RoundedRectangle(cornerRadius: KGMRadius.card))
                .overlay(RoundedRectangle(cornerRadius: KGMRadius.card).stroke(Color.kgmBorder.opacity(0.9)))
                .padding(.horizontal, KGMSpacing.base)
                .padding(.vertical, KGMSpacing.sm)
            }
        }
    }

    private var personalizedRecommendationsSection: some View {
        VStack(alignment: .leading, spacing: KGMSpacing.md) {
            sectionHeader(
                icon: "sparkles",
                title: vm.personalizedRecommendations.title,
                subtitle: vm.personalizedRecommendations.subtitle,
                iconBackground: Color.kgmInfo,
                actionTitle: "Keşfet"
            ) {
                openAllProducts()
            }

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: KGMSpacing.sm) {
                    ForEach(displayedPersonalizedProducts) { product in
                        HomeQuickProductCard(
                            product: product,
                            onAdd: { cartRepo.addToCart(product, quantity: 1) },
                            onTap: { selectedProduct = product }
                        )
                        .frame(width: 148)
                    }
                }
                .padding(.horizontal, KGMSpacing.base)
            }
        }
        .padding(.vertical, KGMSpacing.md)
        .background(Color.kgmCard)
        .padding(.top, KGMSpacing.sm)
    }

    private var recentPurchasesSection: some View {
        VStack(alignment: .leading, spacing: KGMSpacing.md) {
            sectionHeader(
                icon: "clock.arrow.circlepath",
                title: "Son Aldıklarım",
                subtitle: "Daha önce aldığınız ürünleri hızlıca ekleyin",
                iconBackground: Color.kgmInfo,
                actionTitle: "Siparişler"
            ) {
                appState.openProfile(.orders)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: KGMSpacing.sm) {
                    ForEach(vm.recentPurchases.prefix(12)) { product in
                        HomeQuickProductCard(
                            product: product,
                            onAdd: { cartRepo.addToCart(product, quantity: 1) },
                            onTap: { selectedProduct = product }
                        )
                        .frame(width: 148)
                    }
                }
                .padding(.horizontal, KGMSpacing.base)
            }
        }
        .padding(.vertical, KGMSpacing.md)
        .background(Color.kgmCard)
        .padding(.top, KGMSpacing.sm)
    }

    private var couponOffersSection: some View {
        VStack(alignment: .leading, spacing: KGMSpacing.md) {
            sectionHeader(
                icon: "ticket.fill",
                title: "Kuponlarım",
                subtitle: "Sepette kullanabileceğiniz aktif fırsatlar",
                iconBackground: Color.kgmDiscount,
                actionTitle: "Sepete Git"
            ) {
                appState.selectedTab = .cart
            }

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: KGMSpacing.sm) {
                    ForEach(vm.couponOffers) { coupon in
                        HomeCouponOfferCard(coupon: coupon) {
                            cartRepo.applyCoupon(coupon.code)
                            appState.showToast("\(coupon.code) kuponu sepete uygulandı")
                        }
                        .frame(width: 230)
                    }
                }
                .padding(.horizontal, KGMSpacing.base)
            }
        }
        .padding(.vertical, KGMSpacing.md)
        .background(Color.kgmBackground)
        .padding(.top, KGMSpacing.sm)
    }

    private var popularSection: some View {
        VStack(alignment: .leading, spacing: KGMSpacing.md) {
            sectionHeader(
                icon: "star.fill",
                title: "Çok Satanlar",
                subtitle: "Karacabey'in favori ürünleri",
                iconBackground: Color.kgmTextPrimary,
                actionTitle: "Tümünü Gör"
            ) {
                openAllProducts()
            }

            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: KGMSpacing.sm),
                GridItem(.flexible(), spacing: KGMSpacing.sm)
            ], spacing: KGMSpacing.sm) {
                ForEach(displayedPopularProducts) { product in
                    clearHomeProductCard(product)
                }
            }
            .padding(.horizontal, KGMSpacing.base)
        }
        .padding(.vertical, KGMSpacing.md)
        .background(Color.kgmBackground)
        .padding(.top, KGMSpacing.sm)
    }

    private var productGridColumns: [GridItem] {
        [
            GridItem(.flexible(minimum: 0, maximum: .infinity), spacing: KGMSpacing.sm, alignment: .top),
            GridItem(.flexible(minimum: 0, maximum: .infinity), spacing: KGMSpacing.sm, alignment: .top)
        ]
    }

    private var allProductsSection: some View {
        VStack(alignment: .leading, spacing: KGMSpacing.md) {
            sectionHeader(
                icon: "basket.fill",
                title: "Market Reyonu",
                subtitle: "\(vm.allProducts.count) ürün listeleniyor",
                iconBackground: Color.kgmPrimary,
                actionTitle: "Tümü"
            ) {
                openAllProducts()
            }

            LazyVGrid(columns: productGridColumns, alignment: .center, spacing: KGMSpacing.sm) {
                ForEach(displayedAllProducts) { product in
                    clearHomeProductCard(product)
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 286, alignment: .top)
                }
            }
            .padding(.horizontal, KGMSpacing.base)

            if vm.allProducts.count > 24 {
                Button {
                    openAllProducts()
                } label: {
                    HStack(spacing: KGMSpacing.xs) {
                        Text("Tüm \(vm.allProducts.count) ürünü görüntüle")
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .bold))
                    }
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(Color.kgmPrimary)
                    .clipShape(RoundedRectangle(cornerRadius: KGMRadius.md))
                }
                .buttonStyle(.plain)
                .padding(.horizontal, KGMSpacing.base)
                .padding(.top, KGMSpacing.xs)
            }
        }
        .padding(.vertical, KGMSpacing.md)
        .background(Color.kgmCard)
        .padding(.top, KGMSpacing.sm)
    }

    private func sectionHeader(
        icon: String,
        title: String,
        subtitle: String,
        iconBackground: Color,
        actionTitle: String,
        action: @escaping () -> Void
    ) -> some View {
        HStack(spacing: KGMSpacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .black))
                .foregroundColor(.white)
                .frame(width: 30, height: 30)
                .background(iconBackground)
                .clipShape(RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 17, weight: .heavy))
                    .foregroundColor(.kgmTextPrimary)
                    .lineLimit(1)
                Text(subtitle)
                    .font(.kgmSmall)
                    .foregroundColor(.kgmTextSecondary)
                    .lineLimit(1)
            }

            Spacer()

            Button(action: action) {
                HStack(spacing: 4) {
                    Text(actionTitle)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .bold))
                }
                .font(.kgmCaptionMedium)
                .foregroundColor(.kgmPrimary)
                .padding(.horizontal, KGMSpacing.sm)
                .frame(height: 34)
                .background(Color.kgmPrimary.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: KGMRadius.md))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, KGMSpacing.base)
    }

    private func addHomeProductToCart(_ product: Product) {
        cartRepo.addToCart(product)
        withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
            _ = hiddenHomeProductIds.insert(product.id)
        }
    }

    private func clearHomeProductCard(_ product: Product) -> some View {
        KGMProductCard(
            product: product,
            onAddToCart: { addHomeProductToCart(product) },
            onFavorite: { favRepo.toggle(product) },
            onTap: { selectedProduct = product }
        )
        .frame(maxWidth: .infinity, alignment: .top)
    }

    private func openAllProducts() {
        AdMobService.shared.performAfterOptionalInterstitial {
            productRoute = .all(UUID())
        }
    }

    private func openCategory(_ categoryId: String) {
        AdMobService.shared.performAfterOptionalInterstitial {
            productRoute = .category(categoryId, UUID())
        }
    }

    private func openDiscountedProducts() {
        AdMobService.shared.performAfterOptionalInterstitial {
            productRoute = .discounted(UUID())
        }
    }

    private func openBestSellers() {
        AdMobService.shared.performAfterOptionalInterstitial {
            productRoute = .bestSellers(UUID())
        }
    }

    private func openNewProducts() {
        AdMobService.shared.performAfterOptionalInterstitial {
            productRoute = .newProducts(UUID())
        }
    }

    private func handleBannerTap(_ banner: BannerItem) {
        guard let actionURL = banner.actionURL?.trimmingCharacters(in: .whitespacesAndNewlines),
              !actionURL.isEmpty else {
            openAllProducts()
            return
        }
        handleHomeShortcut(actionURL)
    }

    private func handleHomeShortcut(_ rawValue: String) {
        let normalized = rawValue.lowercased()

        if normalized.contains("campaign") || normalized.contains("kampanya") {
            openDiscountedProducts()
        } else if normalized.contains("bestseller") || normalized.contains("best-seller") || normalized.contains("cok-satan") || normalized.contains("çok-satan") {
            openBestSellers()
        } else if normalized.contains("products/new") || normalized.contains("yeni-urun") || normalized.contains("new-products") {
            openNewProducts()
        } else if normalized.contains("categor"), let categoryId = deepLinkIdentifier(from: rawValue) {
            openCategory(categoryId)
        } else {
            DeepLinkRouter.shared.open(rawValue)
        }
    }

    private func deepLinkIdentifier(from rawValue: String) -> String? {
        guard let url = URL(string: rawValue) else { return nil }
        return url.pathComponents.last(where: { $0 != "/" && !$0.isEmpty })
    }

    private func closeDrawer() {
        withAnimation(.easeInOut(duration: 0.22)) { isDrawerOpen = false }
    }

    private func iconButton(_ systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) { iconCircle(systemName) }
            .buttonStyle(.plain)
    }

    private func iconCircle(_ systemName: String) -> some View {
        Image(systemName: systemName)
            .font(.system(size: 18, weight: .bold))
            .foregroundColor(.kgmTextPrimary)
            .frame(width: 42, height: 42)
            .background(Color.kgmCard)
            .clipShape(Circle())
            .overlay(Circle().stroke(Color.kgmBorder))
    }

    private func iconPlain(_ systemName: String) -> some View {
        Image(systemName: systemName)
            .font(.system(size: 22, weight: .semibold))
            .foregroundColor(.kgmTextPrimary)
            .frame(width: 34, height: 42)
    }

}

private struct KGMWordmark: View {
    var body: some View {
        HStack(spacing: KGMSpacing.sm) {
            Image(systemName: "basket.fill")
                .font(.system(size: 18, weight: .black))
                .foregroundColor(.white)
                .frame(width: 36, height: 36)
                .background(Color.kgmPrimary)
                .clipShape(RoundedRectangle(cornerRadius: KGMRadius.sm))

            VStack(alignment: .leading, spacing: 1) {
                Text("Karacabey")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.kgmTextMuted)
                HStack(spacing: 4) {
                    Text("Gross Market")
                        .font(.system(size: 17, weight: .black))
                        .foregroundColor(.kgmTextPrimary)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.kgmTextMuted)
                }
            }
        }
        .minimumScaleFactor(0.82)
        .lineLimit(1)
    }
}

private struct HomeCategoryTile: View {
    let category: Category
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: KGMSpacing.xs) {
                Text(emoji)
                    .font(.system(size: 30))
                    .frame(width: 64, height: 64)
                    .background(tint.opacity(0.12))
                    .clipShape(Circle())

                Text(category.name)
                    .font(.kgmCaptionMedium)
                    .foregroundColor(.kgmTextPrimary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .frame(minHeight: 34, alignment: .top)
            }
            .padding(.vertical, KGMSpacing.sm)
            .frame(height: 112)
            .frame(maxWidth: .infinity)
            .background(Color.kgmCard)
        }
        .buttonStyle(.plain)
    }

    private var emoji: String {
        let value = "\(category.slug) \(category.name)".lowercased()
        if value.contains("meyve") || value.contains("sebze") { return "🍎" }
        if value.contains("süt") || value.contains("sut") || value.contains("peynir") || value.contains("kahvaltı") { return "🧀" }
        if value.contains("et") || value.contains("tavuk") || value.contains("balık") || value.contains("balik") { return "🥩" }
        if value.contains("temizlik") || value.contains("deterjan") { return "🧼" }
        if value.contains("bakım") || value.contains("bakim") || value.contains("kozmetik") { return "🧴" }
        if value.contains("içecek") || value.contains("icecek") || value.contains("su") { return "🧃" }
        if value.contains("atıştırmalık") || value.contains("atistirmalik") || value.contains("çikolata") { return "🍫" }
        if value.contains("fırın") || value.contains("ekmek") || value.contains("pastane") { return "🥖" }
        if value.contains("temel") || value.contains("gıda") || value.contains("gida") || value.contains("yağ") { return "🍚" }
        if value.contains("dondurma") { return "🍦" }
        if value.contains("bebek") || value.contains("cocuk") || value.contains("çocuk") { return "🍼" }
        if value.contains("evcil") || value.contains("kedi") || value.contains("köpek") { return "🐾" }
        if value.contains("ev") || value.contains("yaşam") || value.contains("yasam") { return "🛋️" }
        if value.contains("kırtasiye") || value.contains("kirtasiye") { return "✏️" }
        if value.contains("oyuncak") { return "🧸" }
        if value.contains("elektronik") { return "🔌" }
        if value.contains("kampanya") || value.contains("indirim") { return "🎁" }
        return "🛒"
    }

    private var tint: Color {
        switch category.slug {
        case "meyve-sebze": return .green
        case "et-tavuk-sarkuteri": return .red
        case "sut-kahvaltilik": return .blue
        case "icecek": return .cyan
        case "temizlik": return .purple
        case "kisisel-bakim": return .pink
        case "bebek": return .orange
        case "ev-yasam": return .indigo
        default: return .kgmPrimary
        }
    }
}

private struct HomeAllCategoriesTile: View {
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: KGMSpacing.xs) {
                Image(systemName: "square.grid.2x2.fill")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.kgmPrimary)
                    .frame(width: 64, height: 64)
                    .background(Color.kgmPrimary.opacity(0.10))
                    .clipShape(Circle())

                Text("Tüm Kategoriler")
                    .font(.kgmCaptionMedium)
                    .foregroundColor(.kgmTextPrimary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .frame(minHeight: 34, alignment: .top)
            }
            .padding(.vertical, KGMSpacing.sm)
            .frame(height: 112)
            .frame(maxWidth: .infinity)
            .background(Color.kgmCard)
        }
        .buttonStyle(.plain)
    }
}

private struct HomeQuickProductCard: View {
    let product: Product
    let onAdd: () -> Void
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: KGMSpacing.xs) {
                KGMProductImage(
                    url: product.resolvedImageURL,
                    height: 92,
                    cornerRadius: KGMRadius.md,
                    horizontalPadding: 6,
                    verticalPadding: 6,
                    zoom: 1.04,
                    backgroundColor: .white
                )

                Text(product.brand.isEmpty ? "KGM" : product.brand)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(.kgmTextMuted)
                    .lineLimit(1)

                Text(product.name)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.kgmTextPrimary)
                    .lineLimit(2)
                    .frame(minHeight: 34, alignment: .topLeading)

                HStack(spacing: 4) {
                    Text(product.effectivePrice.formattedAsTurkishLira)
                        .font(.system(size: 13, weight: .black, design: .rounded))
                        .foregroundColor(.kgmPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)
                    Spacer(minLength: 0)
                    Button(action: onAdd) {
                        Image(systemName: "plus")
                            .font(.system(size: 12, weight: .heavy))
                            .foregroundColor(.white)
                            .frame(width: 30, height: 30)
                            .background(product.isInStock ? Color.kgmPrimary : Color.kgmTextMuted)
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .disabled(!product.isInStock)
                }
            }
            .padding(KGMSpacing.sm)
            .background(Color.kgmCardElevated)
            .clipShape(RoundedRectangle(cornerRadius: KGMRadius.card))
            .overlay(RoundedRectangle(cornerRadius: KGMRadius.card).stroke(Color.kgmBorder.opacity(0.9)))
        }
        .buttonStyle(.plain)
    }
}

private struct HomeCouponOfferCard: View {
    let coupon: CustomerCouponOffer
    let onApply: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: KGMSpacing.sm) {
            HStack(alignment: .top) {
                Image(systemName: "ticket.fill")
                    .font(.system(size: 17, weight: .black))
                    .foregroundColor(.white)
                    .frame(width: 38, height: 38)
                    .background(Color.kgmPrimary)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                Spacer()
                Text(coupon.code)
                    .font(.system(size: 13, weight: .black, design: .monospaced))
                    .foregroundColor(.kgmPrimary)
                    .padding(.horizontal, 9)
                    .frame(height: 28)
                    .background(Color.kgmPrimary.opacity(0.08))
                    .clipShape(Capsule())
            }

            Text(coupon.discountLabel)
                .font(.system(size: 18, weight: .black))
                .foregroundColor(.kgmTextPrimary)
                .lineLimit(1)
            Text(coupon.subtitle)
                .font(.kgmCaption)
                .foregroundColor(.kgmTextSecondary)
                .lineLimit(2)

            Button(action: onApply) {
                Text("Kuponu Uygula")
                    .font(.kgmCaptionMedium)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 38)
                    .background(Color.kgmPrimary)
                    .clipShape(RoundedRectangle(cornerRadius: KGMRadius.md))
            }
            .buttonStyle(.plain)
        }
        .padding(KGMSpacing.md)
        .background(Color.kgmCard)
        .clipShape(RoundedRectangle(cornerRadius: KGMRadius.card))
        .overlay(RoundedRectangle(cornerRadius: KGMRadius.card).stroke(Color.kgmBorder.opacity(0.9)))
    }
}

private struct LoyaltyRewardChip: View {
    let reward: CustomerLoyaltyReward

    var body: some View {
        HStack(spacing: KGMSpacing.xs) {
            Image(systemName: reward.isUnlocked ? "checkmark.seal.fill" : "lock.fill")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(reward.isUnlocked ? .kgmPrimary : .kgmTextMuted)
            VStack(alignment: .leading, spacing: 1) {
                Text(reward.title)
                    .font(.kgmSmall.weight(.bold))
                    .foregroundColor(.kgmTextPrimary)
                    .lineLimit(1)
                Text(reward.subtitle)
                    .font(.system(size: 10))
                    .foregroundColor(.kgmTextMuted)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, KGMSpacing.sm)
        .frame(height: 44)
        .background(reward.isUnlocked ? Color.kgmPrimary.opacity(0.08) : Color.kgmCardElevated)
        .clipShape(Capsule())
        .overlay(Capsule().stroke(reward.isUnlocked ? Color.kgmPrimary.opacity(0.18) : Color.kgmBorder, lineWidth: 1))
    }
}

private struct KGMMobileCategoryDrawer: View {
    let categories: [Category]
    let selectedCity: String
    let onClose: () -> Void
    let onCategory: (Category) -> Void
    let onShortcut: (String) -> Void
    @State private var query = ""

    private var filteredCategories: [Category] {
        guard !query.isEmpty else { return categories }
        return categories.filter { $0.name.localizedCaseInsensitiveContains(query) }
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Color.black.opacity(0.32)
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                    .onTapGesture(perform: onClose)

                VStack(alignment: .leading, spacing: KGMSpacing.base) {
                    HStack {
                        Text("Tüm Reyonlar")
                            .font(.kgmTitle2)
                            .foregroundColor(.kgmTextPrimary)
                        Spacer()
                        Button(action: onClose) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(.kgmTextPrimary)
                                .frame(width: 44, height: 44)
                                .background(Color.kgmCardElevated)
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                    }

                    HStack(spacing: KGMSpacing.sm) {
                        Image(systemName: "magnifyingglass").foregroundColor(.kgmTextMuted)
                        TextField("Reyon ara", text: $query).font(.kgmBody)
                    }
                    .padding(.horizontal, KGMSpacing.md)
                    .frame(height: 46)
                    .background(Color.kgmCardElevated)
                    .clipShape(Capsule())

                    HStack(spacing: KGMSpacing.sm) {
                        Image(systemName: "location.fill").foregroundColor(.kgmPrimary)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Teslimat konumu").font(.kgmSmall).foregroundColor(.kgmTextMuted)
                            Text(selectedCity).font(.kgmCaptionMedium).foregroundColor(.kgmTextPrimary)
                        }
                    }
                    .padding(KGMSpacing.md)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.kgmPrimary.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: KGMRadius.md))

                    HStack(spacing: KGMSpacing.sm) {
                        drawerShortcut("Kampanyalar", icon: "tag.fill", link: "kgm://campaigns")
                        drawerShortcut("Çok Satanlar", icon: "flame.fill", link: "kgm://products/bestsellers")
                        drawerShortcut("Yeni Ürünler", icon: "sparkles", link: "kgm://products/new")
                    }

                    ScrollView(showsIndicators: false) {
                        LazyVStack(spacing: KGMSpacing.xs) {
                            ForEach(filteredCategories) { category in
                                Button {
                                    onCategory(category)
                                } label: {
                                    HStack(spacing: KGMSpacing.md) {
                                        Image(systemName: category.iconName)
                                            .foregroundColor(.kgmPrimary)
                                            .frame(width: 34, height: 34)
                                            .background(Color.kgmPrimary.opacity(0.10))
                                            .clipShape(Circle())
                                        Text(category.name).font(.kgmBodyMedium).foregroundColor(.kgmTextPrimary)
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                            .font(.system(size: 12, weight: .semibold))
                                            .foregroundColor(.kgmTextMuted)
                                    }
                                    .padding(.vertical, KGMSpacing.sm)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.bottom, KGMSpacing.xl)
                    }
                }
                .padding(.top, proxy.safeAreaInsets.top + KGMSpacing.sm)
                .padding(.bottom, max(proxy.safeAreaInsets.bottom, KGMSpacing.base))
                .padding(.horizontal, KGMSpacing.base)
                .frame(width: min(proxy.size.width * 0.86, 360))
                .frame(maxHeight: .infinity, alignment: .top)
                .background(Color.kgmCard)
                .transition(.move(edge: .leading))
                .gesture(
                    DragGesture(minimumDistance: 18)
                        .onEnded { value in
                            if value.translation.width < -60 {
                                onClose()
                            }
                        }
                )
            }
        }
    }

    private func drawerShortcut(_ title: String, icon: String, link: String) -> some View {
        Button { onShortcut(link) } label: {
            VStack(spacing: KGMSpacing.xs) {
                Image(systemName: icon).foregroundColor(.kgmPrimary)
                Text(title)
                    .font(.kgmSmall)
                    .foregroundColor(.kgmTextPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, KGMSpacing.sm)
            .background(Color.kgmCardElevated)
            .clipShape(RoundedRectangle(cornerRadius: KGMRadius.md))
        }
        .buttonStyle(.plain)
    }
}
