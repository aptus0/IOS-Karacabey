import Foundation

final class DiskCache {
    static let shared = DiskCache()

    private let directoryURL: URL
    private let queue = DispatchQueue(label: "kgm.diskcache", qos: .utility)
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    private init() {
        let base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        directoryURL = base.appendingPathComponent("kgm-cache", isDirectory: true)
        try? FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)

        let enc = JSONEncoder()
        enc.dateEncodingStrategy = .iso8601
        encoder = enc

        let dec = JSONDecoder()
        dec.keyDecodingStrategy = .convertFromSnakeCase
        dec.dateDecodingStrategy = .iso8601
        decoder = dec
    }

    private func url(for key: String) -> URL {
        directoryURL.appendingPathComponent("\(key).json")
    }

    func save<T: Encodable>(_ value: T, for key: String) {
        queue.async { [weak self] in
            guard let self else { return }
            guard let data = try? self.encoder.encode(value) else { return }
            try? data.write(to: self.url(for: key), options: .atomic)
        }
    }

    func load<T: Decodable>(_ type: T.Type, for key: String) -> T? {
        let url = url(for: key)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? decoder.decode(T.self, from: data)
    }

    func age(for key: String) -> TimeInterval? {
        guard
            let attrs = try? FileManager.default.attributesOfItem(atPath: url(for: key).path),
            let modified = attrs[.modificationDate] as? Date
        else { return nil }
        return Date().timeIntervalSince(modified)
    }

    func clear() {
        queue.async { [weak self] in
            guard let self else { return }
            let files = (try? FileManager.default.contentsOfDirectory(at: self.directoryURL, includingPropertiesForKeys: nil)) ?? []
            files.forEach { try? FileManager.default.removeItem(at: $0) }
        }
    }
}

enum DiskCacheKey {
    static let allProducts = "all_products"
    static let popularProducts = "popular_products"
    static let discountedProducts = "discounted_products"
    static let categories = "categories"
    static let banners = "banners"
    static let stories = "stories"
    static let appSettings = "app_settings"
    static let recentSearches = "recent_searches"
    static let recentlyViewedProducts = "recently_viewed_products"

    static func productPage(categoryId: String?, page: Int, limit: Int) -> String {
        let category = (categoryId?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false ? categoryId! : "all")
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: " ", with: "_")
        return "products_\(category)_p\(page)_l\(limit)"
    }

    static func productDetail(_ idOrSlug: String) -> String {
        "product_detail_\(idOrSlug.replacingOccurrences(of: "/", with: "-"))"
    }

    static func productSearch(_ query: String) -> String {
        let normalized = query
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: " ", with: "_")
        return "product_search_\(normalized.prefix(80))"
    }

    static func externalSearch(_ query: String) -> String {
        let normalized = query
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: " ", with: "_")
        return "external_search_\(normalized.prefix(80))"
    }
}


/// Faz 2: katalogu tamamen API'ye bağımlı bırakmayan hafif offline katman.
/// Ürün listesi, detay, arama, son aramalar ve son görüntülenenler disk cache'te tutulur.
@MainActor
final class CatalogCacheStore {
    static let shared = CatalogCacheStore()

    private let cache = DiskCache.shared
    private let maxRecentSearches = 12
    private let maxViewedProducts = 30

    private init() {}

    func saveProductPage(_ products: [Product], categoryId: String?, page: Int, limit: Int) {
        guard !products.isEmpty else { return }
        cache.save(products, for: DiskCacheKey.productPage(categoryId: categoryId, page: page, limit: limit))
        mergeIntoAllProducts(products)
    }

    func productPage(categoryId: String?, page: Int, limit: Int, maxAge: TimeInterval = 12 * 60 * 60) -> [Product] {
        let key = DiskCacheKey.productPage(categoryId: categoryId, page: page, limit: limit)
        if let age = cache.age(for: key), age > maxAge { return [] }
        return cache.load([Product].self, for: key) ?? []
    }

