import ActivityKit
import SwiftUI
import UIKit
import WidgetKit

private let appGroup = "group.com.karacabeygrossmarket.app"
private let kgmOrange = Color(red: 1.0, green: 0.42, blue: 0.0)
private let kgmOrange2 = Color(red: 1.0, green: 0.23, blue: 0.0)
private let kgmDark = Color(red: 0.10, green: 0.09, blue: 0.09)
private let kgmCream = Color(red: 1.0, green: 0.95, blue: 0.88)

private func normalizedStatus(_ status: String) -> String {
    status.lowercased().replacingOccurrences(of: "-", with: "_")
}

private func statusLabel(_ status: String) -> String {
    switch normalizedStatus(status) {
    case "pending": return "Sipariş alındı"
    case "awaiting_payment": return "Ödeme bekleniyor"
    case "reviewing": return "Kontrol ediliyor"
    case "received": return "Mağazaya ulaştı"
    case "preparing", "processing": return "Hazırlanıyor"
    case "on_the_way", "shipping", "in_delivery": return "Yola çıktı"
    case "delivered", "completed": return "Teslim edildi"
    case "cancelled", "canceled", "failed": return "İptal edildi"
    default: return "Güncelleniyor"
    }
}

private func statusProgress(_ status: String) -> Double {
    switch normalizedStatus(status) {
    case "pending", "awaiting_payment", "reviewing", "received": return 0.22
    case "preparing", "processing": return 0.52
    case "on_the_way", "shipping", "in_delivery": return 0.82
    case "delivered", "completed": return 1
    case "cancelled", "canceled", "failed": return 0
    default: return 0.22
    }
}


private struct OrderSnapshot: Codable {
    let orderId: String
    let title: String
    let status: String
    let estimatedDeliveryAt: Date?
    let updatedAt: Date
    let deepLink: String
}

private struct CampaignSnapshot: Codable, Hashable {
    let campaignId: String
    let title: String
    let imageURL: String?
    let ctaTitle: String
    let deepLink: String
    let updatedAt: Date
}

private enum SharedSnapshots {
    static func order() -> OrderSnapshot? {
        decode(OrderSnapshot.self, key: "kgm.widget.order.snapshot")
    }

    static func campaign() -> CampaignSnapshot? {
        campaigns().first ?? decode(CampaignSnapshot.self, key: "kgm.widget.campaign.snapshot")
    }

    static func campaigns() -> [CampaignSnapshot] {
        if let items = decode([CampaignSnapshot].self, key: "kgm.widget.campaigns.snapshot"), !items.isEmpty {
            return items
        }
        return decode(CampaignSnapshot.self, key: "kgm.widget.campaign.snapshot").map { [$0] } ?? []
    }

    static func campaignImage(index: Int) -> UIImage? {
        let directory = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroup)
        if let url = directory?.appendingPathComponent("kgm-widget-campaign-\(index).jpg"),
           let image = UIImage(contentsOfFile: url.path) {
            return image
        }
        if index == 0,
           let url = directory?.appendingPathComponent("kgm-widget-campaign.jpg") {
            return UIImage(contentsOfFile: url.path)
        }
        return nil
    }

    private static func decode<T: Decodable>(_ type: T.Type, key: String) -> T? {
        guard let data = UserDefaults(suiteName: appGroup)?.data(forKey: key) else { return nil }
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(type, from: data)
    }
}

private struct SnapshotEntry: TimelineEntry {
    let date: Date
    let order: OrderSnapshot?
    let campaigns: [CampaignSnapshot]
    let campaignIndex: Int

    var campaign: CampaignSnapshot? {
        guard !campaigns.isEmpty else { return nil }
        return campaigns[campaignIndex % campaigns.count]
    }
}

private struct SnapshotProvider: TimelineProvider {
    func placeholder(in context: Context) -> SnapshotEntry {
        SnapshotEntry(date: .now, order: nil, campaigns: [], campaignIndex: 0)
    }

