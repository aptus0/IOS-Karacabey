import CoreLocation
import Foundation

@MainActor
final class DeliveryZoneResolver {
    static let shared = DeliveryZoneResolver()
    private let apiClient = APIClient.shared

    private init() {}

    func resolve(location: CLLocationCoordinate2D) async throws -> DeliveryZoneResolution {
        let request = DeliveryZoneResolveRequest(latitude: location.latitude, longitude: location.longitude)
        return try await apiClient.request(Endpoint.resolveDeliveryZone(request))
    }

    func nearbyBranches(latitude: Double, longitude: Double) async throws -> [Branch] {
        try await apiClient.request(Endpoint.nearbyBranches(latitude: latitude, longitude: longitude))
    }
}
