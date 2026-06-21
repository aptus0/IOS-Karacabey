import SwiftUI

struct KGMPaymentMethodCard: View {
    let method: PaymentMethod
    var isSelected: Bool = false
    var onSelect: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: KGMSpacing.md) {
            ZStack {
                Circle()
                    .fill(Color.kgmPrimary.opacity(0.1))
                    .frame(width: 44, height: 44)
                Image(systemName: method.type.iconName)
                    .foregroundColor(Color.kgmPrimary)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(method.type.displayName)
                    .font(.kgmBodyMedium)
                if let holder = method.cardHolderName {
                    Text(holder)
                        .font(.kgmCaption)
                        .foregroundColor(.secondary)
                }
                if let expiry = method.expiryDate {
                    Text("Son Kullanma: \(expiry)")
                        .font(.kgmSmall)
                        .foregroundColor(.secondary)
                }
            }
            Spacer()
            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(Color.kgmPrimary)
                    .font(.system(size: 22))
            }
        }
        .padding(KGMSpacing.base)
        .background(isSelected ? Color.kgmPrimary.opacity(0.05) : Color(.systemBackground))
        .cornerRadius(KGMRadius.md)
        .overlay(
            RoundedRectangle(cornerRadius: KGMRadius.md)
                .stroke(isSelected ? Color.kgmPrimary : Color(.systemGray5), lineWidth: isSelected ? 2 : 1)
        )
        .onTapGesture { onSelect?() }
    }
}
