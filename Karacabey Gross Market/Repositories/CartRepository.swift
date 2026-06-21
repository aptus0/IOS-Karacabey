import Foundation
import Combine

enum CartSyncState: Equatable {
    case idle
    case queued
    case syncing
    case waitingConnection(String)

    var isActive: Bool {
        switch self {
        case .idle: return false
        case .queued, .syncing, .waitingConnection: return true
        }
    }

    var title: String {
        switch self {
        case .idle:
            return "Sepet güncel"
        case .queued:
            return "Sepet kaydediliyor"
        case .syncing:
            return "Sepet eşitleniyor"
        case .waitingConnection:
            return "Bağlantı bekleniyor"
        }
    }

    var message: String {
        switch self {
        case .idle:
            return "Sepetiniz güncel."
        case .queued:
            return "İşleminiz cihaza kaydedildi, sunucuya gönderiliyor."
        case .syncing:
            return "Sepetiniz güvenli şekilde güncelleniyor."
        case .waitingConnection(let message):
            return message
        }
    }
}

private struct CartSyncPendingTarget: Codable, Identifiable {
    var id: String { productId }
    let productId: String
    var quantity: Int
    let slug: String
    let name: String
    let brand: String
    let price: Double
    let discountedPrice: Double?
    let imageURL: String
    let categoryId: String
    let categoryName: String
    let unit: String
    let stockQuantity: Int
    let isInStock: Bool
    var updatedAt: Date

    init(product: Product, quantity: Int) {
        self.productId = product.id
        self.quantity = quantity
        self.slug = product.slug
        self.name = product.name
        self.brand = product.brand
        self.price = product.price
        self.discountedPrice = product.discountedPrice
        self.imageURL = product.imageURL
        self.categoryId = product.categoryId
        self.categoryName = product.categoryName
        self.unit = product.unit
        self.stockQuantity = product.stockQuantity
        self.isInStock = product.isInStock
        self.updatedAt = Date()
    }

    var productSnapshot: Product {
        Product(
            id: productId,
            slug: slug,
            name: name,
            brand: brand,
            price: price,
            discountedPrice: discountedPrice,
            imageURL: imageURL,
            categoryId: categoryId,
            categoryName: categoryName,
            unit: unit,
            stockQuantity: stockQuantity,
            isInStock: isInStock
        )
    }
}

@MainActor
final class CartRepository: ObservableObject {
    static let shared = CartRepository()

    @Published private(set) var cart: Cart = .empty
    @Published private(set) var lastError: String?
    @Published private(set) var syncState: CartSyncState = .idle
    @Published private(set) var pendingSyncCount: Int = 0

    private let apiClient = APIClient.shared
    private let fallbackMaxQuantity = 99
    private let pendingTargetsStorageKey = "kgm.cart.pendingTargets.v1"
    private let usedCouponsStorageKey = "kgm.cart.usedCoupons.v1"
    private var pendingTargets: [String: CartSyncPendingTarget] = [:]
    private var isProcessingQueue = false
    private var retryTask: Task<Void, Never>?

    private init() {
        loadPendingTargets()
        replayLocalPendingTargets()
        updateQueueStateAfterLocalChange()
    }

    func refreshCart() async throws {
        do {
            let serverCart: Cart = try await apiClient.request(Endpoint.getCart)
            cart = serverCart
            normalizeCartForLocalDisplay()
            replayLocalPendingTargets()
            lastError = nil

            if !pendingTargets.isEmpty {
                startQueueProcessing()
            }
        } catch {
            lastError = error.kgmUserMessage
            throw error
        }
    }

    /// Ürünü sepete ekler. İşlem önce cihazda güvenli biçimde görünür,
    /// sonra sırayla API'ye gönderilir. Ağ yavaşsa müşteri sepetini kaybetmez.
    func addToCart(_ product: Product, quantity: Int = 1) {
        incrementProduct(product, by: quantity)
    }

    func incrementProduct(_ product: Product, by quantity: Int = 1) {
        let maxAllowed = maxAllowedQuantity(for: product)
        guard maxAllowed > 0 else {
            lastError = "Bu ürün şu an stokta yok."
            return
        }

        let currentQuantity = quantityInCart(product.id)
        guard currentQuantity < maxAllowed else {
            lastError = "Bu ürün için maksimum adet sınırına ulaştınız."
            return
        }

        let safeDelta = max(1, min(quantity, maxAllowed - currentQuantity))
        setLocalTarget(product: product, quantity: currentQuantity + safeDelta)
    }

