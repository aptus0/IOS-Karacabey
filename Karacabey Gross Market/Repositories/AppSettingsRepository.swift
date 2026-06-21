import Foundation

@MainActor
final class AppSettingsRepository {
    static let shared = AppSettingsRepository()
    private let apiClient = APIClient.shared

    private init() {}

    func getSettings() async throws -> AppSettingsBundle {
        try await apiClient.request(Endpoint.appSettings)
    }
}