    func getSnapshot(in context: Context, completion: @escaping (SnapshotEntry) -> Void) {
        completion(entry(index: 0))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SnapshotEntry>) -> Void) {
        let campaigns = SharedSnapshots.campaigns()
        let order = SharedSnapshots.order()
        let count = max(campaigns.count, 1)
        let now = Date()
        let entries = (0..<min(count, 5)).map { index in
            SnapshotEntry(
                date: now.addingTimeInterval(TimeInterval(index * 12 * 60)),
                order: order,
                campaigns: campaigns,
                campaignIndex: index
            )
        }
        completion(Timeline(entries: entries.isEmpty ? [entry(index: 0)] : entries,
                            policy: .after(now.addingTimeInterval(12 * 60))))
    }

    private func entry(index: Int) -> SnapshotEntry {
        SnapshotEntry(date: .now,
                      order: SharedSnapshots.order(),
                      campaigns: SharedSnapshots.campaigns(),
                      campaignIndex: index)
    }
}

private struct KGMBrandBadge: View {
    let compact: Bool

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "cart.fill")
                .font(compact ? .caption2.bold() : .caption.bold())
            Text(compact ? "KGM" : "Karacabey Gross")
                .font(compact ? .caption.bold() : .caption.weight(.heavy))
                .lineLimit(1)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, compact ? 8 : 10)
        .frame(height: compact ? 24 : 30)
        .background(.black.opacity(0.36))
        .clipShape(Capsule())
    }
}

private struct CampaignWidgetView: View {
    let entry: SnapshotEntry
    @Environment(\.widgetFamily) private var family

    private var inlineStatusText: String {
        entry.order.map { statusLabel($0.status) } ?? "Hazır"
    }

    private var rectangularStatusText: String {
        entry.order.map { statusLabel($0.status) } ?? "Aktif sipariş yok"
    }

    var body: some View {
        switch family {
        case .accessoryInline:
            accessoryInline
        case .accessoryCircular:
            accessoryCircular
        case .accessoryRectangular:
            accessoryRectangular
        default:
            homeCampaign
        }
    }

    private var homeCampaign: some View {
        ZStack(alignment: .bottomLeading) {
            campaignBackground

            LinearGradient(
                colors: [.black.opacity(0.02), .black.opacity(0.20), .black.opacity(0.76)],
                startPoint: .top,
                endPoint: .bottom
            )

            VStack(alignment: .leading, spacing: family == .systemSmall ? 7 : 10) {
                HStack {
                    KGMBrandBadge(compact: family == .systemSmall)
                    Spacer(minLength: 0)
                    if entry.campaigns.count > 1, family != .systemSmall {
                        Text("\((entry.campaignIndex % entry.campaigns.count) + 1)/\(entry.campaigns.count)")
                            .font(.caption2.bold())
                            .foregroundStyle(.white)
                            .padding(.horizontal, 8)
                            .frame(height: 24)
                            .background(.white.opacity(0.18))
                            .clipShape(Capsule())
                    }
                }

                Spacer(minLength: 0)

                Text(verbatim: entry.campaign?.title ?? "Karacabey Gross Market")
                    .font(family == .systemSmall ? .headline.weight(.black) : .title2.weight(.black))
                    .foregroundStyle(.white)
                    .lineLimit(family == .systemSmall ? 3 : 2)
                    .minimumScaleFactor(0.78)

                HStack(spacing: 7) {
                    Text(entry.campaign?.ctaTitle ?? "Kampanyaları Gör")
                        .font(.caption.weight(.heavy))
                        .foregroundStyle(kgmDark)
                        .lineLimit(1)
                    Image(systemName: "arrow.right")
                        .font(.caption.bold())
                        .foregroundStyle(kgmDark)
                }
                .padding(.horizontal, 12)
                .frame(height: 32)
                .background(.white)
                .clipShape(Capsule())
            }
            .padding(family == .systemSmall ? 12 : 16)
        }
        .widgetURL(URL(string: entry.campaign?.deepLink ?? "kgm://campaigns"))
        .containerBackground(for: .widget) { kgmOrange }
    }

