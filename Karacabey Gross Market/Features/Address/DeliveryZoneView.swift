import SwiftUI

struct DeliveryZoneView: View {
    let resolution: DeliveryZoneResolution

    var body: some View {
        VStack(alignment: .leading, spacing: KGMSpacing.md) {
            Label(
                resolution.isDeliverable ? "Teslimat yapılabilir" : "Teslimat bölgesi dışında",
                systemImage: resolution.isDeliverable ? "checkmark.seal.fill" : "xmark.seal.fill"
            )
            .font(.kgmHeadline)
            .foregroundColor(resolution.isDeliverable ? .kgmSuccess : .kgmError)

            if let minimum = resolution.minimumCartAmountKurus {
                Text("Minimum sepet: \(minimum.formattedTRY)")
                    .font(.kgmBody)
            }
            if let fee = resolution.deliveryFeeKurus {
                Text("Teslimat ücreti: \(fee.formattedTRY)")
                    .font(.kgmBody)
            }
            if let minutes = resolution.estimatedMinutes {
                Text("Tahmini süre: \(minutes) dk")
                    .font(.kgmBody)
            }
        }
        .padding(KGMSpacing.base)
        .background(Color.kgmCard)
        .cornerRadius(KGMRadius.card)
    }
}
