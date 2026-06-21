import Foundation

enum NotificationCategory: String, Codable, CaseIterable {
    case order = "ORDER"
    case campaign = "CAMPAIGN"
    case system = "SYSTEM"
    case delivery = "DELIVERY"
    case payment = "PAYMENT"

    var displayName: String {
        switch self {
        case .order: return "Sipariş"
        case .campaign: return "Kampanya"
        case .system: return "Sistem"
        case .delivery: return "Teslimat"
        case .payment: return "Ödeme"
        }
    }
}

struct NotificationItem: Identifiable, Decodable, Hashable {
    let id: String
    var userId: String
    var title: String
    var body: String
    var category: NotificationCategory
    var deepLink: String?
    var imageURL: String?
    var ctaTitle: String?
    var isRead: Bool
    var createdAt: Date
    var readAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case userId
        case title
        case body
        case category
        case type
        case deepLink
        case actionURL = "actionUrl"
        case imageURL = "imageUrl"
        case ctaTitle
        case isRead
        case createdAt
        case readAt
    }

    init(
        id: String,
        userId: String,
        title: String,
        body: String,
        category: NotificationCategory,
        deepLink: String? = nil,
        imageURL: String? = nil,
        ctaTitle: String? = nil,
        isRead: Bool = false,
        createdAt: Date = Date(),
        readAt: Date? = nil
    ) {
        self.id = id
        self.userId = userId
        self.title = title
        self.body = body
        self.category = category
        self.deepLink = deepLink
        self.imageURL = imageURL
        self.ctaTitle = ctaTitle
        self.isRead = isRead
        self.createdAt = createdAt
        self.readAt = readAt
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        if let intId = try? c.decode(Int64.self, forKey: .id) {
            id = String(intId)
        } else {
            id = (try? c.decode(String.self, forKey: .id)) ?? UUID().uuidString
        }
        if let intUserId = try? c.decode(Int64.self, forKey: .userId) {
            userId = String(intUserId)
        } else {
            userId = (try? c.decodeIfPresent(String.self, forKey: .userId)) ?? ""
        }
        title = (try? c.decode(String.self, forKey: .title)) ?? "Bildirim"
        body = (try? c.decode(String.self, forKey: .body)) ?? ""
        let categoryRaw = (try? c.decodeIfPresent(String.self, forKey: .category))
            ?? (try? c.decodeIfPresent(String.self, forKey: .type))
            ?? NotificationCategory.system.rawValue
        switch categoryRaw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "order", "order_update": category = .order
        case "campaign", "product": category = .campaign
        case "delivery", "cargo_update", "shipment": category = .delivery
        case "payment", "payment_update": category = .payment
        default: category = .system
        }
        deepLink = (try? c.decodeIfPresent(String.self, forKey: .deepLink))
            ?? (try? c.decodeIfPresent(String.self, forKey: .actionURL))
        imageURL = try? c.decodeIfPresent(String.self, forKey: .imageURL)
        ctaTitle = try? c.decodeIfPresent(String.self, forKey: .ctaTitle)
        createdAt = (try? c.decode(Date.self, forKey: .createdAt)) ?? Date()
        readAt = try? c.decodeIfPresent(Date.self, forKey: .readAt)
        isRead = (try? c.decode(Bool.self, forKey: .isRead)) ?? (readAt != nil)
    }
}

struct DeviceToken: Identifiable, Codable, Hashable {
    let id: String
    var userId: String
    var token: String
    var platform: String
    var appVersion: String
    var osVersion: String
    var locale: String
    var isActive: Bool
    var registeredAt: Date
    var lastSeenAt: Date
}

struct DeviceTokenRequest: Codable {
    let token: String
    let platform: String
    let appVersion: String
    let osVersion: String
    let locale: String
}

struct DeviceTokenRegistrationRequest: Codable {
    let platform: String
    let token: String
    let deviceId: String
    let deviceName: String
    let appVersion: String
    let locale: String
    let timezone: String
}

struct NotificationReadRequest: Codable {
    let notificationIds: [String]
}