    @ViewBuilder
    private var campaignBackground: some View {
        if let image = SharedSnapshots.campaignImage(index: entry.campaignIndex) {
            Image(uiImage: image)
                .resizable()
                .interpolation(.high)
                .scaledToFill()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
        } else {
            LinearGradient(colors: [kgmOrange, kgmOrange2, Color(red: 0.85, green: 0.12, blue: 0.0)],
                           startPoint: .topLeading,
                           endPoint: .bottomTrailing)
                .overlay(alignment: .topTrailing) {
                    Image(systemName: "cart.fill")
                        .font(.system(size: 70, weight: .black))
                        .foregroundStyle(.white.opacity(0.18))
                        .padding(18)
                }
        }
    }

    private var campaignInlineTitle: String {
        entry.campaign?.title ?? "Kampanyalar hazır"
    }

    private var accessoryInline: some View {
        Text(verbatim: "KGM · \(campaignInlineTitle)")
            .widgetURL(URL(string: entry.campaign?.deepLink ?? "kgm://campaigns"))
    }

    private var accessoryCircular: some View {
        ZStack {
            AccessoryWidgetBackground()
            Image(systemName: "cart.fill")
                .font(.title3.bold())
                .foregroundStyle(kgmOrange)
        }
        .widgetURL(URL(string: entry.campaign?.deepLink ?? "kgm://campaigns"))
    }

    private var accessoryRectangular: some View {
        VStack(alignment: .leading, spacing: 2) {
            Label("KGM Fırsat", systemImage: "cart.fill")
                .font(.caption.bold())
            Text(verbatim: entry.campaign?.title ?? "Kampanyalar hazır")
                .font(.caption2.weight(.semibold))
                .lineLimit(2)
        }
        .widgetURL(URL(string: entry.campaign?.deepLink ?? "kgm://campaigns"))
    }
}

private struct OrderWidgetView: View {
    let entry: SnapshotEntry
    @Environment(\.widgetFamily) private var family

    private var inlineStatusText: String {
        entry.order.map { statusLabel($0.status) } ?? "Hazır"
    }

    private var rectangularStatusText: String {
        entry.order.map { statusLabel($0.status) } ?? "Aktif sipariş yok"
    }

