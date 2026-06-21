import SwiftUI

struct PaymentProcessingView: View {
    var body: some View {
        VStack(spacing: KGMSpacing.base) {
            ProgressView()
                .tint(.kgmPrimary)
            Text("Ödeme sonucu kontrol ediliyor")
                .font(.kgmHeadline)
                .foregroundColor(.kgmTextPrimary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.kgmBackground)
    }
}

