import Foundation

enum HomeSectionType: String, Codable, CaseIterable {
    case heroBanner = "HERO_BANNER"
    case campaignCarousel = "CAMPAIGN_CAROUSEL"
    case storyStrip = "STORY_STRIP"
    case productCarousel = "PRODUCT_CAROUSEL"
    case categoryGrid = "CATEGORY_GRID"
    case toolsGrid = "TOOLS_GRID"
    case singleBanner = "SINGLE_BANNER"
    case promotedBrands = "PROMOTED_BRANDS"
}

struct HomeSection: Identifiable, Codable, Hashable {
    let id: String
    var type: HomeSectionType
    var title: String?
    var subtitle: String?
    var sortOrder: Int
    var isActive: Bool
    var items: [HomeSectionItem]
    var config: HomeSectionConfig?
}

struct HomeSectionItem: Identifiable, Codable, Hashable {
    let id: String
    var sectionId: String
    var title: String?
    var subtitle: String?
    var imageURL: String?
    var deepLink: String?
    var backgroundColor: String?
    var refId: String?
    var refType: String?
    var sortOrder: Int
    var isActive: Bool
}

struct HomeSectionConfig: Codable, Hashable {
    var autoScroll: Bool?
    var scrollInterval: Int?
    var itemsPerRow: Int?
    var showTitle: Bool?
    var ctaText: String?
    var ctaDeepLink: String?
    var filterTag: String?
    var limit: Int?
}

struct HomeLayout: Codable {
    var sections: [HomeSection]
    var fetchedAt: Date
}
