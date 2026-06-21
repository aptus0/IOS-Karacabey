import SwiftUI

struct KGMStoryBar: View {
    let stories: [Story]
    let onSelect: (Story) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: 14) {
                ForEach(stories) { story in
                    KGMStoryBubble(story: story) { onSelect(story) }
                }
            }
            .padding(.horizontal, KGMSpacing.base)
            .padding(.vertical, KGMSpacing.md)
        }
    }
}

struct KGMStoryBubble: View {
    let story: Story
    let onTap: () -> Void

    private static let ringSize: CGFloat = 92
    private static let imageInset: CGFloat = 4

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 8) {
                ZStack {
                    ringView
                    avatarView
                        .frame(width: Self.ringSize - Self.imageInset * 2,
                               height: Self.ringSize - Self.imageInset * 2)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color.kgmCard, lineWidth: 2))
                }
                .frame(width: Self.ringSize, height: Self.ringSize)

                Text(story.title)
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundColor(.kgmTextPrimary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: 94)
            }
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var ringView: some View {
        if story.isViewed {
            Circle()
                .stroke(Color.kgmBorder, lineWidth: 2)
                .frame(width: Self.ringSize, height: Self.ringSize)
        } else {
            Circle()
                .strokeBorder(
                    AngularGradient(
                        gradient: Gradient(colors: [
                            Color(hex: story.gradientStart) ?? .kgmPrimary,
                            Color(hex: story.gradientEnd) ?? .kgmAccent,
                            Color(hex: story.gradientStart) ?? .kgmPrimary
                        ]),
                        center: .center
                    ),
                    lineWidth: 2.8
                )
                .frame(width: Self.ringSize, height: Self.ringSize)
                .shadow(color: (Color(hex: story.gradientEnd) ?? .kgmAccent).opacity(0.32), radius: 8, x: 0, y: 4)
        }
    }

    @ViewBuilder
    private var avatarView: some View {
        if let rawURL = story.coverImageURL,
           let url = EnvironmentConfig.resolveMediaURL(rawURL) {
            KGMCachedImage(url: url) {
                placeholder
            }
            .scaledToFill()
            .clipped()
            .saturation(1.05)
            .drawingGroup(opaque: false, colorMode: .linear)
        } else {
            fallbackIcon
        }
    }

    private var placeholder: some View {
        Circle()
            .fill(Color.kgmCardElevated)
            .overlay(
                ProgressView()
                    .scaleEffect(0.75)
                    .tint(.kgmTextMuted)
            )
    }

    private var fallbackIcon: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(hex: story.gradientStart) ?? .kgmPrimary,
                    Color(hex: story.gradientEnd) ?? .kgmAccent
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            if story.icon.containsEmoji {
                Text(story.icon)
                    .font(.system(size: 28))
            } else {
                Image(systemName: story.icon)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.white)
            }
        }
    }
}

private extension String {
    var containsEmoji: Bool {
        unicodeScalars.contains { $0.properties.isEmojiPresentation || $0.properties.isEmoji }
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
