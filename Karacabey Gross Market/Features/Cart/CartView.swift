import SwiftUI

struct CartView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var cartRepo: CartRepository
    @State private var navigateToCheckout = false
    @State private var couponCode = ""
    @State private var isEditingCart = false
    @State private var showClearCartAlert = false

    private var meetsMinimumSubtotal: Bool { KGMCheckoutRules.meetsMinimum(cartRepo.cart.subtotal) }

    private var checkoutButtonTitle: String {
        if cartRepo.syncState.isActive { return "Sepet Kaydediliyor" }
        if !meetsMinimumSubtotal { return "Minimum \(KGMCheckoutRules.minimumSubtotalShortLabel)" }
        return "Ödemeye Geç"
    }


    var body: some View {
        Group {
            if cartRepo.cart.isEmpty {
                KGMEmptyStateView(
                    icon: "cart",
                    title: "Sepetiniz Boş",
                    message: "Alışverişe başlamak için ürünleri inceleyin.",
                    buttonTitle: "Alışverişe Başla"
                ) { appState.selectedTab = .categories }
            } else {
                VStack(spacing: 0) {
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: KGMSpacing.md) {
                            if cartRepo.syncState.isActive {
                                cartSyncStatusCard
                            }

                            deliveryAddressCard

                            if isEditingCart {
                                cartEditActionsCard
                            }

                            LazyVStack(spacing: KGMSpacing.sm) {
                                ForEach(cartRepo.cart.items) { item in
                                    CartItemRow(
                                        item: item,
                                        maxQuantity: cartRepo.maxAllowedQuantity(for: item.product),
                                        onIncrement: { cartRepo.incrementProduct(item.product) },
                                        onDecrement: { cartRepo.decrementProduct(productId: item.product.id) },
                                        onRemove: { cartRepo.removeItem(itemId: item.id) }
                                    )
                                }
                            }

                            KGMCouponInput(
                                couponCode: $couponCode,
                                appliedDiscount: cartRepo.cart.discountAmount > 0 ? cartRepo.cart.discountAmount : nil,
                                onApply: { cartRepo.applyCoupon(couponCode) },
                                onRemove: { cartRepo.removeCoupon(); couponCode = "" }
                            )
                            .padding(KGMSpacing.md)
                            .background(Color.kgmCard)
                            .clipShape(RoundedRectangle(cornerRadius: KGMRadius.card))
                            .overlay(RoundedRectangle(cornerRadius: KGMRadius.card).stroke(Color.kgmBorder.opacity(0.95)))

                            if let error = cartRepo.lastError {
                                Label(error, systemImage: "exclamationmark.circle.fill")
                                    .font(.kgmCaption)
                                    .foregroundColor(.kgmError)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(KGMSpacing.md)
                                    .background(Color.kgmError.opacity(0.08))
                                    .clipShape(RoundedRectangle(cornerRadius: KGMRadius.md))
                            }

                            cartSummaryCard
                            Spacer(minLength: KGMSpacing.xxl)
                        }
                        .padding(KGMSpacing.base)
                    }
                    .background(Color.kgmBackground)

                    checkoutBar
                }
            }
        }
        .navigationTitle("Sepetim (\(cartRepo.cart.itemCount))")
        .navigationBarTitleDisplayMode(.inline)
        .background(Color.kgmBackground.ignoresSafeArea())
        .toolbar {
            if !cartRepo.cart.isEmpty {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(isEditingCart ? "Bitti" : "Düzenle") {
                        withAnimation(.easeInOut(duration: 0.18)) {
                            isEditingCart.toggle()
                        }
                    }
                    .foregroundColor(Color.kgmPrimary)
                    .font(.kgmCaptionMedium)
                }
            }
        }
        .navigationDestination(isPresented: $navigateToCheckout) { CheckoutView() }
        .onAppear { couponCode = cartRepo.cart.couponCode ?? couponCode }
        .onChange(of: cartRepo.cart.couponCode) { _, value in couponCode = value ?? "" }
        .alert("Sepeti boşalt", isPresented: $showClearCartAlert) {
            Button("Vazgeç", role: .cancel) {}
            Button("Sepeti Boşalt", role: .destructive) {
                cartRepo.clearCart()
                isEditingCart = false
            }
        } message: {
            Text("Sepetteki tüm ürünler kaldırılacak. Bu işlem otomatik olarak sunucuyla eşitlenecek.")
        }
    }


    private var cartEditActionsCard: some View {
        VStack(alignment: .leading, spacing: KGMSpacing.sm) {
            HStack(spacing: KGMSpacing.sm) {
                Image(systemName: "pencil.circle.fill")
                    .foregroundColor(.kgmPrimary)
                Text("Sepet düzenleme açık")
                    .font(.kgmCaptionMedium)
                    .foregroundColor(.kgmTextPrimary)
                Spacer()
                Button("Sepeti Boşalt") { showClearCartAlert = true }
                    .font(.kgmSmall.weight(.bold))
                    .foregroundColor(.kgmError)
            }
            Text("Adetleri + / − ile güncelleyebilir, çöp ikonuyla ürünü kaldırabilirsiniz.")
                .font(.kgmSmall)
                .foregroundColor(.kgmTextSecondary)
        }
        .padding(KGMSpacing.md)
        .background(Color.kgmPrimary.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: KGMRadius.card))
        .overlay(RoundedRectangle(cornerRadius: KGMRadius.card).stroke(Color.kgmPrimary.opacity(0.20)))
    }

    private var cartSyncStatusCard: some View {
        HStack(alignment: .top, spacing: KGMSpacing.sm) {
            if cartRepo.syncState == .syncing {
                ProgressView()
                    .tint(.kgmPrimary)
                    .frame(width: 24, height: 24)
            } else {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.kgmPrimary)
                    .frame(width: 24, height: 24)
            }

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(cartRepo.syncState.title)
                        .font(.kgmCaptionMedium)
                        .foregroundColor(.kgmTextPrimary)
                    if cartRepo.pendingSyncCount > 0 {
                        Text("\(cartRepo.pendingSyncCount) işlem")
                            .font(.kgmSmall)
                            .foregroundColor(.kgmPrimary)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(Color.kgmPrimary.opacity(0.10))
                            .clipShape(Capsule())
                    }
                }
                Text(cartRepo.syncState.message)
                    .font(.kgmSmall)
                    .foregroundColor(.kgmTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)

            if case .waitingConnection = cartRepo.syncState {
                Button("Tekrar Dene") { cartRepo.retryPendingSync() }
                    .font(.kgmSmall.weight(.bold))
                    .foregroundColor(.kgmPrimary)
            }
        }
        .padding(KGMSpacing.md)
        .background(Color.kgmPrimary.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: KGMRadius.card))
        .overlay(RoundedRectangle(cornerRadius: KGMRadius.card).stroke(Color.kgmPrimary.opacity(0.20)))
    }

    private var deliveryAddressCard: some View {
        HStack(spacing: KGMSpacing.md) {
            Image(systemName: "location.fill")
                .font(.system(size: 17, weight: .bold))
                .foregroundColor(.kgmPrimary)
                .frame(width: 38, height: 38)
                .background(Color.kgmPrimary.opacity(0.10))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 3) {
                Text("Teslimat Adresi")
                    .font(.kgmCaptionMedium)
                    .foregroundColor(.kgmTextPrimary)
                Text("Atatürk Mah. 123. Sk. No:45\nKaracabey / Bursa")
                    .font(.kgmSmall)
                    .foregroundColor(.kgmTextSecondary)
                    .lineLimit(2)
            }

            Spacer(minLength: 0)

            Button { appState.selectedTab = .more } label: {
                HStack(spacing: 3) {
                    Text("Değiştir")
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .bold))
                }
                .font(.kgmCaptionMedium)
                .foregroundColor(.kgmPrimary)
            }
            .buttonStyle(.plain)
        }
        .padding(KGMSpacing.md)
        .background(Color.kgmCard)
        .clipShape(RoundedRectangle(cornerRadius: KGMRadius.card))
        .overlay(RoundedRectangle(cornerRadius: KGMRadius.card).stroke(Color.kgmBorder.opacity(0.95)))
    }

    private var cartSummaryCard: some View {
        VStack(spacing: KGMSpacing.sm) {
            summaryRow("Ara Toplam", value: cartRepo.cart.subtotal)
            if cartRepo.cart.hasDeliveryFee {
                summaryRow("Teslimat Ücreti", value: cartRepo.cart.deliveryFee)
            } else {
                summaryTextRow("Teslimat Ücreti", value: "Adres adımında hesaplanır")
            }
            if cartRepo.cart.discountAmount > 0 {
                summaryRow("İndirim", value: -cartRepo.cart.discountAmount, isDiscount: true)
            }
            Divider()
            HStack {
                Text("Toplam")
                    .font(.kgmHeadline)
                    .foregroundColor(.kgmTextPrimary)
                Spacer()
                Text(cartRepo.cart.total.formattedAsTurkishLira)
                    .font(.system(size: 22, weight: .black, design: .rounded))
                    .foregroundColor(.kgmTextPrimary)
            }
        }
        .padding(KGMSpacing.md)
        .background(Color.kgmCard)
        .clipShape(RoundedRectangle(cornerRadius: KGMRadius.card))
        .overlay(RoundedRectangle(cornerRadius: KGMRadius.card).stroke(Color.kgmBorder.opacity(0.95)))
    }

    private var checkoutBar: some View {
        VStack(spacing: KGMSpacing.sm) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Toplam")
                        .font(.kgmSmall)
                        .foregroundColor(.kgmTextMuted)
                    Text(cartRepo.cart.total.formattedAsTurkishLira)
                        .font(.system(size: 19, weight: .black, design: .rounded))
                        .foregroundColor(.kgmTextPrimary)
                }
                Spacer()
                Button {
                    if cartRepo.syncState.isActive {
                        cartRepo.retryPendingSync()
                    } else if meetsMinimumSubtotal {
                        navigateToCheckout = true
                    }
                } label: {
                    Text(checkoutButtonTitle)
                        .font(.system(size: 15, weight: .heavy))
                        .foregroundColor(.white)
                        .frame(width: 190, height: 52)
                        .background(Color.kgmPrimary)
                        .clipShape(RoundedRectangle(cornerRadius: KGMRadius.md))
                }
                .buttonStyle(.plain)
                .disabled(cartRepo.syncState == .syncing)
            }

            if !meetsMinimumSubtotal {
                HStack(spacing: 6) {
                    Image(systemName: "info.circle.fill")
                    Text("Karacabey içi servis için minimum sepet tutarı \(KGMCheckoutRules.minimumSubtotalDisplay).")
                }
                .font(.kgmSmall)
                .foregroundColor(.kgmWarning)
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            if cartRepo.syncState.isActive {
                Text("Sepetiniz sunucuyla eşitlenmeden ödeme adımına geçmeyelim. İnternet yavaşsa işlemi otomatik tekrar deniyoruz.")
                    .font(.kgmSmall)
                    .foregroundColor(.kgmTextMuted)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(KGMSpacing.base)
        .background(.ultraThinMaterial)
        .overlay(alignment: .top) { Rectangle().fill(Color.kgmBorder.opacity(0.7)).frame(height: 1) }
    }

    private func summaryRow(_ title: String, value: Double, isDiscount: Bool = false) -> some View {
        HStack {
            Text(title)
                .font(.kgmCaptionMedium)
                .foregroundColor(.kgmTextSecondary)
            Spacer()
            Text(value.formattedAsTurkishLira)
                .font(.kgmCaptionMedium)
                .foregroundColor(isDiscount ? .kgmSecondary : .kgmTextPrimary)
        }
    }

    private func summaryTextRow(_ title: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.kgmCaptionMedium)
                .foregroundColor(.kgmTextSecondary)
            Spacer()
            Text(value)
                .font(.kgmCaptionMedium)
                .foregroundColor(.kgmTextMuted)
                .multilineTextAlignment(.trailing)
        }
    }
}

