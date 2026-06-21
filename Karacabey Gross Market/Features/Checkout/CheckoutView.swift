import SwiftUI
import Combine

enum KGMCheckoutRules {
    nonisolated static let minimumSubtotal: Double = 350
    nonisolated static var minimumSubtotalDisplay: String {
        String(format: "₺%.2f", minimumSubtotal).replacingOccurrences(of: ".", with: ",")
    }
    nonisolated static var minimumSubtotalShortLabel: String {
        "\(Int(minimumSubtotal)) TL"
    }

    nonisolated static func meetsMinimum(_ subtotal: Double) -> Bool {
        subtotal >= minimumSubtotal
    }

    nonisolated static func isKaracabeyAddress(_ address: Address?) -> Bool {
        guard let address else { return false }
        return normalized(address.city).contains("bursa") && normalized(address.district).contains("karacabey")
    }

    nonisolated private static func normalized(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "ı", with: "i")
            .replacingOccurrences(of: "ş", with: "s")
            .replacingOccurrences(of: "ğ", with: "g")
            .replacingOccurrences(of: "ü", with: "u")
            .replacingOccurrences(of: "ö", with: "o")
            .replacingOccurrences(of: "ç", with: "c")
    }
}

@MainActor
final class CheckoutViewModel: ObservableObject {
    @Published var selectedAddress: Address? = nil
    @Published var deliveryNote = ""
    @Published var kvkkAccepted = false
    @Published var contractAccepted = false
    @Published var isLoading = false
    @Published var completedOrder: Order? = nil
    @Published var checkoutSession: CheckoutSessionResponse? = nil
    @Published var errorMessage: String? = nil
    @Published var showAddressSheet = false

    @Published private(set) var availableAddresses: [Address] = []

    func canPlaceOrder(cart: Cart) -> Bool {
        !cart.items.isEmpty &&
        KGMCheckoutRules.meetsMinimum(cart.subtotal) &&
        selectedAddress != nil &&
        kvkkAccepted &&
        contractAccepted
    }

    func nextRequirementMessage(cart: Cart) -> String? {
        if cart.items.isEmpty { return "Sepetiniz boş." }
        if !KGMCheckoutRules.meetsMinimum(cart.subtotal) {
            return "Servis için minimum sepet tutarı \(KGMCheckoutRules.minimumSubtotalDisplay) olmalıdır."
        }
        if selectedAddress == nil { return "Devam etmek için teslimat adresi seçin." }
        if !kvkkAccepted || !contractAccepted { return "Devam etmek için KVKK ve satış sözleşmesi onaylarını verin." }
        return nil
    }

    func loadCheckoutData() async {
        await reloadAddresses()
    }

    func reloadAddresses() async {
        do {
            let addresses = try await AddressRepository.shared.getAddresses()
            availableAddresses = addresses
            if let selectedAddress, addresses.contains(where: { $0.id == selectedAddress.id }) {
                self.selectedAddress = addresses.first(where: { $0.id == selectedAddress.id }) ?? selectedAddress
            } else {
                selectedAddress = addresses.first(where: { $0.isDefault }) ?? addresses.first
            }
        } catch {
            errorMessage = error.kgmUserMessage
        }
    }

    func saveAddress(_ address: Address, isNew: Bool) async -> Bool {
        errorMessage = nil
        do {
            var saved = isNew
                ? try await AddressRepository.shared.addAddress(address)
                : try await AddressRepository.shared.updateAddress(address)
            if saved.latitude == nil { saved.latitude = address.latitude }
            if saved.longitude == nil { saved.longitude = address.longitude }

            if isNew {
                availableAddresses.append(saved)
            } else if let idx = availableAddresses.firstIndex(where: { $0.id == saved.id }) {
                availableAddresses[idx] = saved
            }

            if saved.isDefault {
                availableAddresses = availableAddresses.map { item in
                    var copy = item
                    copy.isDefault = copy.id == saved.id
                    return copy
                }
            }

            selectedAddress = saved
            return true
        } catch {
            errorMessage = error.kgmUserMessage
            return false
        }
    }

