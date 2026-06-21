import SwiftUI

struct KGMFeaturedToolBanner: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: KGMSpacing.base) {
                Image(systemName: "shippingbox.and.arrow.backward.fill")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 56, height: 56)
                    .background(Color.white.opacity(0.18))
                    .clipShape(RoundedRectangle(cornerRadius: KGMRadius.md))

                VStack(alignment: .leading, spacing: KGMSpacing.xs) {
                    Text("Sipariş Nerede?")
                        .font(.kgmTitle2)
                        .foregroundColor(.white)
                    Text("Son aktif siparişinin durumunu takip et.")
                        .font(.kgmCallout)
                        .foregroundColor(.white.opacity(0.86))
                }

                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundColor(.white)
            }
            .padding(KGMSpacing.base)
            .background(Color.kgmPrimary)
            .clipShape(RoundedRectangle(cornerRadius: KGMRadius.card))
        }
        .buttonStyle(.plain)
    }
}
