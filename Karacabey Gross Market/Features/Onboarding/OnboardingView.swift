import SwiftUI

struct OnboardingPage: Identifiable {
    let id = UUID()
    let icon: String
    let title: String
    let description: String
    let color: Color
}

struct OnboardingView: View {
    @EnvironmentObject var appState: AppState
    @State private var currentPage = 0

    private let pages: [OnboardingPage] = [
        OnboardingPage(icon: "bolt.fill",          title: "Hızlı Market Alışverişi", description: "Binlerce taze ürüne dakikalar içinde ulaşın. Sepetinizi doldurun, biz kapınıza getiririz.",            color: Color.kgmPrimary),
        OnboardingPage(icon: "lock.shield.fill",   title: "Güvenli Ödeme",            description: "256-bit SSL şifrelemesi ile tüm ödemeleriniz güvence altında. Kart bilgileriniz asla saklanmaz.", color: Color.kgmInfo),
        OnboardingPage(icon: "house.and.flag.fill", title: "Kapınıza Teslimat",        description: "Siparişlerinizi gerçek zamanlı takip edin. Taze ürünler aynı gün teslim.",                          color: Color.kgmAccent),
    ]

    var body: some View {
        ZStack {
            pages[currentPage].color.opacity(0.07).ignoresSafeArea()

            VStack(spacing: 0) {
                HStack {
                    Spacer()
                    Button("Atla") {
                        finishOnboarding()
                    }
                    .font(.kgmBody)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, KGMSpacing.base)
                    .padding(.top, KGMSpacing.base)
                }

                TabView(selection: $currentPage) {
                    ForEach(Array(pages.enumerated()), id: \.offset) { index, page in
                        VStack(spacing: KGMSpacing.xl) {
                            Spacer()
                            ZStack {
                                Circle()
                                    .fill(page.color.opacity(0.15))
                                    .frame(width: 160, height: 160)
                                Image(systemName: page.icon)
                                    .font(.system(size: 72))
                                    .foregroundColor(page.color)
                            }
                            VStack(spacing: KGMSpacing.md) {
                                Text(page.title)
                                    .font(.kgmLargeTitle)
                                    .multilineTextAlignment(.center)
                                    .foregroundColor(.primary)
                                Text(page.description)
                                    .font(.kgmBody)
                                    .multilineTextAlignment(.center)
                                    .foregroundColor(.secondary)
                                    .padding(.horizontal, KGMSpacing.xl)
                            }
                            Spacer()
                        }
                        .tag(index)
                    }
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))

                VStack(spacing: KGMSpacing.lg) {
                    HStack(spacing: KGMSpacing.sm) {
                        ForEach(0..<pages.count, id: \.self) { i in
                            Capsule()
                                .fill(i == currentPage ? pages[currentPage].color : Color(.systemGray4))
                                .frame(width: i == currentPage ? 24 : 8, height: 8)
                                .animation(.easeInOut(duration: 0.3), value: currentPage)
                        }
                    }

                    KGMButton(currentPage == pages.count - 1 ? "Başla" : "İleri") {
                        if currentPage < pages.count - 1 {
                            withAnimation { currentPage += 1 }
                        } else {
                            finishOnboarding()
                        }
                    }
                    .padding(.horizontal, KGMSpacing.base)
                }
                .padding(.bottom, KGMSpacing.xxxl)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: currentPage)
    }

    private func finishOnboarding() {
        UserDefaults.standard.set(true, forKey: "hasSeenOnboarding")
        withAnimation { appState.showingOnboarding = false }
    }
}
