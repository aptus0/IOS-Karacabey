import Foundation

struct CustomerCouponOffer: Identifiable, Codable, Hashable {
    let id: String
    var code: String
    var discountType: String
    var discountValue: Int64
    var minimumOrderCents: Int64
    var startsAt: Date?
    var endsAt: Date?
    var isActive: Bool
    var usageLimit: Int64?
    var usedCount: Int64

    enum CodingKeys: String, CodingKey {
        case id
        case code
        case discountType
        case discountValue
        case minimumOrderCents
        case startsAt
        case endsAt
        case isActive
        case usageLimit
        case usedCount
    }

    init(
        id: String,
        code: String,
        discountType: String,
        discountValue: Int64,
        minimumOrderCents: Int64,
        startsAt: Date? = nil,
        endsAt: Date? = nil,
        isActive: Bool = true,
        usageLimit: Int64? = nil,
        usedCount: Int64 = 0
    ) {
        self.id = id
        self.code = code
        self.discountType = discountType
        self.discountValue = discountValue
        self.minimumOrderCents = minimumOrderCents
        self.startsAt = startsAt
        self.endsAt = endsAt
        self.isActive = isActive
        self.usageLimit = usageLimit
        self.usedCount = usedCount
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let numericID = try? container.decode(Int64.self, forKey: .id) {
            id = String(numericID)
        } else {
            id = (try? container.decode(String.self, forKey: .id)) ?? UUID().uuidString
        }
        code = ((try? container.decode(String.self, forKey: .code)) ?? "").uppercased()
        discountType = ((try? container.decode(String.self, forKey: .discountType)) ?? "fixed").lowercased()
        discountValue = (try? container.decode(Int64.self, forKey: .discountValue)) ?? 0
        minimumOrderCents = (try? container.decode(Int64.self, forKey: .minimumOrderCents)) ?? 0
        startsAt = try? container.decodeIfPresent(Date.self, forKey: .startsAt)
        endsAt = try? container.decodeIfPresent(Date.self, forKey: .endsAt)
        isActive = (try? container.decode(Bool.self, forKey: .isActive)) ?? true
        usageLimit = try? container.decodeIfPresent(Int64.self, forKey: .usageLimit)
        usedCount = (try? container.decode(Int64.self, forKey: .usedCount)) ?? 0
    }

    var minimumOrderAmount: Double { Double(minimumOrderCents) / 100.0 }

    var isUsageLimitReached: Bool {
        if let usageLimit { return usedCount >= usageLimit }
        return false
    }

    var canApply: Bool {
        isActive && !isUsageLimitReached
    }

    var usageLabel: String {
        if isUsageLimitReached { return "Kullanıldı" }
        if let usageLimit { return "Kalan: \(max(0, usageLimit - usedCount))" }
        return "Tek kullanımlık"
    }

    var discountLabel: String {
        if discountType.contains("percent") || discountType == "percentage" {
            return "%\(discountValue) indirim"
        }
        if discountType.contains("delivery") || discountType.contains("shipping") {
            return "Ücretsiz teslimat"
        }
        return (Double(discountValue) / 100.0).formattedAsTurkishLira + " indirim"
    }

    var subtitle: String {
        let minText = minimumOrderCents > 0 ? "Min. \(minimumOrderAmount.formattedAsTurkishLira)" : "Alt limitsiz"
        if let endsAt {
            return "\(minText) · \(endsAt.formatted(date: .abbreviated, time: .omitted)) bitiyor"
        }
        return minText
    }
}

struct StockAlertRequest: Codable {
    let email: String?
    let phone: String?
}

struct StockAlertResponse: Codable {
    let status: String?
    let message: String?
}

struct ReorderLineResult: Decodable, Hashable {
    let productId: Int64?
    let requestedQuantity: Int?
    let addedQuantity: Int?
    let status: String?
}

struct ReorderResponse: Decodable {
    let cart: Cart?
    let addedCount: Int?
    let lines: [ReorderLineResult]?
    let message: String?
}

struct CustomerLoyaltySummary: Codable, Hashable {
    let pointsBalance: Int64
    let lifetimePoints: Int64
    let level: String
    let levelTitle: String
    let progressPercent: Double
    let nextRewardPoints: Int64
    let purchasesToNextReward: Int64?
    let spendToNextRewardCents: Int64
    let isVip: Bool?
    let adFree: Bool?
    let rewards: [CustomerLoyaltyReward]

    var balanceLabel: String { "\(pointsBalance) puan" }
    var progressValue: Double { max(0, min(1, progressPercent / 100.0)) }
    var nextRewardLabel: String {
        if nextRewardPoints <= 0 { return "Ödül hazır" }
        return "\(nextRewardPoints) puan sonra yeni ödül"
    }
    var spendToNextLabel: String {
        if spendToNextRewardCents <= 0 && nextRewardPoints > 0 { return "Mobil alışveriş başına 1 puan" }
        if spendToNextRewardCents <= 0 { return "Sepette kullanıma hazır" }
        return "Yaklaşık \((Double(spendToNextRewardCents) / 100.0).formattedAsTurkishLira) alışveriş"
    }

    static let empty = CustomerLoyaltySummary(
        pointsBalance: 0,
        lifetimePoints: 0,
        level: "starter",
        levelTitle: "KGM Üyesi",
        progressPercent: 0,
        nextRewardPoints: 50,
        purchasesToNextReward: 50,
        spendToNextRewardCents: 0,
        isVip: false,
        adFree: false,
        rewards: []
    )
}

struct CustomerLoyaltyReward: Identifiable, Codable, Hashable {
    let id: String
    let title: String
    let subtitle: String
    let pointsRequired: Int64
    let isUnlocked: Bool

    enum CodingKeys: String, CodingKey {
        case id, title, subtitle, pointsRequired, isUnlocked
    }

    init(id: String, title: String, subtitle: String, pointsRequired: Int64, isUnlocked: Bool) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.pointsRequired = pointsRequired
        self.isUnlocked = isUnlocked
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let numericID = try? container.decode(Int64.self, forKey: .id) {
            id = String(numericID)
        } else {
            id = (try? container.decode(String.self, forKey: .id)) ?? UUID().uuidString
        }
        title = (try? container.decode(String.self, forKey: .title)) ?? "KGM Ödülü"
        subtitle = (try? container.decode(String.self, forKey: .subtitle)) ?? "Alışveriş puanı"
        pointsRequired = (try? container.decode(Int64.self, forKey: .pointsRequired)) ?? 0
        isUnlocked = (try? container.decode(Bool.self, forKey: .isUnlocked)) ?? false
    }
}

struct PersonalizedRecommendationsResponse: Codable, Hashable {
    let title: String
    let subtitle: String
    let strategy: String
    let products: [Product]

    static let empty = PersonalizedRecommendationsResponse(
        title: "Sana Özel Reyon",
        subtitle: "Alışveriş geçmişinize göre öneriler",
        strategy: "empty",
        products: []
    )
}
