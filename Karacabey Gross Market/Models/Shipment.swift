import Foundation

enum ShipmentStatus: String, Codable, CaseIterable {
    case notShipped = "NOT_SHIPPED"
    case readyForPickup = "READY_FOR_PICKUP"
    case pickedUp = "PICKED_UP"
    case inTransit = "IN_TRANSIT"
    case outForDelivery = "OUT_FOR_DELIVERY"
    case delivered = "DELIVERED"
    case failedDelivery = "FAILED_DELIVERY"
    case returned = "RETURNED"

    var displayName: String {
        switch self {
        case .notShipped: return "Hazırlanmadı"
        case .readyForPickup: return "Teslimata Hazır"
        case .pickedUp: return "Kurye Aldı"
        case .inTransit: return "Yolda"
        case .outForDelivery: return "Dağıtımda"
        case .delivered: return "Teslim Edildi"
        case .failedDelivery: return "Teslim Edilemedi"
        case .returned: return "İade"
        }
    }

    init(from decoder: Decoder) throws {
        let value = ((try? decoder.singleValueContainer().decode(String.self)) ?? "").lowercased()
        switch value {
        case "ready_for_pickup", "pending": self = .readyForPickup
        case "picked_up", "shipped": self = .pickedUp
        case "in_transit": self = .inTransit
        case "out_for_delivery": self = .outForDelivery
        case "delivered": self = .delivered
        case "failed_delivery", "exception": self = .failedDelivery
        case "returned": self = .returned
        default: self = .notShipped
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

struct Shipment: Identifiable, Decodable, Hashable {
    let id: String
    var status: ShipmentStatus
    var carrier: String
    var trackingNumber: String?
    var trackingURL: String?
    var shippedAt: Date?
    var deliveredAt: Date?
    var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id, status, carrier, trackingNumber, trackingURL = "trackingUrl", shippedAt, deliveredAt, updatedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let numericID = try? container.decode(Int64.self, forKey: .id) {
            id = String(numericID)
        } else {
            id = (try? container.decode(String.self, forKey: .id)) ?? UUID().uuidString
        }
        status = (try? container.decode(ShipmentStatus.self, forKey: .status)) ?? .notShipped
        carrier = (try? container.decode(String.self, forKey: .carrier)) ?? "Teslimat"
        trackingNumber = try? container.decodeIfPresent(String.self, forKey: .trackingNumber)
        trackingURL = try? container.decodeIfPresent(String.self, forKey: .trackingURL)
        shippedAt = try? container.decodeIfPresent(Date.self, forKey: .shippedAt)
        deliveredAt = try? container.decodeIfPresent(Date.self, forKey: .deliveredAt)
        updatedAt = (try? container.decode(Date.self, forKey: .updatedAt)) ?? Date()
    }
}