    func deleteAddress(_ address: Address) async {
        errorMessage = nil
        do {
            try await AddressRepository.shared.deleteAddress(id: address.id)
            availableAddresses.removeAll { $0.id == address.id }
            if selectedAddress?.id == address.id {
                selectedAddress = availableAddresses.first(where: { $0.isDefault }) ?? availableAddresses.first
            }
        } catch {
            errorMessage = error.kgmUserMessage
        }
    }

    func setDefaultAddress(_ address: Address) async {
        errorMessage = nil
        do {
            try await AddressRepository.shared.setDefaultAddress(id: address.id)
            availableAddresses = availableAddresses.map { item in
                var copy = item
                copy.isDefault = copy.id == address.id
                return copy
            }
            selectedAddress = availableAddresses.first(where: { $0.id == address.id }) ?? address
        } catch {
            errorMessage = error.kgmUserMessage
        }
    }

    func placeOrder(cart: Cart, user: User?, paymentFlow: String) async {
        guard let address = selectedAddress else { errorMessage = "Lütfen teslimat adresi seçin."; return }
        guard !cart.items.isEmpty else { errorMessage = "Sepetiniz boş."; return }
        guard cart.items.allSatisfy({ $0.quantity > 0 }) else { errorMessage = "Sepette geçersiz ürün adedi var."; return }
        guard cart.total > 0 else { errorMessage = "Ödeme tutarı geçersiz."; return }
        guard KGMCheckoutRules.meetsMinimum(cart.subtotal) else {
            errorMessage = "Servis için minimum sepet tutarı \(KGMCheckoutRules.minimumSubtotalDisplay) olmalıdır."
            return
        }
        if paymentFlow == "cash_on_delivery" && !KGMCheckoutRules.isKaracabeyAddress(address) {
            errorMessage = "Kapıda ödeme yalnızca Bursa / Karacabey teslimat adreslerinde kullanılabilir."
            return
        }
        guard kvkkAccepted && contractAccepted else { errorMessage = "Devam etmek için onayları vermelisiniz."; return }
        isLoading = true
        errorMessage = nil
        do {
            let session = try await OrderRepository.shared.createCheckoutSession(
                cart: cart,
                address: address,
                user: user,
                couponCode: cart.couponCode,
                paymentFlow: paymentFlow
            )
            await LiveActivityManager.shared.start(
                orderID: session.orderID,
                orderNumber: session.orderID
            )

            if session.isCashOnDelivery {
                checkoutSession = session
            } else if session.paymentUnavailable == true || (session.paymentURL == nil && session.directPayment == nil) {
                errorMessage = session.message ?? session.providerReason ?? "PayTR ödeme başlatılamadı."
            } else {
                checkoutSession = session
            }
        } catch {
            errorMessage = error.kgmUserMessage
        }
        isLoading = false
    }
}

private enum CheckoutPaymentOption: String, CaseIterable, Identifiable {
    case card
    case wallet
    case transfer
    case cash

    var id: String { rawValue }

    var title: String {
        switch self {
        case .card: return "Kredi / Banka Kartı"
        case .wallet: return "Mobil Cüzdan"
        case .transfer: return "Havale / EFT"
        case .cash: return "Kapıda Ödeme"
        }
    }

    var subtitle: String {
        switch self {
        case .card: return "Visa, Mastercard, Troy"
        case .wallet: return "Apple Pay, Google Pay"
        case .transfer: return "Banka hesabına havale"
        case .cash: return "Bursa / Karacabey'de nakit, kart veya yemek kartı"
        }
    }

    var icon: String {
        switch self {
        case .card: return "creditcard.fill"
        case .wallet: return "iphone.gen3"
        case .transfer: return "building.columns.fill"
        case .cash: return "wallet.pass.fill"
        }
    }

    var paymentFlow: String {
        self == .cash ? "cash_on_delivery" : "direct"
    }

    func isEnabled(for address: Address?) -> Bool {
        switch self {
        case .card: return true
        case .cash: return KGMCheckoutRules.isKaracabeyAddress(address)
        case .wallet, .transfer: return false
        }
    }

    func badge(for address: Address?) -> String? {
        switch self {
        case .card: return "Tavsiye Edilen"
        case .cash: return isEnabled(for: address) ? "Karacabey" : "Sadece Karacabey"
        case .wallet, .transfer: return "Yakında"
        }
    }
}

