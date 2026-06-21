import Foundation

@MainActor
final class OrderRepository {
    static let shared = OrderRepository()
    private let apiClient = APIClient.shared
    private init() {}

    func getOrders() async throws -> [Order] {
        try await apiClient.request(Endpoint.getOrders)
    }

    func getOrder(id: String) async throws -> Order {
        try await apiClient.request(Endpoint.getOrderDetail(id: id))
    }

    func cancelOrder(id: String) async throws {
        _ = try await apiClient.request(Endpoint.cancelOrder(id: id)) as EmptyResponse
    }

    func reorder(id: String) async throws -> ReorderResponse {
        try await apiClient.request(Endpoint.reorder(id: id))
    }

    func createCheckoutSession(
        cart: Cart,
        address: Address,
        user: User?,
        couponCode: String?,
        paymentFlow: String = "iframe"
    ) async throws -> CheckoutSessionResponse {
        guard !cart.items.isEmpty else {
            throw APIError.backend(message: "Sepetiniz boş. Siparişe devam etmek için ürün ekleyin.", code: nil)
        }

        let checkoutKey = "ios-checkout-\(UUID().uuidString)"
        let paymentUID = "ios-payment-\(UUID().uuidString)"
        let email = user?.email?.trimmingCharacters(in: .whitespacesAndNewlines)
        let phone = address.phone.isEmpty ? (user?.phone ?? "") : address.phone
        let checkoutItems = cart.items.compactMap { item -> CheckoutItemPayload? in
            guard let productId = Int64(item.product.id), item.quantity > 0 else { return nil }
            return CheckoutItemPayload(productId: productId, quantity: item.quantity)
        }

        guard checkoutItems.count == cart.items.count else {
            throw APIError.backend(message: "Sepetteki bazı ürünler doğrulanamadı. Lütfen sepetinizi yenileyip tekrar deneyin.", code: nil)
        }

        let request = PlaceOrderRequest(
            source: "ios",
            customer: CheckoutCustomerPayload(
                name: address.recipientName,
                email: email?.isEmpty == false ? email! : "mobil@karacabeygrossmarket.com",
                phone: phone
            ),
            shipping: CheckoutShippingPayload(
                city: address.city,
                district: address.district,
                address: address.fullAddress,
                lat: address.latitude,
                lng: address.longitude
            ),
            cartToken: cart.cartToken ?? KeychainManager.shared.getCartToken(),
            couponCode: couponCode,
            checkoutKey: checkoutKey,
            checkoutUID: checkoutKey,
            paymentUID: paymentUID,
            paymentFlow: paymentFlow,
            items: checkoutItems
        )

        return try await apiClient.request(
            Endpoint.placeOrder(request, idempotencyKey: paymentUID)
        )
    }
}
