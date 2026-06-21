import SwiftUI

struct KGMCategoryCard: View {
    let category: Category
    var onTap: (() -> Void)? = nil

    var body: some View {
        Button(action: { onTap?() }) {
            VStack(spacing: KGMSpacing.sm) {
                ZStack {
                    Circle()
                        .fill(categoryTint.opacity(0.15))
                        .frame(width: 64, height: 64)
                    Image(systemName: category.iconName)
                        .font(.system(size: 28))
                        .foregroundColor(categoryTint)
                }
                Text(category.name)
                    .font(.kgmCaptionMedium)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, KGMSpacing.md)
            .background(Color(.systemBackground))
            .cornerRadius(KGMRadius.sm)
            .shadow(color: .black.opacity(0.05), radius: 3, x: 0, y: 1)
        }
        .buttonStyle(PlainButtonStyle())
    }

    private var categoryTint: Color {
        switch abs(category.id.hashValue) % 5 {
        case 0: return .kgmPrimary
        case 1: return .kgmCampaign
        case 2: return .kgmInfo
        case 3: return .kgmWarning
        default: return .kgmAccent
        }
    }
}