    func decrementProduct(productId: String) {
        guard let item = cartItem(for: productId) else { return }
        if item.quantity <= 1 {
            removeProduct(productId: productId)
        } else {
            setLocalTarget(product: item.product, quantity: item.quantity - 1)
        }
    }

    func updateQuantity(productId: String, quantity: Int) {
        guard let item = cartItem(for: productId) else { return }
        updateQuantity(itemId: item.id, quantity: quantity)
    }

    func updateQuantity(itemId: String, quantity: Int) {
        guard let index = cart.items.firstIndex(where: { $0.id == itemId }) else { return }
        let product = cart.items[index].product

        if quantity <= 0 {
            removeProduct(productId: product.id)
            return
        }

        let maxAllowed = maxAllowedQuantity(for: product)
        guard maxAllowed > 0 else {
            lastError = "Bu ürün şu an stokta yok."
            return
        }

        let safeQuantity = min(max(quantity, 1), maxAllowed)
        guard cart.items[index].quantity != safeQuantity else { return }
        setLocalTarget(product: product, quantity: safeQuantity)
    }

    func removeProduct(productId: String) {
        guard let item = cartItem(for: productId) else { return }
        removeLocalProduct(item.product)
    }

    func removeItem(itemId: String) {
        guard let item = cart.items.first(where: { $0.id == itemId }) else { return }
        removeLocalProduct(item.product)
    }

    func clearCart() {
        let retainedToken = cart.cartToken ?? KeychainManager.shared.getCartToken()
        let products = cart.items.map(\.product)
        cart = Cart(items: [], cartToken: retainedToken, couponCode: nil, discountAmount: 0, deliveryFee: 0)
        markLocalPricingDirty()

        for product in products {
            var target = CartSyncPendingTarget(product: product, quantity: 0)
            target.updatedAt = Date()
            pendingTargets[product.id] = target
        }

        savePendingTargets()
        updateQueueStateAfterLocalChange()
        startQueueProcessing()
    }

    func applyCoupon(_ code: String) {
        let normalizedCode = code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !normalizedCode.isEmpty else { return }

        guard !hasUsedCoupon(normalizedCode) else {
            lastError = "Bu kuponu daha önce kullandınız. Her kupon tek sefer kullanılabilir."
            return
        }

        cart.couponCode = normalizedCode
        markLocalPricingDirty()
        Task {
            do {
                _ = try await apiClient.request(Endpoint.applyCoupon(code: normalizedCode)) as EmptyResponse
                try await self.refreshCart()
                self.lastError = nil
            } catch {
                self.cart.couponCode = nil
                self.lastError = error.kgmUserMessage
                try? await self.refreshCart()
            }
        }
    }

    func removeCoupon() {
        cart.couponCode = nil
        cart.discountAmount = 0
        markLocalPricingDirty()
        Task {
            do {
                _ = try await apiClient.request(Endpoint.removeCoupon) as EmptyResponse
                try await self.refreshCart()
                self.lastError = nil
            } catch {
                self.lastError = error.kgmUserMessage
                try? await self.refreshCart()
            }
        }
    }

    func retryPendingSync() {
        startQueueProcessing(force: true)
    }


    func replaceLocalCart(_ newCart: Cart) {
        cart = newCart
        normalizeCartForLocalDisplay()
        pendingTargets.removeAll()
        savePendingTargets()
        lastError = nil
        syncState = .idle
        pendingSyncCount = 0
    }



    func hasUsedCoupon(_ code: String) -> Bool {
        loadUsedCoupons().contains(normalizeCouponCode(code))
    }

    func markCouponUsedAfterSuccessfulCheckout(_ code: String?) {
        let normalized = normalizeCouponCode(code ?? "")
        guard !normalized.isEmpty else { return }
        var used = loadUsedCoupons()
        used.insert(normalized)
        UserDefaults.standard.set(Array(used).sorted(), forKey: usedCouponsStorageKey)
    }

    func completeCheckoutAndClearLocalCart() {
        markCouponUsedAfterSuccessfulCheckout(cart.couponCode)
        pendingTargets.removeAll()
        savePendingTargets()
        retryTask?.cancel()
        retryTask = nil
        let retainedToken: String? = nil
        KeychainManager.shared.clearCartToken()
        cart = Cart(items: [], cartToken: retainedToken, couponCode: nil, discountAmount: 0, deliveryFee: 0)
        lastError = nil
        syncState = .idle
        pendingSyncCount = 0
    }

