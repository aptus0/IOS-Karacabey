import SwiftUI

struct ProductDetailView: View {
    let product: Product
    @EnvironmentObject var cartRepo: CartRepository
    @EnvironmentObject var favRepo: FavoritesRepository
    @State private var quantity = 1
    @State private var addedToCart = false
    @State private var showProductInfo = true
    @State private var reviews: [KGMProductReview] = []
    @State private var averageRating = 0.0
    @State private var reviewCount = 0
    @State private var showReviewComposer = false
    @State private var reviewSubmitMessage: String?
    @State private var relatedProducts: [Product] = []
    @State private var frequentlyBoughtTogether: [Product] = []
    @State private var recentlyViewedProducts: [Product] = []
    @State private var selectedRelatedProduct: Product?
    @State private var selectedImageIndex = 0
    @State private var fullScreenImageIndex: Int? = nil
    @State private var isRequestingStockAlert = false
    @Environment(\.dismiss) var dismiss

    private var isFav: Bool { favRepo.isFavorite(product.id) }
    private var displayedBrand: String { product.brand.isEmpty ? "Karacabey Gross Market" : product.brand }
    private var maxQuantity: Int { max(cartRepo.maxAllowedQuantity(for: product), 1) }
    private var galleryURLs: [URL] { product.resolvedGalleryImageURLs }
    private var hasMultipleImages: Bool { galleryURLs.count > 1 }
    private var fullScreenGalleryURLs: [URL] {
        let urls = galleryURLs
        if !urls.isEmpty { return urls }
        return [product.resolvedImageURL].compactMap { $0 }
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                heroSection
                mainInfoSection

                VStack(alignment: .leading, spacing: KGMSpacing.base) {
                    shareActionsSection
                    productTrustSection
                    productInfoAccordion

                    if let barcode = product.barcode?.trimmingCharacters(in: .whitespacesAndNewlines), !barcode.isEmpty {
                        barcodeSection(barcode)
                    }

                    if let nutritionInfo = product.nutritionInfo {
                        nutritionSection(nutritionInfo)
                    }

                    if !frequentlyBoughtTogether.isEmpty {
                        frequentlyBoughtTogetherSection
                    }

                    if !relatedProducts.isEmpty {
                        relatedProductsSection
                    }

                    if !recentlyViewedProducts.isEmpty {
                        recentlyViewedSection
                    }

                    reviewsSection

                    Spacer(minLength: 110)
                }
                .padding(.horizontal, KGMSpacing.base)
                .padding(.top, KGMSpacing.base)
            }
        }
        .background(Color.kgmBackground.ignoresSafeArea())
        .navigationBarBackButtonHidden(true)
        .navigationBarHidden(true)
        .navigationDestination(item: $selectedRelatedProduct) { ProductDetailView(product: $0) }
        .task {
            CatalogCacheStore.shared.addRecentlyViewed(product)
            Task { await ProductRepository.shared.recordProductView(slug: product.slug) }
            await loadExperience()
        }
        .safeAreaInset(edge: .bottom) { bottomAddBar }
        .sheet(isPresented: $showReviewComposer) {
            ProductReviewComposerView(productName: product.name) { draft in
                await submitReview(draft)
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .fullScreenCover(isPresented: Binding(
            get: { fullScreenImageIndex != nil },
            set: { if !$0 { fullScreenImageIndex = nil } }
        )) {
            if !fullScreenGalleryURLs.isEmpty {
                ProductImageZoomViewer(
                    urls: fullScreenGalleryURLs,
                    selectedIndex: Binding(
                        get: { fullScreenImageIndex ?? selectedImageIndex },
                        set: { newValue in
                            selectedImageIndex = newValue
                            fullScreenImageIndex = newValue
                        }
                    )
                )
            }
        }
    }

    private var heroSection: some View {
        ZStack(alignment: .top) {
            Color.kgmCard

            VStack(spacing: KGMSpacing.sm) {
                productImageGallery
                    .padding(.top, 76)

                if hasMultipleImages {
                    galleryControls
                        .padding(.bottom, KGMSpacing.md)
                } else {
                    Spacer(minLength: KGMSpacing.md)
                }
            }

            HStack {
                headerButton(systemName: "chevron.left") { dismiss() }
                Spacer()
                Button(action: { favRepo.toggle(product) }) {
                    Image(systemName: isFav ? "heart.fill" : "heart")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(isFav ? .kgmPrimary : .kgmTextPrimary)
                        .frame(width: 44, height: 44)
                        .background(Color.white.opacity(0.96))
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color.kgmBorder, lineWidth: 1))
                }
                .buttonStyle(.plain)

                ShareLink(item: product.shareMessage) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(.kgmTextPrimary)
                        .frame(width: 44, height: 44)
                        .background(Color.white.opacity(0.96))
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color.kgmBorder, lineWidth: 1))
                }
                .accessibilityLabel("Ürünü ve mobil uygulamayı paylaş")
            }
            .padding(.horizontal, KGMSpacing.base)
            .padding(.top, KGMSpacing.md)
        }
    }

    @ViewBuilder
    private var productImageGallery: some View {
        let urls = galleryURLs

        if urls.count > 1 {
            TabView(selection: $selectedImageIndex) {
                ForEach(Array(urls.enumerated()), id: \.offset) { index, url in
                    KGMProductImage(
                        url: url,
                        height: 320,
                        cornerRadius: KGMRadius.xl,
                        horizontalPadding: 24,
                        verticalPadding: 22,
                        zoom: 1.04,
                        backgroundColor: .white
                    )
                    .padding(.horizontal, KGMSpacing.base)
                    .contentShape(Rectangle())
                    .onTapGesture { fullScreenImageIndex = index }
                    .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(height: 320)
        } else {
            KGMProductImage(
                url: urls.first ?? product.resolvedImageURL,
                height: 320,
                cornerRadius: KGMRadius.xl,
                horizontalPadding: 24,
                verticalPadding: 22,
                zoom: 1.04,
                backgroundColor: .white
            )
            .padding(.horizontal, KGMSpacing.base)
            .contentShape(Rectangle())
            .onTapGesture {
                if !fullScreenGalleryURLs.isEmpty { fullScreenImageIndex = 0 }
            }
        }
    }

    private var galleryControls: some View {
        VStack(spacing: KGMSpacing.sm) {
            HStack(spacing: 6) {
                ForEach(galleryURLs.indices, id: \.self) { index in
                    Capsule()
                        .fill(index == selectedImageIndex ? Color.kgmPrimary : Color.kgmBorder)
                        .frame(width: index == selectedImageIndex ? 18 : 7, height: 7)
                        .animation(.easeInOut(duration: 0.2), value: selectedImageIndex)
                }
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: KGMSpacing.xs) {
                    ForEach(Array(galleryURLs.enumerated()), id: \.offset) { index, url in
                        Button {
                            withAnimation(.easeInOut(duration: 0.18)) { selectedImageIndex = index }
                        } label: {
                            KGMProductImage(
                                url: url,
                                height: 52,
                                cornerRadius: KGMRadius.sm,
                                horizontalPadding: 4,
                                verticalPadding: 4,
                                zoom: 1.0,
                                backgroundColor: .white
                            )
                            .frame(width: 58)
                            .overlay(
                                RoundedRectangle(cornerRadius: KGMRadius.sm)
                                    .stroke(index == selectedImageIndex ? Color.kgmPrimary : Color.clear, lineWidth: 2)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, KGMSpacing.base)
            }
        }
    }

    private var mainInfoSection: some View {
        VStack(alignment: .leading, spacing: KGMSpacing.sm) {
            Text(displayedBrand)
                .font(.kgmCaptionMedium)
                .foregroundColor(.kgmTextMuted)
                .lineLimit(1)

            Text(product.name)
                .font(.system(size: 24, weight: .black))
                .foregroundColor(.kgmTextPrimary)
                .lineLimit(3)
                .minimumScaleFactor(0.86)

            HStack(alignment: .center, spacing: KGMSpacing.sm) {
                Text(product.unit.isEmpty ? "Adet" : product.unit)
                    .font(.kgmCallout)
                    .foregroundColor(.kgmTextSecondary)

                if displayedReviewCount > 0 || displayedRating > 0 {
                    Label(String(format: "%.1f", displayedRating), systemImage: "star.fill")
                        .font(.kgmCaptionMedium)
                        .foregroundColor(.kgmWarning)
                }

                Spacer()

                KGMQuantityStepper(quantity: $quantity, max: maxQuantity, size: .medium)
            }

            HStack(alignment: .bottom) {
                KGMPriceLabel(
                    price: product.effectivePrice,
                    originalPrice: product.hasDiscount ? product.price : nil,
                    size: .large
                )
                Spacer()
                stockPill
            }
        }
        .padding(KGMSpacing.base)
        .background(Color.kgmCard)
        .overlay(alignment: .bottom) { Rectangle().fill(Color.kgmBorder.opacity(0.55)).frame(height: 1) }
    }

    private var stockPill: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(product.isInStock ? Color.kgmPrimary : Color.kgmSecondary)
                .frame(width: 7, height: 7)
            Text(product.isInStock ? "Stokta" : "Tükendi")
                .font(.kgmCaptionMedium)
                .foregroundColor(product.isInStock ? .kgmPrimary : .kgmSecondary)
        }
        .padding(.horizontal, KGMSpacing.sm)
        .frame(height: 30)
        .background((product.isInStock ? Color.kgmPrimary : Color.kgmSecondary).opacity(0.08))
        .clipShape(Capsule())
    }

    private var shareActionsSection: some View {
        HStack(spacing: KGMSpacing.sm) {
            ShareLink(item: product.shareMessage) {
                shareActionTile(
                    icon: "square.and.arrow.up",
                    title: "Ürünü Paylaş",
                    subtitle: "Ürün + mobil app linki"
                )
            }
            .buttonStyle(.plain)

            ShareLink(item: "Karacabey Gross Market mobil uygulamasını indir: \(EnvironmentConfig.appShareURL.absoluteString)") {
                shareActionTile(
                    icon: "iphone",
                    title: "Mobil App",
                    subtitle: "Uygulamayı paylaş"
                )
            }
            .buttonStyle(.plain)
        }
    }

    private func shareActionTile(icon: String, title: String, subtitle: String) -> some View {
        HStack(spacing: KGMSpacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(.kgmPrimary)
                .frame(width: 34, height: 34)
                .background(Color.kgmPrimary.opacity(0.10))
                .clipShape(RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.kgmCaptionMedium)
                    .foregroundColor(.kgmTextPrimary)
                    .lineLimit(1)
                Text(subtitle)
                    .font(.kgmSmall)
                    .foregroundColor(.kgmTextMuted)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .padding(KGMSpacing.sm)
        .frame(maxWidth: .infinity)
        .background(Color.kgmCard)
        .clipShape(RoundedRectangle(cornerRadius: KGMRadius.card))
        .overlay(RoundedRectangle(cornerRadius: KGMRadius.card).stroke(Color.kgmBorder.opacity(0.95)))
    }


    private var productTrustSection: some View {
        VStack(alignment: .leading, spacing: KGMSpacing.sm) {
            HStack(spacing: KGMSpacing.sm) {
                trustTile(icon: "shippingbox.fill", title: "Karacabey içi servis", subtitle: "Bölge kontrolüyle teslimat")
                trustTile(icon: "shield.checkered", title: "Güvenli alışveriş", subtitle: "PayTR veya kapıda ödeme")
            }

            HStack(spacing: KGMSpacing.sm) {
                trustTile(icon: "arrow.clockwise", title: "Taze katalog", subtitle: "Stok ve fiyat API ile güncellenir")
                if product.isInStock {
                    trustTile(icon: "checkmark.seal.fill", title: "Sepete uygun", subtitle: "Hemen siparişe eklenebilir")
                } else {
                    notifyWhenAvailableTile
                }
            }
        }
    }

    private func trustTile(icon: String, title: String, subtitle: String) -> some View {
        HStack(alignment: .top, spacing: KGMSpacing.xs) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.kgmPrimary)
                .frame(width: 28, height: 28)
                .background(Color.kgmPrimary.opacity(0.10))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.kgmSmall)
                    .foregroundColor(.kgmTextPrimary)
                    .lineLimit(1)
                Text(subtitle)
                    .font(.system(size: 10, weight: .regular))
                    .foregroundColor(.kgmTextMuted)
                    .lineLimit(2)
            }
            Spacer(minLength: 0)
        }
        .padding(KGMSpacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.kgmCard)
        .clipShape(RoundedRectangle(cornerRadius: KGMRadius.md))
        .overlay(RoundedRectangle(cornerRadius: KGMRadius.md).stroke(Color.kgmBorder.opacity(0.85)))
    }

    private var notifyWhenAvailableTile: some View {
        Button {
            Task { await requestStockAlert() }
        } label: {
            trustTile(
                icon: isRequestingStockAlert ? "hourglass" : "bell.badge.fill",
                title: isRequestingStockAlert ? "Kaydediliyor" : "Gelince haber ver",
                subtitle: "Stok açılınca bildirim"
            )
        }
        .buttonStyle(.plain)
        .disabled(isRequestingStockAlert)
    }

    private var productInfoAccordion: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) { showProductInfo.toggle() }
            } label: {
                HStack {
                    Text("Ürün Bilgisi")
                        .font(.kgmHeadline)
                        .foregroundColor(.kgmTextPrimary)
                    Spacer()
                    Image(systemName: showProductInfo ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.kgmTextMuted)
                }
                .padding(KGMSpacing.md)
            }
            .buttonStyle(.plain)

            if showProductInfo {
                VStack(alignment: .leading, spacing: KGMSpacing.sm) {
                    infoRow("Marka", displayedBrand)
                    infoRow("Ürün Tipi", product.categoryName.isEmpty ? "Market Ürünü" : product.categoryName)
                    infoRow("Birim", product.unit.isEmpty ? "Adet" : product.unit)
                    infoRow("Menşei", "Türkiye")

                    Text(product.description.isEmpty ? "Bu ürün için açıklama yakında eklenecek." : product.description)
                        .font(.kgmCaption)
                        .foregroundColor(.kgmTextSecondary)
                        .lineSpacing(2)
                        .padding(.top, KGMSpacing.xs)
                }
                .padding(.horizontal, KGMSpacing.md)
                .padding(.bottom, KGMSpacing.md)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(Color.kgmCard)
        .clipShape(RoundedRectangle(cornerRadius: KGMRadius.card))
        .overlay(RoundedRectangle(cornerRadius: KGMRadius.card).stroke(Color.kgmBorder.opacity(0.95)))
    }
    
    
    

    private var frequentlyBoughtTogetherSection: some View {
        VStack(alignment: .leading, spacing: KGMSpacing.md) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Sık Birlikte Alınanlar")
                        .font(.kgmHeadline)
                        .foregroundColor(.kgmTextPrimary)
                    Text("Bu ürünle beraber sepete eklenen öneriler")
                        .font(.kgmCaption)
                        .foregroundColor(.kgmTextMuted)
                }
                Spacer()
                Button {
                    cartRepo.addToCart(product, quantity: 1)
                    frequentlyBoughtTogether.prefix(3).forEach { cartRepo.addToCart($0, quantity: 1) }
                    reviewSubmitMessage = "Ürün ve önerilen tamamlayıcılar sepete eklendi."
                } label: {
                    Text("Paketi Ekle")
                        .font(.kgmCaptionMedium)
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .frame(height: 32)
                        .background(Color.kgmPrimary)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: KGMSpacing.sm) {
                    ForEach(frequentlyBoughtTogether.prefix(8)) { item in
                        RelatedMiniProductCard(
                            product: item,
                            onAdd: { cartRepo.addToCart(item, quantity: 1) },
                            onFavorite: { favRepo.toggle(item) },
                            onTap: { selectedRelatedProduct = item }
                        )
                        .frame(width: 122)
                    }
                }
                .padding(.trailing, KGMSpacing.base)
            }
        }
    }

    private var relatedProductsSection: some View {
        VStack(alignment: .leading, spacing: KGMSpacing.md) {
            HStack(alignment: .firstTextBaseline) {
                Text("Bunlar da ilginizi çekebilir")
                    .font(.kgmHeadline)
                    .foregroundColor(.kgmTextPrimary)
                Spacer()
                Text("Tümü")
                    .font(.kgmCaptionMedium)
                    .foregroundColor(.kgmPrimary)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: KGMSpacing.sm) {
                    ForEach(relatedProducts.prefix(10)) { item in
                        RelatedMiniProductCard(
                            product: item,
                            onAdd: { cartRepo.addToCart(item, quantity: 1) },
                            onFavorite: { favRepo.toggle(item) },
                            onTap: { selectedRelatedProduct = item }
                        )
                        .frame(width: 122)
                    }
                }
                .padding(.trailing, KGMSpacing.base)
            }
        }
    }


    private var recentlyViewedSection: some View {
        VStack(alignment: .leading, spacing: KGMSpacing.md) {
            Text("Son İnceledikleriniz")
                .font(.kgmHeadline)
                .foregroundColor(.kgmTextPrimary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: KGMSpacing.sm) {
                    ForEach(recentlyViewedProducts.prefix(8)) { item in
                        RelatedMiniProductCard(
                            product: item,
                            onAdd: { cartRepo.addToCart(item, quantity: 1) },
                            onFavorite: { favRepo.toggle(item) },
                            onTap: { selectedRelatedProduct = item }
                        )
                        .frame(width: 122)
                    }
                }
                .padding(.trailing, KGMSpacing.base)
            }
        }
    }

    private var reviewsSection: some View {
        VStack(alignment: .leading, spacing: KGMSpacing.md) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Değerlendirmeler")
                        .font(.kgmHeadline)
                        .foregroundColor(.kgmTextPrimary)
                    Text("Ürünü kullanan müşterilerin yorumları")
                        .font(.kgmCaption)
                        .foregroundColor(.kgmTextMuted)
                }
                Spacer()
                Button {
                    reviewSubmitMessage = nil
                    showReviewComposer = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "square.and.pencil")
                        Text("Yorum Yap")
                    }
                    .font(.kgmCaptionMedium)
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .frame(height: 34)
                    .background(Color.kgmPrimary)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }

            reviewRatingSummary

            if let reviewSubmitMessage {
                HStack(alignment: .top, spacing: KGMSpacing.sm) {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundColor(.kgmPrimary)
                    Text(reviewSubmitMessage)
                        .font(.kgmCaptionMedium)
                        .foregroundColor(.kgmTextSecondary)
                    Spacer(minLength: 0)
                }
                .padding(KGMSpacing.md)
                .background(Color.kgmPrimary.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: KGMRadius.md))
                .overlay(RoundedRectangle(cornerRadius: KGMRadius.md).stroke(Color.kgmPrimary.opacity(0.18)))
                .transition(.opacity.combined(with: .move(edge: .top)))
            }

            if reviews.isEmpty {
                VStack(alignment: .leading, spacing: KGMSpacing.sm) {
                    Image(systemName: "star.bubble.fill")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundColor(.kgmWarning)
                    Text("İlk değerlendirmeyi siz yapın")
                        .font(.kgmBodyMedium)
                        .foregroundColor(.kgmTextPrimary)
                    Text("Ürün hakkında yorumunuz diğer müşterilere yardımcı olur. Puan verip kısa bir deneyim yazabilirsiniz.")
                        .font(.kgmCaption)
                        .foregroundColor(.kgmTextSecondary)
                        .lineSpacing(2)
                    Button {
                        reviewSubmitMessage = nil
                        showReviewComposer = true
                    } label: {
                        Text("Değerlendir")
                            .font(.kgmCaptionMedium)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 42)
                            .background(Color.kgmPrimary)
                            .clipShape(RoundedRectangle(cornerRadius: KGMRadius.md))
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 4)
                }
                .padding(KGMSpacing.md)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.kgmCard)
                .clipShape(RoundedRectangle(cornerRadius: KGMRadius.card))
                .overlay(RoundedRectangle(cornerRadius: KGMRadius.card).stroke(Color.kgmBorder.opacity(0.8)))
            } else {
                ForEach(reviews) { review in
                    reviewCard(review)
                }
            }
        }
    }

    private var reviewRatingSummary: some View {
        HStack(spacing: KGMSpacing.md) {
            VStack(alignment: .leading, spacing: 4) {
                Text(displayedReviewCount > 0 ? String(format: "%.1f", displayedRating) : "—")
                    .font(.system(size: 34, weight: .black, design: .rounded))
                    .foregroundColor(.kgmTextPrimary)
                KGMStaticStars(rating: Int(displayedRating.rounded()), size: 13)
                Text(displayedReviewCount > 0 ? "\(displayedReviewCount) değerlendirme" : "Henüz değerlendirme yok")
                    .font(.kgmSmall)
                    .foregroundColor(.kgmTextMuted)
            }
            .frame(width: 112, alignment: .leading)

            VStack(alignment: .leading, spacing: 7) {
                ForEach((1...5).reversed(), id: \.self) { star in
                    let count = reviews.filter { $0.rating == star }.count
                    HStack(spacing: 7) {
                        Text("\(star)")
                            .font(.kgmSmall)
                            .foregroundColor(.kgmTextMuted)
                            .frame(width: 10, alignment: .trailing)
                        Image(systemName: "star.fill")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.kgmWarning)
                        GeometryReader { proxy in
                            Capsule()
                                .fill(Color.kgmBorder.opacity(0.65))
                                .overlay(alignment: .leading) {
                                    Capsule()
                                        .fill(Color.kgmWarning)
                                        .frame(width: proxy.size.width * ratingRatio(count))
                                }
                        }
                        .frame(height: 7)
                    }
                }
            }
        }
        .padding(KGMSpacing.md)
        .background(Color.kgmCard)
        .clipShape(RoundedRectangle(cornerRadius: KGMRadius.card))
        .overlay(RoundedRectangle(cornerRadius: KGMRadius.card).stroke(Color.kgmBorder.opacity(0.8)))
    }

    private func ratingRatio(_ count: Int) -> CGFloat {
        guard !reviews.isEmpty else { return 0 }
        return CGFloat(count) / CGFloat(reviews.count)
    }

    private func reviewCard(_ review: KGMProductReview) -> some View {
        VStack(alignment: .leading, spacing: KGMSpacing.sm) {
            HStack(alignment: .top, spacing: KGMSpacing.sm) {
                Circle()
                    .fill(review.isPending ? Color.kgmPrimary.opacity(0.16) : Color.kgmWarning.opacity(0.16))
                    .frame(width: 38, height: 38)
                    .overlay(
                        Text(String(review.authorName.prefix(1)).uppercased())
                            .font(.system(size: 15, weight: .black))
                            .foregroundColor(review.isPending ? .kgmPrimary : .kgmWarning)
                    )

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(review.authorName)
                            .font(.kgmBodyMedium)
                            .foregroundColor(.kgmTextPrimary)
                            .lineLimit(1)
                        if review.isPending {
                            Text("Onay bekliyor")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.kgmPrimary)
                                .padding(.horizontal, 7)
                                .frame(height: 20)
                                .background(Color.kgmPrimary.opacity(0.10))
                                .clipShape(Capsule())
                        }
                    }
                    KGMStaticStars(rating: review.rating, size: 12)
                }
                Spacer()
                Text(review.createdAt, style: .date)
                    .font(.kgmSmall)
                    .foregroundColor(.kgmTextMuted)
            }

            if let title = review.title, !title.isEmpty {
                Text(title)
                    .font(.kgmCallout)
                    .foregroundColor(.kgmTextPrimary)
            }
            if let body = review.body, !body.isEmpty {
                Text(body)
                    .font(.kgmBody)
                    .foregroundColor(.kgmTextSecondary)
                    .lineSpacing(2)
            }
        }
        .padding(KGMSpacing.md)
        .background(Color.kgmCard)
        .clipShape(RoundedRectangle(cornerRadius: KGMRadius.card))
        .overlay(RoundedRectangle(cornerRadius: KGMRadius.card).stroke(Color.kgmBorder.opacity(0.8)))
    }

    @MainActor
    private func submitReview(_ draft: ProductReviewDraft) async -> Bool {
        guard draft.isValid else { return false }
        let pendingReview = draft.asPendingReview

        do {
            try await ProductRepository.shared.submitReview(slug: product.slug, request: draft.asRequest)
            ProductReviewLocalStore.clearPendingReviews(slug: product.slug)
            reviewSubmitMessage = "Değerlendirmeniz alındı. Yayınlanmadan önce kısa bir kontrol sürecinden geçebilir."
            if let response = try? await ProductRepository.shared.getReviews(slug: product.slug) {
                applyReviews(response.reviews, average: response.averageRating, count: response.reviewCount)
            } else {
                recalculateReviewStats()
            }
        } catch {
            ProductReviewLocalStore.addPendingReview(pendingReview, slug: product.slug)
            reviews = mergeReviews(ProductReviewLocalStore.pendingReviews(slug: product.slug), reviews)
            recalculateReviewStats()
            reviewSubmitMessage = "Değerlendirmeniz cihazda onay bekleyen yorum olarak kaydedildi. Bağlantı veya sunucu hazır olduğunda tekrar gönderilebilir."
        }

        return true
    }

    private func applyReviews(_ remoteReviews: [KGMProductReview], average: Double, count: Int) {
        let pending = ProductReviewLocalStore.pendingReviews(slug: product.slug)
        reviews = mergeReviews(pending, remoteReviews)
        if pending.isEmpty {
            averageRating = average
            reviewCount = count
        } else {
            recalculateReviewStats()
        }
    }

    private func mergeReviews(_ pending: [KGMProductReview], _ remote: [KGMProductReview]) -> [KGMProductReview] {
        var seen = Set<String>()
        return (pending + remote).filter { review in
            seen.insert(review.id).inserted
        }
    }

    private func recalculateReviewStats() {
        guard !reviews.isEmpty else {
            averageRating = 0
            reviewCount = 0
            return
        }
        reviewCount = reviews.count
        averageRating = Double(reviews.reduce(0) { $0 + $1.rating }) / Double(reviews.count)
    }

    private var bottomAddBar: some View {
        HStack(spacing: KGMSpacing.sm) {
            Button { cartRepo.addToCart(product, quantity: quantity) } label: {
                Image(systemName: "cart")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.kgmTextPrimary)
                    .frame(width: 52, height: 52)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: KGMRadius.md))
                    .overlay(RoundedRectangle(cornerRadius: KGMRadius.md).stroke(Color.kgmBorder, lineWidth: 1))
            }
            .buttonStyle(.plain)
            .disabled(!product.isInStock)

            Button {
                cartRepo.addToCart(product, quantity: quantity)
                withAnimation { addedToCart = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) { addedToCart = false }
            } label: {
                Text(addedToCart ? "Sepete Eklendi ✓" : "Sepete Ekle • \((product.effectivePrice * Double(quantity)).formattedAsTurkishLira)")
                    .font(.system(size: 16, weight: .heavy))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(product.isInStock ? Color.kgmPrimary : Color.kgmTextMuted)
                    .clipShape(RoundedRectangle(cornerRadius: KGMRadius.md))
            }
            .buttonStyle(.plain)
            .disabled(!product.isInStock)
        }
        .padding(KGMSpacing.base)
        .background(.ultraThinMaterial)
        .overlay(alignment: .top) { Rectangle().fill(Color.kgmBorder.opacity(0.7)).frame(height: 1) }
    }

    private var displayedRating: Double { reviewCount > 0 ? averageRating : product.rating }
    private var displayedReviewCount: Int { reviewCount > 0 ? reviewCount : product.reviewCount }

    private func headerButton(systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 17, weight: .bold))
                .foregroundColor(.kgmTextPrimary)
                .frame(width: 44, height: 44)
                .background(Color.white.opacity(0.96))
                .clipShape(Circle())
                .overlay(Circle().stroke(Color.kgmBorder, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private func infoRow(_ title: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.kgmCaption)
                .foregroundColor(.kgmTextMuted)
            Spacer()
            Text(value)
                .font(.kgmCaptionMedium)
                .foregroundColor(.kgmTextPrimary)
                .multilineTextAlignment(.trailing)
                .lineLimit(2)
        }
    }

    private func barcodeSection(_ barcode: String) -> some View {
        VStack(alignment: .leading, spacing: KGMSpacing.sm) {
            Text("Barkod")
                .font(.kgmHeadline)
                .foregroundColor(.kgmTextPrimary)

            HStack(spacing: KGMSpacing.md) {
                Image(systemName: "barcode.viewfinder")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundColor(.kgmPrimary)
                    .frame(width: 54, height: 54)
                    .background(Color.kgmPrimary.opacity(0.10))
                    .clipShape(RoundedRectangle(cornerRadius: KGMRadius.md))

                VStack(alignment: .leading, spacing: 4) {
                    Text(barcode)
                        .font(.system(size: 17, weight: .semibold, design: .monospaced))
                        .foregroundColor(.kgmTextPrimary)
                        .textSelection(.enabled)
                    Text("Kasada ve hızlı siparişte bu kodla eşleşir.")
                        .font(.kgmCaption)
                        .foregroundColor(.kgmTextSecondary)
                }
                Spacer(minLength: 0)
            }
            .padding(KGMSpacing.md)
            .background(Color.kgmCard)
            .clipShape(RoundedRectangle(cornerRadius: KGMRadius.card))
            .overlay(RoundedRectangle(cornerRadius: KGMRadius.card).stroke(Color.kgmBorder.opacity(0.95)))
        }
    }

    private func nutritionSection(_ nutrition: NutritionInfo) -> some View {
        VStack(alignment: .leading, spacing: KGMSpacing.sm) {
            Text("Besin Değerleri")
                .font(.kgmHeadline)
                .foregroundColor(.kgmTextPrimary)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: KGMSpacing.sm) {
                nutritionRow("Kalori", nutrition.calories)
                nutritionRow("Protein", nutrition.protein)
                nutritionRow("Yağ", nutrition.fat)
                nutritionRow("Karbonhidrat", nutrition.carbs)
                nutritionRow("Lif", nutrition.fiber)
            }
        }
    }

    private func nutritionRow(_ label: String, _ value: String?) -> some View {
        HStack {
            Text(label).font(.kgmCaption).foregroundColor(.kgmTextMuted)
            Spacer()
            Text(value ?? "-").font(.kgmCaptionMedium).foregroundColor(.kgmTextPrimary)
        }
        .padding(KGMSpacing.sm)
        .background(Color.kgmCard)
        .cornerRadius(KGMRadius.sm)
        .overlay(RoundedRectangle(cornerRadius: KGMRadius.sm).stroke(Color.kgmBorder.opacity(0.7)))
    }

    @MainActor
    private func requestStockAlert() async {
        guard !isRequestingStockAlert else { return }
        isRequestingStockAlert = true
        defer { isRequestingStockAlert = false }
        do {
            let response = try await ProductRepository.shared.requestStockAlert(slug: product.slug)
            reviewSubmitMessage = response.message ?? "Ürün stoğa girince bildirimlerden haber vereceğiz."
        } catch {
            reviewSubmitMessage = error.kgmUserMessage
        }
    }

    private func loadExperience() async {
        recentlyViewedProducts = CatalogCacheStore.shared.recentlyViewedProducts()
            .filter { $0.id != product.id }

        async let reviewsTask = ProductRepository.shared.getReviews(slug: product.slug)
        async let relatedTask = ProductRepository.shared.getRelatedProducts(slug: product.slug)
        async let frequentlyTask = ProductRepository.shared.getFrequentlyBoughtTogether(slug: product.slug)

        if let response = try? await reviewsTask {
            applyReviews(response.reviews, average: response.averageRating, count: response.reviewCount)
        } else {
            reviews = ProductReviewLocalStore.pendingReviews(slug: product.slug)
            recalculateReviewStats()
        }

        let apiFrequently = (try? await frequentlyTask) ?? []
        frequentlyBoughtTogether = Array(apiFrequently.filter { $0.id != product.id }.uniquedById().prefix(8))

        let apiRelated = (try? await relatedTask) ?? []
        let cleanRelated = apiRelated
            .filter { $0.id != product.id }
            .uniquedById()

        if !cleanRelated.isEmpty {
            relatedProducts = Array(cleanRelated.prefix(10))
            return
        }

        let fallbackCategoryId = product.categoryId.trimmingCharacters(in: .whitespacesAndNewlines)
        let fallbackProducts = (try? await ProductRepository.shared.getProducts(
            categoryId: fallbackCategoryId.isEmpty ? nil : fallbackCategoryId,
            page: 1,
            limit: 12
        )) ?? []

        relatedProducts = Array(
            fallbackProducts
                .filter { $0.id != product.id }
                .uniquedById()
                .prefix(10)
        )
    }
}


