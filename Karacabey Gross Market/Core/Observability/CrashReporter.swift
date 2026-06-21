import Foundation

#if canImport(FirebaseCrashlytics)
import FirebaseCrashlytics
#endif

enum CrashReporter {
    static func configure() {
        #if canImport(FirebaseCrashlytics)
        guard AppDelegate.isFirebaseConfigured else { return }
        #if DEBUG
        Crashlytics.crashlytics().setCrashlyticsCollectionEnabled(false)
        #else
        Crashlytics.crashlytics().setCrashlyticsCollectionEnabled(true)
        #endif
        Crashlytics.crashlytics().setCustomValue(EnvironmentConfig.appVersion, forKey: "app_version")
        Crashlytics.crashlytics().setCustomValue(EnvironmentConfig.buildNumber, forKey: "build_number")
        #endif
    }

    static func recordAPIError(_ error: Error, method: HTTPMethod, path: String) {
        guard shouldReport(error) else { return }
        var metadata = [
            "http_method": method.rawValue,
            "endpoint": sanitizedEndpoint(path)
        ]
        if let apiError = error as? APIError {
            metadata["api_error"] = apiError.technicalLogDescription
            if let correlationID = apiError.correlationID {
                metadata["correlation_id"] = correlationID
            }
        }
        record(
            error,
            context: "api_request",
            metadata: metadata
        )
    }

    static func record(_ error: Error, context: String, metadata: [String: String] = [:]) {
        #if canImport(FirebaseCrashlytics)
        guard AppDelegate.isFirebaseConfigured else { return }
        let crashlytics = Crashlytics.crashlytics()
        crashlytics.setCustomValue(context, forKey: "error_context")
        for (key, value) in metadata {
            crashlytics.setCustomValue(value, forKey: key)
        }
        crashlytics.record(error: sanitizedNSError(from: error))
        #endif
    }

    private static func shouldReport(_ error: Error) -> Bool {
        switch error {
        case APIError.serverError, APIError.serverErrorWithCorrelation, APIError.backendWithCorrelation, APIError.decodingError, APIError.unknown:
            return true
        default:
            return false
        }
    }

    static func sanitizedEndpoint(_ path: String) -> String {
        path
            .split(separator: "/")
            .map { component in
                component.allSatisfy(\.isNumber) ? "{id}" : String(component)
            }
            .joined(separator: "/")
    }

    private static func sanitizedNSError(from error: Error) -> NSError {
        let code: Int
        switch error {
        case APIError.serverError(let statusCode):
            code = statusCode
        case APIError.serverErrorWithCorrelation(let statusCode, _):
            code = statusCode
        case APIError.backendWithCorrelation:
            code = 1002
        case APIError.decodingError:
            code = 1001
        default:
            code = 1000
        }
        return NSError(
            domain: "com.karacabeygrossmarket.mobile",
            code: code,
            userInfo: [NSLocalizedDescriptionKey: String(describing: type(of: error))]
        )
    }
}
