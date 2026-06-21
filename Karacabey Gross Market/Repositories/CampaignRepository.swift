import Foundation

@MainActor
final class CampaignRepository {
    static let shared = CampaignRepository()
    private let apiClient = APIClient.shared

    private init() {}

    func getCampaigns() async throws -> [Campaign] {
        try await apiClient.request(Endpoint.campaigns)
    }

    func getHomepageBanners() async throws -> [BannerItem] {
        let content: HomepageContent = try await apiClient.request(Endpoint.home)
        return content.blocks
    }

    func getStories() async throws -> [Story] {
        try await apiClient.request(Endpoint.stories)
    }
}