private struct ProductReviewComposerView: View {
    let productName: String
    let onSubmit: (ProductReviewDraft) async -> Bool

    @Environment(\.dismiss) private var dismiss
    @State private var rating = 5
    @State private var title = ""
    @State private var reviewBody = ""
    @State private var authorName = ""
    @State private var isSubmitting = false
    @State private var validationMessage: String?

    private var draft: ProductReviewDraft {
        ProductReviewDraft(rating: rating, title: title, body: reviewBody, authorName: authorName)
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: KGMSpacing.base) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Ürünü Değerlendir")
                            .font(.system(size: 24, weight: .black))
                            .foregroundColor(.kgmTextPrimary)
                        Text(productName)
                            .font(.kgmCaptionMedium)
                            .foregroundColor(.kgmTextSecondary)
                            .lineLimit(2)
                    }

                    VStack(alignment: .leading, spacing: KGMSpacing.sm) {
                        Text("Puanınız")
                            .font(.kgmBodyMedium)
                            .foregroundColor(.kgmTextPrimary)
                        KGMEditableStars(rating: $rating)
                        Text(ratingDescription)
                            .font(.kgmCaption)
                            .foregroundColor(.kgmTextMuted)
                    }
                    .padding(KGMSpacing.md)
                    .background(Color.kgmCard)
                    .clipShape(RoundedRectangle(cornerRadius: KGMRadius.card))
                    .overlay(RoundedRectangle(cornerRadius: KGMRadius.card).stroke(Color.kgmBorder.opacity(0.8)))

                    fieldGroup(title: "Başlık", placeholder: "Örn: Taze ve kaliteli", text: $title)
                    fieldGroup(title: "Adınız", placeholder: "Müşteri", text: $authorName)

                    VStack(alignment: .leading, spacing: KGMSpacing.sm) {
                        Text("Yorumunuz")
                            .font(.kgmBodyMedium)
                            .foregroundColor(.kgmTextPrimary)
                        TextEditor(text: $reviewBody)
                            .font(.kgmBody)
                            .frame(minHeight: 130)
                            .padding(10)
                            .background(Color.kgmCardElevated)
                            .clipShape(RoundedRectangle(cornerRadius: KGMRadius.md))
                            .overlay(alignment: .topLeading) {
                                if reviewBody.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                    Text("Ürün hakkındaki deneyiminizi yazın...")
                                        .font(.kgmBody)
                                        .foregroundColor(.kgmTextMuted)
                                        .padding(.top, 18)
                                        .padding(.leading, 16)
                                        .allowsHitTesting(false)
                                }
                            }
                            .overlay(RoundedRectangle(cornerRadius: KGMRadius.md).stroke(Color.kgmBorder.opacity(0.85)))
                    }

                    if let validationMessage {
                        Text(validationMessage)
                            .font(.kgmCaptionMedium)
                            .foregroundColor(.kgmError)
                    }

                    Button {
                        Task { await submit() }
                    } label: {
                        HStack {
                            if isSubmitting { ProgressView().tint(.white) }
                            Text(isSubmitting ? "Gönderiliyor..." : "Değerlendirmeyi Gönder")
                                .font(.system(size: 16, weight: .heavy))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(draft.isValid && !isSubmitting ? Color.kgmPrimary : Color.kgmTextMuted)
                        .clipShape(RoundedRectangle(cornerRadius: KGMRadius.md))
                    }
                    .buttonStyle(.plain)
                    .disabled(!draft.isValid || isSubmitting)

                    Text("Yorumlar yayınlanmadan önce mağaza tarafından kontrol edilebilir. Uygunsuz içerikler yayınlanmaz.")
                        .font(.kgmSmall)
                        .foregroundColor(.kgmTextMuted)
                        .lineSpacing(2)
                        .padding(.bottom, KGMSpacing.base)
                }
                .padding(KGMSpacing.base)
            }
            .background(Color.kgmBackground.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Kapat") { dismiss() }
                }
            }
        }
    }

    private var ratingDescription: String {
        switch rating {
        case 5: return "Harika"
        case 4: return "Çok iyi"
        case 3: return "Orta"
        case 2: return "Beklentimin altında"
        default: return "Memnun kalmadım"
        }
    }

    private func fieldGroup(title: String, placeholder: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: KGMSpacing.sm) {
            Text(title)
                .font(.kgmBodyMedium)
                .foregroundColor(.kgmTextPrimary)
            TextField(placeholder, text: text)
                .font(.kgmBody)
                .padding(.horizontal, KGMSpacing.md)
                .frame(height: 48)
                .background(Color.kgmCardElevated)
                .clipShape(RoundedRectangle(cornerRadius: KGMRadius.md))
                .overlay(RoundedRectangle(cornerRadius: KGMRadius.md).stroke(Color.kgmBorder.opacity(0.85)))
        }
    }

    private func submit() async {
        guard draft.isValid else {
            validationMessage = "Lütfen puan verip en az birkaç kelimelik yorum yazın."
            return
        }
        validationMessage = nil
        isSubmitting = true
        let success = await onSubmit(draft)
        isSubmitting = false
        if success { dismiss() }
    }
}