struct CartItemRow: View {
    let item: CartItem
    var maxQuantity: Int = 99
    var onIncrement: (() -> Void)? = nil
    var onDecrement: (() -> Void)? = nil
    var onRemove: (() -> Void)? = nil

    private var quantityBinding: Binding<Int> {
        Binding(
            get: { item.quantity },
            set: { _ in }
        )
    }


    var body: some View {
        HStack(spacing: KGMSpacing.md) {
            KGMProductImage(
                url: item.product.resolvedImageURL,
                height: 78,
                cornerRadius: KGMRadius.md,
                horizontalPadding: 5,
                verticalPadding: 5,
                zoom: 1.04,
                backgroundColor: .white
            )
            .frame(width: 78)

            VStack(alignment: .leading, spacing: KGMSpacing.xs) {
                Text(item.product.name)
                    .font(.kgmCaptionMedium)
                    .foregroundColor(.kgmTextPrimary)
                    .lineLimit(2)
                Text(item.product.unit.isEmpty ? "Adet" : item.product.unit)
                    .font(.kgmSmall)
                    .foregroundColor(.kgmTextSecondary)

                KGMQuantityStepper(
                    quantity: quantityBinding,
                    min: 1,
                    max: max(maxQuantity, item.quantity),
                    size: .small,
                    onIncrement: onIncrement,
                    onDecrement: onDecrement
                )
            }

            Spacer(minLength: 0)

            VStack(alignment: .trailing, spacing: KGMSpacing.sm) {
                Button(action: { onRemove?() }) {
                    Image(systemName: "trash")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.kgmTextMuted)
                        .frame(width: 30, height: 30)
                        .background(Color.kgmCardElevated)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)

                Text(item.totalPrice.formattedAsTurkishLira)
                    .font(.system(size: 15, weight: .black, design: .rounded))
                    .foregroundColor(Color.kgmPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.76)
            }
        }
        .padding(KGMSpacing.md)
        .background(Color.kgmCard)
        .clipShape(RoundedRectangle(cornerRadius: KGMRadius.card))
        .overlay(RoundedRectangle(cornerRadius: KGMRadius.card).stroke(Color.kgmBorder.opacity(0.95)))
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) { onRemove?() } label: {
                Label("Sil", systemImage: "trash")
            }
        }
    }
}
