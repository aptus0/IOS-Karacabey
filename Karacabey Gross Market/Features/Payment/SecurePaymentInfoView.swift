import SwiftUI

struct SecurePaymentInfoView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: KGMSpacing.sm) {
            KGMSecureBadge(message: "PayTR ile 3D Secure destekli güvenli ödeme")
            Text("Kart bilgileriniz uygulamada saklanmaz, loglanmaz ve ödeme doğrulaması backend üzerinden yürütülür.")
                .font(.kgmCallout)
                .foregroundColor(.kgmTextSecondary)
        }
        .padding(KGMSpacing.base)
        .background(Color.kgmSecurePayment.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: KGMRadius.card))
    }
}
