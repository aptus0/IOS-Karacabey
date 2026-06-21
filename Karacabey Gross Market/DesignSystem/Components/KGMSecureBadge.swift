import SwiftUI

struct KGMSecureBadge: View {
    var message: String = "256-bit SSL ile güvenli ödeme"

    var body: some View {
        HStack(spacing: KGMSpacing.xs) {
            Image(systemName: "lock.shield.fill")
                .foregroundColor(Color.kgmPrimary)
                .font(.system(size: 14))
            Text(message)
                .font(.kgmSmall)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, KGMSpacing.md)
        .padding(.vertical, KGMSpacing.xs)
        .background(Color.kgmPrimary.opacity(0.08))
        .cornerRadius(KGMRadius.full)
    }
}
