import Foundation

enum HTTPMethod: String {
    case get = "GET", post = "POST", put = "PUT", delete = "DELETE", patch = "PATCH"
}

protocol APIEndpoint {
    var path: String { get }
    var method: HTTPMethod { get }
    var queryItems: [URLQueryItem]? { get }
    var body: Encodable? { get }
    var requiresAuth: Bool { get }
    var idempotencyKey: String? { get }
    var requiredAction: String? { get }
}

// Go API (api-go) tarafındaki gerçek route envanteri ile eşleştirilmiştir.
// Backend kaynağı: api-go/cmd/api/middleware.go. Tüm path'ler /api/v1 prefix'i
// `KGM_API_BASE_URL` (Info.plist) içinden geldiği için burada *prefix'siz*
// tutulur. Backend'de henüz karşılığı olmayan uçlar için en yakın handler'a
// köprülenmiş, gerçekten desteklenmeyenlerde `requiresAuth=false` ile birlikte
// `__unsupported__/...` yolunu bırakıyoruz (Repository tarafı runtime'da yakalar).
enum Endpoint {
    // Auth
    case login(LoginRequest)
    case register(RegisterRequest)
    case logout
    case refreshToken(String)
    case forgotPassword(String)
    case authLogEvent(MobileEventRequest)
    case actionToken(action: String)
    // App
    case appSettings
    case home
    case homeSections
    case campaigns
    case stories
    // Products
    case products(categoryId: String?, page: Int, limit: Int)
    case productDetail(id: String)
    case productRelated(slug: String)
    case productReviews(slug: String)
    case submitProductReview(slug: String, ProductReviewSubmissionRequest)
    case productFrequentlyBoughtTogether(slug: String)
    case productStockAlert(slug: String, StockAlertRequest)
    case productView(slug: String)
    case searchProducts(query: String, page: Int)
    case visualProductSearch(VisualProductSearchRequest)
    case externalProductSearch(ExternalProductSearchRequest)
    case brands
    // Categories
    case categories
    // Cart
    case getCart
    case addToCart(AddCartItemRequest)
    case updateCartItem(itemId: String, UpdateCartItemRequest)
    case removeFromCart(itemId: String)
    case clearCart
    case applyCoupon(code: String)
    case removeCoupon
    // Checkout
    case prepareCheckout(CheckoutPrepareRequest, idempotencyKey: String)
    case placeOrder(PlaceOrderRequest, idempotencyKey: String)
    // Orders
    case getOrders
    case getOrderDetail(id: String)
    case orderTracking(id: String)
    case cancelOrder(id: String)
    case reorder(id: String)
    // Payment
    case paymentMethods
    case paytrInit(PayTRInitRequest, idempotencyKey: String)
    case paytrPayment(PayTRPaymentRequest, idempotencyKey: String)
    case paymentStatus(id: String)
    case cancelPayment(id: String)
    case refundRequest(id: String, RefundRequestPayload)
    // User
    case getProfile
    case updateProfile
    case customerCoupons
    case recentPurchases(limit: Int)
    case customerLoyalty
    case customerRecommendations(limit: Int)
    case getAddresses
    case addAddress(Address)
    case updateAddress(id: String, Address)
    case deleteAddress(id: String)
    case setDefaultAddress(id: String)
    // Notifications
    case registerDeviceToken(DeviceTokenRegistrationRequest)
    case deleteDeviceToken(id: String)
    case notifications(status: String?, page: Int, limit: Int)
    case markNotificationRead(id: String)
    case deleteNotification(id: String)
    case markAllNotificationsRead
    // Mobile telemetry / device registry (Go: /api/v1/mobile/*)
    case mobileDeviceRegister(MobileDeviceRegisterRequest)
    case mobileEvent(MobileEventRequest)
    case mobileBootstrap
    case liveActivityToken(LiveActivityTokenRequest)
    // Location
    case resolveDeliveryZone(DeliveryZoneResolveRequest)
    case nearbyBranches(latitude: Double, longitude: Double)
    // Sync
    case sync(afterId: String?)
    case clientMutations(ClientMutationsRequest)
    // Favorites
    case getFavorites
    case addFavorite(slug: String)
    case removeFavorite(slug: String)
}

