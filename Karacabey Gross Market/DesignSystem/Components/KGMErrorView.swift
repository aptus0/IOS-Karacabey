import SwiftUI

struct KGMErrorView: View {
    let message: String
    var retryAction: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: KGMSpacing.base) {
            Spacer()
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundColor(Color.kgmWarning)
            Text("Bir Hata Oluştu")
                .font(.kgmTitle2)
            Text(message)
                .font(.kgmBody)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, KGMSpacing.xl)
            if let retry = retryAction {
                KGMButton("Tekrar Dene", style: .outline, fullWidth: false, action: retry)
                    .padding(.horizontal, KGMSpacing.xxl)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}
