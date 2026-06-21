import Foundation

enum AppEnvironment {
    case development
    case staging
    case production
}

struct EnvironmentConfig {
    static let current: AppEnvironment = .production

    static var apiBaseURL: URL {
        if let value = Bundle.main.object(forInfoDictionaryKey: "KGM_API_BASE_URL") as? String,
           let url = URL(string: value),
           url.scheme == "https" {
            return url
        }

        return fallbackBaseURL
    }

    static var baseURL: String {
        apiBaseURL.absoluteString.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    }

    static var webBaseURL: URL {
        if let value = Bundle.main.object(forInfoDictionaryKey: "KGM_WEB_BASE_URL") as? String,
           let url = URL(string: value),
           url.scheme?.hasPrefix("http") == true {
            return url
        }

        return URL(string: "https://karacabeygrossmarket.com")!
    }

    static var productShareBaseURL: URL {
        if let value = Bundle.main.object(forInfoDictionaryKey: "KGM_PRODUCT_SHARE_BASE_URL") as? String,
           let url = URL(string: value),
           url.scheme?.hasPrefix("http") == true {
            return url
        }

        return webBaseURL.appendingPathComponent("products")
    }

    static var appShareURL: URL {
        if let value = Bundle.main.object(forInfoDictionaryKey: "KGM_APP_SHARE_URL") as? String,
           let url = URL(string: value),
           url.scheme?.hasPrefix("http") == true {
            return url
        }

        return webBaseURL.appendingPathComponent("mobil-app")
    }


    static var supportMailboxURL: URL {
        if let value = Bundle.main.object(forInfoDictionaryKey: "KGM_SUPPORT_MAIL_BASE_URL") as? String,
           let url = URL(string: value),
           url.scheme?.hasPrefix("http") == true {
            return url
        }

        return URL(string: "https://webmail.karacabeygrossmarket.com")!
    }

    static var tlsCertificateSHA256Pins: Set<String> {
        guard let raw = Bundle.main.object(forInfoDictionaryKey: "KGM_TLS_CERT_SHA256_PINS") as? String else { return [] }
        return Set(
            raw
                .split { $0 == "," || $0 == " " || $0 == "\n" || $0 == "\t" }
                .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty && !$0.contains("$(") }
        )
    }

    static var supportMailEndpointURL: URL {
        if let value = Bundle.main.object(forInfoDictionaryKey: "KGM_SUPPORT_MAIL_URL") as? String,
           let url = URL(string: value),
           url.scheme?.hasPrefix("http") == true {
            return url
        }

        return supportMailboxURL.appendingPathComponent("api/support")
    }

    static func resolveMediaURL(_ rawValue: String) -> URL? {
        let value = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return nil }

        if value.hasPrefix("//"), let url = URL(string: "https:" + value) {
            return url
        }

        if let absolute = URL(string: value), absolute.scheme != nil {
            return absolute
        }

        let fragmentSplit = value.split(separator: "#", maxSplits: 1, omittingEmptySubsequences: false)
        let withoutFragment = String(fragmentSplit.first ?? "")
        let fragment = fragmentSplit.count > 1 ? String(fragmentSplit[1]) : nil
        let querySplit = withoutFragment.split(separator: "?", maxSplits: 1, omittingEmptySubsequences: false)
        let pathValue = String(querySplit.first ?? "")
        let query = querySplit.count > 1 ? String(querySplit[1]) : nil

        let normalizedPath = pathValue.hasPrefix("/") ? pathValue : "/\(pathValue)"
        let mediaHost: URL
        if normalizedPath.lowercased().hasPrefix("/api/") {
            mediaHost = apiBaseURL
        } else {
            mediaHost = webBaseURL
        }

        var components = URLComponents(url: mediaHost, resolvingAgainstBaseURL: false)
        components?.path = normalizedPath
        components?.query = query
        components?.fragment = fragment
        return components?.url
    }


    static var googleMapsAPIKey: String? {
        guard let value = Bundle.main.object(forInfoDictionaryKey: "KGM_GOOGLE_MAPS_API_KEY") as? String,
              !value.isEmpty,
              !value.contains("$(") else {
            return nil
        }
        return value
    }

    static var appGroupIdentifier: String {
        Bundle.main.object(forInfoDictionaryKey: "KGM_APP_GROUP_IDENTIFIER") as? String
        ?? "group.com.karacabeygrossmarket.app"
    }

    private static var fallbackBaseURL: URL {
        switch current {
        case .development:
            return URL(string: "https://api.karacabeygrossmarket.com/api/v1")!
        case .staging:
            return URL(string: "https://api.karacabeygrossmarket.com/api/v1")!
        case .production:
            return URL(string: "https://api.karacabeygrossmarket.com/api/v1")!
        }
    }

    static var isDebugLoggingEnabled: Bool {
        #if DEBUG
        true
        #else
        false
        #endif
    }

    nonisolated static let requestTimeout: TimeInterval = 30
    nonisolated static let checkoutRequestTimeout: TimeInterval = 60
    static let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    static let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
}