private struct KGMEditableStars: View {
    @Binding var rating: Int

    var body: some View {
        HStack(spacing: 10) {
            ForEach(1...5, id: \.self) { index in
                Button {
                    withAnimation(.spring(response: 0.22, dampingFraction: 0.72)) {
                        rating = index
                    }
                } label: {
                    Image(systemName: index <= rating ? "star.fill" : "star")
                        .font(.system(size: 31, weight: .bold))
                        .foregroundColor(index <= rating ? .kgmWarning : .kgmBorder)
                        .scaleEffect(index == rating ? 1.08 : 1.0)
                }
                .buttonStyle(.plain)
            }
        }
        .accessibilityLabel("Puan seçimi")
    }
}

private struct KGMStaticStars: View {
    let rating: Int
    let size: CGFloat

    var body: some View {
        HStack(spacing: 2) {
            ForEach(1...5, id: \.self) { index in
                Image(systemName: index <= rating ? "star.fill" : "star")
                    .font(.system(size: size, weight: .bold))
                    .foregroundColor(index <= rating ? .kgmWarning : .kgmBorder)
            }
        }
        .accessibilityLabel("\(rating) yıldız")
    }
}

private struct RelatedMiniProductCard: View {
    let product: Product
    var onAdd: () -> Void
    var onFavorite: () -> Void
    var onTap: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: KGMSpacing.xs) {
            ZStack(alignment: .topTrailing) {
                KGMProductImage(
                    url: product.resolvedImageURL,
                    height: 86,
                    cornerRadius: KGMRadius.sm,
                    horizontalPadding: 6,
                    verticalPadding: 6,
                    zoom: 1.04,
                    backgroundColor: .white
                )

                Button(action: onFavorite) {
                    Image(systemName: product.isFavorite ? "heart.fill" : "heart")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(product.isFavorite ? .kgmPrimary : .kgmTextPrimary)
                        .frame(width: 28, height: 28)
                        .background(Color.white.opacity(0.96))
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color.kgmBorder, lineWidth: 1))
                }
                .padding(5)
                .buttonStyle(.plain)
            }

            Text(product.brand.isEmpty ? "KGM" : product.brand)
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(.kgmTextMuted)
                .lineLimit(1)

            Text(product.name)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.kgmTextPrimary)
                .lineLimit(2)
                .frame(minHeight: 28, alignment: .topLeading)

            HStack(alignment: .center, spacing: 2) {
                Text(product.effectivePrice.formattedAsTurkishLira)
                    .font(.system(size: 12, weight: .black, design: .rounded))
                    .foregroundColor(.kgmPrimary)
                    .minimumScaleFactor(0.75)
                    .lineLimit(1)
                Spacer(minLength: 0)
                Button(action: onAdd) {
                    Image(systemName: "plus")
                        .font(.system(size: 11, weight: .heavy))
                        .foregroundColor(.white)
                        .frame(width: 26, height: 26)
                        .background(Color.kgmPrimary)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(KGMSpacing.xs)
        .background(Color.kgmCard)
        .clipShape(RoundedRectangle(cornerRadius: KGMRadius.md))
        .overlay(RoundedRectangle(cornerRadius: KGMRadius.md).stroke(Color.kgmBorder.opacity(0.9)))
        .contentShape(RoundedRectangle(cornerRadius: KGMRadius.md))
        .onTapGesture(perform: onTap)
    }
}

