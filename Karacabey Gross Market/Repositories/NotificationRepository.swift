import Foundation

enum NotificationListStatus: String {
    case unread
    case read
    case all
}

struct NotificationListMeta: Decodable {
    let unreadCount: Int
}

struct NotificationListResponse: Decodable {
    let data: [NotificationItem]
    let meta: NotificationListMeta?
}

@MainActor
final class NotificationRepository {
    static let shared = NotificationRepository()
    private let apiClient = APIClient.shared

    private init() {}

    func registerDeviceToken(_ request: DeviceTokenRegistrationRequest) async throws {
        _ = try await apiClient.request(Endpoint.registerDeviceToken(request)) as EmptyResponse
    }

    func deleteDeviceToken(id: String) async throws {
        _ = try await apiClient.request(Endpoint.deleteDeviceToken(id: id)) as EmptyResponse
    }

    func getNotifications(status: NotificationListStatus = .unread, page: Int = 1, limit: Int = 30) async throws -> [NotificationItem] {
        try await getNotificationList(status: status, page: page, limit: limit).data
    }

    func getNotificationList(status: NotificationListStatus = .unread, page: Int = 1, limit: Int = 30) async throws -> NotificationListResponse {
        let safePage = max(page, 1)
        let safeLimit = min(max(limit, 1), 100)
        return try await apiClient.request(
            Endpoint.notifications(status: status.rawValue, page: safePage, limit: safeLimit)
        )
    }

    func unreadCount() async throws -> Int {
        let response = try await getNotificationList(status: .unread, page: 1, limit: 1)

        return response.meta?.unreadCount ?? response.data.filter { !$0.isRead }.count
    }

    func markRead(id: String) async throws {
        _ = try await apiClient.request(Endpoint.markNotificationRead(id: id)) as EmptyResponse
    }

    func markAllRead() async throws {
        _ = try await apiClient.request(Endpoint.markAllNotificationsRead) as EmptyResponse
    }

    func delete(id: String) async throws {
        _ = try await apiClient.request(Endpoint.deleteNotification(id: id)) as EmptyResponse
    }
}
