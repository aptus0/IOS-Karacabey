import Foundation

struct RequestBuilder {
    private let authInterceptor = AuthInterceptor()
    private let encoder: JSONEncoder

    init(encoder: JSONEncoder = .kgm) {
        self.encoder = encoder
    }

    func build(endpoint: APIEndpoint) throws -> URLRequest {
        if endpoint.path.hasPrefix("__unsupported__") {
            throw APIError.unsupported
        }

        guard var components = URLComponents(url: EnvironmentConfig.apiBaseURL, resolvingAgainstBaseURL: false) else {
            throw APIError.invalidURL
        }

        components.path = normalizedPath(basePath: components.path, endpointPath: endpoint.path)
        components.queryItems = endpoint.queryItems

        guard let url = components.url else { throw APIError.invalidURL }
        guard url.scheme == "https" else { throw APIError.insecureTransport }

        var request = URLRequest(url: url)
        request.httpMethod = endpoint.method.rawValue
        request.timeoutInterval = EnvironmentConfig.requestTimeout
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(EnvironmentConfig.appVersion, forHTTPHeaderField: "X-App-Version")
        request.setValue(EnvironmentConfig.buildNumber, forHTTPHeaderField: "X-Build-Number")
        request.setValue("ios", forHTTPHeaderField: "X-Platform")

        if let idempotencyKey = endpoint.idempotencyKey {
            request.setValue(idempotencyKey, forHTTPHeaderField: "Idempotency-Key")
        }

        if let body = endpoint.body {
            let bodyEncoder = (endpoint as? APIBodyEncodingStrategy)?.bodyEncoder ?? encoder
            request.httpBody = try bodyEncoder.encode(AnyEncodable(body))
        }

        try authInterceptor.adapt(&request, requiresAuth: endpoint.requiresAuth)
        return request
    }

    private func normalizedPath(basePath: String, endpointPath: String) -> String {
        let cleanedBase = basePath.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let cleanedEndpoint = endpointPath.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        return "/" + [cleanedBase, cleanedEndpoint].filter { !$0.isEmpty }.joined(separator: "/")
    }
}

protocol APIBodyEncodingStrategy {
    var bodyEncoder: JSONEncoder { get }
}

struct AnyEncodable: Encodable {
    private let encodeClosure: (Encoder) throws -> Void

    init(_ value: Encodable) {
        encodeClosure = value.encode
    }

    func encode(to encoder: Encoder) throws {
        try encodeClosure(encoder)
    }
}

extension JSONEncoder {
    static let kgm: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()

    static var paytr: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }
}
