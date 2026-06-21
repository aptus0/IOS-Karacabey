import Foundation
import Combine

@MainActor
final class FavoritesRepository: ObservableObject {
    static let shared = FavoritesRepository()

    @Published private(set) var favorites: [Product] = []
    @Published private(set) var lastError: String?
    private let apiClient = APIClient.shared

    private init() {}

    func refresh() async throws {
        favorites = try await apiClient.request(Endpoint.getFavorites)
        lastError = nil
    }

    func toggle(_ product: Product) {
        let alreadyFavorite = isFavorite(product)
        let previous = favorites

        if alreadyFavorite {
            favorites.removeAll { matches($0, product) }
        } else if !favorites.contains(where: { matches($0, product) }) {
            favorites.append(product)
        }

        Task {
            let endpoint: Endpoint = alreadyFavorite
                ? .removeFavorite(slug: favoriteKey(for: product))
                : .addFavorite(slug: favoriteKey(for: product))
            do {
                _ = try await apiClient.request(endpoint) as EmptyResponse
                self.lastError = nil
            } catch {
                self.favorites = previous
                self.lastError = alreadyFavorite
                    ? "Favorilerden çıkarılamadı. Tekrar deneyin."
                    : "Favorilere eklenemedi. Tekrar deneyin."
            }
        }
    }

    func isFavorite(_ product: Product) -> Bool {
        favorites.contains { matches($0, product) }
    }

    func isFavorite(_ productId: String) -> Bool {
        favorites.contains { $0.id == productId || $0.slug == productId }
    }

    private func matches(_ lhs: Product, _ rhs: Product) -> Bool {
        lhs.id == rhs.id || (!lhs.slug.isEmpty && lhs.slug == rhs.slug)
    }

    private func favoriteKey(for product: Product) -> String {
        product.slug.isEmpty ? product.id : product.slug
    }
}
