//
//  Karacabey_Gross_MarketTests.swift
//  Karacabey Gross MarketTests
//
//  Created by ttsy0 on 5/17/26.
//

import Foundation
import Testing
@testable import Karacabey_Gross_Market

@MainActor
struct Karacabey_Gross_MarketTests {

    @Test func checkoutSessionDecodesPaymentId() async throws {
        let json = """
        {
          "data": {
            "merchant_oid": "KGM123",
            "order_id": 7,
            "payment_id": 42,
            "status": "awaiting_payment",
            "total_cents": 7990,
            "currency": "TL",
            "iframe_src": "https://www.paytr.com/odeme/guvenli/token"
          }
        }
        """.data(using: .utf8)!

        let response = try JSONDecoder.kgm.decode(APIResponse<CheckoutSessionResponse>.self, from: json)
        #expect(response.data?.orderID == "7")
        #expect(response.data?.paymentID == "42")
        #expect(response.data?.paymentURL?.absoluteString == "https://www.paytr.com/odeme/guvenli/token")
    }

    @Test func checkoutSessionDecodesCashOnDelivery() async throws {
        let json = """
        {
          "data": {
            "order_id": 9,
            "payment_id": 77,
            "payment_flow": "cash_on_delivery",
            "cash_on_delivery": true,
            "message": "Kapıda ödeme ile siparişiniz alındı."
          }
        }
        """.data(using: .utf8)!

        let response = try JSONDecoder.kgm.decode(APIResponse<CheckoutSessionResponse>.self, from: json)
        #expect(response.data?.orderID == "9")
        #expect(response.data?.paymentID == "77")
        #expect(response.data?.isCashOnDelivery == true)
        #expect(response.data?.paymentURL == nil)
    }

    @Test func paymentStatusDecodesGoResponse() async throws {
        let json = """
        {
          "data": {
            "id": 42,
            "status": "paid",
            "merchant_oid": "KGM123",
            "amount_cents": 7990
          }
        }
        """.data(using: .utf8)!

        let response = try JSONDecoder.kgm.decode(APIResponse<PaymentStatusResponse>.self, from: json)
        #expect(response.data?.paymentId == "42")
        #expect(response.data?.status == .succeeded)
        #expect(response.data?.amount == 79.90)
    }

    @Test func urlErrorsMapToSpecificMessages() async throws {
        #expect(APIError.from(URLError(.notConnectedToInternet)).errorDescription == "İnternet bağlantınızı kontrol edip tekrar deneyin.")
        #expect(APIError.from(URLError(.networkConnectionLost)).errorDescription == "Bağlantı kısa süreli kesildi. İşleminizi tekrar deniyoruz.")
        #expect(APIError.from(URLError(.timedOut)).errorDescription == "Sunucu yanıtı gecikti. Lütfen birkaç saniye sonra tekrar deneyin.")
    }

