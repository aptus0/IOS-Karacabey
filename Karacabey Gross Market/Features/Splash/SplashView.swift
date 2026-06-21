import SwiftUI

struct SplashView: View {
    let progress: Double
    let statusText: String
    let isUsingCache: Bool
    @State private var isVisible = false

    var body: some View {
        ZStack {
            Image("KGMSplashBackground")
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()

            LinearGradient(
                colors: [Color.black.opacity(0.12), Color.kgmPrimary.opacity(0.38), Color.black.opacity(0.68)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 18) {
                Spacer()

                Image(systemName: "cart.fill")
                    .font(.system(size: 42, weight: .black))
                    .foregroundColor(.white)
                    .frame(width: 88, height: 88)
                    .background(Color.white.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 26, style: .continuous)
                            .stroke(Color.white.opacity(0.22), lineWidth: 1)
                    )

                VStack(spacing: 6) {
                    Text("Karacabey Gross Market")
                        .font(.system(size: 22, weight: .black, design: .rounded))
                        .foregroundColor(.white)

                    Text(statusText.isEmpty ? "Uygulama hazırlanıyor..." : statusText)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white.opacity(0.92))
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .padding(.horizontal, 28)
                }

                VStack(spacing: 8) {
                    ProgressView(value: min(max(progress, 0), 1))
                        .progressViewStyle(.linear)
                        .tint(.white)
                        .frame(width: 168)

                    if isUsingCache {
                        Text("Kayıtlı verilerle hızlı açılıyor")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white.opacity(0.82))
                    }
                }
                .padding(.top, 4)

                Spacer()
            }
            .opacity(isVisible ? 1 : 0.94)
            .scaleEffect(isVisible ? 1 : 0.98)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.22)) {
                isVisible = true
            }
        }
    }
}

struct SplashView_Previews: PreviewProvider {
    static var previews: some View {
        SplashView(progress: 0.65, statusText: "Yükleniyor...", isUsingCache: true)
            .previewLayout(.fixed(width: 390, height: 844))
    }
}
