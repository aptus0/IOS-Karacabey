import Foundation

struct Campaign: Identifiable, Decodable, Hashable {
    let id: String
    var title: String
    var subtitle: String?
    var imageURL: String
    var badgeText: String?
    var ctaText: String
    var deepLink: String?
    var backgroundColor: String
    var startsAt: Date?
    var endsAt: Date?
    var isActive: Bool
    var sortOrder: Int

    var isLive: Bool {
        guard isActive else { return false }
        let now = Date()
        if let s = startsAt, now < s { return false }
        if let e = endsAt, now > e { return false }
        return true
    }

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case title
        case slug
        case subtitle
        case description
        case imageURL = "imageUrl"
        case bannerImageURL = "bannerImageUrl"
        case badgeText
        case ctaText
        case deepLink
        case backgroundColor
        case startsAt
        case endsAt
        case isActive
        case sortOrder
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        if let intId = try? c.decode(Int64.self, forKey: .id) {
            id = String(intId)
        } else {
            id = (try? c.decode(String.self, forKey: .id)) ?? UUID().uuidString
        }
        title = (try? c.decode(String.self, forKey: .title))
            ?? (try? c.decode(String.self, forKey: .name))
            ?? ""
        subtitle = (try? c.decodeIfPresent(String.self, forKey: .subtitle))
            ?? (try? c.decodeIfPresent(String.self, forKey: .description))
        imageURL = (try? c.decode(String.self, forKey: .imageURL))
            ?? (try? c.decode(String.self, forKey: .bannerImageURL))
            ?? ""
        badgeText = try? c.decodeIfPresent(String.self, forKey: .badgeText)
        ctaText = (try? c.decode(String.self, forKey: .ctaText)) ?? "İncele"
        let slug = (try? c.decodeIfPresent(String.self, forKey: .slug)) ?? nil
        deepLink = (try? c.decodeIfPresent(String.self, forKey: .deepLink))
            ?? slug.map { "kgm://campaigns/\($0)" }
        backgroundColor = (try? c.decode(String.self, forKey: .backgroundColor)) ?? "#FF7A00"
        let iso = ISO8601DateFormatter()
        if let s = try? c.decodeIfPresent(String.self, forKey: .startsAt) {
            startsAt = iso.date(from: s)
        } else {
            startsAt = try? c.decodeIfPresent(Date.self, forKey: .startsAt)
        }
        if let s = try? c.decodeIfPresent(String.self, forKey: .endsAt) {
            endsAt = iso.date(from: s)
        } else {
            endsAt = try? c.decodeIfPresent(Date.self, forKey: .endsAt)
        }
        isActive = (try? c.decodeIfPresent(Bool.self, forKey: .isActive)) ?? true
        sortOrder = (try? c.decodeIfPresent(Int.self, forKey: .sortOrder)) ?? 0
    }
}

// Go API: GET /api/v1/content/stories — admin/stories tablosundan beslenir.
struct Story: Identifiable, Codable, Hashable {
    let id: String
    var title: String
    var subtitle: String?
    var coverImageURL: String?
    var deepLink: String?
    var categorySlug: String?
    var gradientStart: String
    var gradientEnd: String
    var icon: String
    var sortOrder: Int
    var isViewed: Bool = false

    // `JSONDecoder.keyDecodingStrategy = .convertFromSnakeCase` "image_url" → "imageUrl"
    // şeklinde çevirir; acronymleri (URL/Url) korumaz. Bu yüzden CodingKey raw
    // değerlerini decoder'ın üretmesi beklenen camelCase formuyla eşleştiriyoruz.
    enum CodingKeys: String, CodingKey {
        case id
        case title
        case subtitle
        case imageURL = "imageUrl"
        case coverImageURL = "coverImageUrl"
        case deepLink
        case customURL = "customUrl"
        case categorySlug
        case gradientStart
        case gradientEnd
        case icon
        case sortOrder
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        if let intId = try? c.decode(Int64.self, forKey: .id) {
            id = String(intId)
        } else {
            id = (try? c.decode(String.self, forKey: .id)) ?? UUID().uuidString
        }
        title = (try? c.decode(String.self, forKey: .title)) ?? ""
        subtitle = try? c.decodeIfPresent(String.self, forKey: .subtitle)
        coverImageURL = (try? c.decodeIfPresent(String.self, forKey: .coverImageURL))
            ?? (try? c.decodeIfPresent(String.self, forKey: .imageURL))
        deepLink = (try? c.decodeIfPresent(String.self, forKey: .deepLink))
            ?? (try? c.decodeIfPresent(String.self, forKey: .customURL))
        categorySlug = try? c.decodeIfPresent(String.self, forKey: .categorySlug)
        gradientStart = (try? c.decode(String.self, forKey: .gradientStart)) ?? "#FF7A00"
        gradientEnd = (try? c.decode(String.self, forKey: .gradientEnd)) ?? "#FF3300"
        icon = (try? c.decode(String.self, forKey: .icon)) ?? "tag.fill"
        sortOrder = (try? c.decode(Int.self, forKey: .sortOrder)) ?? 0
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(title, forKey: .title)
        try c.encodeIfPresent(subtitle, forKey: .subtitle)
        try c.encodeIfPresent(coverImageURL, forKey: .coverImageURL)
        try c.encodeIfPresent(deepLink, forKey: .deepLink)
        try c.encodeIfPresent(categorySlug, forKey: .categorySlug)
        try c.encode(gradientStart, forKey: .gradientStart)
        try c.encode(gradientEnd, forKey: .gradientEnd)
        try c.encode(icon, forKey: .icon)
        try c.encode(sortOrder, forKey: .sortOrder)
    }
}
