import SwiftUI

struct PaymentFailedView: View {
    let message: String
    let retry: () -> Void
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: KGMSpacing.lg) {
            Spacer()
            Image(systemName: "creditcard.trianglebadge.exclamationmark")
                .font(.system(size: 58, weight: .semibold))
                .foregroundColor(.kgmError)
            VStack(spacing: KGMSpacing.sm) {
                Text("Ödeme tamamlanamadı")
                    .font(.kgmTitle2)
                    .foregroundColor(.kgmTextPrimary)
                Text(message)
                    .font(.kgmBody)
                    .foregroundColor(.kgmTextSecondary)
                    .multilineTextAlignment(.center)
            }
            VStack(spacing: KGMSpacing.sm) {
                KGMButton("Tekrar Dene", action: retry)
                KGMButton("Sepete Dön", style: .outline) {
                    dismiss()
                    appState.selectedTab = .cart
                }
            }
            .padding(.horizontal, KGMSpacing.xl)
            Spacer()
        }
        .padding(KGMSpacing.base)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.kgmBackground)
    }
}
