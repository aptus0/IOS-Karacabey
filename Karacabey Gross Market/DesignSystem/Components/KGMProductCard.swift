import SwiftUI

struct KGMProductImage: View {
    let url: URL?
    var height: CGFloat
    var cornerRadius: CGFloat = KGMRadius.sm
    var horizontalPadding: CGFloat = 10
    var verticalPadding: CGFloat = 10
    var zoom: CGFloat = 1.0
    var backgroundColor: Color = .white

    @StateObject private var loader = ImageLoader()

    var body: some View {
        ZStack {
            backgroundColor

            if let uiImage = loader.image {
                Image(uiImage: uiImage)
                    .resizable()
                    .interpolation(.high)
                    .antialiased(true)
                    .aspectRatio(contentMode: .fit)
                    .scaleEffect(zoom)
                    .padding(.horizontal, horizontalPadding)
                    .padding(.vertical, verticalPadding)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
                    .accessibilityHidden(true)
            } else {
                Rectangle()
                    .fill(Color.kgmCardElevated)
                    .overlay(
                        Image(systemName: "photo")
                            .font(.system(size: 26, weight: .semibold))
                            .foregroundColor(.kgmTextMuted)
                    )
                    .accessibilityHidden(true)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: height)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius)
                .stroke(Color.kgmBorder.opacity(0.65), lineWidth: 1)
        )
        .onAppear { loader.load(url: url) }
        .onChange(of: url) { _, newUrl in loader.load(url: newUrl) }
    }
}

struct KGMProductCard: View {
    let product: Product
    var onAddToCart: (() -> Void)? = nil
    var onFavorite: (() -> Void)? = nil
    var onTap: (() -> Void)? = nil

    @EnvironmentObject private var cartRepo: CartRepository
    @EnvironmentObject private var favRepo: FavoritesRepository
    @State private var suppressNextCardTap = false

