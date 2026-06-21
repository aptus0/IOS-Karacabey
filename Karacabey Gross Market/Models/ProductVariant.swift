import Foundation

struct ProductVariant: Identifiable, Codable, Hashable {
    let id: String
    var productId: String
    var sku: String
    var barcode: String?
    var name: String
    var price: Double
    var discountedPrice: Double?
    var stockQuantity: Int
    var unit: String
    var weight: Double?
    var isDefault: Bool
    var isActive: Bool
    var sortOrder: Int
    var images: [ProductImage]

    var hasDiscount: Bool { discountedPrice != nil && discountedPrice! < price }
    var effectivePrice: Double { discountedPrice ?? price }
    var discountPercent: Int {
        guard let dp = discountedPrice, price > 0 else { return 0 }
        return Int(((price - dp) / price) * 100)
    }
}

struct ProductImage: Identifiable, Codable, Hashable {
    let id: String
    var productId: String
    var variantId: String?
    var url: String
    var altText: String?
    var sortOrder: Int
    var isPrimary: Bool
}

struct ProductReview: Identifiable, Codable, Hashable {
    let id: String
    var productId: String
    var userId: String
    var userName: String
    var rating: Int
    var title: String?
    var body: String?
    var createdAt: Date
    var isVerifiedPurchase: Bool
    var helpfulCount: Int
}

struct Favorite: Identifiable, Codable, Hashable {
    let id: String
    var userId: String
    var productId: String
    var product: Product?
    var addedAt: Date
}
