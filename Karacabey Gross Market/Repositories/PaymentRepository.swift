import Foundation

@MainActor
final class PaymentRepository {
    static let shared = PaymentRepository()
    private let apiClient = APIClient.shared

    private init() {}

    func getPaymentMethods() async throws -> [PaymentMethod] {
        try await apiClient.request(Endpoint.paymentMethods)
    }

    func initPayTR(orderId: String, paymentMethodId: String?, returnURL: String) async throws -> PayTRTokenResponse {
        throw APIError.backend(message: "PayTR ödeme başlatma için sepet, kullanıcı ve adres bilgileriyle JSON payload gönderilmelidir.", code: "paytr_payload_required")
    }

    func startPayTRPayment(_ payload: PayTRPaymentRequest) async throws -> CheckoutSessionResponse {
        try payload.validate()
        PayTRPaymentRequestLogger.log(payload)
        return try await apiClient.request(
            Endpoint.paytrPayment(payload, idempotencyKey: payload.orderId)
        )
    }

    func paymentStatus(id: String) async throws -> PaymentStatusResponse {
        try await apiClient.request(Endpoint.paymentStatus(id: id))
    }

    func cancelPayment(id: String) async throws {
        _ = try await apiClient.request(Endpoint.cancelPayment(id: id)) as EmptyResponse
    }

    func requestRefund(paymentId: String, amountKurus: Int64?, reason: String) async throws {
        let payload = RefundRequestPayload(amountKurus: amountKurus, reason: reason)
        _ = try await apiClient.request(Endpoint.refundRequest(id: paymentId, payload)) as EmptyResponse
    }
}
