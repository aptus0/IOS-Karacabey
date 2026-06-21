import Foundation
import WidgetKit

struct WidgetOrderSnapshot: Codable, Hashable {
    let orderId: String
    let title: String
    let status: OrderStatus
    let estimatedDeliveryAt: Date?
    let updatedAt: Date
    let deepLink: String
}

struct WidgetCampaignSnapshot: Codable, Hashable {
    let campaignId: String
    let title: String
    let imageURL: String?
    let ctaTitle: String
    let deepLink: String
    let updatedAt: Date
}

enum WidgetSnapshotStore {
    private static let orderKey = "kgm.widget.order.snapshot"
    private static let campaignKey = "kgm.widget.campaign.snapshot"
    private static let campaignsKey = "kgm.widget.campaigns.snapshot"
    private static let campaignImageName = "kgm-widget-campaign.jpg"
    private static let campaignImagePrefix = "kgm-widget-campaign-"

    private static var defaults: UserDefaults {
        UserDefaults(suiteName: EnvironmentConfig.appGroupIdentifier) ?? .standard
    }

    static func save(order: WidgetOrderSnapshot?) {
        save(order, key: orderKey)
        reloadWidgetTimelines()
    }

    static func save(campaign: WidgetCampaignSnapshot?, imageData: Data? = nil) {
        save(campaign, key: campaignKey)
        if let campaign {
            save([campaign], key: campaignsKey)
        } else {
            defaults.removeObject(forKey: campaignsKey)
        }

        if let imageData, let url = campaignImageURL {
            try? imageData.write(to: url, options: .atomic)
            if let multiURL = campaignImageURL(index: 0) {
                try? imageData.write(to: multiURL, options: .atomic)
            }
        } else if campaign == nil, let url = campaignImageURL {
            try? FileManager.default.removeItem(at: url)
            clearCampaignImages()
        }
        reloadWidgetTimelines()
    }

    static func save(campaigns: [WidgetCampaignSnapshot], imageDataByIndex: [Int: Data]) {
        let trimmed = Array(campaigns.prefix(5))
        save(trimmed.first, key: campaignKey)
        save(trimmed, key: campaignsKey)

        clearCampaignImages()
        for (index, imageData) in imageDataByIndex where index < 5 {
            if let url = campaignImageURL(index: index) {
                try? imageData.write(to: url, options: .atomic)
            }
            if index == 0, let url = campaignImageURL {
                try? imageData.write(to: url, options: .atomic)
            }
        }

        reloadWidgetTimelines()
    }

    static func loadOrder() -> WidgetOrderSnapshot? {
        load(WidgetOrderSnapshot.self, key: orderKey)
    }

    static func loadCampaign() -> WidgetCampaignSnapshot? {
        load(WidgetCampaignSnapshot.self, key: campaignKey)
    }

    static func loadCampaigns() -> [WidgetCampaignSnapshot] {
        if let campaigns = load([WidgetCampaignSnapshot].self, key: campaignsKey), !campaigns.isEmpty {
            return campaigns
        }
        return loadCampaign().map { [$0] } ?? []
    }

    static var campaignImageURL: URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: EnvironmentConfig.appGroupIdentifier)?
            .appendingPathComponent(campaignImageName)
    }

    static func campaignImageURL(index: Int) -> URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: EnvironmentConfig.appGroupIdentifier)?
            .appendingPathComponent("\(campaignImagePrefix)\(index).jpg")
    }


    private static func reloadWidgetTimelines() {
        [
            "KGMOrderWidget",
            "KGMCampaignWidget",
            "KGMDealMiniWidget",
            "KGMSearchWidget",
            "KGMCartWidget",
            "KGMStoreWidget",
            "KGMQuickWidget"
        ].forEach { WidgetCenter.shared.reloadTimelines(ofKind: $0) }
    }

    private static func clearCampaignImages() {
        for index in 0..<5 {
            if let url = campaignImageURL(index: index) {
                try? FileManager.default.removeItem(at: url)
            }
        }
    }

    private static func save<T: Encodable>(_ value: T?, key: String) {
        guard let value, let data = try? JSONEncoder.kgm.encode(value) else {
            defaults.removeObject(forKey: key)
            return
        }
        defaults.set(data, forKey: key)
    }

    private static func load<T: Decodable>(_ type: T.Type, key: String) -> T? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder.kgm.decode(T.self, from: data)
    }
}
