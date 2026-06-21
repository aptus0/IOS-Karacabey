import SwiftUI

struct KGMCouponInput: View {
    @Binding var couponCode: String
    var isLoading: Bool = false
    var appliedDiscount: Double? = nil
    var onApply: (() -> Void)? = nil
    var onRemove: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: KGMSpacing.xs) {
            if let discount = appliedDiscount {
                HStack {
                    Image(systemName: "tag.fill")
                        .foregroundColor(Color.kgmPrimary)
                    Text("\"\(couponCode)\" kuponu uygulandı")
                        .font(.kgmCallout)
                        .foregroundColor(Color.kgmPrimary)
                    Spacer()
                    Text("-\(discount.formattedAsTurkishLira)")
                        .font(.kgmBodyMedium)
                        .foregroundColor(Color.kgmSecondary)
                    Button(action: { onRemove?() }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                }
                .padding(KGMSpacing.md)
                .background(Color.kgmPrimary.opacity(0.08))
                .cornerRadius(KGMRadius.sm)
            } else {
                HStack(spacing: KGMSpacing.sm) {
                    TextField("Kupon kodunuz", text: $couponCode)
                        .font(.kgmBody)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.characters)
                        .padding(.horizontal, KGMSpacing.md)
                        .frame(height: 48)
                        .background(Color.kgmCardElevated)
                        .cornerRadius(KGMRadius.sm)
                    KGMButton(
                        "Uygula",
                        isLoading: isLoading,
                        isDisabled: couponCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                        fullWidth: false
                    ) {
                        onApply?()
                    }
                    .frame(width: 100)
                }
            }
        }
    }
}
