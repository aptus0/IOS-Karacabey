import SwiftUI

struct StoryViewerView: View {
    let stories: [Story]
    @Binding var startIndex: Int
    let onViewed: (Story) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var currentIndex: Int = 0
    @State private var progress: Double = 0
    @State private var timerTask: Task<Void, Never>?
    @State private var isPaused = false

    private let duration: Double = 6.0
    private let tick: Double = 0.035

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if stories.indices.contains(currentIndex) {
                let story = stories[currentIndex]
                content(for: story)
            }
        }
        .onAppear {
            currentIndex = max(0, min(startIndex, stories.count - 1))
            startTimer()
            markViewed()
        }
        .onDisappear { timerTask?.cancel() }
    }

    @ViewBuilder
    private func content(for story: Story) -> some View {
        ZStack(alignment: .top) {
            backgroundLayer(for: story)
                .ignoresSafeArea()

            HStack(spacing: 0) {
                Rectangle().fill(Color.clear).contentShape(Rectangle())
                    .onTapGesture { goPrevious() }
                Rectangle().fill(Color.clear).contentShape(Rectangle())
                    .onTapGesture { goNext() }
            }
            .onLongPressGesture(minimumDuration: 0.08, maximumDistance: 42, pressing: { pressing in
                if pressing { pauseStory() } else { resumeStory() }
            }, perform: {})

            VStack(spacing: KGMSpacing.md) {
                progressBar
                headerRow(for: story)
                Spacer()
                footer(for: story)
            }
            .padding(.horizontal, KGMSpacing.base)
            .padding(.top, KGMSpacing.md)
            .padding(.bottom, KGMSpacing.xl)
        }
    }

    private func backgroundLayer(for story: Story) -> some View {
        GeometryReader { proxy in
            ZStack {
                if let rawURL = story.coverImageURL,
                   let url = EnvironmentConfig.resolveMediaURL(rawURL) {
                    KGMCachedImage(url: url) {
                        gradientFallback(for: story)
                    }
                    .scaledToFill()
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .clipped()
                    .blur(radius: 22)
                    .saturation(1.08)
                    .overlay(Color.black.opacity(0.34))

                    KGMCachedImage(url: url) {
                        ProgressView().tint(.white)
                    }
                    .scaledToFit()
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .clipped()
                    .shadow(color: .black.opacity(0.30), radius: 18, x: 0, y: 8)
                    .overlay(Color.black.opacity(0.02))
                } else {
                    gradientFallback(for: story)
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
    }

    private func gradientFallback(for story: Story) -> some View {
        LinearGradient(
            colors: [
                Color(hex: story.gradientStart) ?? .kgmPrimary,
                Color(hex: story.gradientEnd) ?? .kgmAccent
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var progressBar: some View {
        HStack(spacing: 4) {
            ForEach(stories.indices, id: \.self) { i in
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.white.opacity(0.30))
                        Capsule()
                            .fill(isPaused && i == currentIndex ? Color.white.opacity(0.72) : Color.white)
                            .frame(width: barWidth(for: i, total: geo.size.width))
                    }
                }
                .frame(height: 3.2)
            }
        }
    }

    private func barWidth(for index: Int, total: CGFloat) -> CGFloat {
        if index < currentIndex { return total }
        if index > currentIndex { return 0 }
        return total * CGFloat(progress)
    }

    private func headerRow(for story: Story) -> some View {
        HStack(alignment: .top, spacing: KGMSpacing.sm) {
            VStack(alignment: .leading, spacing: 2) {
                Text(story.title)
                    .font(.kgmHeadline)
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.25), radius: 4, x: 0, y: 2)
                if let subtitle = story.subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.kgmCaption)
                        .foregroundColor(.white.opacity(0.90))
                        .lineLimit(2)
                }
            }
            Spacer()
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
                    .padding(10)
                    .background(Color.black.opacity(0.28))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
    }

    @ViewBuilder
    private func footer(for story: Story) -> some View {
        if let link = story.deepLink, !link.isEmpty {
            Button {
                DeepLinkRouter.shared.open(link)
                dismiss()
            } label: {
                HStack {
                    Text(ctaLabel(for: story))
                        .font(.kgmBodyMedium)
                    Image(systemName: "arrow.right")
                }
                .foregroundColor(.kgmTextPrimary)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(Color.white)
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
    }

    private func ctaLabel(for story: Story) -> String {
        if story.categorySlug != nil { return "Kategoriyi Görüntüle" }
        return "Detaya Git"
    }

    private func startTimer() {
        timerTask?.cancel()
        isPaused = false
        progress = 0
        timerTask = Task { @MainActor in
            while progress < 1.0 {
                guard !Task.isCancelled else { return }
                try? await Task.sleep(nanoseconds: UInt64(tick * 1_000_000_000))
                guard !Task.isCancelled else { return }
                if !isPaused {
                    progress = min(1.0, progress + tick / duration)
                }
            }
            guard !Task.isCancelled else { return }
            goNext()
        }
    }

    private func pauseStory() {
        isPaused = true
    }

    private func resumeStory() {
        isPaused = false
    }

    private func goNext() {
        if currentIndex + 1 < stories.count {
            currentIndex += 1
            markViewed()
            startTimer()
        } else {
            dismiss()
        }
    }

    private func goPrevious() {
        if currentIndex > 0 {
            currentIndex -= 1
            startTimer()
        } else {
            progress = 0
            startTimer()
        }
    }

    private func markViewed() {
        guard stories.indices.contains(currentIndex) else { return }
        onViewed(stories[currentIndex])
    }
}

private extension Color {
    init?(hex: String) {
        var sanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if sanitized.hasPrefix("#") { sanitized.removeFirst() }
        guard sanitized.count == 6, let value = UInt32(sanitized, radix: 16) else { return nil }
        let r = Double((value >> 16) & 0xFF) / 255
        let g = Double((value >> 8) & 0xFF) / 255
        let b = Double(value & 0xFF) / 255
        self = Color(red: r, green: g, blue: b)
    }
}
