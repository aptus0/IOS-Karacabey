import Foundation

struct APIResponse<T: Decodable>: Decodable {
    let data: T?
    let message: String?
    let code: String?

    enum CodingKeys: String, CodingKey {
        case data, message, code
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let decodedData: T?
        do {
            decodedData = try container.decodeIfPresent(T.self, forKey: .data)
        } catch {
            decodedData = nil
        }
        data = decodedData

        let decodedMessage: String?
        do {
            decodedMessage = try container.decodeIfPresent(String.self, forKey: .message)
        } catch {
            decodedMessage = nil
        }
        message = decodedMessage

        if let stringCode = try? container.decodeIfPresent(String.self, forKey: .code) {
            code = stringCode
        } else if let intCode = try? container.decodeIfPresent(Int.self, forKey: .code) {
            code = String(intCode)
        } else {
            code = nil
        }
    }
}

struct EmptyResponse: Decodable {}

struct RefreshTokenRequest: Encodable {
    let refreshToken: String
}

struct ForgotPasswordRequest: Encodable {
    let email: String
}

struct ApplyCouponRequest: Encodable {
    let code: String
}

struct AddCartItemRequest: Encodable {
    let productId: String
    let quantity: Int

    enum CodingKeys: String, CodingKey {
        case productID = "product_id"
        case quantity
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(Int64(productId) ?? 0, forKey: .productID)
        try container.encode(quantity, forKey: .quantity)
    }
}

struct UpdateCartItemRequest: Encodable {
    let quantity: Int
}

struct CheckoutPrepareRequest: Encodable {
    let addressId: String
    let deliveryNote: String?
}

struct PlaceOrderRequest: Encodable {
    let source: String
    let customer: CheckoutCustomerPayload
    let shipping: CheckoutShippingPayload
    let cartToken: String?
    let couponCode: String?
    let checkoutKey: String
    let checkoutUID: String
    let paymentUID: String
    let paymentFlow: String
    let items: [CheckoutItemPayload]
}

struct CheckoutCustomerPayload: Encodable {
    let name: String
    let email: String
    let phone: String
}

struct CheckoutShippingPayload: Encodable {
    let city: String
    let district: String
    let address: String
    let lat: Double?
    let lng: Double?
}

struct CheckoutItemPayload: Encodable {
    let productId: Int64
    let quantity: Int
}

struct PayTRInitRequest: Encodable {
    let orderId: String
    let paymentMethodId: String?
    let returnURL: String
}

struct CheckoutSessionResponse: Decodable, Identifiable, Hashable {
    let merchantOID: String
    let orderID: String
    let paymentID: String?
    let status: String
    let totalCents: Int64
    let currency: String
    let checkoutURL: String?
    let iframeToken: String?
    let iframeSrc: String?
    let paymentFlow: String?
    let cashOnDelivery: Bool?
    let paymentUnavailable: Bool?
    let message: String?
    let providerReason: String?
    let traceID: String?
    let directPayment: DirectPaymentPayload?

    var id: String { orderID }
    var isCashOnDelivery: Bool {
        cashOnDelivery == true || paymentFlow == "cash_on_delivery" || status == "cash_on_delivery"
    }
    var paymentURL: URL? {
        if let checkoutURL, let url = URL(string: checkoutURL) { return url }
        if let iframeSrc, let url = URL(string: iframeSrc) { return url }
        return nil
    }

    enum CodingKeys: String, CodingKey {
        case merchantOID = "merchantOid"
        case orderID = "orderId"
        case paymentID = "paymentId"
        case status
        case totalCents
        case currency
        case checkoutURL = "checkoutUrl"
        case iframeToken
        case iframeSrc
        case paymentFlow
        case cashOnDelivery
        case paymentUnavailable
        case message
        case providerReason
        case traceID = "traceId"
        case directPayment
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        merchantOID = (try? container.decode(String.self, forKey: .merchantOID)) ?? ""
        if let numericOrderID = try? container.decode(Int64.self, forKey: .orderID) {
            orderID = String(numericOrderID)
        } else {
            orderID = (try? container.decode(String.self, forKey: .orderID)) ?? UUID().uuidString
        }
        if let numericPaymentID = try? container.decode(Int64.self, forKey: .paymentID) {
            paymentID = String(numericPaymentID)
        } else {
            paymentID = try? container.decodeIfPresent(String.self, forKey: .paymentID)
        }
        status = (try? container.decode(String.self, forKey: .status)) ?? ""
        totalCents = (try? container.decode(Int64.self, forKey: .totalCents)) ?? 0
        currency = (try? container.decode(String.self, forKey: .currency)) ?? "TL"
        checkoutURL = try? container.decodeIfPresent(String.self, forKey: .checkoutURL)
        iframeToken = try? container.decodeIfPresent(String.self, forKey: .iframeToken)
        iframeSrc = try? container.decodeIfPresent(String.self, forKey: .iframeSrc)
        paymentFlow = try? container.decodeIfPresent(String.self, forKey: .paymentFlow)
        cashOnDelivery = try? container.decodeIfPresent(Bool.self, forKey: .cashOnDelivery)
        paymentUnavailable = try? container.decodeIfPresent(Bool.self, forKey: .paymentUnavailable)
        message = try? container.decodeIfPresent(String.self, forKey: .message)
        providerReason = try? container.decodeIfPresent(String.self, forKey: .providerReason)
        traceID = try? container.decodeIfPresent(String.self, forKey: .traceID)
        directPayment = try? container.decodeIfPresent(DirectPaymentPayload.self, forKey: .directPayment)
    }
}

struct DirectPaymentPayload: Decodable, Hashable {
    let postURL: String
    let fields: [String: String]

