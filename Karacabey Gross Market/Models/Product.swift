import Foundation

struct Product: Identifiable, Codable, Hashable {
    let id: String
    var slug: String
    var name: String
    var brand: String
    var description: String
    var price: Double
    var discountedPrice: Double?
    var imageURL: String
    var galleryImageURLs: [String]
    var barcode: String?
    var categoryId: String
    var categoryName: String
    var unit: String
    var stockQuantity: Int
    var isInStock: Bool
    var isFavorite: Bool
    var rating: Double
    var reviewCount: Int
    var nutritionInfo: NutritionInfo?
    var tags: [String]

    var hasDiscount: Bool { discountedPrice != nil && discountedPrice! < price }
    var discountPercent: Int {
        guard let dp = discountedPrice, price > 0 else { return 0 }
        return Int(((price - dp) / price) * 100)
    }
    var effectivePrice: Double { discountedPrice ?? price }

    var numericId: Int64? { Int64(id) }
    var resolvedImageURL: URL? {
        Self.resolveImageURL(imageURL)
    }

    /// Ürün detayında gerçek galeri varsa tüm görselleri döndürür;
    /// galeri yoksa tek ana görseli kullanır. Böylece detay sayfasında
    /// süs amaçlı değil, veriye bağlı kaydırmalı görsel sistemi çalışır.
    var resolvedGalleryImageURLs: [URL] {
        let candidates = ([imageURL] + galleryImageURLs)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        var seen = Set<String>()
        return candidates.compactMap { raw in
            guard seen.insert(raw).inserted else { return nil }
            return Self.resolveImageURL(raw)
        }
    }

    var productShareURL: URL {
        EnvironmentConfig.productShareBaseURL
            .appendingPathComponent(slug.isEmpty ? id : slug)
    }

    var shareMessage: String {
        let unitLabel = unit.isEmpty ? "Adet" : unit
        return """
        Karacabey Gross Market ürününü incele:
        \(name)
        Fiyat: \(effectivePrice.formattedAsTurkishLira) / \(unitLabel)
        Ürün linki: \(productShareURL.absoluteString)

        Mobil uygulamadan daha hızlı sipariş ver:
        \(EnvironmentConfig.appShareURL.absoluteString)
        """
    }

    private static func resolveImageURL(_ rawValue: String) -> URL? {
        EnvironmentConfig.resolveMediaURL(rawValue)
    }

    // `JSONDecoder.keyDecodingStrategy = .convertFromSnakeCase` "image_url" → "imageUrl"
    // şeklinde çevirir; URL gibi acronymleri korumaz. Bu yüzden URL ile biten
    // alanlar için raw değeri açıkça veriyoruz.
    enum CodingKeys: String, CodingKey {
        case id
        case slug
        case name
        case brand
        case description
        case price
        case discountedPrice
        case compareAtPriceCents
        case priceCents
        case imageURL = "imageUrl"
        case image
        case imageURLs = "imageUrls"
        case images
        case galleryImages
        case gallery
        case media
        case photos
        case thumbnailURL = "thumbnailUrl"
        case photoURL = "photoUrl"
        case featuredImageURL = "featuredImageUrl"
        case barcode
        case categoryId
        case categoryName
        case unit
        case unitName
        case stockQuantity
        case isInStock
        case isFavorite
        case rating
        case reviewCount
        case nutritionInfo
        case tags
        case categories
    }