    var body: some View {
        switch family {
        case .accessoryInline:
            Text(verbatim: "KGM Sipariş · \(inlineStatusText)")
        case .accessoryCircular:
            ZStack {
                AccessoryWidgetBackground()
                Image(systemName: "bag.fill")
                    .font(.title3.bold())
                    .foregroundStyle(kgmOrange)
            }
        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 3) {
                Label("Sipariş", systemImage: "bag.fill").font(.caption.bold())
                Text(verbatim: rectangularStatusText)
                    .font(.caption2.weight(.semibold))
                    .lineLimit(2)
            }
        default:
            homeOrder
        }
    }

    private var homeOrder: some View {
        ZStack(alignment: .leading) {
            LinearGradient(colors: [Color.white, kgmCream, kgmOrange.opacity(0.18)],
                           startPoint: .topLeading,
                           endPoint: .bottomTrailing)
            Circle()
                .fill(kgmOrange.opacity(0.14))
                .frame(width: 130, height: 130)
                .offset(x: 120, y: -70)

            VStack(alignment: .leading, spacing: family == .systemSmall ? 7 : 10) {
                HStack(spacing: 8) {
                    Image(systemName: "bag.fill")
                        .font(.caption.bold())
                        .foregroundStyle(.white)
                        .frame(width: 28, height: 28)
                        .background(kgmOrange)
                        .clipShape(RoundedRectangle(cornerRadius: 9))
                    Text("Siparişim")
                        .font(.caption.bold())
                        .foregroundStyle(kgmDark)
                    Spacer(minLength: 0)
                }

                if let order = entry.order {
                    Text(order.title)
                        .font(family == .systemSmall ? .headline : .title3.bold())
                        .foregroundStyle(kgmDark)
                        .lineLimit(1)
                    Text(statusLabel(order.status))
                        .font(.caption.weight(.heavy))
                        .foregroundStyle(kgmOrange)
                    ProgressView(value: progress(order.status))
                        .tint(kgmOrange)
                    if family != .systemSmall {
                        Text(order.estimatedDeliveryAt.map { "Tahmini teslimat: \($0.formatted(date: .omitted, time: .shortened))" } ?? "Durum anlık güncellenir")
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Text("Aktif sipariş yok")
                        .font(.headline.bold())
                        .foregroundStyle(kgmDark)
                    Text("Sipariş verdiğinde kilit ekranında ve widgetlarda takip edebilirsin.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(family == .systemSmall ? 3 : 2)
                }
                Spacer(minLength: 0)
            }
            .padding()
        }
        .widgetURL(URL(string: entry.order?.deepLink ?? "kgm://orders"))
        .containerBackground(for: .widget) { Color.white }
    }

    private func progress(_ status: String) -> Double {
        switch normalized(status) {
        case "pending", "awaiting_payment", "reviewing", "received": return 0.22
        case "preparing", "processing": return 0.52
        case "on_the_way", "shipping", "in_delivery": return 0.82
        case "delivered", "completed": return 1
        case "cancelled", "canceled", "failed": return 0
        default: return 0.22
        }
    }

    private func statusLabel(_ status: String) -> String {
        switch normalized(status) {
        case "pending": return "Sipariş alındı"
        case "awaiting_payment": return "Ödeme bekleniyor"
        case "reviewing": return "Kontrol ediliyor"
        case "received": return "Mağazaya ulaştı"
        case "preparing", "processing": return "Hazırlanıyor"
        case "on_the_way", "shipping", "in_delivery": return "Yola çıktı"
        case "delivered", "completed": return "Teslim edildi"
        case "cancelled", "canceled", "failed": return "İptal edildi"
        default: return "Güncelleniyor"
        }
    }

    private func normalized(_ status: String) -> String {
        status.lowercased().replacingOccurrences(of: "-", with: "_")
    }
}

private struct QuickWidgetView: View {
    let entry: SnapshotEntry

    var body: some View {
        ZStack {
            LinearGradient(colors: [kgmDark, Color.black], startPoint: .topLeading, endPoint: .bottomTrailing)
            HStack(spacing: 12) {
                quickButton("Ara", "magnifyingglass", "kgm://search")
                quickButton("Sepet", "cart.fill", "kgm://cart")
                quickButton("Fırsat", "tag.fill", entry.campaign?.deepLink ?? "kgm://campaigns")
            }
            .padding()
        }
        .containerBackground(for: .widget) { kgmDark }
    }

    private func quickButton(_ title: String, _ icon: String, _ link: String) -> some View {
        Link(destination: URL(string: link) ?? URL(string: "kgm://home")!) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.headline.bold())
                    .foregroundStyle(.white)
                    .frame(width: 34, height: 34)
                    .background(kgmOrange)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                Text(title)
                    .font(.caption2.bold())
                    .foregroundStyle(.white.opacity(0.92))
            }
            .frame(maxWidth: .infinity)
        }
    }
}



private struct KGMSearchWidgetView: View {
    let entry: SnapshotEntry
    @Environment(\.widgetFamily) private var family

    private var inlineStatusText: String {
        entry.order.map { statusLabel($0.status) } ?? "Hazır"
    }

    private var rectangularStatusText: String {
        entry.order.map { statusLabel($0.status) } ?? "Aktif sipariş yok"
    }

