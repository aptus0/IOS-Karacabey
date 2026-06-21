import Foundation
import Combine

@MainActor
final class PaymentService: ObservableObject {
    private let repository = PaymentRepository.shared

    func startPayTR(orderId: String, paymentMethodId: String?) async throws -> PayTRTokenResponse {
        try await repository.initPayTR(
            orderId: orderId,
            paymentMethodId: paymentMethodId,
            returnURL: "kgm://payment/callback"
        )
    }

    func startPayTR(payload: PayTRPaymentRequest) async throws -> CheckoutSessionResponse {
        try await repository.startPayTRPayment(payload)
    }
}

@MainActor
final class PaymentStatusPoller: ObservableObject {
    private let repository = PaymentRepository.shared

    func poll(paymentId: String, maxAttempts: Int = 20) async throws -> PaymentStatusResponse {
        var latestResponse: PaymentStatusResponse?
        for attempt in 0..<maxAttempts {
            let response = try await repository.paymentStatus(id: paymentId)
            latestResponse = response
            if response.status.isTerminal {
                return response
            }
            if attempt < maxAttempts - 1 {
                try await Task.sleep(nanoseconds: 2_000_000_000)
            }
        }
        if let latestResponse {
            return latestResponse
        }
        throw APIError.networkError("Ödeme sonucu zamanında alınamadı.")
    }
}

struct PayTRRedirectHandler {
    func result(for url: URL) -> PayTRPaymentResult? {
        if url.scheme == "kgm", url.host == "payment" {
            DeepLinkRouter.shared.open(url.absoluteString)
            return paymentResult(from: url) ?? .success
        }

        guard let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https" else {
            return nil
        }

        let value = url.absoluteString.lowercased()
        if value.contains("/checkout/success") || value.contains("payment/success") {
            return .success
        }
        if value.contains("/checkout/fail") || value.contains("/checkout/failed") || value.contains("payment/fail") {
            return .failure
        }
        return nil
    }

    private func paymentResult(from url: URL) -> PayTRPaymentResult? {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return nil }
        let status = components.queryItems?
            .first(where: { ["status", "result", "state"].contains($0.name.lowercased()) })?
            .value?
            .lowercased()

        switch status {
        case "success", "ok", "paid":
            return .success
        case "fail", "failed", "error", "cancel", "cancelled", "canceled":
            return .failure
        default:
            let value = url.absoluteString.lowercased()
            if value.contains("fail") || value.contains("cancel") { return .failure }
            if value.contains("success") || value.contains("paid") { return .success }
            return nil
        }
    }
}
