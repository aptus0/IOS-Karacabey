import SwiftUI
import StoreKit

struct PaymentSuccessView: View {
    let orderId: String
    var title: String = "Siparişiniz Kontrol Ediliyor"
    var message: String = "Ödemeniz alındı. Siparişiniz mağaza tarafından onaylandığında size bildirim göndereceğiz."
    var buttonTitle: String = "Siparişi Gör"
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @Environment(\.requestReview) private var requestReview
    @State private var isVisible = false
    @State private var didCompleteCartCleanup = false

    var body: some View {
        KGMEmptyStateView(
            icon: "checkmark.seal.fill",
            title: title,
            message: message,
            buttonTitle: buttonTitle,
            buttonAction: {
                dismiss()
                appState.openProfile(.orders)
            }
        )
        .scaleEffect(isVisible ? 1 : 0.92)
        .opacity(isVisible ? 1 : 0)
        .task {
            if !didCompleteCartCleanup {
                didCompleteCartCleanup = true
                await MainActor.run {
                    CartRepository.shared.completeCheckoutAndClearLocalCart()
                }
            }
            withAnimation(.spring(response: 0.48, dampingFraction: 0.76)) {
                isVisible = true
            }
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            requestReview()
        }
    }
}
