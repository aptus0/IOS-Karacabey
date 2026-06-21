import Foundation

struct Brand: Identifiable, Codable, Hashable {
    let id: String
    var name: String
    var slug: String
    var logoURL: String?
    var description: String?
    var isActive: Bool
    var sortOrder: Int
}
