import SwiftUI
import Combine

@MainActor
final class ProductListViewModel: ObservableObject {
    @Published var products: [Product] = []
    @Published var isLoading = false
    @Published var isLoadingMore = false
    @Published var canLoadMore = false
    @Published var errorMessage: String?
    @Published var isGridView = true
    @Published var sortOption: SortOption = .relevant
    @Published var showDiscountOnly = false
    @Published var showBestSellersOnly = false
    @Published var showInStockOnly = false
    @Published var selectedCategoryChip = "Tümü"
    @Published var searchText = ""

    private let pageSize = 80
    private var currentPage = 1
    private var lastCategoryId: String?
    private var cachedPagedProducts: [Product] = []
    private var didApplyInitialFilters = false

    enum SortOption: String, CaseIterable {
        case relevant    = "Önerilen"
        case priceLow    = "Fiyat Artan"
        case priceHigh   = "Fiyat Azalan"
        case nameAZ      = "İsim A-Z"
    }

    var availableCategoryChips: [String] {
        let categoryNames = products
            .map { $0.categoryName.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        let tagNames = products
            .flatMap(\.tags)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        var seen = Set<String>()
        let dynamic = (categoryNames + tagNames)
            .filter { seen.insert($0.lowercased()).inserted }
            .prefix(12)

        return ["Tümü"] + Array(dynamic)
    }

    var filtered: [Product] {
        var result = products

        let normalizedQuery = searchText
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)

        if !normalizedQuery.isEmpty {
            result = result.filter { product in
                let searchable = [
                    product.name,
                    product.brand,
                    product.categoryName,
                    product.categoryId,
                    product.barcode ?? "",
                    product.tags.joined(separator: " ")
                ]
                .joined(separator: " ")
                .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)

                return searchable.contains(normalizedQuery)
            }
        }

        if selectedCategoryChip != "Tümü" {
            let chip = selectedCategoryChip.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            result = result.filter { product in
                let searchable = [product.categoryName, product.categoryId, product.brand, product.name]
                    .joined(separator: " ")
                    .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
                let tagMatch = product.tags.contains { tag in
                    tag.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current).contains(chip)
                }
                return searchable.contains(chip) || tagMatch
            }
        }

        if showInStockOnly { result = result.filter { $0.isInStock } }
        if showDiscountOnly { result = result.filter { $0.hasDiscount } }
        if showBestSellersOnly {
            result = result.sorted { lhs, rhs in
                bestSellerScore(lhs) > bestSellerScore(rhs)
            }
        }
        switch sortOption {
        case .priceLow:  result.sort { $0.effectivePrice < $1.effectivePrice }
        case .priceHigh: result.sort { $0.effectivePrice > $1.effectivePrice }
        case .nameAZ:    result.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        default: break
        }
        return result
    }

    var hasActiveFilters: Bool {
        showDiscountOnly || showBestSellersOnly || showInStockOnly || sortOption != .relevant || selectedCategoryChip != "Tümü" || !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var discountedProductCount: Int { products.filter(\.hasDiscount).count }
    var resultCountText: String {
        if canLoadMore || isLoadingMore {
            return "\(filtered.count) ürün · devamı yüklenir"
        }
        return "\(filtered.count) ürün"
    }

    func clearFilters() {
        showDiscountOnly = false
        showBestSellersOnly = false
        showInStockOnly = false
        sortOption = .relevant
        selectedCategoryChip = "Tümü"
        searchText = ""
    }

    func applyInitialFilters(discountOnly: Bool, bestSellersOnly: Bool, searchText initialSearchText: String) {
        guard !didApplyInitialFilters else { return }
        didApplyInitialFilters = true
        showDiscountOnly = discountOnly
        showBestSellersOnly = bestSellersOnly
        searchText = initialSearchText
    }

    private func bestSellerScore(_ product: Product) -> Double {
        let tagBoost = product.tags.contains { tag in
            let normalized = tag.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            return normalized.contains("cok satan") || normalized.contains("çok satan") || normalized.contains("bestseller")
        } ? 10_000.0 : 0.0

        return tagBoost + Double(product.reviewCount * 10) + product.rating
    }

    func load(categoryId: String?, preferCache: Bool = true) async {
        guard !isLoading else { return }
        lastCategoryId = categoryId
        errorMessage = nil
        currentPage = 1
        canLoadMore = false
        cachedPagedProducts = []

        if preferCache {
            let cached = cachedProducts(for: categoryId)
            if !cached.isEmpty {
                cachedPagedProducts = cached
                products = Array(cached.prefix(pageSize))
                canLoadMore = cached.count > products.count
                if !availableCategoryChips.contains(selectedCategoryChip) {
                    selectedCategoryChip = "Tümü"
                }
                return
            }
        }

        isLoading = true
        defer { isLoading = false }

        do {
            let firstPage = try await ProductRepository.shared.getProducts(categoryId: categoryId, page: 1, limit: pageSize)
            products = firstPage.filter { $0.effectivePrice > 0 }
            canLoadMore = firstPage.count >= pageSize
            currentPage = 1
            if !availableCategoryChips.contains(selectedCategoryChip) {
                selectedCategoryChip = "Tümü"
            }
        } catch {
            if products.isEmpty {
                errorMessage = error.kgmUserMessage
            }
        }
    }

    func reload() async {
        products = []
        cachedPagedProducts = []
        currentPage = 1
        canLoadMore = false
        await load(categoryId: lastCategoryId, preferCache: false)
    }

    func loadMoreIfNeeded(currentProduct: Product) async {
        guard filtered.last?.id == currentProduct.id else { return }
        await loadMore()
    }

    func loadMore() async {
        guard canLoadMore, !isLoading, !isLoadingMore else { return }
        isLoadingMore = true
        defer { isLoadingMore = false }

        if products.count < cachedPagedProducts.count {
            let startIndex = products.count
            let endIndex = min(startIndex + pageSize, cachedPagedProducts.count)
            let nextSlice = Array(cachedPagedProducts[startIndex..<endIndex])
            appendUnique(nextSlice)
            canLoadMore = products.count < cachedPagedProducts.count
            currentPage = max(currentPage, Int(ceil(Double(products.count) / Double(pageSize))))
            return
        }

        do {
            let nextPage = currentPage + 1
            let nextProducts = try await ProductRepository.shared.getProducts(categoryId: lastCategoryId, page: nextPage, limit: pageSize)
            appendUnique(nextProducts.filter { $0.effectivePrice > 0 })
            currentPage = nextPage
            canLoadMore = nextProducts.count >= pageSize
        } catch {
            canLoadMore = false
            if products.isEmpty {
                errorMessage = error.kgmUserMessage
            }
        }
    }

    private func appendUnique(_ items: [Product]) {
        guard !items.isEmpty else { return }
        var seen = Set(products.map(\.id))
        let unique = items.filter { seen.insert($0.id).inserted }
        products.append(contentsOf: unique)
    }

    private func cachedProducts(for categoryId: String?) -> [Product] {
        let cached = PreloadService.shared.allProducts.filter { $0.effectivePrice > 0 }
        guard !cached.isEmpty else { return [] }
        guard let categoryId, !categoryId.isEmpty else { return cached }

        let target = categoryId.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
        return cached.filter { product in
            let values = [product.categoryId, product.categoryName, product.name, product.brand]
                .joined(separator: " ")
                .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            let tagMatch = product.tags.contains { tag in
                tag.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current).contains(target)
            }
            return values.contains(target) || tagMatch
        }
    }
}


