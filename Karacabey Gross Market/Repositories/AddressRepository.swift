import Foundation

@MainActor
final class AddressRepository {
    static let shared = AddressRepository()
    private let apiClient = APIClient.shared

    private init() {}

    func getAddresses() async throws -> [Address] {
        try await apiClient.request(Endpoint.getAddresses)
    }

    func addAddress(_ address: Address) async throws -> Address {
        try await apiClient.request(Endpoint.addAddress(address))
    }

    func updateAddress(_ address: Address) async throws -> Address {
        try await apiClient.request(Endpoint.updateAddress(id: address.id, address))
    }

    func deleteAddress(id: String) async throws {
        _ = try await apiClient.request(Endpoint.deleteAddress(id: id)) as EmptyResponse
    }

    func setDefaultAddress(id: String) async throws {
        _ = try await apiClient.request(Endpoint.setDefaultAddress(id: id)) as EmptyResponse
    }
}
