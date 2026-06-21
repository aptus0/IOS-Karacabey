import SwiftUI
import Combine

@MainActor
final class SearchViewModel: ObservableObject {
    @Published var query = ""
    @Published var results: [Product] = []
    @Published var recommendedProducts: [Product] = []
    @Published var isLoading = false
    @Published var hasSearched = false
    @Published var errorMessage: String?
    @Published var recentSearches: [String]
    @Published var popularSearches: [String]

    private var suggestionTask: Task<Void, Never>?
    private static let recentSearchesKey = "kgm.recentSearches"
    private static let fallbackPopularSearches = ["Meyve", "Sebze", "Et", "Süt Ürünleri", "İçecek", "Temizlik"]

    init() {
        recentSearches = UserDefaults.standard.stringArray(forKey: Self.recentSearchesKey) ?? []
        popularSearches = Self.fallbackPopularSearches
        hydrateRecommendationsFromCache()
    }

    func loadDiscoveryData() async {
        hydrateRecommendationsFromCache()

        async let categoriesTask = ProductRepository.shared.getCategories()
        async let productsTask = ProductRepository.shared.getAllProducts()

        if let categories = try? await categoriesTask {
            let categoryNames = categories.map(\.name).filter { !$0.isEmpty }
            if !categoryNames.isEmpty {
                popularSearches = Array(categoryNames.prefix(10))
            }
        }

        if recommendedProducts.isEmpty, let products = try? await productsTask {
            recommendedProducts = Array(products.filter { $0.effectivePrice > 0 }.prefix(12))
        }
    }

    func search() async {
        await runSearch(query.trimmingCharacters(in: .whitespacesAndNewlines), addToRecent: true)
    }

    func scheduleSuggestions(for rawQuery: String) {
        let nextQuery = rawQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        suggestionTask?.cancel()

        guard nextQuery.count >= 2 else {
            isLoading = false
            results = []
            hasSearched = false
            errorMessage = nil
            return
        }

        suggestionTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 220_000_000)
            guard !Task.isCancelled else { return }
            await self?.runSearch(nextQuery, addToRecent: false)
        }
    }

    func reset() {
        suggestionTask?.cancel()
        query = ""
        results = []
        isLoading = false
        hasSearched = false
        errorMessage = nil
    }

    private func runSearch(_ searchQuery: String, addToRecent shouldAddToRecent: Bool) async {
        guard !searchQuery.isEmpty else { return }
        isLoading = true
        hasSearched = true
        errorMessage = nil
        do {
            results = try await ProductRepository.shared.search(query: searchQuery)
            if shouldAddToRecent {
                addToRecent(searchQuery)
            }
        } catch {
            results = []
            errorMessage = "Arama yapılamadı. Bağlantınızı kontrol edip tekrar deneyin."
        }
        isLoading = false
    }

    func clearRecents() {
        recentSearches = []
        persistRecentSearches()
    }

    private func hydrateRecommendationsFromCache() {
        let preload = PreloadService.shared
        let source = !preload.popularProducts.isEmpty ? preload.popularProducts : preload.allProducts
        recommendedProducts = Array(source.filter { $0.effectivePrice > 0 }.prefix(12))
    }

    private func addToRecent(_ q: String) {
        recentSearches.removeAll { $0.caseInsensitiveCompare(q) == .orderedSame }
        recentSearches.insert(q, at: 0)
        if recentSearches.count > 8 { recentSearches = Array(recentSearches.prefix(8)) }
        persistRecentSearches()
    }

    private func persistRecentSearches() {
        UserDefaults.standard.set(recentSearches, forKey: Self.recentSearchesKey)
    }
}

struct SearchView: View {
    @StateObject private var vm = SearchViewModel()
    @EnvironmentObject var cartRepo: CartRepository
    @EnvironmentObject var favRepo: FavoritesRepository
    @State private var selectedProduct: Product? = nil

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                VStack(spacing: KGMSpacing.sm) {
                    KGMSearchBar(
                        text: $vm.query,
                        placeholder: "Ürün ara, öneriler otomatik gelsin",
                        onSubmit: { Task { await vm.search() } },
                        onCancel: { vm.reset() }
                    )
                    .padding(.horizontal, KGMSpacing.base)
                    .onChange(of: vm.query) { _, newValue in
                        vm.scheduleSuggestions(for: newValue)
                    }
                }
                .padding(.vertical, KGMSpacing.sm)
                .background(Color.kgmCard)
                Divider()

