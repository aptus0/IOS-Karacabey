import SwiftUI
import Combine
import UserNotifications

@MainActor
final class OrdersViewModel: ObservableObject {
    @Published var orders: [Order] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    func load() async {
        isLoading = true
        errorMessage = nil
        do {
            orders = try await OrderRepository.shared.getOrders()
            let trackedOrder = orders.first(where: { $0.status != .delivered && $0.status != .cancelled }) ?? orders.first
            WidgetSnapshotStore.save(order: trackedOrder.map {
                WidgetOrderSnapshot(
                    orderId: $0.id,
                    title: "Sipariş #\($0.orderNumber)",
                    status: $0.status,
                    estimatedDeliveryAt: $0.estimatedDelivery,
                    updatedAt: $0.shipment?.updatedAt ?? Date(),
                    deepLink: "kgm://orders/\($0.id)"
                )
            })
            await LiveActivityManager.shared.reconcile(orders: orders)
            await KGMOrderStatusNotifier.syncAndNotify(orders: orders)
        } catch {
            errorMessage = error.kgmUserMessage
        }
        isLoading = false
    }
}

private enum KGMOrderStatusNotifier {
    private static let snapshotKey = "kgm.order.status.snapshot.v1"

    static func syncAndNotify(orders: [Order]) async {
        let previous = loadSnapshot()
        var current: [String: String] = [:]

        for order in orders {
            current[order.id] = order.status.rawValue
            guard let oldStatus = previous[order.id], oldStatus != order.status.rawValue else { continue }
            await sendStatusNotification(for: order)
        }

        saveSnapshot(current)
    }

    private static func loadSnapshot() -> [String: String] {
        guard let data = UserDefaults.standard.data(forKey: snapshotKey),
              let snapshot = try? JSONDecoder().decode([String: String].self, from: data) else {
            return [:]
        }
        return snapshot
    }

    private static func saveSnapshot(_ snapshot: [String: String]) {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        UserDefaults.standard.set(data, forKey: snapshotKey)
    }

    private static func sendStatusNotification(for order: Order) async {
        let content = UNMutableNotificationContent()
        content.title = "Siparişiniz \(order.status.displayName)"
        content.body = "Sipariş #\(order.orderNumber) durumu güncellendi. Detayları Siparişlerim ekranından takip edebilirsiniz."
        content.sound = UNNotificationSound(named: UNNotificationSoundName(rawValue: "kgm_notification.caf"))
        content.categoryIdentifier = "KGM_RICH_NOTIFICATION"
        content.userInfo = [
            "deep_link": "kgm://orders/\(order.id)",
            "order_id": order.id,
            "order_number": order.orderNumber,
            "status": order.status.rawValue
        ]

        let identifier = "kgm-order-\(order.id)-\(order.status.rawValue)"
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: nil)
        try? await UNUserNotificationCenter.current().add(request)
    }
}


struct OrdersView: View {
    var initialOrderID: String? = nil
    @StateObject private var vm = OrdersViewModel()
    @State private var selectedOrder: Order? = nil

    var body: some View {
        Group {
            if vm.isLoading {
                KGMLoadingView()
            } else if let errorMessage = vm.errorMessage {
                KGMErrorView(message: errorMessage) {
                    Task { await vm.load() }
                }
            } else if vm.orders.isEmpty {
                KGMEmptyStateView(icon: "bag.circle", title: "Henüz Sipariş Yok",
                                  message: "İlk siparişinizi vermek için alışverişe başlayın.")
            } else {
                List {
                    ForEach(vm.orders) { order in
                        OrderRow(order: order)
                            .onTapGesture { selectedOrder = order }
                            .listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .background(Color.kgmBackground)
            }
        }
        .background(Color.kgmBackground.ignoresSafeArea())
        .navigationTitle("Siparişlerim")
        .navigationBarTitleDisplayMode(.large)
        .navigationDestination(item: $selectedOrder) { order in
            OrderDetailView(order: order) {
                Task { await vm.load() }
            }
        }
        .task { await vm.load() }
        .onChange(of: vm.orders) { _, orders in
            guard selectedOrder == nil, let initialOrderID else { return }
            selectedOrder = orders.first(where: { $0.id == initialOrderID })
        }
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 30_000_000_000)
                guard !Task.isCancelled else { return }
                await vm.load()
            }
        }
        .refreshable { await vm.load() }
        .onReceive(NotificationCenter.default.publisher(for: .kgmPushNotificationReceived)) { _ in
            Task { await vm.load() }
        }
    }
}