    init(
        id: String,
        slug: String,
        name: String,
        brand: String = "",
        description: String = "",
        price: Double,
        discountedPrice: Double? = nil,
        imageURL: String = "",
        galleryImageURLs: [String] = [],
        barcode: String? = nil,
        categoryId: String = "",
        categoryName: String = "",
        unit: String = "Adet",
        stockQuantity: Int = 0,
        isInStock: Bool = true,
        isFavorite: Bool = false,
        rating: Double = 0,
        reviewCount: Int = 0,
        nutritionInfo: NutritionInfo? = nil,
        tags: [String] = []
    ) {
        self.id = id
        self.slug = slug
        self.name = name
        self.brand = brand
        self.description = description
        self.price = price
        self.discountedPrice = discountedPrice
        self.imageURL = imageURL
        self.galleryImageURLs = galleryImageURLs
        self.barcode = barcode
        self.categoryId = categoryId
        self.categoryName = categoryName
        self.unit = unit
        self.stockQuantity = stockQuantity
        self.isInStock = isInStock
        self.isFavorite = isFavorite
        self.rating = rating
        self.reviewCount = reviewCount
        self.nutritionInfo = nutritionInfo
        self.tags = tags
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        if let intId = try? container.decode(Int64.self, forKey: .id) {
            id = String(intId)
        } else {
            id = try container.decode(String.self, forKey: .id)
        }

        slug = (try? container.decode(String.self, forKey: .slug)) ?? id
        name = (try? container.decode(String.self, forKey: .name)) ?? ""
        brand = (try? container.decodeIfPresent(String.self, forKey: .brand)) ?? ""
        description = (try? container.decodeIfPresent(String.self, forKey: .description)) ?? ""

        let priceCents = Self.decodeInt64IfPresent(container, forKey: .priceCents) ?? 0
        let compareAtCents = Self.decodeInt64IfPresent(container, forKey: .compareAtPriceCents)
        let currentPrice = priceCents > 0 ? Double(priceCents) / 100.0 : nil

        if let compareAtCents, compareAtCents > priceCents, let currentPrice {
            price = Double(compareAtCents) / 100.0
            discountedPrice = currentPrice
        } else {
            price = Self.decodeDoubleIfPresent(container, forKey: .price) ?? currentPrice ?? 0
            discountedPrice = Self.decodeDoubleIfPresent(container, forKey: .discountedPrice)
        }

        imageURL = Self.firstNonEmptyString(container, keys: [
            .imageURL,
            .image,
            .thumbnailURL,
            .photoURL,
            .featuredImageURL
        ]) ?? ""

        galleryImageURLs = Self.decodeImageGallery(container)
        if imageURL.isEmpty, let firstGalleryImage = galleryImageURLs.first {
            imageURL = firstGalleryImage
        }

        barcode = try? container.decodeIfPresent(String.self, forKey: .barcode)
        unit = (try? container.decodeIfPresent(String.self, forKey: .unitName))
            ?? (try? container.decodeIfPresent(String.self, forKey: .unit))
            ?? "Adet"
        stockQuantity = Self.decodeIntIfPresent(container, forKey: .stockQuantity) ?? 0
        isInStock = (try? container.decode(Bool.self, forKey: .isInStock)) ?? (stockQuantity > 0)
        isFavorite = (try? container.decode(Bool.self, forKey: .isFavorite)) ?? false
        rating = (try? container.decode(Double.self, forKey: .rating)) ?? 0
        reviewCount = (try? container.decode(Int.self, forKey: .reviewCount)) ?? 0
        nutritionInfo = try? container.decodeIfPresent(NutritionInfo.self, forKey: .nutritionInfo)
        tags = (try? container.decode([String].self, forKey: .tags)) ?? []

        let categoryRefs = (try? container.decode([ProductCategoryRef].self, forKey: .categories)) ?? []
        categoryId = (try? container.decodeIfPresent(String.self, forKey: .categoryId)) ?? categoryRefs.first?.slug ?? ""
        categoryName = (try? container.decodeIfPresent(String.self, forKey: .categoryName)) ?? categoryRefs.first?.name ?? ""
    }


    private static func decodeDoubleIfPresent(_ container: KeyedDecodingContainer<CodingKeys>, forKey key: CodingKeys) -> Double? {
        if let value = try? container.decode(Double.self, forKey: key) { return value }
        if let value = try? container.decode(Int.self, forKey: key) { return Double(value) }
        if let value = try? container.decode(Int64.self, forKey: key) { return Double(value) }
        if let value = try? container.decode(String.self, forKey: key) {
            let normalized = value
                .replacingOccurrences(of: "₺", with: "")
                .replacingOccurrences(of: "TL", with: "")
                .replacingOccurrences(of: "tl", with: "")
                .replacingOccurrences(of: " ", with: "")
                .replacingOccurrences(of: ",", with: ".")
            return Double(normalized)
        }
        return nil
    }