private extension Array where Element == Product {
    func uniquedById() -> [Product] {
        var seen = Set<String>()
        return filter { product in seen.insert(product.id).inserted }
    }
}


private struct ProductImageZoomViewer: View {
    let urls: [URL]
    @Binding var selectedIndex: Int
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.black.ignoresSafeArea()

            TabView(selection: $selectedIndex) {
                ForEach(Array(urls.enumerated()), id: \.offset) { index, url in
                    KGMZoomableRemoteImage(url: url)
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .ignoresSafeArea()

            VStack {
                HStack {
                    Text("Görseli yakınlaştır")
                        .font(.kgmCaptionMedium)
                        .foregroundColor(.white.opacity(0.82))
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 42, height: 42)
                            .background(Color.white.opacity(0.16))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, KGMSpacing.base)
                .padding(.top, KGMSpacing.base)

                Spacer()

                if urls.count > 1 {
                    HStack(spacing: 6) {
                        ForEach(urls.indices, id: \.self) { index in
                            Capsule()
                                .fill(index == selectedIndex ? Color.white : Color.white.opacity(0.35))
                                .frame(width: index == selectedIndex ? 18 : 7, height: 7)
                        }
                    }
                    .padding(.bottom, KGMSpacing.xl)
                }
            }
        }
    }
}