    @Test func addressValidationRequiresCoreFields() async throws {
        #expect(AddressInputValidator.isValid(
            firstName: "Ali",
            lastName: "Yilmaz",
            phone: "05551112233",
            city: "Bursa",
            district: "Karacabey",
            neighborhood: "Yeni",
            street: "Bursa Yolu"
        ))

        #expect(!AddressInputValidator.isValid(
            firstName: "Ali",
            lastName: "",
            phone: "555",
            city: "Bursa",
            district: "Karacabey",
            neighborhood: "Yeni",
            street: "Bursa Yolu"
        ))
    }

    @Test func checkoutRulesRequireMinimumAndKaracabeyForCash() async throws {
        let local = Address(
            id: "1",
            title: "Ev",
            firstName: "Ali",
            lastName: "Yilmaz",
            phone: "05551112233",
            city: "Bursa",
            district: "Karacabey",
            neighborhood: "Yeni",
            street: "Bursa Yolu",
            buildingNo: "1",
            apartmentNo: "2",
            floor: "3",
            directions: "",
            isDefault: true
        )
        let remote = Address(
            id: "2",
            title: "İş",
            firstName: "Ali",
            lastName: "Yilmaz",
            phone: "05551112233",
            city: "Balıkesir",
            district: "Bandırma",
            neighborhood: "Merkez",
            street: "Sahil",
            buildingNo: "1",
            apartmentNo: "2",
            floor: "3",
            directions: "",
            isDefault: false
        )

        #expect(KGMCheckoutRules.meetsMinimum(350))
        #expect(!KGMCheckoutRules.meetsMinimum(349.99))
        #expect(KGMCheckoutRules.isKaracabeyAddress(local))
        #expect(!KGMCheckoutRules.isKaracabeyAddress(remote))
    }

    @Test func payTRPaymentRequestEncodesExpectedCamelCaseBody() async throws {
        let product = Product(
            id: "42",
            slug: "sut",
            name: "Süt",
            price: 1299.50,
            stockQuantity: 10
        )
        let cart = Cart(
            items: [CartItem(id: "cart-1", product: product, quantity: 1)],
            cartToken: "cart-token",
            couponCode: nil,
            discountAmount: 0,
            deliveryFee: 0
        )
        let address = Address(
            id: "7",
            title: "Ev",
            firstName: "Ali",
            lastName: "Yilmaz",
            phone: "05551112233",
            city: "Bursa",
            district: "Karacabey",
            neighborhood: "Yeni",
            street: "Bursa Yolu",
            buildingNo: "1",
            apartmentNo: "2",
            floor: "3",
            directions: "",
            isDefault: true
        )
        let user = User(
            id: 5,
            publicUID: "usr_5",
            customerUID: "cus_5",
            syncVersion: 1,
            name: "Ali Yilmaz",
            phone: "05551112233",
            email: "customer@example.com",
            avatarURL: nil,
            emailVerifiedAt: nil
        )

        let payload = try PayTRPaymentRequest(orderId: "KGM-ORDER-ID", user: user, address: address, cart: cart)
        let data = try JSONEncoder.paytr.encode(payload)
        let object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let basket = try #require(object["basket"] as? [[String: Any]])
        let firstItem = try #require(basket.first)

        #expect(object["orderId"] as? String == "KGM-ORDER-ID")
        #expect(object["userId"] as? String == "5")
        #expect(object["email"] as? String == "customer@example.com")
        #expect(object["phone"] as? String == "05551112233")
        #expect(object["amountKurus"] as? Int == 129950)
        #expect(object["addressId"] as? String == "7")
        #expect(object["order_id"] == nil)
        #expect(firstItem["productId"] as? String == "42")
        #expect(firstItem["unitPriceKurus"] as? Int == 129950)
    }

    @Test func cashOnDeliveryCheckoutRequestEncodesPaymentFlow() async throws {
        let request = PlaceOrderRequest(
            source: "ios",
            customer: CheckoutCustomerPayload(
                name: "Ali Yilmaz",
                email: "customer@example.com",
                phone: "05551112233"
            ),
            shipping: CheckoutShippingPayload(
                city: "Bursa",
                district: "Karacabey",
                address: "Yeni Mahalle, Bursa Yolu No 1",
                lat: nil,
                lng: nil
            ),
            cartToken: "cart-token",
            couponCode: nil,
            checkoutKey: "ios-checkout-test",
            checkoutUID: "ios-checkout-test",
            paymentUID: "ios-payment-test",
            paymentFlow: "cash_on_delivery",
            items: [CheckoutItemPayload(productId: 42, quantity: 1)]
        )

        let data = try JSONEncoder.kgm.encode(request)
        let object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let items = try #require(object["items"] as? [[String: Any]])
        let firstItem = try #require(items.first)

        #expect(object["payment_flow"] as? String == "cash_on_delivery")
        #expect(object["checkout_uid"] as? String == "ios-checkout-test")
        #expect(object["payment_uid"] as? String == "ios-payment-test")
        #expect(object["paymentFlow"] == nil)
        #expect(firstItem["product_id"] as? Int == 42)
    }

    @Test func payTRPaymentRequestRejectsInvalidInputs() async throws {
        do {
            _ = try PayTRPaymentRequest(
                orderId: "KGM-1",
                userId: "5",
                email: "",
                phone: "05551112233",
                amountKurus: 100,
                addressId: "7",
                basket: []
            )
            Issue.record("Expected invalid PayTR payload to throw.")
        } catch {
            #expect(error.localizedDescription.contains("e-posta"))
        }
    }

    @Test func productDecodesBarcode() async throws {
        let json = """
        {
          "id": 12,
          "slug": "domates",
          "name": "Domates",
          "barcode": "8690000000012",
          "price_cents": 2490,
          "stock_quantity": 8
        }
        """.data(using: .utf8)!

        let product = try JSONDecoder.kgm.decode(Product.self, from: json)
        #expect(product.barcode == "8690000000012")
        #expect(product.effectivePrice == 24.90)
    }

    @Test func productDecodesCategoryNameAndZeroStock() async throws {
        let json = """
        {
          "id": 12,
          "slug": "domates",
          "name": "Domates",
          "price_cents": 2490,
          "stock_quantity": 0,
          "categories": [{"id": 3, "name": "Meyve ve Sebze", "slug": "meyve-sebze"}]
        }
        """.data(using: .utf8)!

        let product = try JSONDecoder.kgm.decode(Product.self, from: json)
        #expect(product.categoryId == "meyve-sebze")
        #expect(product.categoryName == "Meyve ve Sebze")
        #expect(product.stockQuantity == 0)
        #expect(!product.isInStock)
    }

    @Test func orderDecodesGoAccountResponseAndPendingStatus() async throws {
        let json = """
        {
          "id": 91,
          "merchant_oid": "KGM-91",
          "status": "pending",
          "subtotal_cents": 35000,
          "shipping_cents": 0,
          "discount_cents": 1000,
          "total_cents": 34000,
          "customer_name": "Ali Yilmaz",
          "customer_phone": "05551112233",
          "shipping_city": "Bursa",
          "shipping_district": "Karacabey",
          "shipping_address": "Yeni Mahalle",
          "created_at": "2026-06-07T07:00:00Z",
          "items": [{
            "id": 5,
            "name": "Süt",
            "quantity": 2,
            "unit_price_cents": 12500,
            "line_total_cents": 25000
          }]
        }
        """.data(using: .utf8)!

        let order = try JSONDecoder.kgm.decode(Order.self, from: json)
        #expect(order.id == "91")
        #expect(order.orderNumber == "KGM-91")
        #expect(order.status == .pending)
        #expect(order.items.first?.product.name == "Süt")
        #expect(order.total == 340)
        #expect(order.deliveryAddress.district == "Karacabey")
    }

    @Test func partiallyRefundedPaymentIsTerminal() async throws {
        #expect(PaymentStatus.partiallyRefunded.isTerminal)
        #expect(!PaymentStatus.pending.isTerminal)
        #expect(!PaymentStatus.processing.isTerminal)
    }

    @Test func notificationDecodesBackendReadAtAndActionURL() async throws {
        let json = """
        {
          "id": "15",
          "type": "order",
          "title": "Sipariş güncellendi",
          "body": "Siparişiniz hazırlanıyor.",
          "action_url": "kgm://order/91",
          "read_at": "2026-06-07T07:00:00Z",
          "created_at": "2026-06-07T06:00:00Z"
        }
        """.data(using: .utf8)!

        let notification = try JSONDecoder.kgm.decode(NotificationItem.self, from: json)
        #expect(notification.isRead)
        #expect(notification.deepLink == "kgm://order/91")
    }

    @Test func protectedEndpointsDeclareExpectedActionTokens() async throws {
        #expect(Endpoint.addToCart(AddCartItemRequest(productId: "42", quantity: 1)).requiredAction == "cart.add")
        #expect(Endpoint.updateCartItem(itemId: "7", UpdateCartItemRequest(quantity: 2)).requiredAction == "cart.update")
        #expect(Endpoint.removeFromCart(itemId: "7").requiredAction == "cart.delete")
        #expect(Endpoint.markNotificationRead(id: "15").requiredAction == "notification.read")
        #expect(Endpoint.getCart.requiredAction == nil)
        #expect(Endpoint.actionToken(action: "cart.add").requiredAction == nil)
    }

    @Test func actionTokenResponseAndRichNotificationDecode() async throws {
        let tokenJSON = """
        {"token":"signed-token","action":"cart.add","expires_at":1781234567,"ttl_seconds":90}
        """.data(using: .utf8)!
        let token = try JSONDecoder.kgm.decode(ActionTokenResponse.self, from: tokenJSON)
        #expect(token.action == "cart.add")
        #expect(token.ttlSeconds == 90)

        let notificationJSON = """
        {
          "id": "16",
          "type": "campaign",
          "title": "Hafta Sonu Fırsatı",
          "body": "Seçili ürünlerde fırsatlar.",
          "action_url": "kgm://campaigns/hafta-sonu",
          "image_url": "https://example.com/campaign.jpg",
          "cta_title": "Kampanyayı Gör",
          "created_at": "2026-06-12T07:00:00Z"
        }
        """.data(using: .utf8)!
        let notification = try JSONDecoder.kgm.decode(NotificationItem.self, from: notificationJSON)
        #expect(notification.category == .campaign)
        #expect(notification.imageURL == "https://example.com/campaign.jpg")
        #expect(notification.ctaTitle == "Kampanyayı Gör")
    }

    @Test func crashReporterSanitizesNumericEndpointIdentifiers() async throws {
        #expect(CrashReporter.sanitizedEndpoint("/orders/91/items/4") == "orders/{id}/items/{id}")
        #expect(CrashReporter.sanitizedEndpoint("/products/domates") == "products/domates")
    }

    @Test func imageOnlyHomepageAndStoryContentDecodeWithoutTitles() async throws {
        let homepageJSON = """
        {
          "blocks": [{
            "id": 12,
            "type": "carousel_slide",
            "title": null,
            "subtitle": null,
            "image_url": "/campaigns/hosgeldin-indirimi.webp",
            "action_url": "/kampanyalar/hosgeldin-indirimi"
          }]
        }
        """.data(using: .utf8)!
        let homepage = try JSONDecoder.kgm.decode(HomepageContent.self, from: homepageJSON)
        #expect(homepage.blocks.first?.title == "")
        #expect(homepage.blocks.first?.imageURL == "/campaigns/hosgeldin-indirimi.webp")

        let storyJSON = """
        {
          "id": 13,
          "title": null,
          "cover_image_url": "/storage/stories/welcome.webp",
          "deep_link": "/kampanyalar/hosgeldin-indirimi"
        }
        """.data(using: .utf8)!
        let story = try JSONDecoder.kgm.decode(Story.self, from: storyJSON)
        #expect(story.title == "")
        #expect(story.deepLink == "/kampanyalar/hosgeldin-indirimi")
    }
}