    private var cartQuantity: Int { cartRepo.quantityInCart(product.id) }
    private var displayedBrand: String { product.brand.isEmpty ? "Karacabey Gross Market" : product.brand }
    private var isProductFavorite: Bool { product.isFavorite || favRepo.isFavorite(product) }
    private var hasPendingCartSync: Bool { cartRepo.hasPendingChange(for: product.id) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            imageArea
            contentArea
        }
        .frame(maxWidth: .infinity, minHeight: 292, alignment: .top)
        .background(Color.kgmCard)
        .contentShape(RoundedRectangle(cornerRadius: KGMRadius.card))
        .onTapGesture {
            if suppressNextCardTap {
                suppressNextCardTap = false
                return
            }
            onTap?()
        }
        .clipShape(RoundedRectangle(cornerRadius: KGMRadius.card))
        .overlay(
            RoundedRectangle(cornerRadius: KGMRadius.card)
                .stroke(Color.kgmBorder.opacity(0.95), lineWidth: 1)
        )
        .kgmShadow(KGMShadow(color: .black.opacity(0.045), radius: 8, x: 0, y: 3))
        .accessibilityElement(children: .contain)
        .accessibilityAction(named: "Ürün detayını aç") { onTap?() }
    }

    private var imageArea: some View {
        ZStack(alignment: .topTrailing) {
            KGMProductImage(
                url: product.resolvedImageURL,
                height: 146,
                cornerRadius: KGMRadius.md,
                horizontalPadding: 8,
                verticalPadding: 8,
                zoom: 1.07,
                backgroundColor: .white
            )
            .padding(KGMSpacing.xs)

            VStack(alignment: .trailing, spacing: KGMSpacing.xs) {
                Button(action: runControlAction(onFavorite)) {
                    Image(systemName: isProductFavorite ? "heart.fill" : "heart")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(isProductFavorite ? Color.kgmPrimary : .kgmTextPrimary)
                        .frame(width: 38, height: 38)
                        .background(Color.white.opacity(0.97))
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color.kgmBorder, lineWidth: 1))
                        .kgmShadow(KGMShadow(color: .black.opacity(0.06), radius: 6, x: 0, y: 2))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(isProductFavorite ? "\(product.name) favorilerden çıkar" : "\(product.name) favorilere ekle")

                if hasPendingCartSync {
                    Text("Kaydediliyor")
                        .font(.system(size: 10, weight: .heavy))
                        .foregroundColor(.kgmPrimary)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 4)
                        .background(Color.white.opacity(0.97))
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(Color.kgmPrimary.opacity(0.25), lineWidth: 1))
                }

                if product.hasDiscount {
                    Text("%\(product.discountPercent)")
                        .font(.system(size: 12, weight: .heavy))
                        .foregroundColor(.white)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 4)
                        .background(Color.kgmDiscount)
                        .clipShape(Capsule())
                }
            }
            .padding(.top, KGMSpacing.sm)
            .padding(.trailing, KGMSpacing.sm)
        }
    }

    private var contentArea: some View {
        VStack(alignment: .leading, spacing: KGMSpacing.xs) {
            Text(displayedBrand)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.kgmTextMuted)
                .lineLimit(1)

            Text(product.name)
                .font(.system(size: 15.5, weight: .semibold))
                .foregroundColor(.kgmTextPrimary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .minimumScaleFactor(0.86)
                .frame(minHeight: 39, alignment: .topLeading)

            HStack(spacing: 5) {
                Text(product.unit.isEmpty ? "Adet" : product.unit)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.kgmTextSecondary)
                    .lineLimit(1)
                if product.isInStock {
                    Text("Stokta")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.kgmSuccess)
                } else {
                    Text("Stok Yok")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.kgmError)
                }
            }

            priceAndActionRow
                .padding(.top, KGMSpacing.xs)
        }
        .padding(.horizontal, KGMSpacing.sm)
        .padding(.top, KGMSpacing.xs)
        .padding(.bottom, KGMSpacing.sm)
    }

    private var priceAndActionRow: some View {
        HStack(alignment: .bottom, spacing: KGMSpacing.xs) {
            VStack(alignment: .leading, spacing: 1) {
                if product.hasDiscount {
                    Text(product.price.formattedAsTurkishLira)
                        .font(.system(size: 11, weight: .medium))
                        .strikethrough()
                        .foregroundColor(.kgmTextMuted)
                        .lineLimit(1)
                }

                Text(product.effectivePrice.formattedAsTurkishLira)
                    .font(.system(size: 17.5, weight: .black, design: .rounded))
                    .foregroundColor(Color.kgmPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }

            Spacer(minLength: 3)

            if cartQuantity > 0 {
                KGMInlineQuantityControl(
                    quantity: cartQuantity,
                    isMinusEnabled: cartQuantity > 1,
                    onMinus: runControlAction {
                        cartRepo.decrementProduct(productId: product.id)
                    },
                    onPlus: runControlAction {
                        cartRepo.incrementProduct(product)
                    }
                )
            } else {
                Button(action: runControlAction(addProductToCart)) {
                    HStack(spacing: 5) {
                        Image(systemName: "plus")
                            .font(.system(size: 13, weight: .heavy))
                        Text(product.isInStock ? "Ekle" : "Yok")
                            .font(.system(size: 13, weight: .heavy))
                    }
                    .foregroundColor(.white)
                    .frame(width: 78, height: 38)
                    .background(product.isInStock ? Color.kgmPrimary : Color.kgmTextMuted)
                    .clipShape(Capsule())
                    .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .disabled(!product.isInStock)
                .accessibilityLabel("\(product.name) sepete ekle")
                .accessibilityHint(product.isInStock ? "Ürünü bir adet sepete ekler." : "Ürün stokta yok.")
            }
        }
    }

    private func addProductToCart() {
        if let onAddToCart {
            onAddToCart()
        } else {
            cartRepo.addToCart(product)
        }
    }

    private func runControlAction(_ action: (() -> Void)?) -> () -> Void {
        {
            suppressNextCardTap = true
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.prepare()
            generator.impactOccurred()

            withAnimation(.spring(response: 0.3, dampingFraction: 0.68)) {
                action?()
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                suppressNextCardTap = false
            }
        }
    }
}

private struct KGMInlineQuantityControl: View {
    let quantity: Int
    var isMinusEnabled: Bool = true
    let onMinus: () -> Void
    let onPlus: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            Button(action: onMinus) {
                Image(systemName: quantity <= 1 ? "trash" : "minus")
                    .font(.system(size: 11, weight: .heavy))
                    .foregroundColor(.kgmPrimary)
                    .frame(width: 28, height: 34)
            }
            .buttonStyle(.plain)

            Text("\(quantity)")
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundColor(.kgmTextPrimary)
                .frame(width: 30, height: 34)
                .background(Color.white)

            Button(action: onPlus) {
                Image(systemName: "plus")
                    .font(.system(size: 12, weight: .heavy))
                    .foregroundColor(.white)
                    .frame(width: 30, height: 34)
                    .background(Color.kgmPrimary)
            }
            .buttonStyle(.plain)
        }
        .clipShape(Capsule())
        .overlay(Capsule().stroke(Color.kgmPrimary.opacity(0.22), lineWidth: 1))
        .background(Capsule().fill(Color.white))
        .kgmShadow(KGMShadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2))
    }
}

extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat
    var corners: UIRectCorner
    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(roundedRect: rect, byRoundingCorners: corners, cornerRadii: CGSize(width: radius, height: radius))
        return Path(path.cgPath)
    }
}
