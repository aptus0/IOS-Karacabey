import Foundation

@MainActor
final class ShoppingExperienceRepository {
    static let shared = ShoppingExperienceRepository()
    private let apiClient = APIClient.shared
    private let catalogCache = CatalogCacheStore.shared

    private init() {}

    func getRecentPurchases(limit: Int = 12) async throws -> [Product] {
        do {
            let products: [Product] = try await apiClient.request(Endpoint.recentPurchases(limit: limit))
            products.forEach { catalogCache.saveProductDetail($0) }
            return products
        } catch APIError.unauthorized {
            return []
        } catch {
            let fallback = catalogCache.recentlyViewedProducts()
            if !fallback.isEmpty { return Array(fallback.prefix(limit)) }
            throw error
        }
    }

    func getCustomerCoupons() async throws -> [CustomerCouponOffer] {
        do {
            return try await apiClient.request(Endpoint.customerCoupons)
        } catch APIError.unauthorized {
            return []
        }
    }

    func getLoyaltySummary() async throws -> CustomerLoyaltySummary? {
        do {
            return try await apiClient.request(Endpoint.customerLoyalty)
        } catch APIError.unauthorized {
            return nil
        } catch APIError.notFound {
            return CustomerLoyaltySummary.empty
        } catch {
            throw error
        }
    }

    func getPersonalizedRecommendations(limit: Int = 12) async throws -> PersonalizedRecommendationsResponse {
        do {
            let response: PersonalizedRecommendationsResponse = try await apiClient.request(Endpoint.customerRecommendations(limit: limit))
            response.products.forEach { catalogCache.saveProductDetail($0) }
            return response
        } catch APIError.unauthorized {
            let fallback = catalogCache.recentlyViewedProducts()
            return PersonalizedRecommendationsResponse(
                title: "Son İnceledikleriniz",
                subtitle: "Giriş yapınca size özel önerileri de göstereceğiz",
                strategy: "recently_viewed_fallback",
                products: Array(fallback.prefix(limit))
            )
        } catch {
            let fallback = catalogCache.recentlyViewedProducts()
            if !fallback.isEmpty {
                return PersonalizedRecommendationsResponse(
                    title: "Son İnceledikleriniz",
                    subtitle: "Bağlantı yavaş olsa da cihazdaki ürünleri gösteriyoruz",
                    strategy: "offline_cache_fallback",
                    products: Array(fallback.prefix(limit))
                )
            }
            throw error
        }
    }

}
