import Foundation
import Combine
import UIKit

@MainActor
final class PreloadService: ObservableObject {
    static let shared = PreloadService()

    @Published private(set) var allProducts: [Product] = []
    @Published private(set) var popularProducts: [Product] = []
    @Published private(set) var discountedProducts: [Product] = []
    @Published private(set) var categories: [Category] = []
    @Published private(set) var banners: [BannerItem] = []
    @Published private(set) var stories: [Story] = []
    @Published private(set) var isReady: Bool = false
    @Published private(set) var lastError: String?
    @Published private(set) var progress: Double = 0.05
    @Published private(set) var statusText: String = "Uygulama hazırlanıyor..."
    @Published private(set) var isUsingCachedData: Bool = false

    private let cache = DiskCache.shared
    private let productRepo = ProductRepository.shared
    private let campaignRepo = CampaignRepository.shared
    private var hasBootstrapped = false
    private var refreshTask: Task<Void, Never>?

    private init() {
        hydrateFromCache()
    }

    private func hydrateFromCache() {
        if let all = cache.load([Product].self, for: DiskCacheKey.allProducts) {
            allProducts = all.filter { $0.effectivePrice > 0 }
        }
        if let p = cache.load([Product].self, for: DiskCacheKey.popularProducts) {
            popularProducts = p.filter { $0.effectivePrice > 0 }
        }
        if let d = cache.load([Product].self, for: DiskCacheKey.discountedProducts) {
            discountedProducts = d.filter { $0.effectivePrice > 0 }
        }
        if let c = cache.load([Category].self, for: DiskCacheKey.categories) {
            categories = c
        }
        if let b = cache.load([BannerItem].self, for: DiskCacheKey.banners) {
            banners = b
        }
        if let s = cache.load([Story].self, for: DiskCacheKey.stories) {
            stories = s
        }

        isUsingCachedData = !allProducts.isEmpty || !popularProducts.isEmpty || !categories.isEmpty || !banners.isEmpty || !stories.isEmpty
        isReady = isUsingCachedData
    }

    func bootstrap() async {
        guard !hasBootstrapped else {
            refreshInBackground()
            return
        }

        hasBootstrapped = true
        statusText = "Yerel veriler hazırlanıyor..."
        progress = 0.20
        hydrateFromCache()

        if isUsingCachedData {
            statusText = "Önbellekten hızlı açılıyor..."
            progress = 0.82
        } else {
            statusText = "Veriler arka planda yükleniyor..."
            progress = 0.45
        }

        // Açılışı API bekletmeden hızlandırır. Home ekranı cache varsa anında dolar,
        // cache yoksa skeleton gösterirken veriler arka planda alınır ve kaydedilir.
        isReady = true
        refreshInBackground()
    }

    func refreshInBackground() {
        if refreshTask != nil { return }

        refreshTask = Task(priority: .userInitiated) { [weak self] in
            await self?.refresh()
            await MainActor.run { self?.refreshTask = nil }
        }
    }

    func refresh() async {
        lastError = nil
        statusText = isUsingCachedData ? "Veriler arka planda yenileniyor..." : "Ürünler yükleniyor..."
        progress = max(progress, isUsingCachedData ? 0.84 : 0.52)

        async let productsTask = fetchProducts()
        async let categoriesTask = fetchCategories()
        async let bannersTask = fetchBanners()
        async let storiesTask = fetchStories()

        let products = await productsTask
        progress = max(progress, 0.62)
        let cats = await categoriesTask
        progress = max(progress, 0.72)
        let bnrs = await bannersTask
        progress = max(progress, 0.82)
        let stry = await storiesTask
        progress = max(progress, 0.90)

        if let products {
            let visibleProducts = products.filter { $0.effectivePrice > 0 }
            let pop = Array(visibleProducts.prefix(18))
            let disc = Array(visibleProducts.filter { $0.hasDiscount }.prefix(18))
            allProducts = visibleProducts
            popularProducts = pop
            discountedProducts = disc
            cache.save(visibleProducts, for: DiskCacheKey.allProducts)
            cache.save(pop, for: DiskCacheKey.popularProducts)
            cache.save(disc, for: DiskCacheKey.discountedProducts)
        }
        if let cats {
            categories = cats
            cache.save(cats, for: DiskCacheKey.categories)
        }
        if let bnrs {
            banners = bnrs
            cache.save(bnrs, for: DiskCacheKey.banners)
            await updateWidgetCampaignSnapshot(with: bnrs)
        }
        if let stry {
            stories = stry
            cache.save(stry, for: DiskCacheKey.stories)
        }

        await prewarmVisualCache()

        isUsingCachedData = !allProducts.isEmpty || !popularProducts.isEmpty || !categories.isEmpty || !banners.isEmpty || !stories.isEmpty
        statusText = isUsingCachedData ? "Hazır" : "Bağlantı bekleniyor"
        progress = 1.0
        isReady = true
    }

    private func fetchProducts() async -> [Product]? {
        do {
            // Açılışta 12.000+ ürünü tek seferde çekmek ana ekran ve "Tüm Ürünler"
            // geçişini yavaşlatıyordu. İlk paket hızlıca cache'e alınır; ürün listesi
            // ekranı aşağı indikçe sayfa sayfa devamını yükler.
            return try await productRepo.getProducts(page: 1, limit: 120)
        } catch {
            if lastError == nil { lastError = error.kgmUserMessage }
            return nil
        }
    }

    private func fetchCategories() async -> [Category]? {
        do { return try await productRepo.getCategories() }
        catch { return nil }
    }

    private func fetchBanners() async -> [BannerItem]? {
        do { return try await campaignRepo.getHomepageBanners() }
        catch { return nil }
    }

    private func fetchStories() async -> [Story]? {
        do { return try await campaignRepo.getStories() }
        catch { return nil }
    }

    private func updateWidgetCampaignSnapshot(with banners: [BannerItem]) async {
        let featuredBanners = Array(banners.prefix(5))
        guard !featuredBanners.isEmpty else {
            WidgetSnapshotStore.save(campaign: nil)
            return
        }

        let snapshots = featuredBanners.map { banner in
            WidgetCampaignSnapshot(
                campaignId: banner.id,
                title: banner.title.isEmpty ? "Karacabey Gross Market" : banner.title,
                imageURL: banner.imageURL,
                ctaTitle: banner.subtitle.isEmpty ? "Kampanyayı Gör" : banner.subtitle,
                deepLink: banner.actionURL ?? "kgm://campaigns",
                updatedAt: Date()
            )
        }

        var imageDataByIndex: [Int: Data] = [:]
        for (index, banner) in featuredBanners.enumerated() {
            guard let url = banner.resolvedImageURL else { continue }
            if let data = try? await URLSession.shared.data(from: url).0 {
                imageDataByIndex[index] = data
            }
        }

        WidgetSnapshotStore.save(campaigns: snapshots, imageDataByIndex: imageDataByIndex)
    }

    private func prewarmVisualCache() async {
        statusText = "Görseller optimize ediliyor..."
        progress = max(progress, 0.94)

        let visualURLs = Array(Set(
            banners.compactMap { $0.resolvedImageURL } +
            stories.compactMap { story in
                guard let raw = story.coverImageURL else { return nil }
                return EnvironmentConfig.resolveMediaURL(raw)
            }
        ))

        for url in visualURLs.prefix(24) {
            if let cached = await ImageCache.shared.image(for: url), cached.size.width > 0 {
                continue
            }
            if let data = try? await URLSession.shared.data(from: url).0,
               let image = UIImage(data: data) {
                await ImageCache.shared.insertImage(image, for: url)
            }
        }
    }
}
