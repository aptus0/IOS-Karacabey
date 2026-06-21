import Foundation

struct ActionTokenResponse: Decodable {
    let token: String
    let action: String
    let expiresAt: Int64
    let ttlSeconds: Int
}

@MainActor
final class ActionTokenProvider {
    static let shared = ActionTokenProvider()

    private struct CachedToken {
        let value: String
        let expiresAt: Date
    }

    private var cache: [String: CachedToken] = [:]
    private var inFlight: [String: Task<String, Error>] = [:]
    private let expiryLeeway: TimeInterval = 10

    private init() {}

    func token(for action: String, forceRefresh: Bool = false) async throws -> String {
        if forceRefresh {
            invalidate(action)
        } else if let cached = cache[action],
                  cached.expiresAt.timeIntervalSinceNow > expiryLeeway {
            return cached.value
        }

        if let task = inFlight[action] {
            return try await task.value
        }

        let task = Task<String, Error> { @MainActor in
            let response: ActionTokenResponse = try await APIClient.shared.request(
                Endpoint.actionToken(action: action)
            )
            let expiresAt = Date(timeIntervalSince1970: TimeInterval(response.expiresAt))
            cache[action] = CachedToken(value: response.token, expiresAt: expiresAt)
            return response.token
        }
        inFlight[action] = task

        do {
            let value = try await task.value
            inFlight[action] = nil
            return value
        } catch {
            inFlight[action] = nil
            throw error
        }
    }

    func invalidate(_ action: String) {
        cache[action] = nil
        inFlight[action]?.cancel()
        inFlight[action] = nil
    }
}
