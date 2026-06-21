import SwiftUI

struct KGMLoadingView: View {
    var message: String = "Yükleniyor..."

    var body: some View {
        VStack(spacing: KGMSpacing.base) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: Color.kgmPrimary))
                .scaleEffect(1.3)
            Text(message)
                .font(.kgmCallout)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct KGMLoadingOverlay: View {
    var body: some View {
        ZStack {
            Color.black.opacity(0.3).ignoresSafeArea()
            VStack(spacing: KGMSpacing.base) {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(1.5)
                Text("Lütfen bekleyin...")
                    .font(.kgmBody)
                    .foregroundColor(.white)
            }
            .padding(KGMSpacing.xl)
            .background(Color(.systemGray2).opacity(0.9))
            .cornerRadius(KGMRadius.md)
        }
    }
}
