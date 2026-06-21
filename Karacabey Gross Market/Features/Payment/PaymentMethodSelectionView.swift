import SwiftUI

struct PaymentMethodSelectionView: View {
    let methods: [PaymentMethod]
    @Binding var selectedMethod: PaymentMethod?

    var body: some View {
        VStack(alignment: .leading, spacing: KGMSpacing.md) {
            Text("Ödeme Yöntemi")
                .font(.kgmTitle2)
                .foregroundColor(.kgmTextPrimary)

            ForEach(methods) { method in
                KGMPaymentMethodCard(
                    method: method,
                    isSelected: selectedMethod?.id == method.id
                ) {
                    selectedMethod = method
                }
            }
        }
    }
}