    private func normalizeCouponCode(_ code: String) -> String {
        code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
    }

    private func loadUsedCoupons() -> Set<String> {
        let values = UserDefaults.standard.stringArray(forKey: usedCouponsStorageKey) ?? []
        return Set(values.map(normalizeCouponCode).filter { !$0.isEmpty })
    }

    func hasPendingChange(for productId: String) -> Bool {
        pendingTargets[productId] != nil
    }

    func cartItem(for productId: String) -> CartItem? {
        cart.items.first { $0.product.id == productId }
    }

    func isInCart(_ productId: String) -> Bool {
        cart.items.contains { $0.product.id == productId }
    }

    func quantityInCart(_ productId: String) -> Int {
        cart.items.first { $0.product.id == productId }?.quantity ?? 0
    }

    func maxAllowedQuantity(for product: Product) -> Int {
        if product.stockQuantity > 0 { return product.stockQuantity }
        if product.isInStock { return fallbackMaxQuantity }
        return 0
    }

    private func setLocalTarget(product: Product, quantity: Int) {
        let safeQuantity = max(0, quantity)
        if safeQuantity > 0 {
            upsertLocalItem(product: product, quantity: safeQuantity)
        } else {
            cart.items.removeAll { $0.product.id == product.id }
        }
        markLocalPricingDirty()

        var target = CartSyncPendingTarget(product: product, quantity: safeQuantity)
        target.updatedAt = Date()
        pendingTargets[product.id] = target
        savePendingTargets()
        updateQueueStateAfterLocalChange()
        startQueueProcessing()
    }

    private func removeLocalProduct(_ product: Product) {
        cart.items.removeAll { $0.product.id == product.id }
        markLocalPricingDirty()

        var target = CartSyncPendingTarget(product: product, quantity: 0)
        target.updatedAt = Date()
        pendingTargets[product.id] = target
        savePendingTargets()
        updateQueueStateAfterLocalChange()
        startQueueProcessing()
    }

    private func upsertLocalItem(product: Product, quantity: Int) {
        if let index = cart.items.firstIndex(where: { $0.product.id == product.id }) {
            cart.items[index].quantity = quantity
            cart.items[index].product = product
            cart.items[index].lineTotalCents = nil
        } else {
            let item = CartItem(id: "local-\(UUID().uuidString)", product: product, quantity: quantity, lineTotalCents: nil)
            cart.items.append(item)
        }
    }

    private func startQueueProcessing(force: Bool = false) {
        retryTask?.cancel()
        retryTask = nil
        guard !pendingTargets.isEmpty else {
            syncState = .idle
            pendingSyncCount = 0
            return
        }
        if isProcessingQueue && !force { return }
        Task { await self.processQueue() }
    }

    private func processQueue() async {
        guard !isProcessingQueue else { return }
        guard !pendingTargets.isEmpty else {
            syncState = .idle
            pendingSyncCount = 0
            return
        }

        isProcessingQueue = true
        syncState = .syncing
        defer {
            isProcessingQueue = false
            updateQueueStateAfterLocalChange()
        }

        var serverCart: Cart
        do {
            serverCart = try await apiClient.request(Endpoint.getCart)
        } catch {
            handleQueueFailure(error)
            return
        }

        while let target = nextPendingTarget() {
            do {
                serverCart = try await apply(target: target, to: serverCart)
                pendingTargets.removeValue(forKey: target.productId)
                savePendingTargets()
                pendingSyncCount = pendingTargets.count
                cart = serverCart
                normalizeCartForLocalDisplay()
                replayLocalPendingTargets()
                lastError = nil
            } catch {
                if isPermanentCartSyncError(error) {
                    pendingTargets.removeValue(forKey: target.productId)
                    savePendingTargets()
                    pendingSyncCount = pendingTargets.count
                    lastError = error.kgmUserMessage
                    if let refreshed: Cart = try? await apiClient.request(Endpoint.getCart) {
                        serverCart = refreshed
                        cart = refreshed
                        normalizeCartForLocalDisplay()
                        replayLocalPendingTargets()
                    }
                    continue
                }

                handleQueueFailure(error)
                return
            }
        }

        cart = serverCart
        normalizeCartForLocalDisplay()
        lastError = nil
        syncState = .idle
    }

