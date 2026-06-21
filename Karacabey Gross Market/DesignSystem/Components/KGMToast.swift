import SwiftUI

struct KGMToast: View {
    let message: String
    var isError: Bool = false

    var body: some View {
        HStack(spacing: KGMSpacing.sm) {
            Image(systemName: isError ? "xmark.circle.fill" : "checkmark.circle.fill")
                .foregroundColor(isError ? Color.kgmSecondary : Color.kgmPrimary)
            Text(message)
                .font(.kgmCallout)
                .foregroundColor(.primary)
                .lineLimit(2)
        }
        .padding(.horizontal, KGMSpacing.base)
        .padding(.vertical, KGMSpacing.md)
        .background(Color(.systemBackground))
        .cornerRadius(KGMRadius.md)
        .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
        .padding(.horizontal, KGMSpacing.base)
    }
}
