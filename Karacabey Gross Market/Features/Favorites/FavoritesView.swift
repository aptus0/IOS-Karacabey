import SwiftUI

struct FavoritesView: View {
    @EnvironmentObject var favRepo: FavoritesRepository
    @EnvironmentObject var cartRepo: CartRepository
    @State private var selectedProduct: Product? = nil

    private let columns = [GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        Group {
            if favRepo.favorites.isEmpty {
                KGMEmptyStateView(
                    icon: "heart.slash",
                    title: "Favori Ürününüz Yok",
                    message: "Beğendiğiniz ürünleri favorilere ekleyerek daha hızlı ulaşın."
                )
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: KGMSpacing.sm) {
                        ForEach(favRepo.favorites) { p in
                            KGMProductCard(product: p,
                                           onAddToCart: { cartRepo.addToCart(p) },
                                           onFavorite: { favRepo.toggle(p) },
                                           onTap: { selectedProduct = p })
                        }
                    }
                    .padding(KGMSpacing.base)
                }
                .background(Color.kgmBackground)
            }
        }
        .background(Color.kgmBackground.ignoresSafeArea())
        .navigationTitle("Favorilerim")
        .navigationBarTitleDisplayMode(.large)
        .navigationDestination(item: $selectedProduct) { ProductDetailView(product: $0) }
        .task { try? await favRepo.refresh() }
        .refreshable { try? await favRepo.refresh() }
    }
}
