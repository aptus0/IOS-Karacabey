import Foundation
import CoreLocation

struct Store: Identifiable, Codable, Hashable {
    let id: String
    var name: String
    var slug: String
    var logoURL: String?
    var coverImageURL: String?
    var phone: String?
    var email: String?
    var taxNumber: String?
    var isActive: Bool
    var createdAt: Date
}

struct Branch: Identifiable, Codable, Hashable {
    let id: String
    var storeId: String
    var name: String
    var address: String
    var city: String
    var district: String
    var postalCode: String?
    var latitude: Double
    var longitude: Double
    var phone: String?
    var isActive: Bool
    var opensAt: String
    var closesAt: String

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

struct DeliveryZone: Identifiable, Codable, Hashable {
    let id: String
    var branchId: String
    var name: String
    var polygonGeoJSON: String
    var minOrderAmount: Double
    var deliveryFee: Double
    var freeDeliveryThreshold: Double?
    var estimatedMinutes: Int
    var isActive: Bool
}

struct DeliveryZoneResolveRequest: Codable {
    let latitude: Double
    let longitude: Double
}

struct DeliveryZoneResolution: Codable, Hashable {
    let isDeliverable: Bool
    let zone: DeliveryZone?
    let minimumCartAmountKurus: Int64?
    let deliveryFeeKurus: Int64?
    let estimatedMinutes: Int?
    let message: String?
}
