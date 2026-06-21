import Foundation

enum PaymentStatus: String, Codable, CaseIterable {
    case pending = "PENDING"
    case processing = "PROCESSING"
    case succeeded = "SUCCEEDED"
    case failed = "FAILED"
    case cancelled = "CANCELLED"
    case refunded = "REFUNDED"
    case partiallyRefunded = "PARTIALLY_REFUNDED"

    var displayName: String {
        switch self {
        case .pending: return "Bekliyor"
        case .processing: return "İşleniyor"
        case .succeeded: return "Tamamlandı"
        case .failed: return "Başarısız"
        case .cancelled: return "İptal Edildi"
        case .refunded: return "İade Edildi"
        case .partiallyRefunded: return "Kısmi İade"
        }
    }

    var isTerminal: Bool {
        switch self {
        case .succeeded, .failed, .cancelled, .refunded, .partiallyRefunded: return true
        default: return false
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = (try? container.decode(String.self)) ?? ""
        switch rawValue.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "pending", "awaiting_payment":
            self = .pending
        case "processing":
            self = .processing
        case "succeeded", "success", "paid":
            self = .succeeded
        case "failed", "fail":
            self = .failed
        case "cancelled", "canceled":
            self = .cancelled
        case "refunded":
            self = .refunded
        case "partially_refunded", "partiallyrefunded":
            self = .partiallyRefunded
        default:
            self = .failed
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

enum PaymentProvider: String, Codable {
    case paytr = "PAYTR"
    case stripe = "STRIPE"
    case cash = "CASH_ON_DELIVERY"
}

struct Payment: Identifiable, Codable, Hashable {
    let id: String
    var orderId: String
    var provider: PaymentProvider
    var status: PaymentStatus
    var amount: Double
    var currency: String
    var providerTransactionId: String?
    var providerPaymentToken: String?
    var idempotencyKey: String
    var createdAt: Date
    var updatedAt: Date
    var attempts: [PaymentAttempt]
    var refunds: [Refund]
}

struct PaymentAttempt: Identifiable, Codable, Hashable {
    let id: String
    var paymentId: String
    var status: PaymentStatus
    var errorCode: String?
    var errorMessage: String?
    var providerResponse: String?
    var attemptedAt: Date
}

struct PaymentEvent: Identifiable, Codable, Hashable {
    let id: String
    var paymentId: String
    var eventType: String
    var payload: String?
    var receivedAt: Date
}

struct Refund: Identifiable, Codable, Hashable {
    let id: String
    var paymentId: String
    var orderId: String
    var amount: Double
    var reason: String?
    var status: PaymentStatus
    var providerRefundId: String?
    var requestedAt: Date
    var processedAt: Date?
}

struct PayTRTokenRequest: Codable {
    let orderId: String
    let amount: Double
    let currency: String
    let idempotencyKey: String
}

struct PayTRTokenResponse: Codable {
    let token: String
    let paymentPageURL: String
    let expiresIn: Int
}

struct PayTRPaymentRequest: Codable, Hashable {
    let orderId: String
    let userId: String
    let email: String
    let phone: String
    let amountKurus: Int
    let currency: String
    let addressId: String
    let basket: [PayTRBasketItem]

    init(
        orderId: String,
        userId: String,
        email: String,
        phone: String,
        amountKurus: Int,
        currency: String = "TL",
        addressId: String,
        basket: [PayTRBasketItem]
    ) throws {
        self.orderId = orderId
        self.userId = userId
        self.email = email
        self.phone = phone
        self.amountKurus = amountKurus
        self.currency = currency
        self.addressId = addressId
        self.basket = basket
        try validate()
    }

    @MainActor
    init(orderId: String, user: User?, address: Address, cart: Cart) throws {
        guard let user else {
            throw APIError.backend(message: "Online ödeme için giriş yapmalısınız.", code: nil)
        }

        let email = user.email?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let phone = (address.phone.isEmpty ? (user.phone ?? "") : address.phone)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        try self.init(
            orderId: orderId,
            userId: String(user.id),
            email: email,
            phone: phone,
            amountKurus: cart.total.kurus,
            addressId: address.id,
            basket: cart.items.map(PayTRBasketItem.init)
        )
    }

    func validate() throws {
        if orderId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw APIError.backend(message: "Ödeme başlatılamadı: sipariş numarası eksik.", code: nil)
        }
        if userId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw APIError.backend(message: "Ödeme başlatılamadı: kullanıcı bilgisi eksik.", code: nil)
        }
        if !email.contains("@") {
            throw APIError.backend(message: "Ödeme için geçerli bir e-posta adresi gereklidir.", code: nil)
        }
        if phone.filter(\.isNumber).count < 10 {
            throw APIError.backend(message: "Ödeme için geçerli bir telefon numarası gereklidir.", code: nil)
        }
        if amountKurus <= 0 {
            throw APIError.backend(message: "Ödeme tutarı geçersiz.", code: nil)
        }
        if currency.uppercased() != "TL" {
            throw APIError.backend(message: "PayTR ödemelerinde para birimi TL olmalıdır.", code: nil)
        }
        if addressId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw APIError.backend(message: "Ödeme için teslimat adresi seçilmelidir.", code: nil)
        }
        if basket.isEmpty {
            throw APIError.backend(message: "Sepetiniz boş. Ödeme başlatılamaz.", code: nil)
        }

        for item in basket {
            try item.validate()
        }
    }
}