private struct KGMZoomableRemoteImage: View {
    let url: URL
    @StateObject private var loader = ImageLoader()
    @State private var scale: CGFloat = 1
    @State private var lastScale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                if let uiImage = loader.image {
                    Image(uiImage: uiImage)
                        .resizable()
                        .interpolation(.high)
                        .antialiased(true)
                        .scaledToFit()
                        .scaleEffect(scale)
                        .offset(offset)
                        .frame(width: proxy.size.width, height: proxy.size.height)
                        .contentShape(Rectangle())
                        .gesture(zoomGesture)
                        .simultaneousGesture(dragGesture)
                        .onTapGesture(count: 2) { toggleZoom() }
                } else {
                    ProgressView()
                        .tint(.white)
                        .scaleEffect(1.1)
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .onAppear { loader.load(url: url) }
        .onChange(of: url) { _, newURL in
            resetZoom()
            loader.load(url: newURL)
        }
    }

    private var zoomGesture: some Gesture {
        MagnificationGesture()
            .onChanged { value in
                scale = min(max(lastScale * value, 1), 5)
            }
            .onEnded { _ in
                lastScale = scale
                if scale <= 1.02 { resetZoom() }
            }
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 8)
            .onChanged { value in
                guard scale > 1 else { return }
                offset = CGSize(
                    width: lastOffset.width + value.translation.width,
                    height: lastOffset.height + value.translation.height
                )
            }
            .onEnded { _ in
                guard scale > 1 else { resetZoom(); return }
                lastOffset = offset
            }
    }

    private func toggleZoom() {
        withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
            if scale > 1 {
                resetZoom()
            } else {
                scale = 2.4
                lastScale = 2.4
            }
        }
    }

    private func resetZoom() {
        scale = 1
        lastScale = 1
        offset = .zero
        lastOffset = .zero
    }
}
