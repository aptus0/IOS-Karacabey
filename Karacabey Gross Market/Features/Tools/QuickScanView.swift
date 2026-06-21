import SwiftUI
import AVFoundation
import Combine
import PhotosUI
import UIKit

@MainActor
final class QuickScanViewModel: ObservableObject {
    @Published var products: [Product] = []
    @Published var externalResults: [ExternalMarketProduct] = []
    @Published var externalDisclaimer = "Dış market sonuçları yalnızca karşılaştırma amaçlıdır. Fiyat ve stok güncelliği garanti edilmez."
    @Published var labels: [String] = []
    @Published var query = ""
    @Published var scannedCode: String?
    @Published var isLoading = false
    @Published var isExternalLoading = false
    @Published var errorMessage: String?
    @Published var matchedProductForNavigation: Product?
    @Published var manualBarcode = ""
    @Published var manualQuery = ""
    @Published private(set) var recentSearches: [String] = CatalogCacheStore.shared.recentSearches()

    func search(code: String) async {
        let clean = code.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }
        guard !(isLoading && scannedCode == clean) else { return }
        scannedCode = clean
        query = clean
        labels = ["Önce KGM kataloğu", "Barkod", clean]
        await run(source: .barcode(clean)) {
            try await ProductRepository.shared.searchBarcode(clean)
        }
    }

    func searchManualBarcode() async {
        await search(code: manualBarcode)
    }

    func searchManualQuery() async {
        let clean = manualQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard clean.count >= 2 else {
            errorMessage = "Ürün adı veya marka için en az 2 karakter yazın."
            return
        }
        scannedCode = nil
        query = clean
        labels = ["Önce KGM kataloğu", "Ürün adı", clean]
        await run(source: .text(clean)) {
            let products = try await ProductRepository.shared.search(query: clean)
            return VisualProductSearchResponse(query: clean, labels: ["kgm katalog"], products: products, message: nil)
        }
    }

    func search(imageData: Data) async {
        scannedCode = nil
        labels = ["Önce KGM kataloğu", "Gemini AI", "Görsel analiz"]
        await run(source: .image) {
            try await ProductRepository.shared.visualSearch(imageData: imageData)
        }
    }

    func clearMatchedNavigation() {
        matchedProductForNavigation = nil
    }

    enum SearchSource {
        case barcode(String)
        case image
        case text(String)
    }

    private func run(source: SearchSource, _ operation: @escaping () async throws -> VisualProductSearchResponse) async {
        isLoading = true
        isExternalLoading = false
        errorMessage = nil
        externalResults = []
        defer { isLoading = false }

        do {
            let response = try await operation()
            query = response.query.isEmpty ? query : response.query
            labels = normalizeLabels(response.labels, source: source)
            products = response.products
            if products.isEmpty {
                errorMessage = "KGM kataloğunda eşleşen ürün bulunamadı. Dış marketlerde karşılaştırma sonuçlarını arıyoruz."
                await loadExternalResults(for: externalQuery(source: source, response: response))
            } else if case .barcode(let code) = source {
                matchedProductForNavigation = exactBarcodeMatch(in: products, code: code) ?? products.first
            } else if products.count == 1 {
                matchedProductForNavigation = products.first
            }
            recentSearches = CatalogCacheStore.shared.recentSearches()
        } catch {
            products = []
            errorMessage = source.errorMessage
            await loadExternalResults(for: query)
        }
    }

    private func loadExternalResults(for query: String) async {
        let clean = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard clean.count >= 2 else { return }
        isExternalLoading = true
        defer { isExternalLoading = false }
        do {
            let response = try await ProductRepository.shared.externalSearch(query: clean, maxResults: 8)
            externalDisclaimer = response.disclaimer
            externalResults = response.results.filter { !$0.url.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            if externalResults.isEmpty && products.isEmpty {
                errorMessage = "KGM kataloğunda ve dış aramada sonuç bulunamadı. Bu ürün talebi rapora alınabilir."
            }
        } catch {
            if products.isEmpty {
                errorMessage = "KGM kataloğunda ürün bulunamadı. Dış market araması şu anda tamamlanamadı."
            }
        }
    }

    private func externalQuery(source: SearchSource, response: VisualProductSearchResponse) -> String {
        if !response.query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return response.query }
        switch source {
        case .barcode(let code): return code
        case .text(let text): return text
        case .image:
            return response.labels.first(where: { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) ?? query
        }
    }

    private func normalizeLabels(_ incoming: [String], source: SearchSource) -> [String] {
        var result = incoming.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        result.insert("Önce KGM kataloğu", at: 0)
        switch source {
        case .barcode(let code):
            result.append("Barkod")
            result.append(code)
        case .image:
            result.append("Gemini AI")
            result.append("Görsel analiz")
        case .text(let text):
            result.append("Ürün adı")
            result.append(text)
        }
        var seen = Set<String>()
        return result.filter { seen.insert($0.lowercased()).inserted }
    }

    private func exactBarcodeMatch(in products: [Product], code: String) -> Product? {
        products.first { product in
            product.barcode?.trimmingCharacters(in: .whitespacesAndNewlines) == code
        }
    }
}