    private static func decodeIntIfPresent(_ container: KeyedDecodingContainer<CodingKeys>, forKey key: CodingKeys) -> Int? {
        if let value = try? container.decode(Int.self, forKey: key) { return value }
        if let value = try? container.decode(Int64.self, forKey: key) { return Int(value) }
        if let value = try? container.decode(Double.self, forKey: key) { return Int(value) }
        if let value = try? container.decode(String.self, forKey: key) { return Int(value.trimmingCharacters(in: .whitespacesAndNewlines)) }
        return nil
    }

    private static func decodeInt64IfPresent(_ container: KeyedDecodingContainer<CodingKeys>, forKey key: CodingKeys) -> Int64? {
        if let value = try? container.decode(Int64.self, forKey: key) { return value }
        if let value = try? container.decode(Int.self, forKey: key) { return Int64(value) }
        if let value = try? container.decode(Double.self, forKey: key) { return Int64(value) }
        if let value = try? container.decode(String.self, forKey: key) { return Int64(value.trimmingCharacters(in: .whitespacesAndNewlines)) }
        return nil
    }

    private static func firstNonEmptyString(_ container: KeyedDecodingContainer<CodingKeys>, keys: [CodingKeys]) -> String? {
        for key in keys {
            if let value = try? container.decode(String.self, forKey: key) {
                let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty { return trimmed }
            }
        }
        return nil
    }

    private static func decodeImageGallery(_ container: KeyedDecodingContainer<CodingKeys>) -> [String] {
        let keys: [CodingKeys] = [.imageURLs, .images, .galleryImages, .gallery, .media, .photos]
        var results: [String] = []

        for key in keys {
            if let values = try? container.decode([String].self, forKey: key) {
                results.append(contentsOf: values)
            }

            if let values = try? container.decode([FlexibleProductImage].self, forKey: key) {
                results.append(contentsOf: values.compactMap(\.bestURL))
            }
        }

        var seen = Set<String>()
        return results
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .filter { seen.insert($0).inserted }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(slug, forKey: .slug)
        try container.encode(name, forKey: .name)
        try container.encode(brand, forKey: .brand)
        try container.encode(description, forKey: .description)
        try container.encode(price, forKey: .price)
        try container.encodeIfPresent(discountedPrice, forKey: .discountedPrice)
        try container.encode(imageURL, forKey: .imageURL)
        try container.encode(galleryImageURLs, forKey: .imageURLs)
        try container.encodeIfPresent(barcode, forKey: .barcode)
        try container.encode(categoryId, forKey: .categoryId)
        try container.encode(categoryName, forKey: .categoryName)
        try container.encode(unit, forKey: .unit)
        try container.encode(stockQuantity, forKey: .stockQuantity)
        try container.encode(isInStock, forKey: .isInStock)
        try container.encode(isFavorite, forKey: .isFavorite)
        try container.encode(rating, forKey: .rating)
        try container.encode(reviewCount, forKey: .reviewCount)
        try container.encodeIfPresent(nutritionInfo, forKey: .nutritionInfo)
        try container.encode(tags, forKey: .tags)
    }
}

private struct ProductCategoryRef: Decodable, Hashable {
    let slug: String
    let name: String?
}

private struct FlexibleProductImage: Decodable, Hashable {
    var url: String?
    var imageUrl: String?
    var imageURL: String?
    var src: String?
    var path: String?
    var fileUrl: String?
    var original: String?
    var thumbnail: String?

    var bestURL: String? {
        [url, imageUrl, imageURL, src, path, fileUrl, original, thumbnail]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { !$0.isEmpty }
    }
}

struct NutritionInfo: Codable, Hashable {
    var calories: String?
    var protein: String?
    var fat: String?
    var carbs: String?
    var fiber: String?
}
