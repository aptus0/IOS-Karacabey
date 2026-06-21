import SwiftUI

struct KGMPriceLabel: View {
    let price: Double
    var originalPrice: Double? = nil
    var size: PriceSize = .medium

    enum PriceSize { case small, medium, large }

    var body: some View {
        HStack(alignment: .bottom, spacing: KGMSpacing.xs) {
            Text(price.formattedAsTurkishLira)
                .font(priceFont)
                .foregroundColor(Color.kgmPrimary)
            if let original = originalPrice, original > price {
                Text(original.formattedAsTurkishLira)
                    .font(.kgmSmall)
                    .strikethrough()
                    .foregroundColor(.secondary)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Fiyat")
        .accessibilityValue(accessibilityValue)
    }

    private var accessibilityValue: String {
        guard let original = originalPrice, original > price else {
            return price.formattedAsTurkishLira
        }
        return "\(price.formattedAsTurkishLira), eski fiyat \(original.formattedAsTurkishLira)"
    }

    private var priceFont: Font {
        switch size {
        case .small:  return .kgmPriceSmall
        case .medium: return .kgmPrice
        case .large:  return .system(size: 24, weight: .bold)
        }
    }
}
