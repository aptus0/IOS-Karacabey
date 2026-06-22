import SwiftUI

struct BannerItem: Identifiable, Codable, Hashable {
    let id: String
    let title: String
    let subtitle: String
    let imageURL: String
    let backgroundColor: String
    let actionURL: String?

    var resolvedImageURL: URL? {
        EnvironmentConfig.resolveMediaURL(imageURL)
    }

    enum CodingKeys: String, CodingKey {
        case id, title, subtitle, backgroundColor
        case imageURL = "imageUrl"
        case mobileImageURL = "mobileImageUrl"
        case desktopImageURL = "desktopImageUrl"
        case bannerImageURL = "bannerImageUrl"
        case coverImageURL = "coverImageUrl"
        case image
        case picture
        case actionURL = "actionUrl"
        case linkURL = "linkUrl"
        case deepLink
        case url
    }

    init(id: String, title: String, subtitle: String, imageURL: String, backgroundColor: String, actionURL: String?) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.imageURL = imageURL
        self.backgroundColor = backgroundColor
        self.actionURL = actionURL
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let numericID = try? container.decode(Int64.self, forKey: .id) {
            id = String(numericID)
        } else {
            id = (try? container.decode(String.self, forKey: .id)) ?? UUID().uuidString
        }
        title = (try? container.decode(String.self, forKey: .title)) ?? ""
        subtitle = (try? container.decodeIfPresent(String.self, forKey: .subtitle)) ?? ""
        imageURL = Self.firstString(
            in: container,
            keys: [.mobileImageURL, .imageURL, .bannerImageURL, .desktopImageURL, .coverImageURL, .image, .picture]
        ) ?? ""
        backgroundColor = (try? container.decodeIfPresent(String.self, forKey: .backgroundColor)) ?? "#FF7A00"
        actionURL = Self.firstString(in: container, keys: [.actionURL, .linkURL, .deepLink, .url])
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encode(subtitle, forKey: .subtitle)
        try container.encode(imageURL, forKey: .imageURL)
        try container.encode(backgroundColor, forKey: .backgroundColor)
        try container.encodeIfPresent(actionURL, forKey: .actionURL)
    }

    private static func firstString(
        in container: KeyedDecodingContainer<CodingKeys>,
        keys: [CodingKeys]
    ) -> String? {
        for key in keys {
            let value = try? container.decodeIfPresent(String.self, forKey: key)
            if let value {
                let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    return trimmed
                }
            }
        }

        return nil
    }
}

struct HomepageContent: Decodable {
    let blocks: [BannerItem]
}

struct KGMBannerCard: View {
    let banner: BannerItem

    var body: some View {
        ZStack(alignment: .leading) {
            backgroundLayer
            imageLayer
            contentLayer
        }
        .clipShape(RoundedRectangle(cornerRadius: KGMRadius.md))
        .overlay(RoundedRectangle(cornerRadius: KGMRadius.md).stroke(Color.kgmBorder.opacity(0.30), lineWidth: 1))
        .clipped()
        .accessibilityElement(children: .combine)
    }

    private var backgroundLayer: some View {
        RoundedRectangle(cornerRadius: KGMRadius.md)
            .fill(Color(hex: banner.backgroundColor) ?? Color.kgmCampaign)
    }

    private var imageLayer: some View {
        KGMCachedImage(url: banner.resolvedImageURL) {
            bannerPlaceholder
        }
        .scaledToFill()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
        .overlay(bannerScrim)
    }

    private var bannerPlaceholder: some View {
        LinearGradient(
            colors: [Color.kgmPrimary.opacity(0.22), Color.kgmPrimary.opacity(0.08)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .overlay(
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 28, weight: .semibold))
                .foregroundColor(.white.opacity(0.72))
        )
    }

    private var bannerScrim: some View {
        LinearGradient(
            colors: [Color.black.opacity(0.46), Color.black.opacity(0.12), Color.black.opacity(0.0)],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    private var contentLayer: some View {
        HStack {
            VStack(alignment: .leading, spacing: KGMSpacing.xs) {
                subtitleBadge
                bannerTitle
                callToActionLabel
            }
            .padding(KGMSpacing.base)

            Spacer()
        }
    }

    @ViewBuilder
    private var subtitleBadge: some View {
        if !banner.subtitle.isEmpty {
            Text(banner.subtitle)
                .font(.kgmCaptionMedium)
                .foregroundColor(.white)
                .lineLimit(1)
                .padding(.horizontal, KGMSpacing.sm)
                .frame(height: 28)
                .background(Color.kgmPrimary.opacity(0.78))
                .clipShape(Capsule())
        }
    }

    private var bannerTitle: some View {
        Text(banner.title.isEmpty ? "Karacabey Gross Market" : banner.title)
            .font(.system(size: 24, weight: .black))
            .foregroundColor(.white)
            .lineLimit(2)
            .minimumScaleFactor(0.78)
    }

    private var callToActionLabel: some View {
        Text("Alışverişe Başla")
            .font(.kgmCaptionMedium)
            .foregroundColor(.kgmPrimary)
            .lineLimit(1)
            .minimumScaleFactor(0.86)
            .padding(.horizontal, KGMSpacing.base)
            .frame(height: 38)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: KGMRadius.sm))
    }
}

struct KGMBannerSlider: View {
    let banners: [BannerItem]
    let onBannerTap: (BannerItem) -> Void
    @State private var currentIndex = 0
    private let maximumCardHeight: CGFloat = 232
    private let minimumCardHeight: CGFloat = 184
    private let dotHeight: CGFloat = 8

    var body: some View {
        GeometryReader { proxy in
            let cardWidth = max(0, proxy.size.width - (KGMSpacing.base * 2))
            let cardHeight = min(max(cardWidth * 0.56, minimumCardHeight), maximumCardHeight)

            VStack(spacing: KGMSpacing.sm) {
                TabView(selection: $currentIndex) {
                    ForEach(Array(banners.enumerated()), id: \.offset) { index, banner in
                        Button {
                            onBannerTap(banner)
                        } label: {
                            KGMBannerCard(banner: banner)
                                .frame(width: cardWidth, height: cardHeight)
                        }
                        .buttonStyle(.plain)
                        .frame(maxWidth: .infinity, maxHeight: cardHeight)
                        .tag(index)
                        .accessibilityLabel(banner.title.isEmpty ? "Karacabey Gross Market kampanyası" : banner.title)
                    }
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                .frame(height: cardHeight)
                .clipped()

                HStack(spacing: KGMSpacing.xs) {
                    ForEach(0..<banners.count, id: \.self) { i in
                        Capsule()
                            .fill(i == currentIndex ? Color.kgmPrimary : Color(.systemGray4))
                            .frame(width: i == currentIndex ? 16 : 6, height: dotHeight)
                            .animation(.easeInOut(duration: 0.2), value: currentIndex)
                    }
                }
            }
            .frame(width: proxy.size.width, height: cardHeight + KGMSpacing.sm + dotHeight, alignment: .top)
        }
        .frame(height: maximumCardHeight + KGMSpacing.sm + dotHeight)
        .clipped()
        .task(id: banners.count) {
            guard banners.count > 1 else { return }
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 4_000_000_000)
                guard !Task.isCancelled, banners.count > 1 else { return }
                withAnimation(.easeInOut(duration: 0.35)) {
                    currentIndex = (currentIndex + 1) % banners.count
                }
            }
        }
        .onChange(of: banners.count) { _, count in
            if currentIndex >= count {
                currentIndex = max(0, count - 1)
            }
        }
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
