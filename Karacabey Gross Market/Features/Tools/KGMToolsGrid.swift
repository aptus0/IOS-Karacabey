import SwiftUI

struct KGMToolsGrid: View {
    let tools: [KGMTool]
    let action: (KGMTool) -> Void

    private let columns = [
        GridItem(.flexible(), spacing: KGMSpacing.sm),
        GridItem(.flexible(), spacing: KGMSpacing.sm)
    ]

    var body: some View {
        LazyVGrid(columns: columns, spacing: KGMSpacing.sm) {
            ForEach(tools) { tool in
                KGMToolCoverCard(tool: tool, action: action)
            }
        }
    }
}

extension KGMTool {
    static let homeTools: [KGMTool] = [
        KGMTool(id: "order", title: "Sipariş Nerede?", subtitle: "Sipariş durumunu takip et.", iconName: "shippingbox.fill", badge: nil, tint: .kgmPrimary, deepLink: "kgm://order/latest"),
        KGMTool(id: "campaigns", title: "Kampanyalar", subtitle: "Bugünün indirimlerini kaçırma.", iconName: "tag.fill", badge: "Yeni", tint: .kgmCampaign, deepLink: "kgm://campaigns"),
        KGMTool(id: "nearby", title: "Yakındaki Mağaza", subtitle: "Konumuna en yakın şubeyi gör.", iconName: "map.fill", badge: nil, tint: .kgmMapPin, deepLink: "kgm://branches/nearby"),
        KGMTool(id: "coupons", title: "Kuponlarım", subtitle: "Tanımlı kuponlarını incele.", iconName: "ticket.fill", badge: nil, tint: .kgmDiscount, deepLink: "kgm://coupons"),
        KGMTool(id: "favorites", title: "Favorilerim", subtitle: "Sevdiğin ürünlere hızlı dön.", iconName: "heart.fill", badge: nil, tint: .kgmError, deepLink: "kgm://favorites"),
        KGMTool(id: "zone", title: "Teslimat Bölgem", subtitle: "Adresine teslimat durumunu kontrol et.", iconName: "location.fill", badge: nil, tint: .kgmInfo, deepLink: "kgm://delivery-zone"),
        KGMTool(id: "notifications", title: "Bildirimler", subtitle: "Sipariş ve kampanya mesajlarını gör.", iconName: "bell.fill", badge: nil, tint: .kgmInfo, deepLink: "kgm://notifications"),
        KGMTool(id: "support", title: "Yardım & Destek", subtitle: "Sipariş ve hesap desteği al.", iconName: "questionmark.bubble.fill", badge: nil, tint: .kgmWarning, deepLink: "kgm://support")
    ]
}