    func saveProductDetail(_ product: Product) {
        cache.save(product, for: DiskCacheKey.productDetail(product.id))
        if !product.slug.isEmpty {
            cache.save(product, for: DiskCacheKey.productDetail(product.slug))
        }
        mergeIntoAllProducts([product])
    }

    func productDetail(_ idOrSlug: String, maxAge: TimeInterval = 24 * 60 * 60) -> Product? {
        let key = DiskCacheKey.productDetail(idOrSlug)
        if let age = cache.age(for: key), age > maxAge { return nil }
        return cache.load(Product.self, for: key)
    }

    func saveSearchResults(_ products: [Product], query: String) {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        cache.save(products, for: DiskCacheKey.productSearch(query))
        addRecentSearch(query)
        mergeIntoAllProducts(products)
    }

    func searchResults(query: String, maxAge: TimeInterval = 6 * 60 * 60) -> [Product] {
        let key = DiskCacheKey.productSearch(query)
        if let age = cache.age(for: key), age > maxAge { return [] }
        if let cached = cache.load([Product].self, for: key), !cached.isEmpty { return cached }
        return localSearch(query: query)
    }

    func saveExternalResults(_ response: ExternalProductSearchResponse, query: String) {
        guard !response.results.isEmpty else { return }
        cache.save(response, for: DiskCacheKey.externalSearch(query))
    }

    func externalResults(query: String, maxAge: TimeInterval = 60 * 60) -> ExternalProductSearchResponse? {
        let key = DiskCacheKey.externalSearch(query)
        if let age = cache.age(for: key), age > maxAge { return nil }
        return cache.load(ExternalProductSearchResponse.self, for: key)
    }

    func addRecentSearch(_ query: String) {
        let clean = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard clean.count >= 2 else { return }
        var searches = recentSearches()
        searches.removeAll { $0.localizedCaseInsensitiveCompare(clean) == .orderedSame }
        searches.insert(clean, at: 0)
        cache.save(Array(searches.prefix(maxRecentSearches)), for: DiskCacheKey.recentSearches)
    }

    func recentSearches() -> [String] {
        cache.load([String].self, for: DiskCacheKey.recentSearches) ?? []
    }

    func addRecentlyViewed(_ product: Product) {
        var products = recentlyViewedProducts()
        products.removeAll { $0.id == product.id }
        products.insert(product, at: 0)
        cache.save(Array(products.prefix(maxViewedProducts)), for: DiskCacheKey.recentlyViewedProducts)
        saveProductDetail(product)
    }

    func recentlyViewedProducts() -> [Product] {
        cache.load([Product].self, for: DiskCacheKey.recentlyViewedProducts) ?? []
    }

    func localSearch(query: String, limit: Int = 30) -> [Product] {
        let needle = query
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
        guard needle.count >= 2 else { return [] }

        let source = (cache.load([Product].self, for: DiskCacheKey.allProducts) ?? [])
            .filter { $0.effectivePrice > 0 }
        guard !source.isEmpty else { return [] }

        return Array(source
            .filter { product in
                [
                    product.name,
                    product.brand,
                    product.categoryName,
                    product.categoryId,
                    product.barcode ?? "",
                    product.tags.joined(separator: " ")
                ]
                .joined(separator: " ")
                .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
                .contains(needle)
            }
            .prefix(limit))
    }

    private func mergeIntoAllProducts(_ incoming: [Product]) {
        guard !incoming.isEmpty else { return }
        var products = cache.load([Product].self, for: DiskCacheKey.allProducts) ?? []
        var byId = Dictionary(uniqueKeysWithValues: products.enumerated().map { ($0.element.id, $0.offset) })
        for product in incoming where product.effectivePrice > 0 {
            if let index = byId[product.id] {
                products[index] = product
            } else {
                byId[product.id] = products.count
                products.append(product)
            }
        }
        cache.save(products, for: DiskCacheKey.allProducts)
    }
}

