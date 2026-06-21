import SwiftUI

struct KGMCartSummaryView: View {
    let cart: Cart
    var buttonTitle: String = "Siparişi Onayla"
    var isButtonDisabled: Bool = false
    var onCheckout: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 0) {
            Divider()
            VStack(spacing: KGMSpacing.sm) {
                summaryRow("Ara Toplam", value: cart.subtotal)
                if cart.hasDeliveryFee {
                    summaryRow("Teslimat Ücreti", value: cart.deliveryFee)
                } else {
                    summaryTextRow("Teslimat Ücreti", value: "Adres adımında hesaplanır")
                }
                if cart.discountAmount > 0 {
                    summaryRow("İndirim", value: -cart.discountAmount, isDiscount: true)
                }
                Divider()
                HStack {
                    Text("Toplam")
                        .font(.kgmTitle2)
                    Spacer()
                    Text(cart.total.formattedAsTurkishLira)
                        .font(.kgmTitle2)
                        .foregroundColor(Color.kgmPrimary)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Toplam")
                .accessibilityValue(cart.total.formattedAsTurkishLira)
                KGMButton(buttonTitle, isDisabled: isButtonDisabled, action: { onCheckout?() })
            }
            .padding(KGMSpacing.base)
        }
        .background(Color(.systemBackground))
    }

    private func summaryRow(_ title: String, value: Double, isFree: Bool = false, isDiscount: Bool = false) -> some View {
        HStack {
            Text(title)
                .font(.kgmBody)
                .foregroundColor(.secondary)
            Spacer()
            if isFree && value == 0 {
                Text("Ücretsiz")
                    .font(.kgmBodyMedium)
                    .foregroundColor(Color.kgmPrimary)
            } else {
                Text(value.formattedAsTurkishLira)
                    .font(.kgmBodyMedium)
                    .foregroundColor(isDiscount ? Color.kgmSecondary : .primary)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityValue(isFree && value == 0 ? "Ücretsiz" : value.formattedAsTurkishLira)
    }

    private func summaryTextRow(_ title: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.kgmBody)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.kgmCaptionMedium)
                .foregroundColor(.kgmTextSecondary)
                .multilineTextAlignment(.trailing)
                .lineLimit(2)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityValue(value)
    }
}
