import Foundation

@MainActor
final class ProductRepository {
    static let shared = ProductRepository()
    private let apiClient = APIClient.shared
    private let catalogCache = CatalogCacheStore.shared
    private init() {}

    func getProducts(categoryId: String? = nil, page: Int = 1, limit: Int = 100) async throws -> [Product] {
        do {
            let products = try await getProductPage(categoryId: categoryId, page: page, limit: limit).data
            catalogCache.saveProductPage(products, categoryId: categoryId, page: page, limit: limit)
            return products
        } catch {
            let cached = catalogCache.productPage(categoryId: categoryId, page: page, limit: limit)
            if !cached.isEmpty { return cached }
            throw error
        }
    }

    func getAllProducts(categoryId: String? = nil, limit: Int = 100) async throws -> [Product] {
        let firstPage = try await getProductPage(categoryId: categoryId, page: 1, limit: limit)
        guard let lastPage = firstPage.lastPage, lastPage > 1 else {
            return firstPage.data
        }

        var products = firstPage.data
        for nextPage in 2...lastPage {
            let page = try await getProductPage(categoryId: categoryId, page: nextPage, limit: limit)
            products.append(contentsOf: page.data)
        }
        return products
    }

    func getProduct(id: String) async throws -> Product {
        do {
            let product: Product = try await apiClient.request(Endpoint.productDetail(id: id))
            catalogCache.saveProductDetail(product)
            return product
        } catch {
            if let cached = catalogCache.productDetail(id) { return cached }
            throw error
        }
    }

    func getRelatedProducts(slug: String) async throws -> [Product] {
        try await apiClient.request(Endpoint.productRelated(slug: slug))
    }

    func getFrequentlyBoughtTogether(slug: String) async throws -> [Product] {
        try await apiClient.request(Endpoint.productFrequentlyBoughtTogether(slug: slug))
    }

    func requestStockAlert(slug: String, email: String? = nil, phone: String? = nil) async throws -> StockAlertResponse {
        try await apiClient.request(Endpoint.productStockAlert(slug: slug, StockAlertRequest(email: email, phone: phone)))
    }

    func getReviews(slug: String) async throws -> ProductReviewsResponse {
        try await apiClient.request(Endpoint.productReviews(slug: slug))
    }

    func recordProductView(slug: String) async {
        do {
            let _: EmptyResponse = try await apiClient.request(Endpoint.productView(slug: slug))
        } catch {
            // Ürün görüntüleme kaydı öneri sistemini besler; hata kullanıcı deneyimini bozmasın.
        }
    }

    func submitReview(slug: String, request: ProductReviewSubmissionRequest) async throws {
        let _: EmptyResponse = try await apiClient.request(Endpoint.submitProductReview(slug: slug, request))
    }

    func getCategories() async throws -> [Category] {
        try await apiClient.request(Endpoint.categories)
    }

    func search(query: String) async throws -> [Product] {
        let clean = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return [] }
        do {
            let page: ProductPage = try await apiClient.request(Endpoint.searchProducts(query: clean, page: 1))
            catalogCache.saveSearchResults(page.data, query: clean)
            return page.data
        } catch {
            let cached = catalogCache.searchResults(query: clean)
            if !cached.isEmpty { return cached }
            throw error
        }
    }

    func externalSearch(query: String, maxResults: Int = 8) async throws -> ExternalProductSearchResponse {
        let clean = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard clean.count >= 2 else {
            return ExternalProductSearchResponse(
                query: clean,
                disclaimer: "Dış market araması için en az 2 karakter yazın.",
                results: []
            )
        }
        do {
            let request = ExternalProductSearchRequest(query: clean, maxResults: maxResults)
            let response: ExternalProductSearchResponse = try await apiClient.request(Endpoint.externalProductSearch(request))
            catalogCache.saveExternalResults(response, query: clean)
            return response
        } catch {
            if let cached = catalogCache.externalResults(query: clean) { return cached }
            throw error
        }
    }

    func visualSearch(imageData: Data) async throws -> VisualProductSearchResponse {
        let request = VisualProductSearchRequest(
            imageBase64: imageData.base64EncodedString(),
            mimeType: "image/jpeg",
            barcode: nil,
            provider: "gemini",
            mode: "product_image_analysis",
            maxResults: 12
        )
        return try await apiClient.request(Endpoint.visualProductSearch(request))
    }

    func searchBarcode(_ code: String) async throws -> VisualProductSearchResponse {
        let request = VisualProductSearchRequest(
            imageBase64: nil,
            mimeType: nil,
            barcode: code,
            provider: "barcode",
            mode: "barcode_lookup",
            maxResults: 12
        )
        return try await apiClient.request(Endpoint.visualProductSearch(request))
    }

    func getDiscountedProducts() async throws -> [Product] {
        try await getProducts().filter { $0.hasDiscount }
    }

    func getPopularProducts() async throws -> [Product] {
        try await Array(getProducts().prefix(6))
    }

    private func getProductPage(categoryId: String?, page: Int, limit: Int) async throws -> ProductPage {
        try await apiClient.request(Endpoint.products(categoryId: categoryId, page: page, limit: limit))
    }
}

private struct ProductPage: Decodable {
    let data: [Product]
    let total: Int?
    let perPage: Int?
    let currentPage: Int?
    let lastPage: Int?
}