    var body: some View {
        switch family {
        case .accessoryInline:
            Text("KGM · Ürün ara")
                .widgetURL(URL(string: "kgm://search"))
        case .accessoryCircular:
            ZStack {
                AccessoryWidgetBackground()
                Image(systemName: "magnifyingglass")
                    .font(.title3.bold())
                    .foregroundStyle(kgmOrange)
            }
            .widgetURL(URL(string: "kgm://search"))
        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 3) {
                Label("Ürün Ara", systemImage: "magnifyingglass")
                    .font(.caption.bold())
                Text("Barkod, marka veya ürün adıyla hızlı arama")
                    .font(.caption2.weight(.semibold))
                    .lineLimit(2)
            }
            .widgetURL(URL(string: "kgm://search"))
        default:
            ZStack(alignment: .leading) {
                LinearGradient(colors: [Color.white, kgmCream, kgmOrange.opacity(0.16)],
                               startPoint: .topLeading,
                               endPoint: .bottomTrailing)
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .font(.title3.bold())
                            .foregroundStyle(.white)
                            .frame(width: 42, height: 42)
                            .background(kgmOrange)
                            .clipShape(RoundedRectangle(cornerRadius: 13))
                        Spacer()
                        Image(systemName: "barcode.viewfinder")
                            .foregroundStyle(kgmOrange.opacity(0.82))
                    }
                    Spacer(minLength: 0)
                    Text("Hızlı Arama")
                        .font(.title3.weight(.black))
                        .foregroundStyle(kgmDark)
                    Text("Ürün, kampanya ve barkod araması")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                .padding()
            }
            .widgetURL(URL(string: "kgm://search"))
            .containerBackground(for: .widget) { Color.white }
        }
    }
}

private struct KGMCartWidgetView: View {
    let entry: SnapshotEntry
    @Environment(\.widgetFamily) private var family

    private var inlineStatusText: String {
        entry.order.map { statusLabel($0.status) } ?? "Hazır"
    }

    private var rectangularStatusText: String {
        entry.order.map { statusLabel($0.status) } ?? "Aktif sipariş yok"
    }

    var body: some View {
        switch family {
        case .accessoryInline:
            Text("KGM Sepet · Devam et")
                .widgetURL(URL(string: "kgm://cart"))
        case .accessoryCircular:
            ZStack {
                AccessoryWidgetBackground()
                Image(systemName: "cart.fill")
                    .font(.title3.bold())
                    .foregroundStyle(kgmOrange)
            }
            .widgetURL(URL(string: "kgm://cart"))
        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 3) {
                Label("Sepet", systemImage: "cart.fill")
                    .font(.caption.bold())
                Text("Alışverişe kaldığın yerden devam et")
                    .font(.caption2.weight(.semibold))
                    .lineLimit(2)
            }
            .widgetURL(URL(string: "kgm://cart"))
        default:
            ZStack(alignment: .leading) {
                LinearGradient(colors: [kgmDark, Color.black], startPoint: .topLeading, endPoint: .bottomTrailing)
                Circle().fill(kgmOrange.opacity(0.24)).frame(width: 150, height: 150).offset(x: 110, y: -70)
                VStack(alignment: .leading, spacing: 10) {
                    Image(systemName: "cart.fill")
                        .font(.title2.bold())
                        .foregroundStyle(.white)
                        .frame(width: 48, height: 48)
                        .background(kgmOrange)
                        .clipShape(RoundedRectangle(cornerRadius: 15))
                    Spacer(minLength: 0)
                    Text("Sepetim")
                        .font(.title3.weight(.black))
                        .foregroundStyle(.white)
                    Text("Tek dokunuşla sepetine git")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.76))
                        .lineLimit(2)
                }
                .padding()
            }
            .widgetURL(URL(string: "kgm://cart"))
            .containerBackground(for: .widget) { kgmDark }
        }
    }
}

private struct KGMStoreWidgetView: View {
    let entry: SnapshotEntry
    @Environment(\.widgetFamily) private var family

    private var inlineStatusText: String {
        entry.order.map { statusLabel($0.status) } ?? "Hazır"
    }

    private var rectangularStatusText: String {
        entry.order.map { statusLabel($0.status) } ?? "Aktif sipariş yok"
    }

