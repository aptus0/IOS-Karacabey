import Foundation

struct KGMProductReview: Identifiable, Codable, Hashable {
    let id: String
    let authorName: String
    let rating: Int
    let title: String?
    let body: String?
    let createdAt: Date
    let isPending: Bool

    enum CodingKeys: String, CodingKey {
        case id, authorName, rating, title, body, createdAt, isPending
    }

    init(
        id: String = UUID().uuidString,
        authorName: String,
        rating: Int,
        title: String?,
        body: String?,
        createdAt: Date = Date(),
        isPending: Bool = false
    ) {
        self.id = id
        self.authorName = authorName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Müşteri" : authorName
        self.rating = max(1, min(5, rating))
        self.title = title?.nilIfBlank
        self.body = body?.nilIfBlank
        self.createdAt = createdAt
        self.isPending = isPending
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let numericID = try? container.decode(Int64.self, forKey: .id) {
            id = String(numericID)
        } else {
            id = (try? container.decode(String.self, forKey: .id)) ?? UUID().uuidString
        }
        authorName = (try? container.decode(String.self, forKey: .authorName)) ?? "Müşteri"
        rating = max(0, min(5, (try? container.decode(Int.self, forKey: .rating)) ?? 0))
        title = try? container.decodeIfPresent(String.self, forKey: .title)
        body = try? container.decodeIfPresent(String.self, forKey: .body)
        createdAt = (try? container.decode(Date.self, forKey: .createdAt)) ?? Date()
        isPending = (try? container.decode(Bool.self, forKey: .isPending)) ?? false
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(authorName, forKey: .authorName)
        try container.encode(rating, forKey: .rating)
        try container.encodeIfPresent(title, forKey: .title)
        try container.encodeIfPresent(body, forKey: .body)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(isPending, forKey: .isPending)
    }
}

struct ProductReviewsResponse: Decodable {
    let reviews: [KGMProductReview]
    let averageRating: Double
    let reviewCount: Int

    enum CodingKeys: String, CodingKey {
        case reviews, averageRating, reviewCount, data
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        reviews = (try? container.decode([KGMProductReview].self, forKey: .reviews))
            ?? (try? container.decode([KGMProductReview].self, forKey: .data))
            ?? []
        averageRating = (try? container.decode(Double.self, forKey: .averageRating))
            ?? Self.calculateAverage(reviews)
        reviewCount = (try? container.decode(Int.self, forKey: .reviewCount))
            ?? reviews.count
    }

    private static func calculateAverage(_ reviews: [KGMProductReview]) -> Double {
        guard !reviews.isEmpty else { return 0 }
        let total = reviews.reduce(0) { $0 + $1.rating }
        return Double(total) / Double(reviews.count)
    }
}

struct ProductReviewSubmissionRequest: Encodable {
    let rating: Int
    let title: String?
    let body: String
    let authorName: String
    let source: String

    enum CodingKeys: String, CodingKey {
        case rating, title, body, authorName, source
    }

    init(rating: Int, title: String?, body: String, authorName: String, source: String = "ios") {
        self.rating = max(1, min(5, rating))
        self.title = title?.nilIfBlank
        self.body = body.trimmingCharacters(in: .whitespacesAndNewlines)
        self.authorName = authorName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Müşteri" : authorName
        self.source = source
    }
}

struct ProductReviewDraft: Hashable {
    let rating: Int
    let title: String
    let body: String
    let authorName: String

    var sanitizedTitle: String? { title.nilIfBlank }
    var sanitizedBody: String { body.trimmingCharacters(in: .whitespacesAndNewlines) }
    var sanitizedAuthorName: String {
        let trimmed = authorName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Müşteri" : trimmed
    }

    var isValid: Bool {
        rating >= 1 && rating <= 5 && sanitizedBody.count >= 3
    }

    var asRequest: ProductReviewSubmissionRequest {
        ProductReviewSubmissionRequest(
            rating: rating,
            title: sanitizedTitle,
            body: sanitizedBody,
            authorName: sanitizedAuthorName
        )
    }

    var asPendingReview: KGMProductReview {
        KGMProductReview(
            id: "pending-\(UUID().uuidString)",
            authorName: sanitizedAuthorName,
            rating: rating,
            title: sanitizedTitle,
            body: sanitizedBody,
            createdAt: Date(),
            isPending: true
        )
    }
}

enum ProductReviewLocalStore {
    private static let suitePrefix = "kgm.pending.reviews."

    static func pendingReviews(slug: String) -> [KGMProductReview] {
        let key = cacheKey(slug: slug)
        guard let data = UserDefaults.standard.data(forKey: key) else { return [] }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return (try? decoder.decode([KGMProductReview].self, from: data)) ?? []
    }

    static func addPendingReview(_ review: KGMProductReview, slug: String) {
        var current = pendingReviews(slug: slug)
        current.insert(review, at: 0)
        save(current.prefix(10).map { $0 }, slug: slug)
    }

    static func clearPendingReviews(slug: String) {
        UserDefaults.standard.removeObject(forKey: cacheKey(slug: slug))
    }

    private static func save(_ reviews: [KGMProductReview], slug: String) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(reviews) else { return }
        UserDefaults.standard.set(data, forKey: cacheKey(slug: slug))
    }

    private static func cacheKey(slug: String) -> String {
        suitePrefix + slug.lowercased().replacingOccurrences(of: " ", with: "-")
    }
}

private extension String {
    var nilIfBlank: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
