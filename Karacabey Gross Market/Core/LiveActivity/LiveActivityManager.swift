import ActivityKit
import Foundation

struct LiveActivityTokenRequest: Encodable {
    let deviceId: String
    let fcmToken: String
    let token: String
    let kind: String
    let orderId: String?
    let isActive: Bool

    enum CodingKeys: String, CodingKey {
        case deviceId, fcmToken, token, kind, orderId, isActive
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(deviceId, forKey: .deviceId)
        try container.encode(fcmToken, forKey: .fcmToken)
        try container.encode(token, forKey: .token)
        try container.encode(kind, forKey: .kind)
        if let orderId, let numericID = Int64(orderId) {
            try container.encode(numericID, forKey: .orderId)
        }
        try container.encode(isActive, forKey: .isActive)
    }
}

@MainActor
final class LiveActivityManager {
    static let shared = LiveActivityManager()

    private var pushToStartObserver: Task<Void, Never>?
    private var activityObservers: [String: Task<Void, Never>] = [:]

    private init() {}

    func startObservingPushToStartTokens() {
        guard pushToStartObserver == nil else { return }
        Task { await registerCurrentPushToStartToken() }
        pushToStartObserver = Task {
            for await tokenData in Activity<OrderActivityAttributes>.pushToStartTokenUpdates {
                guard !Task.isCancelled else { return }
                await register(tokenData: tokenData, kind: "push_to_start", orderID: nil)
            }
        }
    }

    func registerCurrentPushToStartToken() async {
        guard let tokenData = Activity<OrderActivityAttributes>.pushToStartToken else { return }
        await register(tokenData: tokenData, kind: "push_to_start", orderID: nil)
    }

    func start(orderID: String, orderNumber: String) async {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        if let existing = Activity<OrderActivityAttributes>.activities.first(where: { $0.attributes.orderId == orderID }) {
            observe(existing)
            return
        }

        let attributes = OrderActivityAttributes(
            orderId: orderID,
            orderNumber: orderNumber,
            deepLink: "kgm://orders/\(orderID)"
        )
        let state = OrderActivityAttributes.ContentState(
            status: "reviewing",
            statusLabel: "Kontrol Ediliyor",
            progress: 0.2,
            updatedAt: Int(Date().timeIntervalSince1970)
        )

        do {
            let activity = try Activity.request(
                attributes: attributes,
                content: ActivityContent(state: state, staleDate: nil),
                pushType: .token
            )
            observe(activity)
        } catch {
            #if DEBUG
            print("[LiveActivity] Başlatılamadı: \(error)")
            #endif
        }
    }

    func reconcile(orders: [Order]) async {
        for activity in Activity<OrderActivityAttributes>.activities {
            guard let order = orders.first(where: { $0.id == activity.attributes.orderId }) else {
                observe(activity)
                continue
            }
            let state = contentState(for: order)
            if order.status == .delivered || order.status == .cancelled {
                await activity.end(
                    ActivityContent(state: state, staleDate: nil),
                    dismissalPolicy: .after(Date().addingTimeInterval(30 * 60))
                )
            } else {
                await activity.update(ActivityContent(state: state, staleDate: nil))
                observe(activity)
            }
        }
    }

    private func observe(_ activity: Activity<OrderActivityAttributes>) {
        guard activityObservers[activity.id] == nil else { return }
        activityObservers[activity.id] = Task {
            for await tokenData in activity.pushTokenUpdates {
                guard !Task.isCancelled else { return }
                await register(tokenData: tokenData, kind: "activity", orderID: activity.attributes.orderId)
            }
        }
    }

    private func register(tokenData: Data, kind: String, orderID: String?) async {
        guard let fcmToken = await DeviceTokenService.shared.currentFCMToken() else { return }
        let request = LiveActivityTokenRequest(
            deviceId: DeviceInfo.current.identifier,
            fcmToken: fcmToken,
            token: tokenData.map { String(format: "%02x", $0) }.joined(),
            kind: kind,
            orderId: orderID,
            isActive: true
        )
        do {
            _ = try await APIClient.shared.request(Endpoint.liveActivityToken(request)) as EmptyResponse
        } catch {
            #if DEBUG
            print("[LiveActivity] Token kaydı başarısız: \(error)")
            #endif
        }
    }

    private func contentState(for order: Order) -> OrderActivityAttributes.ContentState {
        OrderActivityAttributes.ContentState(
            status: order.status.rawValue.lowercased(),
            statusLabel: order.status.displayName,
            progress: progress(for: order.status),
            updatedAt: Int(Date().timeIntervalSince1970)
        )
    }

    private func progress(for status: OrderStatus) -> Double {
        switch status {
        case .pending, .awaitingPayment, .reviewing, .received: return 0.2
        case .preparing: return 0.5
        case .onTheWay: return 0.8
        case .delivered: return 1.0
        case .cancelled: return 0.0
        }
    }
}
