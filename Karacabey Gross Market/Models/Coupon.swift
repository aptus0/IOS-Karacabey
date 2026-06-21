import Foundation

enum CouponType: String, Codable, CaseIterable {
    case percentage = "PERCENTAGE"
    case fixedAmount = "FIXED_AMOUNT"
    case freeDelivery = "FREE_DELIVERY"

    var displayName: String {
        switch self {
        case .percentage: return "Yüzde İndirim"
        case .fixedAmount: return "Sabit İndirim"
        case .freeDelivery: return "Ücretsiz Teslimat"
        }
    }
}

struct Coupon: Identifiable, Codable, Hashable {
    let id: String
    var code: String
    var title: String
    var description: String?
    var type: CouponType
    var value: Double
    var minOrderAmount: Double?
    var maxDiscountAmount: Double?
    var usageLimit: Int?
    var usageCount: Int
    var startsAt: Date
    var expiresAt: Date
    var isActive: Bool

    var isValid: Bool {
        isActive && Date() >= startsAt && Date() <= expiresAt
    }

    func discountAmount(for orderTotal: Double) -> Double {
        guard isValid else { return 0 }
        if let min = minOrderAmount, orderTotal < min { return 0 }
        switch type {
        case .percentage:
            let discount = orderTotal * (value / 100)
            if let max = maxDiscountAmount { return min(discount, max) }
            return discount
        case .fixedAmount:
            return min(value, orderTotal)
        case .freeDelivery:
            return 0
        }
    }
}

struct CouponValidationRequest: Codable {
    let code: String
    let orderTotal: Double
}

struct CouponValidationResponse: Codable {
    let coupon: Coupon
    let discountAmount: Double
    let isValid: Bool
    let message: String?
}
