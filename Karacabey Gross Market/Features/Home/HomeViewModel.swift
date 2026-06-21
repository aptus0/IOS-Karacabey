import Foundation
import Combine

@MainActor
final class HomeViewModel: ObservableObject {
    @Published var allProducts: [Product] = []
    @Published var popularProducts: [Product] = []
    @Published var discountedProducts: [Product] = []
    @Published var categories: [Category] = []
    @Published var banners: [BannerItem] = []
    @Published var stories: [Story] = []
    @Published var recentPurchases: [Product] = []
    @Published var couponOffers: [CustomerCouponOffer] = []
    @Published var loyaltySummary: CustomerLoyaltySummary?
    @Published var personalizedRecommendations = PersonalizedRecommendationsResponse.empty
    @Published var isLoading = false
    @Published var hasLoadedOnce = false
    @Published var errorMessage: String?
    @Published var selectedCity = "Karacabey, Bursa"

    private let productRepo = ProductRepository.shared
    private let campaignRepo = CampaignRepository.shared
    private let preload = PreloadService.shared
    private let shoppingRepo = ShoppingExperienceRepository.shared
    private var cancellables = Set<AnyCancellable>()

    init() {
        bindPreload()
        hydrateFromPreload()
    }

    private func bindPreload() {
        preload.$allProducts
            .receive(on: RunLoop.main)
            .sink { [weak self] in self?.allProducts = $0 }
            .store(in: &cancellables)

        preload.$popularProducts
            .receive(on: RunLoop.main)
            .sink { [weak self] in self?.popularProducts = $0 }
            .store(in: &cancellables)

        preload.$discountedProducts
            .receive(on: RunLoop.main)
            .sink { [weak self] in self?.discountedProducts = $0 }
            .store(in: &cancellables)

        preload.$categories
            .receive(on: RunLoop.main)
            .sink { [weak self] in self?.categories = $0 }
            .store(in: &cancellables)

        preload.$banners
            .receive(on: RunLoop.main)
            .sink { [weak self] in self?.banners = $0 }
            .store(in: &cancellables)

        preload.$stories
            .receive(on: RunLoop.main)
            .sink { [weak self] in self?.stories = $0 }
            .store(in: &cancellables)
    }

    private func hydrateFromPreload() {
        allProducts = preload.allProducts
        popularProducts = preload.popularProducts
        discountedProducts = preload.discountedProducts
        categories = preload.categories
        banners = preload.banners
        stories = preload.stories
        if !allProducts.isEmpty || !popularProducts.isEmpty || !categories.isEmpty {
            hasLoadedOnce = true
        }
    }

    func markStoryViewed(_ id: String) {
        guard let idx = stories.firstIndex(where: { $0.id == id }) else { return }
        stories[idx].isViewed = true
    }

    func releaseInitialLoadingIfNeeded(after seconds: UInt64 = 8) async {
        try? await Task.sleep(nanoseconds: seconds * 1_000_000_000)

        guard isLoading, !hasLoadedOnce, allProducts.isEmpty, popularProducts.isEmpty, categories.isEmpty else {
            return
        }

        errorMessage = "Sunucudan yanıt alınamadı. Lütfen bağlantınızı kontrol edip tekrar deneyin."
        hasLoadedOnce = true
        isLoading = false
    }

    func loadData() async {
        let hasCache = !allProducts.isEmpty || !popularProducts.isEmpty || !categories.isEmpty
        if !hasCache { isLoading = true }
        errorMessage = nil
        defer {
            hasLoadedOnce = true
            isLoading = false
        }

        await preload.refresh()
        await loadSalesBoosters()

        if allProducts.isEmpty && popularProducts.isEmpty && categories.isEmpty {
            errorMessage = preload.lastError
        }
    }

    private func loadSalesBoosters() async {
        async let recentTask = shoppingRepo.getRecentPurchases(limit: 12)
        async let couponsTask = shoppingRepo.getCustomerCoupons()
        async let loyaltyTask = shoppingRepo.getLoyaltySummary()
        async let recommendationsTask = shoppingRepo.getPersonalizedRecommendations(limit: 12)

        if let recent = try? await recentTask {
            recentPurchases = recent.uniquedById()
        }
        if let coupons = try? await couponsTask {
            couponOffers = coupons.filter(\.isActive).prefixArray(6)
        }
        if let loyalty = try? await loyaltyTask {
            loyaltySummary = loyalty
        }
        if let recommendations = try? await recommendationsTask {
            personalizedRecommendations = PersonalizedRecommendationsResponse(
                title: recommendations.title,
                subtitle: recommendations.subtitle,
                strategy: recommendations.strategy,
                products: recommendations.products.uniquedById()
            )
        }
    }
}

private extension Array where Element == Product {
    func uniquedById() -> [Product] {
        var seen = Set<String>()
        return filter { seen.insert($0.id).inserted }
    }
}

private extension Array {
    func prefixArray(_ maxLength: Int) -> [Element] {
        Array(prefix(maxLength))
    }
}