extension Endpoint: APIEndpoint {
    var path: String {
        switch self {
        // Auth — Go: /api/v1/auth/{register,login,logout,refresh,forgot-password,me,profile,providers}
        case .login:                     return "/auth/login"
        case .register:                  return "/auth/register"
        case .logout:                    return "/auth/logout"
        case .refreshToken:              return "/auth/refresh"
        case .forgotPassword:            return "/auth/forgot-password"
        case .authLogEvent:              return "/mobile/events"
        case .actionToken:               return "/security/action-token"

        // App / Content — Go: /api/v1/content/*, /api/v1/mobile/bootstrap
        case .appSettings:               return "/mobile/bootstrap"
        case .home:                      return "/content/homepage"
        case .homeSections:              return "/content/homepage"
        case .campaigns:                 return "/content/campaigns"
        case .stories:                   return "/content/stories"

        // Catalog
        case .products:                  return "/products"
        case .productDetail(let slug):   return "/products/\(slug)"
        case .productRelated(let slug):  return "/products/\(slug)/related"
        case .productReviews(let slug):  return "/products/\(slug)/reviews"
        case .submitProductReview(let slug, _): return "/products/\(slug)/reviews"
        case .productFrequentlyBoughtTogether(let slug): return "/products/\(slug)/frequently-bought-together"
        case .productStockAlert(let slug, _): return "/products/\(slug)/stock-alert"
        case .productView(let slug):      return "/products/\(slug)/view"
        case .searchProducts:            return "/products"
        case .visualProductSearch:       return "/products/visual-search"
        case .externalProductSearch:     return "/search/external"
        case .brands:                    return "__unsupported__/brands"
        case .categories:                return "/categories"

        // Cart
        case .getCart:                   return "/cart"
        case .addToCart:                 return "/cart/items"
        case .updateCartItem(let id, _): return "/cart/items/\(id)"
        case .removeFromCart(let id):    return "/cart/items/\(id)"
        case .clearCart:                 return "/cart"
        case .applyCoupon:               return "/cart/coupon"
        case .removeCoupon:              return "/cart/coupon"

        // Checkout — Go: /api/v1/c (paymentGuard) tek uç
        case .prepareCheckout:           return "/shipping/quote"
        case .placeOrder:                return "/c"

        // Orders
        case .getOrders:                 return "/orders"
        case .getOrderDetail(let id):    return "/orders/\(id)"
        case .orderTracking(let id):     return "/orders/\(id)"
        case .cancelOrder(let id):       return "/orders/\(id)/cancel"
        case .reorder(let id):           return "/orders/\(id)/reorder"

        // Payments
        case .paymentMethods:            return "/payment-methods"
        case .paytrInit:                 return "/c"
        case .paytrPayment:              return "/c"
        case .paymentStatus(let id):     return "/payments/\(id)/status"
        case .cancelPayment(let id):     return "__unsupported__/payments/\(id)/cancel"
        case .refundRequest(let id, _):  return "__unsupported__/payments/\(id)/refund-request"

        // Profile / Addresses
        case .getProfile:                return "/auth/me"
        case .updateProfile:             return "/auth/profile"
        case .customerCoupons:           return "/customer/coupons"
        case .recentPurchases:           return "/customer/recent-purchases"
        case .customerLoyalty:           return "/customer/loyalty"
        case .customerRecommendations:   return "/customer/recommendations"
        case .getAddresses:              return "/addresses"
        case .addAddress:                return "/addresses"
        case .updateAddress(let id, _):  return "/addresses/\(id)"
        case .deleteAddress(let id):     return "/addresses/\(id)"
        case .setDefaultAddress(let id): return "/addresses/\(id)/default"

        // Notifications / Devices
        case .registerDeviceToken:       return "/notifications/device-tokens"
        case .deleteDeviceToken(let id): return "/notifications/device-tokens/\(id)"
        case .notifications:             return "/notifications"
        case .markNotificationRead(let id): return "/notifications/\(id)/read"
        case .deleteNotification(let id): return "/notifications/\(id)"
        case .markAllNotificationsRead:  return "/notifications/read-all"

        // Mobile cihaz registry + telemetry
        case .mobileDeviceRegister:      return "/mobile/device/register"
        case .mobileEvent:               return "/mobile/events"
        case .mobileBootstrap:           return "/mobile/bootstrap"
        case .liveActivityToken:         return "/mobile/live-activity-tokens"

        // Location
        case .resolveDeliveryZone:       return "/shipping/quote"
        case .nearbyBranches:            return "/branches/nearby"

        // Sync
        case .sync:                      return "/mobile/sync"
        case .clientMutations:           return "__unsupported__/client-mutations"

        // Favorites
        case .getFavorites:              return "/favorites"
        case .addFavorite(let slug):     return "/favorites/\(slug)"
        case .removeFavorite(let slug):  return "/favorites/\(slug)"
        }
    }

    var method: HTTPMethod {
        switch self {
        case .login, .register, .logout, .forgotPassword, .authLogEvent, .addToCart, .applyCoupon,
             .prepareCheckout, .placeOrder, .cancelOrder, .reorder, .paytrInit, .paytrPayment, .cancelPayment,
             .refundRequest, .addAddress, .setDefaultAddress, .registerDeviceToken,
             .resolveDeliveryZone, .clientMutations, .markNotificationRead, .markAllNotificationsRead, .addFavorite,
             .mobileDeviceRegister, .mobileEvent, .visualProductSearch, .externalProductSearch, .liveActivityToken, .submitProductReview, .productStockAlert, .productView:
            return .post
        case .updateProfile, .updateAddress, .updateCartItem:
            return .patch
        case .removeFromCart, .clearCart, .removeCoupon, .deleteAddress, .deleteDeviceToken, .deleteNotification, .removeFavorite:
            return .delete
        default:
            return .get
        }
    }