struct ProductListView: View {
    var categoryId: String? = nil
    var title: String = "Ürünler"
    var initialDiscountOnly = false
    var initialBestSellersOnly = false
    var initialSearchText = ""

    @StateObject private var vm = ProductListViewModel()
    @EnvironmentObject var cartRepo: CartRepository
    @EnvironmentObject var favRepo: FavoritesRepository
    @State private var selectedProduct: Product? = nil
    private let gridColumns = [
        GridItem(.flexible(minimum: 0, maximum: .infinity), spacing: KGMSpacing.sm, alignment: .top),
        GridItem(.flexible(minimum: 0, maximum: .infinity), spacing: KGMSpacing.sm, alignment: .top)
    ]

    var body: some View {
        Group {
            if vm.isLoading && vm.products.isEmpty {
                KGMLoadingView()
            } else if let error = vm.errorMessage {
                KGMErrorView(message: error) { Task { await vm.load(categoryId: categoryId) } }
            } else if vm.products.isEmpty {
                KGMEmptyStateView(
                    icon: "shippingbox",
                    title: "Ürün bulunamadı",
                    message: "Bu kategoride şu an ürün bulunmuyor.",
                    buttonTitle: "Tekrar Dene"
                ) { Task { await vm.reload() } }
            } else {
                VStack(spacing: 0) {
                    listingHeader

                    if vm.filtered.isEmpty {
                        KGMEmptyStateView(
                            icon: "line.3.horizontal.decrease.circle",
                            title: "Filtreye uygun ürün yok",
                            message: "Arama kelimesini veya seçili filtreleri temizleyerek tüm ürünleri tekrar görebilirsiniz.",
                            buttonTitle: "Filtreleri Temizle"
                        ) { vm.clearFilters() }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.kgmBackground)
                    } else {
                        ScrollView(showsIndicators: false) {
                            if vm.isGridView {
                                LazyVGrid(columns: gridColumns, alignment: .center, spacing: KGMSpacing.sm) {
                                    ForEach(vm.filtered) { product in
                                        KGMProductCard(
                                            product: product,
                                            onAddToCart: { cartRepo.addToCart(product) },
                                            onFavorite: { favRepo.toggle(product) },
                                            onTap: { selectedProduct = product }
                                        )
                                        .frame(maxWidth: .infinity)
                                        .onAppear {
                                            Task { await vm.loadMoreIfNeeded(currentProduct: product) }
                                        }
                                    }

                                    if vm.isLoadingMore {
                                        ProgressView()
                                            .tint(.kgmPrimary)
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, KGMSpacing.md)
                                            .gridCellColumns(2)
                                    }
                                }
                                .padding(KGMSpacing.base)
                            } else {
                                LazyVStack(spacing: KGMSpacing.sm) {
                                    ForEach(vm.filtered) { product in
                                        ProductListRow(
                                            product: product,
                                            onAddToCart: { cartRepo.addToCart(product) },
                                            onTap: { selectedProduct = product }
                                        )
                                        .onAppear {
                                            Task { await vm.loadMoreIfNeeded(currentProduct: product) }
                                        }
                                    }

                                    if vm.isLoadingMore {
                                        ProgressView()
                                            .tint(.kgmPrimary)
                                            .padding(.vertical, KGMSpacing.md)
                                    }
                                }
                                .padding(KGMSpacing.base)
                            }
                        }
                        .background(Color.kgmBackground)
                    }
                }
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(item: $selectedProduct) { ProductDetailView(product: $0) }
        .task {
            vm.applyInitialFilters(
                discountOnly: initialDiscountOnly,
                bestSellersOnly: initialBestSellersOnly,
                searchText: initialSearchText
            )
            await vm.load(categoryId: categoryId)
        }
    }

