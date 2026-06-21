import Foundation

@MainActor
final class APIClient {
    static let shared = APIClient()
    private let session: URLSession
    private let requestBuilder = RequestBuilder()
    private let actionTokenProvider = ActionTokenProvider.shared
    private let securityDelegate = PinnedCertificatesURLSessionDelegate()
    private var refreshTask: Task<AuthSessionResponse, Error>?

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = EnvironmentConfig.requestTimeout
        config.timeoutIntervalForResource = EnvironmentConfig.checkoutRequestTimeout
        config.waitsForConnectivity = true
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        session = URLSession(configuration: config, delegate: securityDelegate, delegateQueue: nil)
    }

    func request<T: Decodable>(_ endpoint: APIEndpoint) async throws -> T {
        let timeout = requestTimeout(for: endpoint)
        let maxAttempts = shouldRetryOnce(endpoint) || endpoint.requiredAction != nil ? 2 : 1
        var lastError: Error?
        var actionToken: String?

        if let action = endpoint.requiredAction {
            actionToken = try await actionTokenProvider.token(for: action)
        }

        if endpoint.requiresAuth, !isRefreshEndpoint(endpoint), KeychainManager.shared.shouldRefreshAccessToken() {
            _ = try? await refreshSessionIfNeeded(force: false)
        }

        for attempt in 1...maxAttempts {
            do {
                var request = try requestBuilder.build(endpoint: endpoint)
                request.timeoutInterval = timeout
                if let actionToken {
                    request.setValue(actionToken, forHTTPHeaderField: "X-Action-Token")
                }

                let (data, response) = try await perform(request: request, timeout: timeout)
                if let action = endpoint.requiredAction,
                   attempt < maxAttempts,
                   isActionTokenRejected(response) {
                    actionTokenProvider.invalidate(action)
                    actionToken = try await actionTokenProvider.token(for: action, forceRefresh: true)
                    continue
                }
                return try handleResponse(data: data, response: response)
            } catch {
                if shouldRefreshAndRetry(error, endpoint: endpoint, attempt: attempt) {
                    do {
                        _ = try await refreshSessionIfNeeded(force: true)
                        continue
                    } catch {
                        KeychainManager.shared.clearAuthSession()
                        CrashReporter.recordAPIError(error, method: endpoint.method, path: endpoint.path)
                        throw APIError.unauthorized
                    }
                }

                lastError = error
                guard attempt < maxAttempts, shouldRetry(error) else {
                    CrashReporter.recordAPIError(error, method: endpoint.method, path: endpoint.path)
                    throw error
                }
                try? await Task.sleep(nanoseconds: 600_000_000)
            }
        }

        throw lastError ?? APIError.unknown
    }

    private func shouldRefreshAndRetry(_ error: Error, endpoint: APIEndpoint, attempt: Int) -> Bool {
        guard attempt == 1, endpoint.requiresAuth, !isRefreshEndpoint(endpoint) else { return false }
        if case APIError.unauthorized = error { return KeychainManager.shared.getRefreshToken() != nil }
        return false
    }

    private func isRefreshEndpoint(_ endpoint: APIEndpoint) -> Bool {
        endpoint.path == Endpoint.refreshToken("").path
    }

    private func refreshSessionIfNeeded(force: Bool) async throws -> AuthSessionResponse {
        if !force, !KeychainManager.shared.shouldRefreshAccessToken() {
            throw APIError.unknown
        }

        if let existing = refreshTask {
            return try await existing.value
        }

        let task = Task<AuthSessionResponse, Error> {
            guard let refreshToken = KeychainManager.shared.getRefreshToken(), !refreshToken.isEmpty else {
                throw APIError.unauthorized
            }
            var request = try requestBuilder.build(endpoint: Endpoint.refreshToken(refreshToken))
            request.timeoutInterval = EnvironmentConfig.requestTimeout
            let (data, response) = try await perform(request: request, timeout: EnvironmentConfig.requestTimeout)
            let session: AuthSessionResponse = try handleResponse(data: data, response: response)
            KeychainManager.shared.saveAuthSession(token: session.token, refreshToken: session.refreshToken, expiresAt: session.expiresAt)
            await MobileTelemetryService.shared.track(eventName: "auth_token_refreshed", screen: "security")
            return session
        }
        refreshTask = task
        defer { refreshTask = nil }
        return try await task.value
    }

    private func isActionTokenRejected(_ response: URLResponse) -> Bool {
        guard let response = response as? HTTPURLResponse,
              response.statusCode == 403,
              let status = response.value(forHTTPHeaderField: "X-Action-Token-Status")?.lowercased()
        else {
            return false
        }
        return status == "missing" || status == "invalid"
    }

    private func perform(request: URLRequest, timeout: TimeInterval) async throws -> (Data, URLResponse) {
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await withTimeout(seconds: timeout) {
                try await self.session.data(for: request)
            }
        } catch let apiError as APIError {
            throw apiError
        } catch let urlError as URLError {
            throw APIError.from(urlError)
        } catch {
            throw APIError.networkError(error.localizedDescription)
        }

        return (data, response)
    }

    private func handleResponse<T: Decodable>(data: Data, response: URLResponse) throws -> T {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.unknown
        }
        let correlationID = correlationID(from: httpResponse)

        switch httpResponse.statusCode {
        case 200...299:
            persistCartTokenIfPresent(in: data, response: httpResponse)
            return try decode(T.self, from: data)
        case 401: throw APIError.unauthorized
        case 404: throw APIError.notFound
        default:
            if T.self == CheckoutSessionResponse.self,
               let paymentResponse = try? decodePaymentFailure(from: data) {
                return paymentResponse as! T
            }
            if let errorResponse = try? JSONDecoder.kgm.decode(APIResponse<EmptyResponse>.self, from: data),
               let message = errorResponse.message {
                throw APIError.backendWithCorrelation(message: message, code: errorResponse.code, correlationID: correlationID)
            }
            throw APIError.serverErrorWithCorrelation(statusCode: httpResponse.statusCode, correlationID: correlationID)
        }
    }

    private func correlationID(from response: HTTPURLResponse) -> String? {
        [
            "X-Correlation-ID",
            "X-Request-ID",
            "X-Trace-ID",
            "CF-Ray"
        ]
            .lazy
            .compactMap { response.value(forHTTPHeaderField: $0)?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { !$0.isEmpty }
    }

    private func requestTimeout(for endpoint: APIEndpoint) -> TimeInterval {
        endpoint.path == "/c" ? EnvironmentConfig.checkoutRequestTimeout : EnvironmentConfig.requestTimeout
    }

    private func shouldRetryOnce(_ endpoint: APIEndpoint) -> Bool {
        endpoint.method == .post && endpoint.path == "/c" && endpoint.idempotencyKey != nil
    }

    private func shouldRetry(_ error: Error) -> Bool {
        switch error {
        case APIError.connectionLost, APIError.requestTimedOut, APIError.serverUnreachable:
            return true
        default:
            return false
        }
    }

    private func persistCartTokenIfPresent(in data: Data, response: HTTPURLResponse) {
        if let headerToken = response.value(forHTTPHeaderField: "X-Cart-Token"),
           !headerToken.isEmpty {
            KeychainManager.shared.saveCartToken(headerToken)
            return
        }

        guard
            !data.isEmpty,
            let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            return
        }

        if let token = object["cart_token"] as? String, !token.isEmpty {
            KeychainManager.shared.saveCartToken(token)
            return
        }

        if let dataObject = object["data"] as? [String: Any],
           let token = dataObject["cart_token"] as? String,
           !token.isEmpty {
            KeychainManager.shared.saveCartToken(token)
        }
    }

    private func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        if T.self == EmptyResponse.self, data.isEmpty {
            return EmptyResponse() as! T
        }

        do {
            if let wrappedValue = try decodeWrapped(T.self, from: data) {
                return wrappedValue
            }
        } catch {
            // Fall through to direct decoding so non-envelope responses keep working.
        }

        do {
            return try JSONDecoder.kgm.decode(T.self, from: data)
        } catch {
            let message = EnvironmentConfig.isDebugLoggingEnabled ? error.localizedDescription : "Yanıt beklenen formatta değil."
            throw APIError.decodingError(message)
        }
    }

    private func decodeWrapped<T: Decodable>(_ type: T.Type, from data: Data) throws -> T? {
        guard responseHasDataEnvelope(data) else { return nil }
        let wrapped = try JSONDecoder.kgm.decode(APIResponse<T>.self, from: data)
        return wrapped.data
    }

    private func decodePaymentFailure(from data: Data) throws -> CheckoutSessionResponse {
        if let wrapped = try? JSONDecoder.kgm.decode(APIResponse<CheckoutSessionResponse>.self, from: data),
           let session = wrapped.data {
            return session
        }
        return try JSONDecoder.kgm.decode(CheckoutSessionResponse.self, from: data)
    }

    private func responseHasDataEnvelope(_ data: Data) -> Bool {
        guard
            !data.isEmpty,
            let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            return false
        }

        return object.keys.contains("data")
    }

    private func withTimeout<T>(
        seconds: TimeInterval,
        operation: @escaping () async throws -> T
    ) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask {
                try await operation()
            }
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                throw APIError.requestTimedOut
            }

            guard let result = try await group.next() else {
                throw APIError.unknown
            }

            group.cancelAll()
            return result
        }
    }
}

nonisolated extension JSONDecoder {
    static let kgm: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
}