    private func nextPendingTarget() -> CartSyncPendingTarget? {
        pendingTargets.values.sorted { $0.updatedAt < $1.updatedAt }.first
    }

    private func apply(target: CartSyncPendingTarget, to serverCart: Cart) async throws -> Cart {
        guard target.productId.numericProductID != nil else {
            throw APIError.backend(message: "Ürün seçimi geçersiz.", code: "validation")
        }

        if target.quantity <= 0 {
            guard let serverItem = serverItem(in: serverCart, productId: target.productId) else {
                return serverCart
            }
            let updated: Cart = try await apiClient.request(Endpoint.removeFromCart(itemId: serverItem.id))
            return updated
        }

        if let serverItem = serverItem(in: serverCart, productId: target.productId) {
            if serverItem.quantity == target.quantity {
                return serverCart
            }
            do {
                let updated: Cart = try await apiClient.request(Endpoint.updateCartItem(itemId: serverItem.id, UpdateCartItemRequest(quantity: target.quantity)))
                return updated
            } catch APIError.notFound {
                let request = AddCartItemRequest(productId: target.productId, quantity: target.quantity)
                let updated: Cart = try await apiClient.request(Endpoint.addToCart(request))
                return updated
            }
        }

        let request = AddCartItemRequest(productId: target.productId, quantity: target.quantity)
        let updated: Cart = try await apiClient.request(Endpoint.addToCart(request))
        return updated
    }

    private func serverItem(in cart: Cart, productId: String) -> CartItem? {
        cart.items.first { $0.product.id == productId && !$0.id.hasPrefix("local-") }
    }

    private func handleQueueFailure(_ error: Error) {
        let message = error.kgmUserMessage
        lastError = message
        syncState = .waitingConnection(message)
        scheduleRetry()
    }

    private func scheduleRetry() {
        retryTask?.cancel()
        retryTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 10_000_000_000)
            await MainActor.run {
                self?.startQueueProcessing(force: true)
            }
        }
    }

    private func isPermanentCartSyncError(_ error: Error) -> Bool {
        switch error {
        case APIError.notFound:
            return true
        case APIError.backend(_, let code), APIError.backendWithCorrelation(_, let code, _):
            let c = code?.lowercased() ?? ""
            return c.contains("stock") || c.contains("validation") || c.contains("invalid")
        default:
            return false
        }
    }

    private func normalizeCartForLocalDisplay() {
        for index in cart.items.indices {
            if cart.items[index].quantity < 1 {
                cart.items[index].quantity = 1
            }
        }
    }

    private func markLocalPricingDirty() {
        cart.subtotalCents = nil
        cart.totalCents = nil
        for index in cart.items.indices {
            cart.items[index].lineTotalCents = nil
        }
    }

    private func replayLocalPendingTargets() {
        guard !pendingTargets.isEmpty else { return }
        for target in pendingTargets.values.sorted(by: { $0.updatedAt < $1.updatedAt }) {
            if target.quantity <= 0 {
                cart.items.removeAll { $0.product.id == target.productId }
            } else {
                upsertLocalItem(product: target.productSnapshot, quantity: target.quantity)
            }
        }
        markLocalPricingDirty()
    }

    private func updateQueueStateAfterLocalChange() {
        pendingSyncCount = pendingTargets.count
        if pendingTargets.isEmpty {
            syncState = .idle
        } else if !isProcessingQueue {
            switch syncState {
            case .waitingConnection:
                break
            default:
                syncState = .queued
            }
        }
    }

    private func loadPendingTargets() {
        guard let data = UserDefaults.standard.data(forKey: pendingTargetsStorageKey),
              let decoded = try? JSONDecoder().decode([CartSyncPendingTarget].self, from: data)
        else {
            pendingTargets = [:]
            pendingSyncCount = 0
            return
        }
        pendingTargets = Dictionary(uniqueKeysWithValues: decoded.map { ($0.productId, $0) })
        pendingSyncCount = pendingTargets.count
    }

    private func savePendingTargets() {
        let values = pendingTargets.values.sorted { $0.updatedAt < $1.updatedAt }
        if values.isEmpty {
            UserDefaults.standard.removeObject(forKey: pendingTargetsStorageKey)
            return
        }
        if let data = try? JSONEncoder().encode(values) {
            UserDefaults.standard.set(data, forKey: pendingTargetsStorageKey)
        }
    }
}

private extension String {
    var numericProductID: Int64? { Int64(self) }
}
