import Foundation

struct Category: Identifiable, Codable, Hashable {
    let id: String
    var slug: String
    var name: String
    var iconName: String
    var colorHex: String
    var productCount: Int
    var subcategories: [SubCategory]?

    enum CodingKeys: String, CodingKey {
        case id
        case slug
        case name
        case iconName
        case colorHex
        case productCount
        case subcategories
        case children
    }

    init(
        id: String,
        slug: String,
        name: String,
        iconName: String = "square.grid.2x2",
        colorHex: String = "#16A34A",
        productCount: Int = 0,
        subcategories: [SubCategory]? = nil
    ) {
        self.id = id
        self.slug = slug
        self.name = name
        self.iconName = iconName
        self.colorHex = colorHex
        self.productCount = productCount
        self.subcategories = subcategories
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let apiSlug = (try? container.decode(String.self, forKey: .slug)) ?? ""
        slug = apiSlug
        id = apiSlug.isEmpty ? String((try? container.decode(Int64.self, forKey: .id)) ?? 0) : apiSlug
        name = (try? container.decode(String.self, forKey: .name)) ?? ""
        iconName = (try? container.decode(String.self, forKey: .iconName)) ?? Self.iconName(for: name)
        colorHex = (try? container.decode(String.self, forKey: .colorHex)) ?? Self.colorHex(for: name)
        productCount = (try? container.decode(Int.self, forKey: .productCount)) ?? 0
        subcategories = (try? container.decodeIfPresent([SubCategory].self, forKey: .subcategories))
            ?? (try? container.decodeIfPresent([SubCategory].self, forKey: .children))
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(slug, forKey: .slug)
        try container.encode(name, forKey: .name)
        try container.encode(iconName, forKey: .iconName)
        try container.encode(colorHex, forKey: .colorHex)
        try container.encode(productCount, forKey: .productCount)
        try container.encodeIfPresent(subcategories, forKey: .subcategories)
    }

    private static func iconName(for name: String) -> String {
        let lower = name.lowercased()
        if lower.contains("et") || lower.contains("tavuk") || lower.contains("balık") { return "figure.hunting" }
        if lower.contains("süt") || lower.contains("peynir") || lower.contains("yoğurt") || lower.contains("kahvaltı") { return "cup.and.saucer.fill" }
        if lower.contains("meyve") || lower.contains("sebze") { return "leaf.fill" }
        if lower.contains("temizlik") || lower.contains("deterjan") { return "bubbles.and.sparkles.fill" }
        if lower.contains("içecek") || lower.contains("su") || lower.contains("kola") { return "mug.fill" }
        if lower.contains("atıştır") || lower.contains("cips") || lower.contains("çikolata") { return "takeoutbag.and.cup.and.straw.fill" }
        if lower.contains("fırın") || lower.contains("ekmek") || lower.contains("pastane") { return "birthday.cake.fill" }
        if lower.contains("temel") || lower.contains("gıda") || lower.contains("yağ") { return "bag.fill" }
        if lower.contains("dondurma") { return "snowflake" }
        if lower.contains("bakım") || lower.contains("kozmetik") || lower.contains("sağlık") { return "heart.fill" }
        if lower.contains("bebek") || lower.contains("çocuk") { return "stroller.fill" }
        if lower.contains("evcil") || lower.contains("kedi") || lower.contains("köpek") { return "pawprint.fill" }
        if lower.contains("ev") || lower.contains("yaşam") { return "house.fill" }
        if lower.contains("kırtasiye") || lower.contains("ofis") { return "pencil.and.outline" }
        if lower.contains("oyuncak") { return "gamecontroller.fill" }
        if lower.contains("elektronik") { return "bolt.fill" }
        if lower.contains("kampanya") || lower.contains("indirim") { return "gift.fill" }
        return "square.grid.2x2.fill"
    }

    private static func colorHex(for name: String) -> String {
        let lower = name.lowercased()
        if lower.contains("et") || lower.contains("tavuk") { return "#DC2626" }
        if lower.contains("süt") || lower.contains("peynir") || lower.contains("yoğurt") { return "#2563EB" }
        if lower.contains("meyve") || lower.contains("sebze") { return "#16A34A" }
        if lower.contains("temizlik") || lower.contains("deterjan") { return "#7C3AED" }
        if lower.contains("içecek") || lower.contains("su") { return "#0891B2" }
        return "#EA580C"
    }
}

struct SubCategory: Identifiable, Codable, Hashable {
    let id: String
    var slug: String
    var name: String
    var parentId: String

    enum CodingKeys: String, CodingKey {
        case id
        case slug
        case name
        case parentId
    }

    init(id: String, slug: String, name: String, parentId: String = "") {
        self.id = id
        self.slug = slug
        self.name = name
        self.parentId = parentId
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let apiSlug = (try? container.decode(String.self, forKey: .slug)) ?? ""
        slug = apiSlug
        id = apiSlug.isEmpty ? String((try? container.decode(Int64.self, forKey: .id)) ?? 0) : apiSlug
        name = (try? container.decode(String.self, forKey: .name)) ?? ""
        parentId = (try? container.decodeIfPresent(String.self, forKey: .parentId)) ?? ""
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(slug, forKey: .slug)
        try container.encode(name, forKey: .name)
        try container.encode(parentId, forKey: .parentId)
    }
}