                if vm.isLoading {
                    KGMLoadingView()
                } else if let errorMessage = vm.errorMessage {
                    KGMErrorView(message: errorMessage) {
                        Task { await vm.search() }
                    }
                } else if vm.hasSearched {
                    searchResultsView
                } else {
                    discoverView
                }
            }
            .background(Color.kgmBackground.ignoresSafeArea())
            .navigationTitle("Arama")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(item: $selectedProduct) { ProductDetailView(product: $0) }
            .task { await vm.loadDiscoveryData() }
        }
    }

    private var discoverView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: KGMSpacing.lg) {
                if !vm.recentSearches.isEmpty {
                    VStack(alignment: .leading, spacing: KGMSpacing.sm) {
                        HStack {
                            Text("Son Aramalar").font(.kgmHeadline)
                            Spacer()
                            Button("Temizle") { vm.clearRecents() }
                                .font(.kgmCaption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal, KGMSpacing.base)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: KGMSpacing.sm) {
                                ForEach(vm.recentSearches, id: \.self) { s in
                                    chipButton(s, icon: "clock")
                                }
                            }
                            .padding(.horizontal, KGMSpacing.base)
                        }
                    }
                }

                VStack(alignment: .leading, spacing: KGMSpacing.sm) {
                    Text("Popüler Aramalar")
                        .font(.kgmHeadline)
                        .padding(.horizontal, KGMSpacing.base)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: KGMSpacing.sm) {
                            ForEach(vm.popularSearches, id: \.self) { s in
                                chipButton(s, icon: "flame")
                            }
                        }
                        .padding(.horizontal, KGMSpacing.base)
                    }
                }

                recommendedProductsSection(title: "Önerilen Ürünler", products: vm.recommendedProducts)
            }
            .padding(.top, KGMSpacing.base)
            .padding(.bottom, KGMSpacing.xl)
        }
    }

    private var searchResultsView: some View {
        Group {
            if vm.results.isEmpty {
                ScrollView {
                    VStack(spacing: KGMSpacing.lg) {
                        KGMEmptyStateView(icon: "magnifyingglass",
                                          title: "Sonuç bulunamadı",
                                          message: "\"\(vm.query)\" için ürün bulunamadı. Aşağıdaki önerilere göz atabilirsiniz.")
                        recommendedProductsSection(title: "Sana Önerilenler", products: vm.recommendedProducts)
                    }
                    .padding(.top, KGMSpacing.base)
                }
            } else {
                ScrollView {
                    LazyVStack(spacing: KGMSpacing.sm) {
                        Text("\(vm.results.count) ürün önerisi")
                            .font(.kgmCaption)
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, KGMSpacing.base)

                        ForEach(vm.results) { product in
                            ProductListRow(
                                product: product,
                                onAddToCart: { cartRepo.addToCart(product) },
                                onTap: { selectedProduct = product }
                            )
                            .padding(.horizontal, KGMSpacing.base)
                        }
                    }
                    .padding(.top, KGMSpacing.sm)
                    .padding(.bottom, KGMSpacing.xl)
                }
            }
        }
    }

    @ViewBuilder
    private func recommendedProductsSection(title: String, products: [Product]) -> some View {
        if !products.isEmpty {
            VStack(alignment: .leading, spacing: KGMSpacing.sm) {
                Text(title)
                    .font(.kgmHeadline)
                    .padding(.horizontal, KGMSpacing.base)

                LazyVStack(spacing: KGMSpacing.sm) {
                    ForEach(products) { product in
                        ProductListRow(
                            product: product,
                            onAddToCart: { cartRepo.addToCart(product) },
                            onTap: { selectedProduct = product }
                        )
                        .padding(.horizontal, KGMSpacing.base)
                    }
                }
            }
        }
    }

    private func chipButton(_ text: String, icon: String) -> some View {
        Button(action: {
            vm.query = text
            Task { await vm.search() }
        }) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                Text(text)
                    .font(.kgmCaption)
                    .foregroundColor(.primary)
            }
            .padding(.horizontal, KGMSpacing.md)
            .padding(.vertical, KGMSpacing.sm)
            .background(Color.kgmCardElevated)
            .cornerRadius(KGMRadius.full)
            .shadow(color: .black.opacity(0.05), radius: 2)
        }
        .buttonStyle(.plain)
    }
}