private extension QuickScanViewModel.SearchSource {
    var errorMessage: String {
        switch self {
        case .barcode:
            return "Barkod önce KGM kataloğunda aranamadı. Bağlantınızı kontrol edip tekrar deneyin."
        case .image:
            return "Gemini AI görsel analizi tamamlanamadı. Bağlantınızı kontrol edip tekrar deneyin."
        case .text:
            return "Ürün adı önce KGM kataloğunda aranamadı. Bağlantınızı kontrol edip tekrar deneyin."
        }
    }
}

struct QuickScanView: View {
    @StateObject private var vm = QuickScanViewModel()
    @EnvironmentObject var cartRepo: CartRepository
    @EnvironmentObject var favRepo: FavoritesRepository
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var selectedProduct: Product?

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: KGMSpacing.base) {
                header
                scannerCard
                manualBarcodeCard
                manualTextSearchCard
                recentSearchesCard
                photoSearchCard
                resultHeader
                resultsGrid
                externalResultsSection
            }
            .padding(.horizontal, KGMSpacing.base)
            .padding(.top, KGMSpacing.md)
            .padding(.bottom, KGMSpacing.xxxl)
        }
        .background(Color.kgmBackground.ignoresSafeArea())
        .navigationTitle("Hızlı Sipariş")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(item: $selectedProduct) { product in
            ProductDetailView(product: product)
        }
        .onChange(of: selectedPhoto) { _, item in
            guard let item else { return }
            Task { await loadPhoto(item) }
        }
        .onChange(of: vm.matchedProductForNavigation) { _, product in
            guard let product else { return }
            selectedProduct = product
            vm.clearMatchedNavigation()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: KGMSpacing.xs) {
            Label("Ürünü Tara veya Fotoğraftan Bul", systemImage: "qrcode.viewfinder")
                .font(.kgmTitle2)
                .foregroundColor(.kgmTextPrimary)
            Text("Barkod, QR veya ürün fotoğrafı ile sepete hızlıca ürün ekleyin.")
                .font(.kgmCallout)
                .foregroundColor(.kgmTextSecondary)
        }
    }

    private var scannerCard: some View {
        VStack(alignment: .leading, spacing: KGMSpacing.md) {
            HStack {
                Text("Barkod / QR Tarama")
                    .font(.kgmHeadline)
                    .foregroundColor(.kgmTextPrimary)
                Spacer()
                if let code = vm.scannedCode {
                    Text(code)
                        .font(.kgmSmall)
                        .foregroundColor(.kgmPrimary)
                        .lineLimit(1)
                        .padding(.horizontal, KGMSpacing.sm)
                        .frame(height: 28)
                        .background(Color.kgmPrimary.opacity(0.09))
                        .clipShape(Capsule())
                }
            }

            BarcodeScannerView { code in
                if code.lowercased().hasPrefix("kgm://") {
                    DeepLinkRouter.shared.open(code)
                } else {
                    Task { await vm.search(code: code) }
                }
            }
            .frame(height: 230)
            .clipShape(RoundedRectangle(cornerRadius: KGMRadius.md))
            .overlay(
                RoundedRectangle(cornerRadius: KGMRadius.md)
                    .stroke(Color.kgmPrimary.opacity(0.24), lineWidth: 1)
            )
        }
        .padding(KGMSpacing.base)
        .background(Color.kgmCard)
        .clipShape(RoundedRectangle(cornerRadius: KGMRadius.card))
        .overlay(RoundedRectangle(cornerRadius: KGMRadius.card).stroke(Color.kgmBorder))
    }

    private var manualBarcodeCard: some View {
        VStack(alignment: .leading, spacing: KGMSpacing.sm) {
            Text("Barkodu Elle Gir")
                .font(.kgmHeadline)
                .foregroundColor(.kgmTextPrimary)

            HStack(spacing: KGMSpacing.sm) {
                TextField("Örn: 869...", text: $vm.manualBarcode)
                    .keyboardType(.numberPad)
                    .textInputAutocapitalization(.never)
                    .font(.kgmBody)
                    .padding(.horizontal, KGMSpacing.md)
                    .frame(height: 46)
                    .background(Color.kgmCardElevated)
                    .clipShape(RoundedRectangle(cornerRadius: KGMRadius.md))
                    .overlay(RoundedRectangle(cornerRadius: KGMRadius.md).stroke(Color.kgmBorder, lineWidth: 1))

                Button {
                    Task { await vm.searchManualBarcode() }
                } label: {
                    Text("Bul")
                        .font(.kgmCaptionMedium)
                        .foregroundColor(.white)
                        .frame(width: 72, height: 46)
                        .background(vm.manualBarcode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color.kgmTextMuted : Color.kgmPrimary)
                        .clipShape(RoundedRectangle(cornerRadius: KGMRadius.md))
                }
                .buttonStyle(.plain)
                .disabled(vm.manualBarcode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(KGMSpacing.base)
        .background(Color.kgmCard)
        .clipShape(RoundedRectangle(cornerRadius: KGMRadius.card))
        .overlay(RoundedRectangle(cornerRadius: KGMRadius.card).stroke(Color.kgmBorder))
    }


    private var manualTextSearchCard: some View {
        VStack(alignment: .leading, spacing: KGMSpacing.sm) {
            HStack {
                Text("Ürün Adıyla Hızlı Ara")
                    .font(.kgmHeadline)
                    .foregroundColor(.kgmTextPrimary)
                Spacer()
                Text("Önce KGM")
                    .font(.kgmSmall)
                    .foregroundColor(.kgmPrimary)
                    .padding(.horizontal, 8)
                    .frame(height: 24)
                    .background(Color.kgmPrimary.opacity(0.09))
                    .clipShape(Capsule())
            }

            HStack(spacing: KGMSpacing.sm) {
                TextField("Örn: süt, yumurta, deterjan", text: $vm.manualQuery)
                    .textInputAutocapitalization(.never)
                    .font(.kgmBody)
                    .padding(.horizontal, KGMSpacing.md)
                    .frame(height: 46)
                    .background(Color.kgmCardElevated)
                    .clipShape(RoundedRectangle(cornerRadius: KGMRadius.md))
                    .overlay(RoundedRectangle(cornerRadius: KGMRadius.md).stroke(Color.kgmBorder, lineWidth: 1))
                    .submitLabel(.search)
                    .onSubmit { Task { await vm.searchManualQuery() } }

                Button {
                    Task { await vm.searchManualQuery() }
                } label: {
                    Text("Ara")
                        .font(.kgmCaptionMedium)
                        .foregroundColor(.white)
                        .frame(width: 72, height: 46)
                        .background(vm.manualQuery.trimmingCharacters(in: .whitespacesAndNewlines).count < 2 ? Color.kgmTextMuted : Color.kgmPrimary)
                        .clipShape(RoundedRectangle(cornerRadius: KGMRadius.md))
                }
                .buttonStyle(.plain)
                .disabled(vm.manualQuery.trimmingCharacters(in: .whitespacesAndNewlines).count < 2)
            }

            Text("KGM'de varsa direkt ürün detayına gider; yoksa Gemini destekli dış market karşılaştırması açılır. Dış sonuçlar sepete eklenemez.")
                .font(.kgmSmall)
                .foregroundColor(.kgmTextMuted)
        }
        .padding(KGMSpacing.base)
        .background(Color.kgmCard)
        .clipShape(RoundedRectangle(cornerRadius: KGMRadius.card))
        .overlay(RoundedRectangle(cornerRadius: KGMRadius.card).stroke(Color.kgmBorder))
    }

    @ViewBuilder
    private var recentSearchesCard: some View {
        if !vm.recentSearches.isEmpty {
            VStack(alignment: .leading, spacing: KGMSpacing.sm) {
                Text("Son Aramalar")
                    .font(.kgmHeadline)
                    .foregroundColor(.kgmTextPrimary)
                FlowTags(tags: vm.recentSearches)
                    .onTapGesture {}
            }
            .padding(KGMSpacing.base)
            .background(Color.kgmCard)
            .clipShape(RoundedRectangle(cornerRadius: KGMRadius.card))
            .overlay(RoundedRectangle(cornerRadius: KGMRadius.card).stroke(Color.kgmBorder))
        }
    }

    private var photoSearchCard: some View {
        HStack(spacing: KGMSpacing.md) {
            Image(systemName: "sparkles")
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(.kgmPrimary)
                .frame(width: 52, height: 52)
                .background(Color.kgmPrimary.opacity(0.10))
                .clipShape(RoundedRectangle(cornerRadius: KGMRadius.md))

            VStack(alignment: .leading, spacing: 4) {
                Text("Gemini AI ile Ürün Bul")
                    .font(.kgmHeadline)
                    .foregroundColor(.kgmTextPrimary)
                Text("Fotoğraftaki ürünü katalogda arar.")
                    .font(.kgmCaption)
                    .foregroundColor(.kgmTextSecondary)
            }
            Spacer()
            PhotosPicker(selection: $selectedPhoto, matching: .images) {
                Image(systemName: "photo.badge.magnifyingglass")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 48, height: 48)
                    .background(Color.kgmPrimary)
                    .clipShape(RoundedRectangle(cornerRadius: KGMRadius.md))
            }
        }
        .padding(KGMSpacing.base)
        .background(Color.kgmCard)
        .clipShape(RoundedRectangle(cornerRadius: KGMRadius.card))
        .overlay(RoundedRectangle(cornerRadius: KGMRadius.card).stroke(Color.kgmBorder))
    }

    @ViewBuilder
    private var resultHeader: some View {
        if vm.isLoading {
            HStack(spacing: KGMSpacing.sm) {
                ProgressView().tint(.kgmPrimary)
                Text(vm.isExternalLoading ? "Dış market sonuçları aranıyor" : "Önce KGM kataloğunda aranıyor")
                    .font(.kgmCaptionMedium)
                    .foregroundColor(.kgmTextSecondary)
            }
        } else if !vm.products.isEmpty {
            VStack(alignment: .leading, spacing: KGMSpacing.xs) {
                Text(vm.query.isEmpty ? "Bulunan Ürünler" : "\"\(vm.query)\" sonuçları")
                    .font(.kgmHeadline)
                    .foregroundColor(.kgmTextPrimary)
                if !vm.labels.isEmpty {
                    FlowTags(tags: vm.labels)
                }
            }
        } else if let error = vm.errorMessage {
            Label(error, systemImage: "info.circle.fill")
                .font(.kgmCaption)
                .foregroundColor(.kgmTextSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var resultsGrid: some View {
        LazyVGrid(columns: [
            GridItem(.flexible(), spacing: KGMSpacing.sm),
            GridItem(.flexible(), spacing: KGMSpacing.sm)
        ], spacing: KGMSpacing.sm) {
            ForEach(vm.products) { product in
                KGMProductCard(
                    product: product,
                    onAddToCart: { cartRepo.addToCart(product) },
                    onFavorite: { favRepo.toggle(product) },
                    onTap: { selectedProduct = product }
                )
            }
        }
    }


    @ViewBuilder
    private var externalResultsSection: some View {
        if vm.isExternalLoading {
            HStack(spacing: KGMSpacing.sm) {
                ProgressView().tint(.kgmPrimary)
                Text("KGM kataloğunda yoksa dış marketler karşılaştırma için taranıyor...")
                    .font(.kgmCaptionMedium)
                    .foregroundColor(.kgmTextSecondary)
            }
            .padding(KGMSpacing.base)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.kgmCard)
            .clipShape(RoundedRectangle(cornerRadius: KGMRadius.card))
        } else if !vm.externalResults.isEmpty {
            VStack(alignment: .leading, spacing: KGMSpacing.sm) {
                Label("Dış Market Karşılaştırması", systemImage: "globe.europe.africa.fill")
                    .font(.kgmHeadline)
                    .foregroundColor(.kgmTextPrimary)
                Text(vm.externalDisclaimer)
                    .font(.kgmSmall)
                    .foregroundColor(.kgmTextMuted)
                ForEach(vm.externalResults) { result in
                    ExternalMarketResultCard(result: result)
                }
            }
        }
    }

    private func loadPhoto(_ item: PhotosPickerItem) async {
        guard let rawData = try? await item.loadTransferable(type: Data.self),
              let image = UIImage(data: rawData),
              let jpegData = image.jpegData(compressionQuality: 0.76) else {
            vm.errorMessage = "Fotoğraf okunamadı."
            return
        }
        await vm.search(imageData: jpegData)
    }
}



private struct ExternalMarketResultCard: View {
    let result: ExternalMarketProduct
    @Environment(\.openURL) private var openURL

    var body: some View {
        Button {
            guard let url = URL(string: result.url) else { return }
            openURL(url)
        } label: {
            HStack(alignment: .top, spacing: KGMSpacing.sm) {
                Image(systemName: "link.circle.fill")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.kgmInfo)
                    .frame(width: 42, height: 42)
                    .background(Color.kgmInfo.opacity(0.10))
                    .clipShape(RoundedRectangle(cornerRadius: KGMRadius.md))

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(result.provider)
                            .font(.kgmSmall)
                            .foregroundColor(.kgmPrimary)
                        Spacer()
                        if let price = result.priceLabel, !price.isEmpty {
                            Text(price)
                                .font(.kgmSmall)
                                .foregroundColor(.kgmTextSecondary)
                        }
                    }
                    Text(result.title)
                        .font(.kgmCaptionMedium)
                        .foregroundColor(.kgmTextPrimary)
                        .lineLimit(2)
                    if let snippet = result.snippet, !snippet.isEmpty {
                        Text(snippet)
                            .font(.kgmSmall)
                            .foregroundColor(.kgmTextMuted)
                            .lineLimit(2)
                    }
                    Text("KGM sepetine eklenemez · Kaynağı aç")
                        .font(.kgmSmall)
                        .foregroundColor(.kgmInfo)
                }
            }
            .padding(KGMSpacing.md)
            .background(Color.kgmCard)
            .clipShape(RoundedRectangle(cornerRadius: KGMRadius.card))
            .overlay(RoundedRectangle(cornerRadius: KGMRadius.card).stroke(Color.kgmBorder.opacity(0.85)))
        }
        .buttonStyle(.plain)
    }
}

