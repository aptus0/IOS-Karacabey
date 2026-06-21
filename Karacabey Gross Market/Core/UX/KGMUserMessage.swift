import Foundation

enum KGMUserMessage {
    static func displayMessage(for error: Error) -> String {
        if let apiError = error as? APIError {
            return apiError.userFacingMessage
        }

        let nsError = error as NSError
        if nsError.domain == NSURLErrorDomain {
            return displayMessage(for: URLError(_nsError: nsError))
        }

        let raw = error.localizedDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        return sanitize(raw, fallback: "İşleminiz tamamlanamadı. Lütfen tekrar deneyin.")
    }

    static func displayMessage(for urlError: URLError) -> String {
        switch urlError.code {
        case .notConnectedToInternet:
            return "İnternet bağlantınızı kontrol edip tekrar deneyin."
        case .networkConnectionLost:
            return "Bağlantı kısa süreli kesildi. İşleminizi tekrar deniyoruz."
        case .timedOut:
            return "Sunucu yanıtı gecikti. Lütfen birkaç saniye sonra tekrar deneyin."
        case .cannotFindHost, .cannotConnectToHost, .dnsLookupFailed:
            return "Servise şu an ulaşılamıyor. Lütfen daha sonra tekrar deneyin."
        default:
            return "Bağlantı sırasında sorun oluştu. Lütfen tekrar deneyin."
        }
    }

    static func backendMessage(_ message: String, code: String?) -> String {
        let normalizedCode = code?.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let normalizedMessage = message.lowercased()

        if normalizedCode.contains("stock") || normalizedMessage.contains("stok") || normalizedMessage.contains("stock") {
            return "Bu üründen yeterli stok bulunmuyor. Lütfen adet bilgisini kontrol edin."
        }
        if normalizedCode.contains("cart") || normalizedMessage.contains("sepet") || normalizedMessage.contains("cart") {
            return "Sepetiniz güncellenemedi. Lütfen bağlantınızı kontrol edip tekrar deneyin."
        }
        if normalizedCode.contains("auth") || normalizedCode.contains("token") || normalizedMessage.contains("unauthorized") || normalizedMessage.contains("token") || normalizedMessage.contains("jwt") {
            return "Oturum süreniz doldu. Lütfen tekrar giriş yapın."
        }
        if normalizedCode.contains("payment") || normalizedMessage.contains("payment") || normalizedMessage.contains("paytr") || normalizedMessage.contains("ödeme") {
            return "Ödeme işlemi tamamlanamadı. Lütfen bilgileri kontrol edip tekrar deneyin."
        }
        if normalizedCode.contains("validation") || normalizedMessage.contains("validation") || normalizedMessage.contains("geçersiz") {
            return "Bilgiler eksik veya hatalı. Lütfen kontrol edip tekrar deneyin."
        }
        if normalizedCode.contains("rate") || normalizedMessage.contains("too many") || normalizedMessage.contains("rate limit") {
            return "Çok hızlı işlem yapıldı. Lütfen birkaç saniye bekleyip tekrar deneyin."
        }
        if normalizedCode.contains("server") || normalizedCode.contains("internal") {
            return "Şu anda işleminizi tamamlayamıyoruz. Lütfen biraz sonra tekrar deneyin."
        }

        return sanitize(message, fallback: "İşleminiz tamamlanamadı. Lütfen bilgileri kontrol edip tekrar deneyin.")
    }

    static func sanitize(_ rawMessage: String, fallback: String) -> String {
        let message = rawMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !message.isEmpty else { return fallback }

        let lower = message.lowercased()
        let technicalSignals = [
            "sql", "exception", "stack", "trace", "jwt", "token", "bearer", "forbidden", "unauthorized",
            "500", "502", "503", "504", "403", "404", "http", "json", "decode", "nil", "null", "panic",
            "mysql", "redis", "cloudflare", "cf-ray", "correlation", "timeout", "timed out", "nsurl", "domain="
        ]

        if technicalSignals.contains(where: { lower.contains($0) }) || message.contains("{") || message.contains("}") || message.count > 160 {
            return fallback
        }

        return message
    }
}

extension Error {
    var kgmUserMessage: String {
        KGMUserMessage.displayMessage(for: self)
    }
}

extension APIError {
    var userFacingMessage: String {
        switch self {
        case .invalidURL:
            return "Servis adresi hazırlanamadı. Lütfen uygulamayı tekrar açın."
        case .noInternetConnection:
            return "İnternet bağlantınızı kontrol edip tekrar deneyin."
        case .connectionLost:
            return "Bağlantı kısa süreli kesildi. İşleminizi tekrar deniyoruz."
        case .requestTimedOut:
            return "Sunucu yanıtı gecikti. Lütfen birkaç saniye sonra tekrar deneyin."
        case .serverUnreachable:
            return "Servise şu an ulaşılamıyor. Lütfen daha sonra tekrar deneyin."
        case .unauthorized:
            return "Oturum süreniz doldu. Lütfen tekrar giriş yapın."
        case .notFound:
            return "Aradığınız kayıt bulunamadı."
        case .serverError, .serverErrorWithCorrelation:
            return "Şu anda işleminizi tamamlayamıyoruz. Lütfen biraz sonra tekrar deneyin."
        case .backend(let message, let code):
            return KGMUserMessage.backendMessage(message, code: code)
        case .backendWithCorrelation(let message, let code, _):
            return KGMUserMessage.backendMessage(message, code: code)
        case .decodingError:
            return "Bilgiler alınırken sorun oluştu. Lütfen tekrar deneyin."
        case .networkError(let message):
            return KGMUserMessage.sanitize(message, fallback: "Bağlantı sırasında sorun oluştu. Lütfen tekrar deneyin.")
        case .insecureTransport:
            return "Güvenli bağlantı kurulamadı. Lütfen daha sonra tekrar deneyin."
        case .unsupported:
            return "Bu özellik şu an aktif değil."
        case .unknown:
            return "Bilinmeyen bir sorun oluştu. Lütfen tekrar deneyin."
        }
    }
}