    enum CodingKeys: String, CodingKey {
        case postURL = "postUrl"
        case postURLSnake = "post_url"
        case fields
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        postURL = (try? container.decode(String.self, forKey: .postURL))
            ?? (try? container.decode(String.self, forKey: .postURLSnake))
            ?? ""
        if let stringFields = try? container.decode([String: String].self, forKey: .fields) {
            fields = stringFields
        } else {
            fields = (try? container.decode([String: FlexibleStringValue].self, forKey: .fields)
                .mapValues(\.value)) ?? [:]
        }
    }
}

private struct FlexibleStringValue: Decodable {
    let value: String

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let string = try? container.decode(String.self) {
            value = string
        } else if let int = try? container.decode(Int.self) {
            value = String(int)
        } else if let double = try? container.decode(Double.self) {
            value = String(double)
        } else if let bool = try? container.decode(Bool.self) {
            value = bool ? "1" : "0"
        } else {
            value = ""
        }
    }
}

struct RefundRequestPayload: Encodable {
    let amountKurus: Int64?
    let reason: String
}

struct ClientMutationsRequest: Encodable {
    let mutations: [String]
}

struct VisualProductSearchRequest: Encodable {
    /// Görsel analizi sunucu tarafında Gemini ile yapılır. API anahtarı mobil uygulamaya konmaz.
    let imageBase64: String?
    let mimeType: String?
    let barcode: String?
    let provider: String?
    let mode: String?
    let maxResults: Int?

    init(
        imageBase64: String?,
        mimeType: String?,
        barcode: String?,
        provider: String? = "gemini",
        mode: String? = "product_match",
        maxResults: Int? = 12
    ) {
        self.imageBase64 = imageBase64
        self.mimeType = mimeType
        self.barcode = barcode
        self.provider = provider
        self.mode = mode
        self.maxResults = maxResults
    }
}

struct VisualProductSearchResponse: Decodable {
    let query: String
    let labels: [String]
    let products: [Product]
    let message: String?

    init(query: String, labels: [String], products: [Product], message: String?) {
        self.query = query
        self.labels = labels
        self.products = products
        self.message = message
    }

    enum CodingKeys: String, CodingKey {
        case query
        case labels
        case products
        case data
        case message
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        query = (try? container.decodeIfPresent(String.self, forKey: .query)) ?? ""
        labels = (try? container.decodeIfPresent([String].self, forKey: .labels)) ?? []
        products = (try? container.decodeIfPresent([Product].self, forKey: .products))
            ?? (try? container.decodeIfPresent([Product].self, forKey: .data))
            ?? []
        message = try? container.decodeIfPresent(String.self, forKey: .message)
    }
}

struct ExternalProductSearchRequest: Encodable {
    let query: String
    let maxResults: Int

    enum CodingKeys: String, CodingKey {
        case query
        case maxResults = "max_results"
    }
}

struct ExternalProductSearchResponse: Codable {
    let query: String
    let disclaimer: String
    let results: [ExternalMarketProduct]

    init(query: String, disclaimer: String, results: [ExternalMarketProduct]) {
        self.query = query
        self.disclaimer = disclaimer
        self.results = results
    }

    enum CodingKeys: String, CodingKey {
        case query
        case disclaimer
        case results
        case data
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        query = (try? container.decodeIfPresent(String.self, forKey: .query)) ?? ""
        disclaimer = (try? container.decodeIfPresent(String.self, forKey: .disclaimer))
            ?? "Dış market sonuçları yalnızca karşılaştırma amaçlıdır. Fiyat ve stok güncelliği garanti edilmez."
        results = (try? container.decodeIfPresent([ExternalMarketProduct].self, forKey: .results))
            ?? (try? container.decodeIfPresent([ExternalMarketProduct].self, forKey: .data))
            ?? []
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(query, forKey: .query)
        try container.encode(disclaimer, forKey: .disclaimer)
        try container.encode(results, forKey: .results)
    }
}

struct ExternalMarketProduct: Identifiable, Codable, Hashable {
    let id: String
    let title: String
    let provider: String
    let url: String
    let snippet: String?
    let imageURL: String?
    let priceLabel: String?

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case provider
        case url
        case snippet
        case imageURL = "image_url"
        case imageUrl
        case priceLabel = "price_label"
        case price
    }

    init(id: String, title: String, provider: String, url: String, snippet: String?, imageURL: String?, priceLabel: String?) {
        self.id = id
        self.title = title
        self.provider = provider
        self.url = url
        self.snippet = snippet
        self.imageURL = imageURL
        self.priceLabel = priceLabel
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        title = (try? container.decodeIfPresent(String.self, forKey: .title)) ?? "Dış market sonucu"
        provider = (try? container.decodeIfPresent(String.self, forKey: .provider)) ?? "Kaynak"
        url = (try? container.decodeIfPresent(String.self, forKey: .url)) ?? ""
        snippet = try? container.decodeIfPresent(String.self, forKey: .snippet)
        imageURL = (try? container.decodeIfPresent(String.self, forKey: .imageURL))
            ?? (try? container.decodeIfPresent(String.self, forKey: .imageUrl))
        priceLabel = (try? container.decodeIfPresent(String.self, forKey: .priceLabel))
            ?? (try? container.decodeIfPresent(String.self, forKey: .price))
        id = (try? container.decodeIfPresent(String.self, forKey: .id))
            ?? String(abs((title + url).hashValue))
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encode(provider, forKey: .provider)
        try container.encode(url, forKey: .url)
        try container.encodeIfPresent(snippet, forKey: .snippet)
        try container.encodeIfPresent(imageURL, forKey: .imageURL)
        try container.encodeIfPresent(priceLabel, forKey: .priceLabel)
    }
}