private enum CheckoutStepState {
    case complete
    case current
    case pending
}

struct CheckoutView: View {
    @StateObject private var vm = CheckoutViewModel()
    @EnvironmentObject var cartRepo: CartRepository
    @EnvironmentObject var appState: AppState
    @State private var selectedPaymentOption: CheckoutPaymentOption = .card
    @State private var cardForm = PayTRCardForm()
    @State private var paymentResult: PayTRPaymentResult? = nil
    @State private var selectedLegalDocument: LegalDocument?

    var body: some View {
        Group {
            if let order = vm.completedOrder {
                OrderSuccessView(
                    order: order,
                    onViewOrders: { appState.openProfile(.orders) },
                    onDone: { appState.selectedTab = .home }
                )
            } else {
                checkoutForm
            }
        }
        .navigationTitle("Ödeme")
        .navigationBarTitleDisplayMode(.inline)
        .task { await vm.loadCheckoutData() }
        .fullScreenCover(item: $vm.checkoutSession, onDismiss: { paymentResult = nil }) { session in
            paymentSheet(for: session)
        }
        .sheet(isPresented: $vm.showAddressSheet) {
            NavigationStack {
                CheckoutAddressPickerView(vm: vm)
            }
        }
        .sheet(item: $selectedLegalDocument) { document in
            NavigationStack {
                LegalDetailView(document: document)
            }
        }
        .onChange(of: vm.selectedAddress) { _, address in
            if !selectedPaymentOption.isEnabled(for: address) {
                selectedPaymentOption = .card
            }
        }
    }

