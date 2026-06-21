import Foundation

enum PaymentType: String, Codable, CaseIterable {
    case creditCard = "CREDIT_CARD"
    case cashOnDelivery = "CASH_ON_DELIVERY"
    case onlineBanking = "ONLINE_BANKING"

    var displayName: String {
        switch self {
        case .creditCard: return "Kredi / Banka Kartı"
        case .cashOnDelivery: return "Kapıda Ödeme"
        case .onlineBanking: return "Online Bankacılık"
        }
    }

    var iconName: String {
        switch self {
        case .creditCard: return "creditcard"
        case .cashOnDelivery: return "banknote"
        case .onlineBanking: return "building.columns"
        }
    }
}

struct PaymentMethod: Identifiable, Codable, Hashable {
    let id: String
    var type: PaymentType
    var maskedCardNumber: String?
    var cardHolderName: String?
    var expiryDate: String?
    var isDefault: Bool

    var displayTitle: String {
        switch type {
        case .creditCard:
            return maskedCardNumber ?? type.displayName
        default:
            return type.displayName
        }
    }
}