    var queryItems: [URLQueryItem]? {
        switch self {
        case .home, .homeSections, .stories:
            return [.init(name: "channel", value: "mobile")]
        case .products(let catId, let page, let limit):
            var items: [URLQueryItem] = [
                .init(name: "page", value: "\(page)"),
                .init(name: "per_page", value: "\(limit)")
            ]
            if let cid = catId { items.append(.init(name: "category", value: cid)) }
            return items
        case .searchProducts(let query, let page):
            return [.init(name: "q", value: query), .init(name: "page", value: "\(page)")]
        case .recentPurchases(let limit):
            return [.init(name: "limit", value: "\(limit)")]
        case .customerRecommendations(let limit):
            return [.init(name: "limit", value: "\(limit)")]
        case .notifications(let status, let page, let limit):
            var items = [
                URLQueryItem(name: "page", value: "\(page)"),
                URLQueryItem(name: "limit", value: "\(limit)")
            ]
            if let status { items.append(URLQueryItem(name: "status", value: status)) }
            return items
        case .actionToken(let action):
            return [.init(name: "action", value: action)]
        case .nearbyBranches(let latitude, let longitude):
            return [.init(name: "lat", value: "\(latitude)"), .init(name: "lng", value: "\(longitude)")]
        case .sync(let afterId):
            guard let afterId else { return nil }
            return [.init(name: "after_id", value: afterId)]
        default:
            return nil
        }
    }

    var body: Encodable? {
        switch self {
        case .login(let request): return request
        case .register(let request): return request
        case .refreshToken(let token): return RefreshTokenRequest(refreshToken: token)
        case .forgotPassword(let email): return ForgotPasswordRequest(email: email)
        case .authLogEvent(let request): return request
        case .addToCart(let request): return request
        case .updateCartItem(_, let request): return request
        case .applyCoupon(let code): return ApplyCouponRequest(code: code)
        case .prepareCheckout(let request, _): return request
        case .placeOrder(let request, _): return request
        case .paytrInit(let request, _): return request
        case .paytrPayment(let request, _): return request
        case .visualProductSearch(let request): return request
        case .externalProductSearch(let request): return request
        case .submitProductReview(_, let request): return request
        case .productStockAlert(_, let request): return request
        case .refundRequest(_, let request): return request
        case .addAddress(let address), .updateAddress(_, let address): return address
        case .registerDeviceToken(let request): return request
        case .resolveDeliveryZone(let request): return request
        case .clientMutations(let request): return request
        case .mobileDeviceRegister(let request): return request
        case .mobileEvent(let request): return request
        case .liveActivityToken(let request): return request
        default: return nil
        }
    }

    var requiresAuth: Bool {
        switch self {
        case .login, .register, .refreshToken, .forgotPassword, .appSettings, .home, .homeSections,
             .campaigns, .stories, .products, .productDetail, .productRelated, .productFrequentlyBoughtTogether, .productReviews, .productView, .searchProducts, .externalProductSearch, .brands,
             .categories, .getCart, .addToCart, .updateCartItem, .removeFromCart, .clearCart,
             .applyCoupon, .removeCoupon, .placeOrder, .nearbyBranches,
             .mobileDeviceRegister, .mobileEvent, .mobileBootstrap, .visualProductSearch, .actionToken:
            return false
        default: return true
        }
    }

    var idempotencyKey: String? {
        switch self {
        case .prepareCheckout(_, let key), .placeOrder(_, let key), .paytrInit(_, let key), .paytrPayment(_, let key):
            return key
        default:
            return nil
        }
    }

    var requiredAction: String? {
        switch self {
        case .addToCart: return "cart.add"
        case .updateCartItem: return "cart.update"
        case .removeFromCart: return "cart.delete"
        case .clearCart: return "cart.clear"
        case .applyCoupon: return "coupon.apply"
        case .removeCoupon: return "coupon.remove"
        case .placeOrder, .paytrInit, .paytrPayment: return "checkout.start"
        case .updateProfile: return "profile.update"
        case .deleteAddress: return "address.delete"
        case .addFavorite: return "favorite.add"
        case .removeFavorite: return "favorite.delete"
        case .markNotificationRead: return "notification.read"
        case .markAllNotificationsRead: return "notification.read_all"
        case .deleteNotification: return "notification.delete"
        case .submitProductReview: return "product.review"
        case .productStockAlert: return "product.stock_alert"
        case .reorder: return "order.reorder"
        default: return nil
        }
    }
}

extension Endpoint: APIBodyEncodingStrategy {
    var bodyEncoder: JSONEncoder {
        switch self {
        case .paytrPayment:
            return .paytr
        default:
            return .kgm
        }
    }
}