    private var checkoutForm: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: KGMSpacing.md) {
                checkoutStepper
                    .padding(.top, KGMSpacing.base)

                deliveryCard
                productsCard
                paymentMethodsCard
                orderNoteCard
                agreementsCard
                orderSummaryCard

                if let error = vm.errorMessage {
                    Label(error, systemImage: "exclamationmark.circle.fill")
                        .font(.kgmCaption)
                        .foregroundColor(Color.kgmError)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, KGMSpacing.base)
                }

                if let requirement = vm.nextRequirementMessage(cart: cartRepo.cart) {
                    Label(requirement, systemImage: "info.circle.fill")
                        .font(.kgmCaption)
                        .foregroundColor(.kgmTextSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, KGMSpacing.base)
                }
            }
            .padding(.bottom, 132)
        }
        .background(Color.kgmBackground.ignoresSafeArea())
        .safeAreaInset(edge: .bottom) { bottomPaymentBar }
        .overlay { if vm.isLoading { KGMLoadingOverlay() } }
    }

    private var checkoutStepper: some View {
        HStack(spacing: KGMSpacing.sm) {
            stepItem(number: "1", title: "Sepet", state: .complete)
            stepLine(isActive: true)
            stepItem(number: "2", title: "Ödeme", state: .current)
            stepLine(isActive: vm.canPlaceOrder(cart: cartRepo.cart))
            stepItem(number: "3", title: "Onay", state: .pending)
        }
        .padding(.horizontal, KGMSpacing.base)
    }

    private var deliveryCard: some View {
        sectionCard {
            HStack(alignment: .center, spacing: KGMSpacing.md) {
                ZStack {
                    RoundedRectangle(cornerRadius: KGMRadius.md)
                        .fill(Color.kgmPrimary.opacity(0.1))
                    Image(systemName: "mappin.circle.fill")
                        .font(.system(size: 34, weight: .semibold))
                        .foregroundColor(Color.kgmPrimary)
                }
                .frame(width: 74, height: 74)

                VStack(alignment: .leading, spacing: 5) {
                    Text("Teslimat Adresi")
                        .font(.kgmHeadline)
                        .foregroundColor(.kgmTextPrimary)
                    if let address = vm.selectedAddress {
                        Text(address.title)
                            .font(.kgmBodyMedium)
                            .foregroundColor(.kgmPrimary)
                        Text(address.fullAddress)
                            .font(.kgmCallout)
                            .foregroundColor(.kgmTextSecondary)
                            .lineLimit(3)
                    } else {
                        Text("Siparişi tamamlamak için adres seçin.")
                            .font(.kgmCallout)
                            .foregroundColor(.kgmTextSecondary)
                    }
                }
                Spacer(minLength: KGMSpacing.xs)
                Button {
                    vm.showAddressSheet = true
                } label: {
                    HStack(spacing: 4) {
                        Text(vm.selectedAddress == nil ? "Seç" : "Değiştir")
                            .font(.kgmCaptionMedium)
                        Image(systemName: "chevron.right")
                            .font(.kgmSmall)
                    }
                    .foregroundColor(.kgmPrimary)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var productsCard: some View {
        sectionCard {
            VStack(spacing: KGMSpacing.sm) {
                HStack {
                    Text("Sipariş Ürünleri")
                        .font(.kgmHeadline)
                        .foregroundColor(.kgmTextPrimary)
                    Spacer()
                    Text("\(cartRepo.cart.itemCount) Ürün")
                        .font(.kgmCaptionMedium)
                        .foregroundColor(.kgmTextSecondary)
                }

                ForEach(cartRepo.cart.items.prefix(5)) { item in
                    checkoutProductRow(item)
                    if item.id != cartRepo.cart.items.prefix(5).last?.id {
                        Divider()
                    }
                }

                if cartRepo.cart.items.count > 5 {
                    Text("+\(cartRepo.cart.items.count - 5) ürün daha")
                        .font(.kgmCaptionMedium)
                        .foregroundColor(.kgmTextSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    private var paymentMethodsCard: some View {
        sectionCard {
            VStack(alignment: .leading, spacing: 0) {
                Text("Ödeme Yöntemi")
                    .font(.kgmHeadline)
                    .foregroundColor(.kgmTextPrimary)
                    .padding(.bottom, KGMSpacing.sm)

                ForEach(CheckoutPaymentOption.allCases) { option in
                    Button {
                        guard option.isEnabled(for: vm.selectedAddress) else { return }
                        selectedPaymentOption = option
                    } label: {
                        HStack(spacing: KGMSpacing.md) {
                            Image(systemName: selectedPaymentOption == option ? "largecircle.fill.circle" : "circle")
                                .font(.system(size: 24))
                                .foregroundColor(option.isEnabled(for: vm.selectedAddress) ? .kgmPrimary : .kgmTextMuted)

                            ZStack {
                                RoundedRectangle(cornerRadius: KGMRadius.sm)
                                    .fill(Color.kgmPrimary.opacity(option.isEnabled(for: vm.selectedAddress) ? 0.1 : 0.05))
                                Image(systemName: option.icon)
                                    .font(.system(size: 24, weight: .semibold))
                                    .foregroundColor(option.isEnabled(for: vm.selectedAddress) ? .kgmPrimary : .kgmTextMuted)
                            }
                            .frame(width: 48, height: 48)

                            VStack(alignment: .leading, spacing: 3) {
                                Text(option.title)
                                    .font(.kgmBodyMedium)
                                    .foregroundColor(option.isEnabled(for: vm.selectedAddress) ? .kgmTextPrimary : .kgmTextMuted)
                                Text(option.subtitle)
                                    .font(.kgmCaption)
                                    .foregroundColor(.kgmTextSecondary)
                            }
                            Spacer()
                            if let badge = option.badge(for: vm.selectedAddress) {
                                Text(badge)
                                    .font(.kgmSmall)
                                    .foregroundColor(option.isEnabled(for: vm.selectedAddress) ? .kgmPrimary : .kgmTextMuted)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 5)
                                    .background((option.isEnabled(for: vm.selectedAddress) ? Color.kgmPrimary : Color.kgmTextMuted).opacity(0.1))
                                    .clipShape(RoundedRectangle(cornerRadius: KGMRadius.sm))
                            }
                        }
                        .padding(.vertical, KGMSpacing.sm)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .disabled(!option.isEnabled(for: vm.selectedAddress))

                    if option.id != CheckoutPaymentOption.allCases.last?.id {
                        Divider()
                    }
                }

                if selectedPaymentOption == .card {
                    Divider()
                        .padding(.vertical, KGMSpacing.sm)
                    cardEntryForm
                }
            }
        }
    }

    private var cardEntryForm: some View {
        VStack(alignment: .leading, spacing: KGMSpacing.md) {
            HStack {
                Label("Kart Bilgileri", systemImage: "creditcard.fill")
                    .font(.kgmBodyMedium)
                    .foregroundColor(.kgmTextPrimary)
                Spacer()
                Text("PayTR + 3D Secure")
                    .font(.kgmSmall)
                    .foregroundColor(.kgmPrimary)
            }

            TextField("Kart üzerindeki ad soyad", text: $cardForm.holderName)
                .textContentType(.name)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
                .kgmCardField()

            TextField("Kart numarası", text: $cardForm.number)
                .keyboardType(.numberPad)
                .textContentType(.creditCardNumber)
                .kgmCardField()
                .onChange(of: cardForm.number) { _, value in
                    cardForm.number = PayTRCardForm.formatCardNumber(value)
                }

            HStack(spacing: KGMSpacing.sm) {
                TextField("AA/YY", text: $cardForm.expiry)
                    .keyboardType(.numberPad)
                    .kgmCardField()
                    .onChange(of: cardForm.expiry) { _, value in
                        cardForm.expiry = PayTRCardForm.formatExpiry(value)
                    }
                SecureField("CVV", text: $cardForm.cvv)
                    .keyboardType(.numberPad)
                    .textContentType(.creditCardSecurityCode)
                    .kgmCardField()
                    .onChange(of: cardForm.cvv) { _, value in
                        cardForm.cvv = String(value.filter(\.isNumber).prefix(4))
                    }
            }

            if let validationMessage = cardForm.validationMessage, !cardForm.isValid {
                Label(validationMessage, systemImage: "info.circle.fill")
                    .font(.kgmSmall)
                    .foregroundColor(.kgmTextSecondary)
            }

            Label("Kart bilgileriniz mağaza sunucularında tutulmaz; doğrudan PayTR güvenli ödeme altyapısına gönderilir.", systemImage: "lock.shield.fill")
                .font(.kgmSmall)
                .foregroundColor(.kgmTextMuted)
        }
    }

    private var orderNoteCard: some View {
        sectionCard {
            VStack(alignment: .leading, spacing: KGMSpacing.sm) {
                Text("Sipariş Notu")
                    .font(.kgmHeadline)
                    .foregroundColor(.kgmTextPrimary)
                TextField("Teslimat için not ekleyin...", text: $vm.deliveryNote, axis: .vertical)
                    .font(.kgmBody)
                    .lineLimit(3, reservesSpace: true)
                    .padding(KGMSpacing.md)
                    .background(Color.kgmCardElevated)
                    .clipShape(RoundedRectangle(cornerRadius: KGMRadius.md))
            }
        }
    }

    private var agreementsCard: some View {
        VStack(spacing: KGMSpacing.sm) {
            agreementRow(
                title: "KVKK Aydınlatma Metni'ni okudum ve kabul ediyorum.",
                document: .kvkk,
                isOn: $vm.kvkkAccepted
            )

            agreementRow(
                title: "Mesafeli Satış Sözleşmesi'ni okudum ve kabul ediyorum.",
                document: .distanceSales,
                isOn: $vm.contractAccepted
            )

            Label("Kapıda ödeme seçiliyse Bursa / Karacabey'de nakit, banka/kredi kartı ve yemek kartı geçerlidir.", systemImage: "fork.knife.circle.fill")
                .font(.kgmCaption)
                .foregroundColor(.kgmTextSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(KGMSpacing.base)
        .background(Color.kgmCard)
        .clipShape(RoundedRectangle(cornerRadius: KGMRadius.card))
        .overlay(RoundedRectangle(cornerRadius: KGMRadius.card).stroke(Color.kgmBorder))
        .padding(.horizontal, KGMSpacing.base)
    }

    private var orderSummaryCard: some View {
        sectionCard {
            VStack(alignment: .leading, spacing: KGMSpacing.md) {
                Text("Sipariş Özeti")
                    .font(.kgmHeadline)
                    .foregroundColor(.kgmTextPrimary)
                summaryRow("Ara Toplam", value: cartRepo.cart.subtotal.formattedAsTurkishLira)
                summaryRow("Minimum Servis", value: KGMCheckoutRules.minimumSubtotalDisplay, isDiscount: KGMCheckoutRules.meetsMinimum(cartRepo.cart.subtotal))
                summaryRow("Teslimat Ücreti", value: cartRepo.cart.hasDeliveryFee ? cartRepo.cart.deliveryFee.formattedAsTurkishLira : "Adres adımında hesaplanır")
                if cartRepo.cart.discountAmount > 0 {
                    summaryRow("İndirim", value: "-\(cartRepo.cart.discountAmount.formattedAsTurkishLira)", isDiscount: true)
                }
                Divider()
                summaryRow("Toplam", value: cartRepo.cart.total.formattedAsTurkishLira, isTotal: true)
            }
        }
    }

    private var bottomPaymentBar: some View {
        VStack(spacing: KGMSpacing.sm) {
            KGMButton(
                bottomButtonTitle,
                isLoading: vm.isLoading,
                isDisabled: !vm.canPlaceOrder(cart: cartRepo.cart)
                    || !selectedPaymentOption.isEnabled(for: vm.selectedAddress)
                    || (selectedPaymentOption == .card && !cardForm.isValid)
            ) {
                Task {
                    await vm.placeOrder(
                        cart: cartRepo.cart,
                        user: appState.currentUser,
                        paymentFlow: selectedPaymentOption.paymentFlow
                    )
                }
            }
            Label(selectedPaymentOption == .cash ? "Kapıda yemek kartı teslimatta geçerlidir." : "Ödemeleriniz 256-bit SSL ile güvence altındadır.", systemImage: selectedPaymentOption == .cash ? "creditcard.and.123" : "shield.checkered")
                .font(.kgmSmall)
                .foregroundColor(.kgmTextMuted)
        }
        .padding(.horizontal, KGMSpacing.base)
        .padding(.top, KGMSpacing.md)
        .padding(.bottom, KGMSpacing.xs)
        .background(.ultraThinMaterial)
    }

    private func paymentSheet(for session: CheckoutSessionResponse) -> some View {
        NavigationStack {
            Group {
                if let paymentResult {
                    switch paymentResult {
                    case .success:
                        if let paymentID = session.paymentID, !paymentID.isEmpty {
                            PaymentStatusPollingView(paymentId: paymentID)
                        } else {
                            PaymentSuccessView(orderId: session.orderID)
                        }
                    case .failure:
                        PaymentFailedView(message: "Ödeme tamamlanamadı. Kart bilgilerinizi veya bankanızın yanıtını kontrol edip tekrar deneyin.") {
                            closePaymentSheet()
                        }
                    }
                } else if session.isCashOnDelivery {
                    PaymentSuccessView(
                        orderId: session.orderID,
                        title: "Siparişiniz Kontrol Ediliyor",
                        message: session.message ?? "Kapıda ödeme siparişiniz mağazaya iletildi. Onaylandığında size sipariş numarasıyla bildirim göndereceğiz.",
                        buttonTitle: "Siparişi Gör"
                    )
                } else if let directPayment = session.directPayment,
                          let postURL = URL(string: directPayment.postURL),
                          PayTRPaymentWebView.isTrustedDirectPaymentURL(postURL) {
                    PayTRPaymentWebView(postURL: postURL, fields: directPayment.fields, card: cardForm) { result in
                        paymentResult = result
                    }
                    .ignoresSafeArea(edges: .bottom)
                } else if let url = session.paymentURL {
                    PayTRPaymentWebView(url: url) { result in
                        paymentResult = result
                    }
                    .ignoresSafeArea(edges: .bottom)
                } else {
                    PaymentFailedView(message: "Ödeme bağlantısı oluşturulamadı.") {
                        closePaymentSheet()
                    }
                }
            }
            .privacySensitive()
            .onAppear { AppSecurityManager.shared.protectSensitiveScreen() }
            .navigationTitle(session.isCashOnDelivery ? "Sipariş Onayı" : "PayTR Kart Ödemesi")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Kapat") { closePaymentSheet() }
                }
            }
        }
    }

    private func closePaymentSheet() {
        vm.checkoutSession = nil
        paymentResult = nil
        Task { try? await cartRepo.refreshCart() }
    }

    private var bottomButtonTitle: String {
        if selectedPaymentOption == .cash {
            return "\(cartRepo.cart.total.formattedAsTurkishLira) Kapıda Ödeme ile Tamamla"
        }
        return "\(cartRepo.cart.total.formattedAsTurkishLira) Öde ve Siparişi Tamamla"
    }

    private func agreementRow(title: String, document: LegalDocument, isOn: Binding<Bool>) -> some View {
        HStack(alignment: .center, spacing: KGMSpacing.sm) {
            Toggle("", isOn: isOn)
                .labelsHidden()
                .tint(Color.kgmPrimary)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.kgmCaption)
                    .foregroundColor(.kgmTextSecondary)
                Button("Sözleşmeyi Aç") {
                    selectedLegalDocument = document
                }
                .font(.kgmCaptionMedium)
                .foregroundColor(.kgmPrimary)
            }
            Spacer(minLength: 0)
        }
    }

    private func checkoutProductRow(_ item: CartItem) -> some View {
        HStack(spacing: KGMSpacing.md) {
            KGMProductImage(
                url: item.product.resolvedImageURL,
                height: 58,
                cornerRadius: KGMRadius.sm,
                horizontalPadding: 4,
                verticalPadding: 4,
                zoom: 1.04,
                backgroundColor: .white
            )
            .frame(width: 58)

            VStack(alignment: .leading, spacing: 4) {
                Text(item.product.name)
                    .font(.kgmBodyMedium)
                    .foregroundColor(.kgmTextPrimary)
                    .lineLimit(1)
                Text("\(item.quantity) x \(item.product.unit)")
                    .font(.kgmCaption)
                    .foregroundColor(.kgmTextSecondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text(item.totalPrice.formattedAsTurkishLira)
                    .font(.kgmBodyMedium)
                    .foregroundColor(.kgmPrimary)
                Text("\(item.quantity) x \(item.product.effectivePrice.formattedAsTurkishLira)")
                    .font(.kgmSmall)
                    .foregroundColor(.kgmTextSecondary)
            }
        }
    }

    private func stepItem(number: String, title: String, state: CheckoutStepState) -> some View {
        VStack(spacing: KGMSpacing.xs) {
            ZStack {
                Circle()
                    .fill(stepFill(for: state))
                    .overlay(Circle().stroke(stepStroke(for: state), lineWidth: state == .pending ? 1 : 0))
                if state == .complete {
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                } else {
                    Text(number)
                        .font(.kgmCaptionMedium)
                        .foregroundColor(state == .current ? .white : .kgmTextMuted)
                }
            }
            .frame(width: 34, height: 34)
            Text(title)
                .font(.kgmCaptionMedium)
                .foregroundColor(state == .pending ? .kgmTextSecondary : .kgmTextPrimary)
                .lineLimit(1)
        }
        .frame(width: 74)
    }

    private func stepLine(isActive: Bool) -> some View {
        Rectangle()
            .fill(isActive ? Color.kgmPrimary : Color.kgmBorder)
            .frame(height: 2)
            .frame(maxWidth: .infinity)
            .padding(.bottom, 22)
    }

    private func stepFill(for state: CheckoutStepState) -> Color {
        switch state {
        case .complete, .current: return .kgmPrimary
        case .pending: return .kgmCardElevated
        }
    }

    private func stepStroke(for state: CheckoutStepState) -> Color {
        state == .pending ? .kgmBorder : .clear
    }

    private func sectionCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: KGMSpacing.sm) {
            content()
        }
        .padding(KGMSpacing.base)
        .background(Color.kgmCard)
        .clipShape(RoundedRectangle(cornerRadius: KGMRadius.card))
        .overlay(RoundedRectangle(cornerRadius: KGMRadius.card).stroke(Color.kgmBorder))
        .padding(.horizontal, KGMSpacing.base)
    }

    private func summaryRow(_ title: String, value: String, isDiscount: Bool = false, isTotal: Bool = false) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(isTotal ? .kgmTitle2 : .kgmBody)
                .foregroundColor(isTotal ? .kgmTextPrimary : .kgmTextSecondary)
            Spacer()
            Text(value)
                .font(isTotal ? .kgmTitle2 : .kgmBodyMedium)
                .foregroundColor(isTotal || isDiscount ? .kgmPrimary : .kgmTextPrimary)
                .multilineTextAlignment(.trailing)
        }
    }
}

private struct CheckoutAddressPickerView: View {
    @ObservedObject var vm: CheckoutViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showAddForm = false
    @State private var editingAddress: Address?

    var body: some View {
        Group {
            if vm.availableAddresses.isEmpty {
                KGMEmptyStateView(
                    icon: "mappin.and.ellipse",
                    title: "Teslimat adresi ekleyin",
                    message: "Siparişi tamamlamak için bir adres kaydedin.",
                    buttonTitle: "Adres Ekle"
                ) {
                    showAddForm = true
                }
            } else {
                List {
                    ForEach(vm.availableAddresses) { address in
                        VStack(spacing: KGMSpacing.sm) {
                            KGMAddressCard(
                                address: address,
                                isSelected: vm.selectedAddress?.id == address.id,
                                onSelect: {
                                    vm.selectedAddress = address
                                    dismiss()
                                },
                                onEdit: { editingAddress = address },
                                onDelete: { Task { await vm.deleteAddress(address) } }
                            )

                            if !address.isDefault {
                                Button {
                                    Task { await vm.setDefaultAddress(address) }
                                } label: {
                                    Label("Varsayılan Yap", systemImage: "checkmark.circle")
                                        .font(.kgmCaptionMedium)
                                        .foregroundColor(Color.kgmPrimary)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                .buttonStyle(.plain)
                                .padding(.horizontal, KGMSpacing.base)
                                .padding(.bottom, KGMSpacing.xs)
                            }
                        }
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
        .navigationTitle("Teslimat Adresi")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Kapat") { dismiss() }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showAddForm = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .task {
            await vm.reloadAddresses()
        }
        .refreshable { await vm.reloadAddresses() }
        .sheet(isPresented: $showAddForm) {
            NavigationStack {
                AddressFormView { address in
                    await vm.saveAddress(address, isNew: true)
                }
            }
        }
        .sheet(item: $editingAddress) { address in
            NavigationStack {
                AddressFormView(existingAddress: address) { updated in
                    await vm.saveAddress(updated, isNew: false)
                }
            }
        }
        .alert("Adres işlemi tamamlanamadı", isPresented: errorAlertBinding) {
            Button("Tamam", role: .cancel) { vm.errorMessage = nil }
        } message: {
            Text(vm.errorMessage ?? "Lütfen tekrar deneyin.")
        }
    }

    private var errorAlertBinding: Binding<Bool> {
        Binding(
            get: { vm.errorMessage != nil },
            set: { if !$0 { vm.errorMessage = nil } }
        )
    }
}

struct OrderSuccessView: View {
    let order: Order
    var onViewOrders: () -> Void
    var onDone: () -> Void

    var body: some View {
        VStack(spacing: KGMSpacing.xl) {
            Spacer()
            ZStack {
                Circle().fill(Color.kgmPrimary.opacity(0.1)).frame(width: 120, height: 120)
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 64)).foregroundColor(Color.kgmPrimary)
            }
            VStack(spacing: KGMSpacing.sm) {
                Text("Siparişiniz Alındı!").font(.kgmLargeTitle)
                Text("Sipariş No: \(order.orderNumber)").font(.kgmBodyMedium).foregroundColor(.secondary)
                if let est = order.estimatedDelivery {
                    Text("Tahmini Teslimat: \(est, style: .time)").font(.kgmBody).foregroundColor(.secondary)
                }
            }
            Text("Siparişinizi \"Siparişlerim\" sayfasından takip edebilirsiniz.")
                .font(.kgmBody).foregroundColor(.secondary).multilineTextAlignment(.center)
                .padding(.horizontal, KGMSpacing.xl)
            VStack(spacing: KGMSpacing.sm) {
                KGMButton("Siparişlerimi Gör", action: onViewOrders)
                KGMButton("Alışverişe Devam Et", style: .outline, action: onDone)
            }
            .padding(.horizontal, KGMSpacing.xl)
            Spacer()
        }
    }
}