struct PayTRBasketItem: Codable, Hashable {
    let productId: String
    let name: String
    let quantity: Int
    let unitPriceKurus: Int

    init(productId: String, name: String, quantity: Int, unitPriceKurus: Int) {
        self.productId = productId
        self.name = name
        self.quantity = quantity
        self.unitPriceKurus = unitPriceKurus
    }

    init(cartItem: CartItem) {
        self.init(
            productId: cartItem.product.id,
            name: cartItem.product.name,
            quantity: cartItem.quantity,
            unitPriceKurus: cartItem.product.effectivePrice.kurus
        )
    }

    func validate() throws {
        if productId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw APIError.backend(message: "Sepette ürün kimliği eksik.", code: nil)
        }
        if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw APIError.backend(message: "Sepette ürün adı eksik.", code: nil)
        }
        if quantity <= 0 {
            throw APIError.backend(message: "Sepette geçersiz ürün adedi var.", code: nil)
        }
        if unitPriceKurus <= 0 {
            throw APIError.backend(message: "Sepette geçersiz ürün fiyatı var.", code: nil)
        }
    }
}

enum PayTRPaymentRequestLogger {
    static func log(_ payload: PayTRPaymentRequest) {
        #if DEBUG
        guard EnvironmentConfig.isDebugLoggingEnabled,
              let data = try? JSONEncoder.paytr.encode(payload),
              let json = String(data: data, encoding: .utf8) else {
            return
        }
        print("[PayTR] request body: \(json)")
        #endif
    }
}

struct PayTRCardForm: Hashable {
    var holderName = ""
    var number = ""
    var expiry = ""
    var cvv = ""

    var sanitizedNumber: String {
        number.filter(\.isNumber)
    }

    var sanitizedCVV: String {
        String(cvv.filter(\.isNumber).prefix(4))
    }

    var expiryParts: (month: String, year: String)? {
        let digits = expiry.filter(\.isNumber)
        guard digits.count >= 4 else { return nil }
        let month = String(digits.prefix(2))
        let year = String(digits.dropFirst(2).prefix(2))
        guard let monthNumber = Int(month), (1...12).contains(monthNumber) else { return nil }
        return (month, year)
    }

    var isValid: Bool {
        holderName.trimmingCharacters(in: .whitespacesAndNewlines).count >= 3 &&
        (15...16).contains(sanitizedNumber.count) &&
        expiryParts != nil &&
        (3...4).contains(sanitizedCVV.count)
    }

    var validationMessage: String? {
        if holderName.trimmingCharacters(in: .whitespacesAndNewlines).count < 3 {
            return "Kart üzerindeki isim gerekli."
        }
        if !(15...16).contains(sanitizedNumber.count) {
            return "Geçerli bir kart numarası girin."
        }
        if expiryParts == nil {
            return "Son kullanma tarihini AA/YY formatında girin."
        }
        if !(3...4).contains(sanitizedCVV.count) {
            return "Geçerli bir CVV girin."
        }
        return nil
    }

    static func formatCardNumber(_ value: String) -> String {
        let digits = String(value.filter(\.isNumber).prefix(16))
        return stride(from: 0, to: digits.count, by: 4)
            .map { index in
                let start = digits.index(digits.startIndex, offsetBy: index)
                let end = digits.index(start, offsetBy: min(4, digits.distance(from: start, to: digits.endIndex)))
                return String(digits[start..<end])
            }
            .joined(separator: " ")
    }

    static func formatExpiry(_ value: String) -> String {
        let digits = String(value.filter(\.isNumber).prefix(4))
        guard digits.count > 2 else { return digits }
        return "\(digits.prefix(2))/\(digits.dropFirst(2))"
    }
}

struct PaymentStatusResponse: Decodable {
    let paymentId: String
    let status: PaymentStatus
    let amount: Double
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case paymentId
        case id
        case status
        case amount
        case amountCents
        case updatedAt
    }

    init(paymentId: String, status: PaymentStatus, amount: Double, updatedAt: Date) {
        self.paymentId = paymentId
        self.status = status
        self.amount = amount
        self.updatedAt = updatedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        if let value = try? container.decode(String.self, forKey: .paymentId) {
            paymentId = value
        } else if let value = try? container.decode(Int64.self, forKey: .paymentId) {
            paymentId = String(value)
        } else if let value = try? container.decode(String.self, forKey: .id) {
            paymentId = value
        } else if let value = try? container.decode(Int64.self, forKey: .id) {
            paymentId = String(value)
        } else {
            paymentId = ""
        }

        status = (try? container.decode(PaymentStatus.self, forKey: .status)) ?? .failed

        if let amount = try? container.decode(Double.self, forKey: .amount) {
            self.amount = amount
        } else if let amountCents = try? container.decode(Int64.self, forKey: .amountCents) {
            amount = Double(amountCents) / 100
        } else {
            amount = 0
        }

        updatedAt = (try? container.decode(Date.self, forKey: .updatedAt)) ?? Date()
    }
}

private extension Double {
    var kurus: Int {
        Int((self * 100).rounded())
    }
}
