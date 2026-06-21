import SwiftUI

struct CouponsView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var cartRepo: CartRepository
    @State private var couponCode = ""
    @State private var offers: [CustomerCouponOffer] = []
    @State private var isLoadingOffers = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: KGMSpacing.base) {
                VStack(alignment: .leading, spacing: KGMSpacing.sm) {
                    Label("Sepet Kuponu", systemImage: "ticket.fill")
                        .font(.kgmHeadline)
                        .foregroundColor(.kgmTextPrimary)

                    Text("Her kupon müşteri başına yalnızca 1 kez kullanılabilir. Kullanılmış veya limiti dolmuş kuponlar tekrar sepete uygulanmaz.")
                        .font(.kgmCaption)
                        .foregroundColor(.kgmTextSecondary)
                }
                .padding(KGMSpacing.base)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.kgmCard)
                .clipShape(RoundedRectangle(cornerRadius: KGMRadius.card))
                .overlay(RoundedRectangle(cornerRadius: KGMRadius.card).stroke(Color.kgmBorder))

                KGMCouponInput(
                    couponCode: $couponCode,
                    appliedDiscount: cartRepo.cart.discountAmount > 0 ? cartRepo.cart.discountAmount : nil,
                    onApply: { applyCoupon(couponCode) },
                    onRemove: { cartRepo.removeCoupon(); couponCode = "" }
                )
                .padding(KGMSpacing.base)
                .background(Color.kgmCard)
                .clipShape(RoundedRectangle(cornerRadius: KGMRadius.card))
                .overlay(RoundedRectangle(cornerRadius: KGMRadius.card).stroke(Color.kgmBorder))

                if let error = cartRepo.lastError {
                    Label(error, systemImage: "exclamationmark.circle.fill")
                        .font(.kgmCaption)
                        .foregroundColor(.kgmError)
                        .padding(KGMSpacing.md)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.kgmError.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: KGMRadius.md))
                }

                if isLoadingOffers {
                    ProgressView("Kuponlar yükleniyor...")
                        .frame(maxWidth: .infinity)
                        .padding(KGMSpacing.base)
                } else if !offers.isEmpty {
                    VStack(alignment: .leading, spacing: KGMSpacing.sm) {
                        Text("Tanımlı Kuponlar")
                            .font(.kgmHeadline)
                            .foregroundColor(.kgmTextPrimary)

                        ForEach(offers) { offer in
                            couponOfferRow(offer)
                        }
                    }
                    .padding(KGMSpacing.base)
                    .background(Color.kgmCard)
                    .clipShape(RoundedRectangle(cornerRadius: KGMRadius.card))
                    .overlay(RoundedRectangle(cornerRadius: KGMRadius.card).stroke(Color.kgmBorder))
                }

                KGMCartSummaryView(cart: cartRepo.cart, buttonTitle: "Sepete Git") {
                    appState.selectedTab = .cart
                }
                    .clipShape(RoundedRectangle(cornerRadius: KGMRadius.card))
            }
            .padding(KGMSpacing.base)
            .padding(.bottom, KGMSpacing.xxxl)
        }
        .background(Color.kgmBackground.ignoresSafeArea())
        .navigationTitle("Kuponlarım")
        .navigationBarTitleDisplayMode(.large)
        .task { await loadOffers() }
        .onAppear {
            couponCode = cartRepo.cart.couponCode ?? couponCode
        }
        .onChange(of: cartRepo.cart.couponCode) { _, value in
            couponCode = value ?? ""
        }
    }

    private func couponOfferRow(_ offer: CustomerCouponOffer) -> some View {
        let alreadyUsed = cartRepo.hasUsedCoupon(offer.code)
        let disabled = alreadyUsed || !offer.canApply

        return HStack(spacing: KGMSpacing.md) {
            Image(systemName: disabled ? "ticket" : "ticket.fill")
                .foregroundColor(disabled ? .kgmTextMuted : .kgmPrimary)
                .frame(width: 34, height: 34)
                .background((disabled ? Color.kgmTextMuted : Color.kgmPrimary).opacity(0.10))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 3) {
                Text(offer.code)
                    .font(.kgmCaptionMedium)
                    .foregroundColor(.kgmTextPrimary)
                Text(offer.subtitle)
                    .font(.kgmSmall)
                    .foregroundColor(.kgmTextSecondary)
                Text(alreadyUsed ? "Bu kuponu daha önce kullandınız" : offer.usageLabel)
                    .font(.kgmSmall)
                    .foregroundColor(disabled ? .kgmTextMuted : .kgmPrimary)
            }

            Spacer()

            Button(disabled ? "Kapalı" : "Uygula") {
                applyCoupon(offer.code)
            }
            .font(.kgmSmall.weight(.bold))
            .foregroundColor(disabled ? .kgmTextMuted : .white)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(disabled ? Color.kgmCardElevated : Color.kgmPrimary)
            .clipShape(RoundedRectangle(cornerRadius: KGMRadius.sm))
            .disabled(disabled)
        }
        .padding(.vertical, KGMSpacing.xs)
    }

    private func applyCoupon(_ code: String) {
        couponCode = code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        cartRepo.applyCoupon(couponCode)
    }

    private func loadOffers() async {
        guard !isLoadingOffers else { return }
        isLoadingOffers = true
        defer { isLoadingOffers = false }
        offers = (try? await ShoppingExperienceRepository.shared.getCustomerCoupons()) ?? []
    }
}
