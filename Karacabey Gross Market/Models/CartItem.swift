import Foundation

struct CartItem: Identifiable, Decodable, Hashable {
    let id: String
    var product: Product
    var quantity: Int
    var lineTotalCents: Int64?

    var totalPrice: Double {
        if let lineTotalCents {
            return lineTotalCents.asDouble
        }
        return product.effectivePrice * Double(quantity)
    }

    enum CodingKeys: String, CodingKey {
        case id
        case product
        case quantity
        case lineTotalCents
    }

    init(id: String, product: Product, quantity: Int, lineTotalCents: Int64? = nil) {
        self.id = id
        self.product = product
        self.quantity = quantity
        self.lineTotalCents = lineTotalCents
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let intId = try? container.decode(Int64.self, forKey: .id) {
            id = String(intId)
        } else {
            id = try container.decode(String.self, forKey: .id)
        }
        product = try container.decode(Product.self, forKey: .product)
        quantity = (try? container.decode(Int.self, forKey: .quantity)) ?? 1
        lineTotalCents = try? container.decodeIfPresent(Int64.self, forKey: .lineTotalCents)
    }
}

struct Cart: Decodable {
    var items: [CartItem]
    var cartToken: String?
    var couponCode: String?
    var discountAmount: Double
    var deliveryFee: Double
    var subtotalCents: Int64?
    var totalCents: Int64?

    var subtotal: Double {
        if let subtotalCents {
            return subtotalCents.asDouble
        }
        return items.reduce(0) { $0 + $1.totalPrice }
    }

    var total: Double {
        if let totalCents {
            return totalCents.asDouble
        }
        return max(0, subtotal - discountAmount + deliveryFee)
    }

    var itemCount: Int { items.reduce(0) { $0 + $1.quantity } }
    var isEmpty: Bool { items.isEmpty }
    var hasDeliveryFee: Bool { deliveryFee > 0 }

    static let empty = Cart(items: [], cartToken: nil, couponCode: nil, discountAmount: 0, deliveryFee: 0)

    enum CodingKeys: String, CodingKey {
        case items
        case cartToken
        case couponCode
        case appliedCoupon
        case discountAmount
        case deliveryFee
        case deliveryFeeCents
        case subtotalCents
        case totalCents
    }

    init(
        items: [CartItem],
        cartToken: String?,
        couponCode: String?,
        discountAmount: Double,
        deliveryFee: Double,
        subtotalCents: Int64? = nil,
        totalCents: Int64? = nil
    ) {
        self.items = items
        self.cartToken = cartToken
        self.couponCode = couponCode
        self.discountAmount = discountAmount
        self.deliveryFee = deliveryFee
        self.subtotalCents = subtotalCents
        self.totalCents = totalCents
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        items = (try? container.decode([CartItem].self, forKey: .items)) ?? []
        cartToken = try? container.decodeIfPresent(String.self, forKey: .cartToken)
        couponCode = try? container.decodeIfPresent(String.self, forKey: .couponCode)
        subtotalCents = try? container.decodeIfPresent(Int64.self, forKey: .subtotalCents)
        totalCents = try? container.decodeIfPresent(Int64.self, forKey: .totalCents)
        if couponCode == nil,
           let coupon = try? container.decodeIfPresent(AppliedCartCoupon.self, forKey: .appliedCoupon) {
            couponCode = coupon.code
            discountAmount = Double(coupon.discountCents) / 100.0
        } else {
            discountAmount = (try? container.decode(Double.self, forKey: .discountAmount)) ?? 0
        }
        if let deliveryFeeCents = try? container.decodeIfPresent(Int64.self, forKey: .deliveryFeeCents) {
            deliveryFee = deliveryFeeCents.asDouble
        } else {
            deliveryFee = (try? container.decode(Double.self, forKey: .deliveryFee)) ?? 0
        }
    }
}

private struct AppliedCartCoupon: Decodable {
    let code: String
    let discountCents: Int64
}