struct OrderRow: View {
    let order: Order

    var statusColor: Color {
        switch order.status {
        case .pending:    return Color.kgmWarning
        case .awaitingPayment: return Color.kgmWarning
        case .reviewing:  return Color.kgmInfo
        case .received:   return Color.kgmInfo
        case .preparing:  return Color.kgmWarning
        case .onTheWay:   return Color.kgmInfo
        case .delivered:  return Color.kgmPrimary
        case .cancelled:  return Color.kgmSecondary
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: KGMSpacing.sm) {
            HStack {
                Text(order.orderNumber).font(.kgmBodyMedium)
                Spacer()
                Text(order.status.displayName)
                    .font(.kgmCaptionMedium)
                    .foregroundColor(.white)
                    .padding(.horizontal, KGMSpacing.sm)
                    .padding(.vertical, 4)
                    .background(statusColor)
                    .cornerRadius(KGMRadius.full)
            }
            Text(order.createdAt, style: .date).font(.kgmCaption).foregroundColor(.secondary)
            Text("\(order.items.count) ürün • \(order.total.formattedAsTurkishLira)")
                .font(.kgmCallout).foregroundColor(.secondary)
            HStack(spacing: KGMSpacing.xs) {
                ForEach(order.items.prefix(3)) { item in
                    KGMProductImage(
                        url: item.product.resolvedImageURL,
                        height: 40,
                        cornerRadius: KGMRadius.sm,
                        horizontalPadding: 3,
                        verticalPadding: 3,
                        zoom: 1.04,
                        backgroundColor: .white
                    )
                    .frame(width: 40)
                }
                if order.items.count > 3 {
                    Text("+\(order.items.count - 3)").font(.kgmSmall).foregroundColor(.secondary)
                }
            }
        }
        .padding(KGMSpacing.base)
        .background(Color.kgmCard)
        .cornerRadius(KGMRadius.md)
        .overlay(RoundedRectangle(cornerRadius: KGMRadius.md).stroke(Color.kgmBorder))
    }
}

struct OrderDetailView: View {
    private let initialOrder: Order
    var onCancelled: () -> Void = {}
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @EnvironmentObject private var cartRepo: CartRepository
    @EnvironmentObject private var appState: AppState
    @State private var liveOrder: Order
    @State private var isRefreshingDetail = false
    @State private var showCancelConfirmation = false
    @State private var isCancelling = false
    @State private var cancellationError: String?
    @State private var isReordering = false
    @State private var reorderMessage: String?

    init(order: Order, onCancelled: @escaping () -> Void = {}) {
        self.initialOrder = order
        self.onCancelled = onCancelled
        _liveOrder = State(initialValue: order)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: KGMSpacing.sm) {
                if isRefreshingDetail {
                    HStack(spacing: KGMSpacing.sm) {
                        ProgressView().tint(.kgmPrimary)
                        Text("Sipariş güncel durumu alınıyor")
                            .font(.kgmCaptionMedium)
                            .foregroundColor(.kgmTextSecondary)
                    }
                    .padding(KGMSpacing.sm)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.kgmCard)
                    .clipShape(RoundedRectangle(cornerRadius: KGMRadius.md))
                    .padding(.horizontal, KGMSpacing.base)
                }

                // Status Timeline
                VStack(alignment: .leading, spacing: KGMSpacing.sm) {
                    Text("Sipariş Durumu").font(.kgmHeadline).padding(.horizontal, KGMSpacing.base)
                    KGMOrderStatusTimeline(order: liveOrder)
                        .background(Color.kgmCard)
                        .cornerRadius(KGMRadius.md)
                }
                .padding(.horizontal, KGMSpacing.base)