    private var listingHeader: some View {
        VStack(alignment: .leading, spacing: KGMSpacing.sm) {
            HStack(spacing: KGMSpacing.sm) {
                HStack(spacing: KGMSpacing.sm) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.kgmTextMuted)
                    TextField("Ürün, marka veya kategori ara", text: $vm.searchText)
                        .font(.kgmCaptionMedium)
                        .textInputAutocapitalization(.never)
                        .disableAutocorrection(true)
                    if !vm.searchText.isEmpty {
                        Button { vm.searchText = "" } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.kgmTextMuted)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, KGMSpacing.md)
                .frame(height: 42)
                .background(Color.kgmCardElevated)
                .clipShape(Capsule())
                .overlay(Capsule().stroke(Color.kgmBorder, lineWidth: 1))

                Button { vm.isGridView.toggle() } label: {
                    Image(systemName: vm.isGridView ? "square.grid.2x2.fill" : "list.bullet")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.kgmPrimary)
                        .frame(width: 42, height: 42)
                        .background(Color.kgmPrimary.opacity(0.08))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: KGMSpacing.xs) {
                    ForEach(vm.availableCategoryChips, id: \.self) { chip in
                        Button { vm.selectedCategoryChip = chip } label: {
                            Text(chip)
                                .font(.kgmCaptionMedium)
                                .foregroundColor(vm.selectedCategoryChip == chip ? .kgmPrimary : .kgmTextPrimary)
                                .padding(.horizontal, KGMSpacing.md)
                                .frame(height: 32)
                                .background(vm.selectedCategoryChip == chip ? Color.kgmPrimary.opacity(0.10) : Color.kgmCardElevated)
                                .clipShape(Capsule())
                                .overlay(Capsule().stroke(vm.selectedCategoryChip == chip ? Color.kgmPrimary.opacity(0.35) : Color.kgmBorder, lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            HStack(spacing: KGMSpacing.sm) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: KGMSpacing.xs) {
                        sortMenu
                        if vm.hasActiveFilters {
                            filterPill(title: "Temizle", icon: "xmark.circle.fill", isActive: true) { vm.clearFilters() }
                        }
                        filterPill(title: "Stokta", icon: vm.showInStockOnly ? "checkmark.seal.fill" : "checkmark.seal", isActive: vm.showInStockOnly) {
                            vm.showInStockOnly.toggle()
                        }
                        filterPill(title: "İndirimli", icon: vm.showDiscountOnly ? "tag.fill" : "tag", isActive: vm.showDiscountOnly) {
                            vm.showDiscountOnly.toggle()
                        }
                        filterPill(title: "Çok Satanlar", icon: "flame.fill", isActive: vm.showBestSellersOnly) {
                            vm.showBestSellersOnly.toggle()
                        }
                    }
                }

                Text(vm.resultCountText)
                    .font(.kgmSmall)
                    .foregroundColor(.kgmTextMuted)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, KGMSpacing.base)
        .padding(.top, KGMSpacing.sm)
        .padding(.bottom, KGMSpacing.md)
        .background(Color.kgmCard)
        .overlay(alignment: .bottom) { Rectangle().fill(Color.kgmBorder.opacity(0.65)).frame(height: 1) }
    }

    private var sortMenu: some View {
        Menu {
            ForEach(ProductListViewModel.SortOption.allCases, id: \.self) { option in
                Button(option.rawValue) { vm.sortOption = option }
            }
        } label: {
            HStack(spacing: 5) {
                Text("Sırala")
                Image(systemName: "chevron.down")
                    .font(.system(size: 10, weight: .bold))
            }
            .font(.kgmCaptionMedium)
            .foregroundColor(vm.sortOption == .relevant ? .kgmTextPrimary : .kgmPrimary)
            .padding(.horizontal, KGMSpacing.sm)
            .frame(height: 32)
            .background(vm.sortOption == .relevant ? Color.kgmCardElevated : Color.kgmPrimary.opacity(0.10))
            .clipShape(Capsule())
            .overlay(Capsule().stroke(vm.sortOption == .relevant ? Color.kgmBorder : Color.kgmPrimary.opacity(0.35), lineWidth: 1))
        }
    }

    private func filterPill(title: String, icon: String, isActive: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .bold))
                Text(title)
            }
            .font(.kgmCaptionMedium)
            .foregroundColor(isActive ? .kgmPrimary : .kgmTextPrimary)
            .padding(.horizontal, KGMSpacing.sm)
            .frame(height: 32)
            .background(isActive ? Color.kgmPrimary.opacity(0.10) : Color.kgmCardElevated)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(isActive ? Color.kgmPrimary.opacity(0.35) : Color.kgmBorder, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

struct ProductListRow: View {
    let product: Product
    var onAddToCart: (() -> Void)? = nil
    var onTap: (() -> Void)? = nil
    @EnvironmentObject private var cartRepo: CartRepository

    private var cartQuantity: Int { cartRepo.quantityInCart(product.id) }
    private var hasPendingCartSync: Bool { cartRepo.hasPendingChange(for: product.id) }

    var body: some View {
        HStack(spacing: KGMSpacing.md) {
            KGMProductImage(
                url: product.resolvedImageURL,
                height: 90,
                cornerRadius: KGMRadius.md,
                horizontalPadding: 7,
                verticalPadding: 7,
                zoom: 1.04,
                backgroundColor: .white
            )
            .frame(width: 90)

            VStack(alignment: .leading, spacing: KGMSpacing.xs) {
                Text(product.brand.isEmpty ? "Karacabey Gross Market" : product.brand)
                    .font(.kgmSmall)
                    .foregroundColor(.kgmTextMuted)
                    .lineLimit(1)
                Text(product.name)
                    .font(.kgmBodyMedium)
                    .foregroundColor(.kgmTextPrimary)
                    .lineLimit(2)
                HStack(spacing: 5) {
                    Text(product.unit.isEmpty ? "Adet" : product.unit)
                        .font(.kgmSmall)
                        .foregroundColor(.kgmTextSecondary)
                    if hasPendingCartSync {
                        Text("Kaydediliyor")
                            .font(.kgmSmall.weight(.bold))
                            .foregroundColor(.kgmPrimary)
                    }
                }
                KGMPriceLabel(price: product.effectivePrice, originalPrice: product.hasDiscount ? product.price : nil, size: .small)
            }

            Spacer(minLength: 0)

            if cartQuantity > 0 {
                KGMQuantityStepper(
                    quantity: .constant(cartQuantity),
                    min: 1,
                    max: max(cartRepo.maxAllowedQuantity(for: product), cartQuantity),
                    size: .small,
                    onIncrement: { cartRepo.incrementProduct(product) },
                    onDecrement: { cartRepo.decrementProduct(productId: product.id) }
                )
            } else {
                Button(action: { onAddToCart?() }) {
                    Image(systemName: "plus")
                        .font(.system(size: 15, weight: .heavy))
                        .foregroundColor(.white)
                        .frame(width: 38, height: 38)
                        .background(product.isInStock ? Color.kgmPrimary : Color.kgmTextMuted)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .disabled(!product.isInStock)
            }
        }
        .padding(KGMSpacing.md)
        .background(Color.kgmCard)
        .contentShape(RoundedRectangle(cornerRadius: KGMRadius.card))
        .onTapGesture { onTap?() }
        .clipShape(RoundedRectangle(cornerRadius: KGMRadius.card))
        .overlay(RoundedRectangle(cornerRadius: KGMRadius.card).stroke(Color.kgmBorder.opacity(0.95)))
        .kgmShadow(KGMShadow(color: .black.opacity(0.04), radius: 7, x: 0, y: 2))
    }
}
