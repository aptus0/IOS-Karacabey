import Foundation

enum APIError: LocalizedError {
    case invalidURL
    case noInternetConnection
    case connectionLost
    case requestTimedOut
    case serverUnreachable
    case unauthorized
    case notFound
    case serverError(Int)
    case backend(message: String, code: String?)
    case backendWithCorrelation(message: String, code: String?, correlationID: String?)
    case serverErrorWithCorrelation(statusCode: Int, correlationID: String?)
    case decodingError(String)
    case networkError(String)
    case insecureTransport
    case unsupported
    case unknown

    var errorDescription: String? {
        switch self {
        case .invalidURL:           return "Geçersiz URL."
        case .noInternetConnection: return "İnternet bağlantınızı kontrol edip tekrar deneyin."
        case .connectionLost:       return "Bağlantı kısa süreli kesildi. İşleminizi tekrar deniyoruz."
        case .requestTimedOut:      return "Sunucu yanıtı gecikti. Lütfen birkaç saniye sonra tekrar deneyin."
        case .serverUnreachable:    return "Servise şu an ulaşılamıyor. Lütfen daha sonra tekrar deneyin."
        case .unauthorized:         return "Oturum süreniz doldu. Lütfen tekrar giriş yapın."
        case .notFound:             return "İstenen kaynak bulunamadı."
        case .serverError, .serverErrorWithCorrelation:
            return "Şu anda işleminizi tamamlayamıyoruz. Lütfen biraz sonra tekrar deneyin."
        case .backend(let message, let code): return KGMUserMessage.backendMessage(message, code: code)
        case .backendWithCorrelation(let message, let code, _):
            return KGMUserMessage.backendMessage(message, code: code)
        case .decodingError:
            return "Bilgiler alınırken sorun oluştu. Lütfen tekrar deneyin."
        case .networkError(let message):
            return KGMUserMessage.sanitize(message, fallback: "Bağlantı sırasında sorun oluştu. Lütfen tekrar deneyin.")
        case .insecureTransport:      return "Güvenli bağlantı kurulamadı. Lütfen daha sonra tekrar deneyin."
        case .unsupported:            return "Bu özellik şu an aktif değil."
        case .unknown:                return "Bilinmeyen bir sorun oluştu. Lütfen tekrar deneyin."
        }
    }

    var correlationID: String? {
        switch self {
        case .backendWithCorrelation(_, _, let correlationID):
            return correlationID
        case .serverErrorWithCorrelation(_, let correlationID):
            return correlationID
        default:
            return nil
        }
    }

    var technicalLogDescription: String {
        switch self {
        case .serverError(let statusCode):
            return "server_error status=\(statusCode)"
        case .serverErrorWithCorrelation(let statusCode, let correlationID):
            return "server_error status=\(statusCode) correlation_id=\(correlationID ?? "none")"
        case .backend(let message, let code):
            return "backend_error code=\(code ?? "none") message=\(message)"
        case .backendWithCorrelation(let message, let code, let correlationID):
            return "backend_error code=\(code ?? "none") correlation_id=\(correlationID ?? "none") message=\(message)"
        case .decodingError(let message):
            return "decoding_error message=\(message)"
        case .networkError(let message):
            return "network_error message=\(message)"
        default:
            return String(describing: self)
        }
    }

    static func from(_ error: URLError) -> APIError {
        switch error.code {
        case .notConnectedToInternet:
            return .noInternetConnection
        case .networkConnectionLost:
            return .connectionLost
        case .timedOut:
            return .requestTimedOut
        case .cannotFindHost, .cannotConnectToHost, .dnsLookupFailed:
            return .serverUnreachable
        default:
            return .networkError(error.localizedDescription)
        }
    }
}
