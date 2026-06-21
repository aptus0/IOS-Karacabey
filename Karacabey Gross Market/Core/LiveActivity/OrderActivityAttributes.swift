import ActivityKit
import Foundation

struct OrderActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        let status: String
        let statusLabel: String
        let progress: Double
        let updatedAt: Int
    }

    let orderId: String
    let orderNumber: String
    let deepLink: String
}