    var body: some View {
        switch family {
        case .accessoryInline:
            Text("KGM · Hızlı teslimat")
                .widgetURL(URL(string: "kgm://store"))
        case .accessoryCircular:
            ZStack {
                AccessoryWidgetBackground()
                Image(systemName: "mappin.and.ellipse")
                    .font(.title3.bold())
                    .foregroundStyle(kgmOrange)
            }
            .widgetURL(URL(string: "kgm://store"))
        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 3) {
                Label("Karacabey", systemImage: "mappin.and.ellipse")
                    .font(.caption.bold())
                Text("Market, teslimat ve mağaza bilgileri")
                    .font(.caption2.weight(.semibold))
                    .lineLimit(2)
            }
            .widgetURL(URL(string: "kgm://store"))
        default:
            ZStack(alignment: .leading) {
                LinearGradient(colors: [kgmOrange, kgmOrange2], startPoint: .topLeading, endPoint: .bottomTrailing)
                VStack(alignment: .leading, spacing: 10) {
                    KGMBrandBadge(compact: false)
                    Spacer(minLength: 0)
                    Text("Karacabey Gross")
                        .font(.title3.weight(.black))
                        .foregroundStyle(.white)
                    Text("Taze ürünler, hızlı teslimat, güvenli alışveriş")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.88))
                        .lineLimit(2)
                    HStack(spacing: 5) {
                        Image(systemName: "location.fill")
                        Text("Mağaza bilgileri")
                    }
                    .font(.caption2.bold())
                    .foregroundStyle(kgmDark)
                    .padding(.horizontal, 10)
                    .frame(height: 28)
                    .background(.white)
                    .clipShape(Capsule())
                }
                .padding()
            }
            .widgetURL(URL(string: "kgm://store"))
            .containerBackground(for: .widget) { kgmOrange }
        }
    }
}

private struct KGMDealMiniWidgetView: View {
    let entry: SnapshotEntry
    @Environment(\.widgetFamily) private var family

    private var inlineStatusText: String {
        entry.order.map { statusLabel($0.status) } ?? "Hazır"
    }

    private var rectangularStatusText: String {
        entry.order.map { statusLabel($0.status) } ?? "Aktif sipariş yok"
    }

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            if let image = SharedSnapshots.campaignImage(index: entry.campaignIndex) {
                Image(uiImage: image)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFill()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
            } else {
                LinearGradient(colors: [kgmOrange, kgmOrange2], startPoint: .topLeading, endPoint: .bottomTrailing)
            }
            LinearGradient(colors: [.clear, .black.opacity(0.75)], startPoint: .top, endPoint: .bottom)
            VStack(alignment: .leading, spacing: 7) {
                Label("Günün Fırsatı", systemImage: "bolt.fill")
                    .font(.caption.bold())
                    .foregroundStyle(.white)
                Text(entry.campaign?.title ?? "Kampanyaları kaçırma")
                    .font(.headline.weight(.black))
                    .foregroundStyle(.white)
                    .lineLimit(2)
            }
            .padding()
        }
        .widgetURL(URL(string: entry.campaign?.deepLink ?? "kgm://campaigns"))
        .containerBackground(for: .widget) { kgmOrange }
    }
}

private struct KGMOrderWidget: Widget {
    let kind = "KGMOrderWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SnapshotProvider()) { entry in
            OrderWidgetView(entry: entry)
        }
        .configurationDisplayName("Sipariş Durumu")
        .description("Siparişinizi ana ekranda, kilit ekranında ve Dynamic Island'da takip edin.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryInline, .accessoryCircular, .accessoryRectangular])
    }
}

private struct KGMCampaignWidget: Widget {
    let kind = "KGMCampaignWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SnapshotProvider()) { entry in
            CampaignWidgetView(entry: entry)
        }
        .configurationDisplayName("KGM Kampanyaları")
        .description("Slider görsellerinden gelen güncel kampanyaları etkileyici widget olarak gösterir.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge, .accessoryInline, .accessoryCircular, .accessoryRectangular])
    }
}

