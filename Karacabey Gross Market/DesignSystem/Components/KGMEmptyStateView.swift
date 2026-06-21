import SwiftUI

struct KGMEmptyStateView: View {
    let icon: String
    let title: String
    let message: String
    var buttonTitle: String? = nil
    var buttonAction: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: KGMSpacing.lg) {
            Spacer()
            Image(systemName: icon)
                .font(.system(size: 64))
                .foregroundColor(Color(.systemGray4))
            VStack(spacing: KGMSpacing.sm) {
                Text(title)
                    .font(.kgmTitle2)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
                Text(message)
                    .font(.kgmBody)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, KGMSpacing.xl)
            }
            if let title = buttonTitle, let action = buttonAction {
                KGMButton(title, fullWidth: false, action: action)
                    .padding(.horizontal, KGMSpacing.xxl)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