private struct FlowTags: View {
    let tags: [String]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: KGMSpacing.xs) {
                ForEach(tags.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }, id: \.self) { tag in
                    Text(tag.localizedCapitalized)
                        .font(.kgmSmall)
                        .foregroundColor(.kgmPrimary)
                        .lineLimit(1)
                        .padding(.horizontal, KGMSpacing.sm)
                        .frame(height: 28)
                        .background(Color.kgmPrimary.opacity(0.09))
                        .clipShape(Capsule())
                        .overlay(
                            Capsule()
                                .stroke(Color.kgmPrimary.opacity(0.14), lineWidth: 1)
                        )
                }
            }
            .padding(.vertical, 1)
        }
    }
}

struct BarcodeScannerView: UIViewControllerRepresentable {
    let onCode: (String) -> Void

    func makeUIViewController(context: Context) -> BarcodeScannerController {
        BarcodeScannerController(onCode: onCode)
    }

    func updateUIViewController(_ uiViewController: BarcodeScannerController, context: Context) {}
}

final class BarcodeScannerController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    private let session = AVCaptureSession()
    private let sessionQueue = DispatchQueue(label: "kgm.barcode.scanner.session")
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private let onCode: (String) -> Void
    private var lastCode = ""
    private var lastCodeDate = Date.distantPast

    init(onCode: @escaping (String) -> Void) {
        self.onCode = onCode
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        configureWhenAllowed()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        startSession()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        stopSession()
    }

    private func configureWhenAllowed() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            configureSession()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    granted ? self?.configureSession() : self?.showCameraMessage()
                }
            }
        default:
            showCameraMessage()
        }
    }

    private func configureSession() {
        guard previewLayer == nil else { return }
        guard let device = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input) else {
            showCameraMessage()
            return
        }
        session.addInput(input)

        let output = AVCaptureMetadataOutput()
        guard session.canAddOutput(output) else {
            showCameraMessage()
            return
        }
        session.addOutput(output)
        output.setMetadataObjectsDelegate(self, queue: .main)
        let desiredTypes: [AVMetadataObject.ObjectType] = [
            .ean8, .ean13, .upce, .qr, .code128, .code39, .code39Mod43,
            .code93, .dataMatrix, .pdf417, .aztec, .interleaved2of5, .itf14
        ]
        output.metadataObjectTypes = desiredTypes.filter { output.availableMetadataObjectTypes.contains($0) }

        let layer = AVCaptureVideoPreviewLayer(session: session)
        layer.videoGravity = .resizeAspectFill
        layer.frame = view.bounds
        view.layer.insertSublayer(layer, at: 0)
        previewLayer = layer
        addScanOverlay()
        startSession()
    }

    private func startSession() {
        sessionQueue.async { [session] in
            if !session.isRunning {
                session.startRunning()
            }
        }
    }

    private func stopSession() {
        sessionQueue.async { [session] in
            if session.isRunning {
                session.stopRunning()
            }
        }
    }

    func metadataOutput(
        _ output: AVCaptureMetadataOutput,
        didOutput metadataObjects: [AVMetadataObject],
        from connection: AVCaptureConnection
    ) {
        guard let readable = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
              let value = readable.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines),
              !value.isEmpty else { return }

        let now = Date()
        guard value != lastCode || now.timeIntervalSince(lastCodeDate) > 2 else { return }
        lastCode = value
        lastCodeDate = now
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        onCode(value)
    }

    private func addScanOverlay() {
        let frameView = UIView()
        frameView.translatesAutoresizingMaskIntoConstraints = false
        frameView.layer.borderColor = UIColor.systemGreen.cgColor
        frameView.layer.borderWidth = 2
        frameView.layer.cornerRadius = 18
        frameView.backgroundColor = UIColor.clear
        view.addSubview(frameView)

        NSLayoutConstraint.activate([
            frameView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            frameView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            frameView.widthAnchor.constraint(equalTo: view.widthAnchor, multiplier: 0.72),
            frameView.heightAnchor.constraint(equalToConstant: 130)
        ])
    }

    private func showCameraMessage() {
        let label = UILabel()
        label.text = "Kamera izni gerekli"
        label.font = .systemFont(ofSize: 16, weight: .semibold)
        label.textColor = .white
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }
}