private struct KGMQuickWidget: Widget {
    let kind = "KGMQuickWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SnapshotProvider()) { entry in
            QuickWidgetView(entry: entry)
        }
        .configurationDisplayName("KGM Hızlı Alışveriş")
        .description("Arama, sepet ve kampanyalara tek dokunuşla ulaşın.")
        .supportedFamilies([.systemMedium])
    }
}

struct OrderActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        let status: String
        let statusLabel: String
        let progress: Double
        let updatedAt: Int
    }

    let orderId: String
    let orderNumber: String
    let deepLink: String
}

private struct KGMOrderLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: OrderActivityAttributes.self) { context in
            HStack(spacing: 14) {
                Image(systemName: "bag.fill")
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(kgmOrange)
                    .clipShape(RoundedRectangle(cornerRadius: 13))
                VStack(alignment: .leading, spacing: 5) {
                    Text("Sipariş #\(context.attributes.orderNumber)")
                        .font(.headline)
                    Text(context.state.statusLabel)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    ProgressView(value: context.state.progress).tint(kgmOrange)
                }
            }
            .padding()
            .activityBackgroundTint(.white)
            .activitySystemActionForegroundColor(kgmOrange)
            .widgetURL(URL(string: context.attributes.deepLink))
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: "bag.fill").foregroundStyle(kgmOrange)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("\(Int(context.state.progress * 100))%").font(.caption.bold())
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(context.state.statusLabel).font(.caption.bold())
                        ProgressView(value: context.state.progress).tint(kgmOrange)
                    }
                }
            } compactLeading: {
                Image(systemName: "bag.fill").foregroundStyle(kgmOrange)
            } compactTrailing: {
                Text("\(Int(context.state.progress * 100))%").font(.caption2.bold())
            } minimal: {
                Image(systemName: "bag.fill").foregroundStyle(kgmOrange)
            }
            .widgetURL(URL(string: context.attributes.deepLink))
        }
    }
}



private struct KGMSearchWidget: Widget {
    let kind = "KGMSearchWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SnapshotProvider()) { entry in
            KGMSearchWidgetView(entry: entry)
        }
        .configurationDisplayName("KGM Ürün Arama")
        .description("Ürün, kategori, barkod ve kampanyalara hızlı ulaşım.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryInline, .accessoryCircular, .accessoryRectangular])
    }
}

private struct KGMCartWidget: Widget {
    let kind = "KGMCartWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SnapshotProvider()) { entry in
            KGMCartWidgetView(entry: entry)
        }
        .configurationDisplayName("KGM Sepetim")
        .description("Sepete ve alışverişe tek dokunuşla devam edin.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryInline, .accessoryCircular, .accessoryRectangular])
    }
}

private struct KGMStoreWidget: Widget {
    let kind = "KGMStoreWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SnapshotProvider()) { entry in
            KGMStoreWidgetView(entry: entry)
        }
        .configurationDisplayName("KGM Mağaza")
        .description("Mağaza, teslimat ve Karacabey Gross bilgilerine hızlı erişim.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryInline, .accessoryCircular, .accessoryRectangular])
    }
}

private struct KGMDealMiniWidget: Widget {
    let kind = "KGMDealMiniWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SnapshotProvider()) { entry in
            KGMDealMiniWidgetView(entry: entry)
        }
        .configurationDisplayName("KGM Günün Fırsatı")
        .description("Slider görsellerinden gelen etkileyici kampanya widget'ı.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

@main
struct KGMWidgetBundle: WidgetBundle {
    var body: some Widget {
        KGMOrderWidget()
        KGMCampaignWidget()
        KGMDealMiniWidget()
        KGMSearchWidget()
        KGMCartWidget()
        KGMStoreWidget()
        KGMQuickWidget()
        KGMOrderLiveActivity()
    }
}