                if liveOrder.status == .reviewing {
                    VStack(alignment: .leading, spacing: KGMSpacing.sm) {
                        Label("Siparişiniz Kontrol Ediliyor", systemImage: "checkmark.shield.fill")
                            .font(.kgmHeadline)
                            .foregroundColor(.kgmInfo)
                        Text("Mağaza siparişinizi kontrol ediyor. Onaylandığında bildirim başlığında sipariş numaranızla birlikte haber vereceğiz.")
                            .font(.kgmCallout)
                            .foregroundColor(.kgmTextSecondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(KGMSpacing.base)
                    .background(Color.kgmInfo.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: KGMRadius.md))
                    .overlay(RoundedRectangle(cornerRadius: KGMRadius.md).stroke(Color.kgmInfo.opacity(0.20)))
                    .padding(.horizontal, KGMSpacing.base)
                }

                if let shipment = liveOrder.shipment {
                    shipmentCard(shipment)
                        .padding(.horizontal, KGMSpacing.base)
                }

                // Items
                VStack(alignment: .leading, spacing: KGMSpacing.sm) {
                    Text("Ürünler").font(.kgmHeadline)
                    ForEach(liveOrder.items) { item in
                        HStack {
                            KGMProductImage(
                                url: item.product.resolvedImageURL,
                                height: 50,
                                cornerRadius: KGMRadius.sm,
                                horizontalPadding: 4,
                                verticalPadding: 4,
                                zoom: 1.04,
                                backgroundColor: .white
                            )
                            .frame(width: 50)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.product.name).font(.kgmCallout).lineLimit(2)
                                Text("\(item.quantity)x \(item.product.effectivePrice.formattedAsTurkishLira)").font(.kgmCaption).foregroundColor(.secondary)
                            }
                            Spacer()
                            Text(item.totalPrice.formattedAsTurkishLira).font(.kgmBodyMedium).foregroundColor(Color.kgmPrimary)
                        }
                    }
                }
                .padding(KGMSpacing.base)
                .background(Color.kgmCard)
                .cornerRadius(KGMRadius.md)
                .overlay(RoundedRectangle(cornerRadius: KGMRadius.md).stroke(Color.kgmBorder))
                .padding(.horizontal, KGMSpacing.base)

                // Address
                VStack(alignment: .leading, spacing: KGMSpacing.sm) {
                    Text("Teslimat Adresi").font(.kgmHeadline)
                    KGMAddressCard(address: liveOrder.deliveryAddress)
                }
                .padding(KGMSpacing.base)
                .background(Color.kgmCard)
                .cornerRadius(KGMRadius.md)
                .overlay(RoundedRectangle(cornerRadius: KGMRadius.md).stroke(Color.kgmBorder))
                .padding(.horizontal, KGMSpacing.base)

                // Summary
                VStack(spacing: KGMSpacing.sm) {
                    summaryRow("Ara Toplam", liveOrder.subtotal.formattedAsTurkishLira)
                    summaryRow("Teslimat", liveOrder.deliveryFee == 0 ? "Ücretsiz" : liveOrder.deliveryFee.formattedAsTurkishLira)
                    if liveOrder.discountAmount > 0 {
                        summaryRow("İndirim", "-\(liveOrder.discountAmount.formattedAsTurkishLira)")
                    }
                    Divider()
                    summaryRow("Toplam", liveOrder.total.formattedAsTurkishLira, isTotal: true)
                }
                .padding(KGMSpacing.base)
                .background(Color.kgmCard)
                .cornerRadius(KGMRadius.md)
                .overlay(RoundedRectangle(cornerRadius: KGMRadius.md).stroke(Color.kgmBorder))
                .padding(.horizontal, KGMSpacing.base)

                VStack(spacing: KGMSpacing.sm) {
                    KGMButton(
                        "Tekrar Sipariş Ver",
                        style: .primary,
                        isLoading: isReordering
                    ) {
                        Task { await reorderCurrentOrder() }
                    }

                    if let reorderMessage {
                        Text(reorderMessage)
                            .font(.kgmCaptionMedium)
                            .foregroundColor(.kgmTextSecondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(KGMSpacing.sm)
                            .background(Color.kgmPrimary.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: KGMRadius.md))
                    }
                }
                .padding(.horizontal, KGMSpacing.base)

                if liveOrder.status == .pending {
                    KGMButton(
                        "Siparişi İptal Et",
                        style: .destructive,
                        isLoading: isCancelling
                    ) {
                        showCancelConfirmation = true
                    }
                    .padding(.horizontal, KGMSpacing.base)
                }

                Spacer(minLength: KGMSpacing.xxl)
            }
            .padding(.top, KGMSpacing.sm)
        }
        .background(Color.kgmBackground.ignoresSafeArea())
        .navigationTitle("Sipariş #\(liveOrder.orderNumber)")
        .navigationBarTitleDisplayMode(.inline)
        .task { await refreshOrderDetail() }
        .refreshable { await refreshOrderDetail() }
        .onReceive(NotificationCenter.default.publisher(for: .kgmPushNotificationReceived)) { _ in
            Task { await refreshOrderDetail() }
        }
        .alert("Siparişi İptal Et", isPresented: $showCancelConfirmation) {
            Button("İptal Et", role: .destructive) {
                Task { await cancelOrder() }
            }
            Button("Vazgeç", role: .cancel) {}
        } message: {
            Text("Bu işlem yalnızca henüz işleme alınmamış siparişler için uygulanabilir.")
        }
        .alert("Sipariş iptal edilemedi", isPresented: Binding(
            get: { cancellationError != nil },
            set: { if !$0 { cancellationError = nil } }
        )) {
            Button("Tamam", role: .cancel) {}
        } message: {
            Text(cancellationError ?? "Lütfen tekrar deneyin.")
        }
    }

    private func shipmentCard(_ shipment: Shipment) -> some View {
        VStack(alignment: .leading, spacing: KGMSpacing.sm) {
            HStack {
                Label("Kargo Takibi", systemImage: "shippingbox.fill")
                    .font(.kgmHeadline)
                Spacer()
                Text(shipment.status.displayName)
                    .font(.kgmCaptionMedium)
                    .foregroundColor(.kgmPrimary)
            }
            Text(shipment.carrier)
                .font(.kgmBodyMedium)
            if let trackingNumber = shipment.trackingNumber {
                Text("Takip No: \(trackingNumber)")
                    .font(.kgmCaption)
                    .foregroundColor(.kgmTextSecondary)
                    .textSelection(.enabled)
            }
            if let trackingURL = shipment.trackingURL, let url = URL(string: trackingURL) {
                Button("Kargo hareketlerini aç") { openURL(url) }
                    .font(.kgmCaptionMedium)
                    .foregroundColor(.kgmPrimary)
            }
        }
        .padding(KGMSpacing.base)
        .background(Color.kgmPrimary.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: KGMRadius.md))
        .overlay(RoundedRectangle(cornerRadius: KGMRadius.md).stroke(Color.kgmPrimary.opacity(0.20)))
    }

    private func refreshOrderDetail() async {
        guard !isRefreshingDetail else { return }
        isRefreshingDetail = true
        defer { isRefreshingDetail = false }
        do {
            liveOrder = try await OrderRepository.shared.getOrder(id: liveOrder.id)
        } catch {
            // Liste ekranındaki son bilinen sipariş verisi kullanıcıda kalır; teknik hata gösterilmez.
        }
    }

    private func cancelOrder() async {
        isCancelling = true
        defer { isCancelling = false }
        do {
            try await OrderRepository.shared.cancelOrder(id: liveOrder.id)
            onCancelled()
            dismiss()
        } catch {
            cancellationError = error.kgmUserMessage
        }
    }


    private func reorderCurrentOrder() async {
        guard !isReordering else { return }
        isReordering = true
        reorderMessage = nil
        defer { isReordering = false }
        do {
            let response = try await OrderRepository.shared.reorder(id: liveOrder.id)
            if let cart = response.cart {
                cartRepo.replaceLocalCart(cart)
            } else {
                try? await cartRepo.refreshCart()
            }
            reorderMessage = response.message ?? "Sipariş ürünleri sepetinize eklendi."
            appState.showToast(reorderMessage ?? "Sepetiniz güncellendi")
            appState.selectedTab = .cart
        } catch {
            reorderMessage = error.kgmUserMessage
        }
    }

    private func summaryRow(_ label: String, _ value: String, isTotal: Bool = false) -> some View {
        HStack {
            Text(label).font(isTotal ? .kgmHeadline : .kgmBody).foregroundColor(isTotal ? .primary : .secondary)
            Spacer()
            Text(value).font(isTotal ? .kgmHeadline : .kgmBody).foregroundColor(isTotal ? Color.kgmPrimary : .primary)
        }
    }
}
