import Foundation
import UIKit

/// Mobil cihazı backend tarafındaki `mobile_devices` tablosuna kaydeder ve
/// `mobile_events` akışına telemetri olayları (app_open, screen_view, security vb.) gönderir.
/// Faz 3 ile offline kuyruk eklendi: internet yoksa event kaybolmaz, sonraki açılışta gönderilir.
@MainActor
final class MobileTelemetryService {
    static let shared = MobileTelemetryService()

    private let apiClient = APIClient.shared
    private let pendingEventsKey = "kgm.mobile.telemetry.pending.events.v1"
    private let maxPendingEvents = 120
    private var registered = false
    private var sessionID = UUID().uuidString
    private var pendingPushToken: String?
    private var lastRegisteredAt: Date?
    private var isFlushing = false

    private init() {}

    func registerOnLaunch() async {
        await register(reason: "launch")
        await track(eventName: "app_open", screen: "launch", payload: ["session": sessionID])
        await flushPendingEvents()
    }

    func registerOnForeground() async {
        if let last = lastRegisteredAt, Date().timeIntervalSince(last) < 30 {
            await track(eventName: "app_foreground", screen: "scene", payload: ["session": sessionID])
            await flushPendingEvents()
            return
        }
        await register(reason: "foreground")
        await track(eventName: "app_foreground", screen: "scene", payload: ["session": sessionID])
        await flushPendingEvents()
    }

    func updatePushToken(_ token: String) async {
        pendingPushToken = token
        await register(reason: "push_token_update")
    }

    func track(eventName: String, screen: String? = nil, payload: [String: Any]? = nil) async {
        let request = makeEventRequest(eventName: eventName, screen: screen, payload: payload)
        do {
            try await send(request)
        } catch {
            enqueue(request)
            #if DEBUG
            print("[MobileTelemetry] event '\(eventName)' kuyruğa alındı: \(error)")
            #endif
        }
    }

    private func register(reason: String) async {
        let request = MobileDeviceRegisterRequest(
            deviceId: DeviceInfo.current.identifier,
            platform: "ios",
            appVersion: EnvironmentConfig.appVersion,
            osVersion: DeviceInfo.current.osVersion,
            deviceModel: DeviceInfo.current.model,
            pushToken: pendingPushToken ?? "",
            locale: Locale.current.identifier,
            timezone: TimeZone.current.identifier
        )
        do {
            _ = try await apiClient.request(Endpoint.mobileDeviceRegister(request)) as EmptyResponse
            registered = true
            lastRegisteredAt = Date()
            #if DEBUG
            print("[MobileTelemetry] cihaz kayıt edildi (reason=\(reason), device_id=\(DeviceInfo.current.identifier))")
            #endif
        } catch {
            #if DEBUG
            print("[MobileTelemetry] cihaz kaydı başarısız (reason=\(reason)): \(error)")
            #endif
        }
    }

    private func makeEventRequest(eventName: String, screen: String?, payload: [String: Any]?) -> MobileEventRequest {
        MobileEventRequest(
            deviceId: DeviceInfo.current.identifier,
            sessionId: sessionID,
            eventName: eventName,
            screen: screen ?? "",
            appVersion: EnvironmentConfig.appVersion,
            platform: "ios",
            payload: payload?.compactMapValues(Self.encodableValue),
            occurredAt: Date()
        )
    }

    private func send(_ request: MobileEventRequest) async throws {
        _ = try await apiClient.request(Endpoint.mobileEvent(request)) as EmptyResponse
    }

    private func flushPendingEvents() async {
        guard !isFlushing else { return }
        isFlushing = true
        defer { isFlushing = false }

        var queue = loadPendingEvents()
        guard !queue.isEmpty else { return }

        var remaining: [MobileEventRequest] = []
        for event in queue {
            do {
                try await send(event)
            } catch {
                remaining.append(event)
            }
        }
        savePendingEvents(remaining)
    }

    private func enqueue(_ event: MobileEventRequest) {
        var queue = loadPendingEvents()
        queue.append(event)
        if queue.count > maxPendingEvents {
            queue = Array(queue.suffix(maxPendingEvents))
        }
        savePendingEvents(queue)
    }

    private func loadPendingEvents() -> [MobileEventRequest] {
        guard let data = UserDefaults.standard.data(forKey: pendingEventsKey) else { return [] }
        return (try? JSONDecoder.kgm.decode([MobileEventRequest].self, from: data)) ?? []
    }

    private func savePendingEvents(_ events: [MobileEventRequest]) {
        guard !events.isEmpty else {
            UserDefaults.standard.removeObject(forKey: pendingEventsKey)
            return
        }
        guard let data = try? JSONEncoder.kgm.encode(events) else { return }
        UserDefaults.standard.set(data, forKey: pendingEventsKey)
    }

    private static func encodableValue(_ value: Any) -> AnyCodableValue? {
        switch value {
        case let v as String: return .string(v)
        case let v as Bool: return .bool(v)
        case let v as Int: return .int(v)
        case let v as Double: return .double(v)
        case let v as Float: return .double(Double(v))
        default:
            if let value = value as? CustomStringConvertible {
                return .string(value.description)
            }
            return nil
        }
    }
}
