import Foundation

enum OrderStatus: String, Codable, CaseIterable {
    case pending = "PENDING"
    case awaitingPayment = "AWAITING_PAYMENT"
    case reviewing = "REVIEWING"
    case received = "RECEIVED"
    case preparing = "PREPARING"
    case onTheWay = "ON_THE_WAY"
    case delivered = "DELIVERED"
    case cancelled = "CANCELLED"

    var displayName: String {
        switch self {
        case .pending: return "Beklemede"
        case .awaitingPayment: return "Ödeme Bekleniyor"
        case .reviewing: return "Kontrol Ediliyor"
        case .received: return "Onaylandı"
        case .preparing: return "Hazırlanıyor"
        case .onTheWay: return "Yola Çıktı"
        case .delivered: return "Teslim Edildi"
        case .cancelled: return "İptal Edildi"
        }
    }


    var progressRank: Int {
        switch self {
        case .pending: return 0
        case .awaitingPayment: return 0
        case .reviewing: return 1
        case .received: return 2
        case .preparing: return 3
        case .onTheWay: return 4
        case .delivered: return 5
        case .cancelled: return -1
        }
    }

    var systemIconName: String {
        switch self {
        case .pending: return "clock"
        case .awaitingPayment: return "creditcard"
        case .reviewing: return "checkmark.shield"
        case .received: return "checkmark.circle"
        case .preparing: return "bag"
        case .onTheWay: return "bicycle"
        case .delivered: return "house"
        case .cancelled: return "xmark.circle"
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let value = ((try? container.decode(String.self)) ?? "").lowercased()
        switch value {
        case "pending", "waiting", "beklemede":
            self = .pending
        case "awaiting_payment":
            self = .awaitingPayment
        case "reviewing", "control", "checking", "paid":
            self = .reviewing
        case "received", "approved", "confirmed", "accepted", "onaylandi", "onaylandı":
            self = .received
        case "processing", "preparing", "hazirlaniyor", "hazırlanıyor":
            self = .preparing
        case "shipping", "in_delivery", "on_the_way", "yola_cikti", "yola_çıktı":
            self = .onTheWay
        case "completed", "delivered":
            self = .delivered
        case "failed", "cancelled", "canceled", "refunded":
            self = .cancelled
        default:
            self = .received
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

struct Order: Identifiable, Decodable, Hashable {
    let id: String
    var orderNumber: String
    var items: [CartItem]
    var status: OrderStatus
    var deliveryAddress: Address
    var paymentMethod: PaymentMethod
    var subtotal: Double
    var discountAmount: Double
    var deliveryFee: Double
    var total: Double
    var createdAt: Date
    var estimatedDelivery: Date?
    var notes: String?
    var shipment: Shipment?

    var statusHistory: [OrderStatusEvent]

    enum CodingKeys: String, CodingKey {
        case id
        case orderNumber
        case merchantOID = "merchantOid"
        case checkoutRef
        case items
        case status
        case deliveryAddress
        case paymentMethod
        case subtotal
        case subtotalCents
        case discountAmount
        case discountCents
        case deliveryFee
        case shippingCents
        case total
        case totalCents
        case createdAt
        case estimatedDelivery
        case notes
        case shipment
        case statusHistory
        case customerName
        case customerPhone
        case shippingCity
        case shippingDistrict
        case shippingAddress
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        if let numericID = try? container.decode(Int64.self, forKey: .id) {
            id = String(numericID)
        } else {
            id = (try? container.decode(String.self, forKey: .id)) ?? UUID().uuidString
        }

        orderNumber = (try? container.decode(String.self, forKey: .orderNumber))
            ?? (try? container.decode(String.self, forKey: .merchantOID))
            ?? (try? container.decode(String.self, forKey: .checkoutRef))
            ?? id
        status = (try? container.decode(OrderStatus.self, forKey: .status)) ?? .received

        if let decodedItems = try? container.decode([CartItem].self, forKey: .items) {
            items = decodedItems
        } else {
            let apiItems = (try? container.decode([OrderAPILineItem].self, forKey: .items)) ?? []
            items = apiItems.map(\.cartItem)
        }

        if let address = try? container.decode(Address.self, forKey: .deliveryAddress) {
            deliveryAddress = address
        } else {
            let recipient = (try? container.decode(String.self, forKey: .customerName)) ?? ""
            let names = recipient.split(separator: " ", maxSplits: 1).map(String.init)
            deliveryAddress = Address(
                id: "order-\(id)",
                title: "Teslimat Adresi",
                firstName: names.first ?? recipient,
                lastName: names.count > 1 ? names[1] : "",
                phone: (try? container.decode(String.self, forKey: .customerPhone)) ?? "",
                city: (try? container.decodeIfPresent(String.self, forKey: .shippingCity)) ?? "",
                district: (try? container.decodeIfPresent(String.self, forKey: .shippingDistrict)) ?? "",
                neighborhood: "",
                street: (try? container.decode(String.self, forKey: .shippingAddress)) ?? "",
                buildingNo: "",
                apartmentNo: "",
                floor: "",
                directions: "",
                isDefault: false
            )
        }

        paymentMethod = (try? container.decode(PaymentMethod.self, forKey: .paymentMethod))
            ?? PaymentMethod(
                id: "order-\(id)",
                type: .cashOnDelivery,
                maskedCardNumber: nil,
                cardHolderName: nil,
                expiryDate: nil,
                isDefault: false
            )
        subtotal = Self.money(in: container, value: .subtotal, cents: .subtotalCents)
        discountAmount = Self.money(in: container, value: .discountAmount, cents: .discountCents)
        deliveryFee = Self.money(in: container, value: .deliveryFee, cents: .shippingCents)
        total = Self.money(in: container, value: .total, cents: .totalCents)
        createdAt = (try? container.decode(Date.self, forKey: .createdAt)) ?? Date()
        estimatedDelivery = try? container.decodeIfPresent(Date.self, forKey: .estimatedDelivery)
        notes = try? container.decodeIfPresent(String.self, forKey: .notes)
        shipment = try? container.decodeIfPresent(Shipment.self, forKey: .shipment)
        statusHistory = (try? container.decode([OrderStatusEvent].self, forKey: .statusHistory))
            ?? [OrderStatusEvent(id: "\(id)-current", status: status, timestamp: createdAt, note: nil)]
    }

    private static func money(
        in container: KeyedDecodingContainer<CodingKeys>,
        value: CodingKeys,
        cents: CodingKeys
    ) -> Double {
        if let amount = try? container.decode(Double.self, forKey: value) {
            return amount
        }
        return Double((try? container.decode(Int64.self, forKey: cents)) ?? 0) / 100
    }
}

struct OrderStatusEvent: Identifiable, Decodable, Hashable {
    let id: String
    var status: OrderStatus
    var timestamp: Date
    var note: String?
}

private struct OrderAPILineItem: Decodable {
    let id: String
    let productId: String?
    let slug: String?
    let imageURL: String?
    let name: String
    let quantity: Int
    let unitPriceCents: Int64
    let lineTotalCents: Int64

    enum CodingKeys: String, CodingKey {
        case id, productId, slug, imageURL = "imageUrl", name, quantity, unitPriceCents, lineTotalCents
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let numericID = try? container.decode(Int64.self, forKey: .id) {
            id = String(numericID)
        } else {
            id = (try? container.decode(String.self, forKey: .id)) ?? UUID().uuidString
        }
        if let numericProductID = try? container.decode(Int64.self, forKey: .productId) {
            productId = String(numericProductID)
        } else {
            productId = try? container.decodeIfPresent(String.self, forKey: .productId)
        }
        slug = try? container.decodeIfPresent(String.self, forKey: .slug)
        imageURL = try? container.decodeIfPresent(String.self, forKey: .imageURL)
        name = (try? container.decode(String.self, forKey: .name)) ?? "Ürün"
        quantity = (try? container.decode(Int.self, forKey: .quantity)) ?? 1
        unitPriceCents = (try? container.decode(Int64.self, forKey: .unitPriceCents)) ?? 0
        lineTotalCents = (try? container.decode(Int64.self, forKey: .lineTotalCents)) ?? 0
    }

    var cartItem: CartItem {
        CartItem(
            id: id,
            product: Product(
                id: productId ?? id,
                slug: slug ?? productId ?? id,
                name: name,
                price: Double(unitPriceCents) / 100,
                imageURL: imageURL ?? ""
            ),
            quantity: quantity,
            lineTotalCents: lineTotalCents
        )
    }
}
