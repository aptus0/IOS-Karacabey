import SwiftUI

struct AddressListView: View {
    @State private var addresses: [Address] = []
    @State private var showAddForm = false
    @State private var editingAddress: Address? = nil
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        Group {
            if isLoading && addresses.isEmpty {
                KGMLoadingView()
            } else if addresses.isEmpty {
                KGMEmptyStateView(
                    icon: "mappin.and.ellipse",
                    title: "Adres ekleyin",
                    message: "Teslimat için ev veya iş adresinizi kaydedebilirsiniz.",
                    buttonTitle: "Adres Ekle"
                ) {
                    showAddForm = true
                }
            } else {
                List {
                    ForEach(addresses) { addr in
                        KGMAddressCard(
                            address: addr,
                            onEdit: { editingAddress = addr },
                            onDelete: { Task { await deleteAddress(addr) } }
                        )
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
        .navigationTitle("Adreslerim")
        .navigationBarTitleDisplayMode(.large)
        .task { await loadAddresses() }
        .refreshable { await loadAddresses() }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { showAddForm = true }) {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showAddForm) {
            NavigationStack {
                AddressFormView { newAddr in
                    await saveAddress(newAddr, isNew: true)
                }
            }
        }
        .sheet(item: $editingAddress) { addr in
            NavigationStack {
                AddressFormView(existingAddress: addr) { updated in
                    await saveAddress(updated, isNew: false)
                }
            }
        }
        .alert("Adres işlemi tamamlanamadı", isPresented: errorAlertBinding) {
            Button("Tamam", role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "Lütfen tekrar deneyin.")
        }
    }

    private func loadAddresses() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            addresses = try await AddressRepository.shared.getAddresses()
        } catch {
            errorMessage = error.kgmUserMessage
        }
    }

    private func saveAddress(_ addr: Address, isNew: Bool) async -> Bool {
        errorMessage = nil
        do {
            var saved = isNew
                ? try await AddressRepository.shared.addAddress(addr)
                : try await AddressRepository.shared.updateAddress(addr)
            if saved.latitude == nil { saved.latitude = addr.latitude }
            if saved.longitude == nil { saved.longitude = addr.longitude }
            if isNew {
                addresses.append(saved)
            } else if let idx = addresses.firstIndex(where: { $0.id == saved.id }) {
                addresses[idx] = saved
            }
            if saved.isDefault {
                addresses = addresses.map { address in
                    var copy = address
                    copy.isDefault = copy.id == saved.id
                    return copy
                }
            }
            return true
        } catch {
            errorMessage = error.kgmUserMessage
            return false
        }
    }

    private func deleteAddress(_ addr: Address) async {
        errorMessage = nil
        do {
            try await AddressRepository.shared.deleteAddress(id: addr.id)
            addresses.removeAll { $0.id == addr.id }
        } catch {
            errorMessage = error.kgmUserMessage
        }
    }

    private var errorAlertBinding: Binding<Bool> {
        Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )
    }
}

struct AddressFormView: View {
    var existingAddress: Address? = nil
    var onSave: (Address) async -> Bool
    @Environment(\.dismiss) var dismiss

    private enum AddressKind: String, CaseIterable, Identifiable {
        case home = "Ev"
        case work = "İş"
        case other = "Diğer"

        var id: String { rawValue }
        var icon: String {
            switch self {
            case .home: return "house.fill"
            case .work: return "briefcase.fill"
            case .other: return "mappin.circle.fill"
            }
        }
    }

    @State private var selectedKind: AddressKind = .home
    @State private var title = ""
    @State private var firstName = ""
    @State private var lastName = ""
    @State private var phone = ""
    @State private var city = ""
    @State private var district = ""
    @State private var neighborhood = ""
    @State private var street = ""
    @State private var buildingNo = ""
    @State private var apartmentNo = ""
    @State private var floor = ""
    @State private var directions = ""
    @State private var latitude: Double?
    @State private var longitude: Double?
    @State private var isDefault = false
    @State private var showMapPicker = false
    @State private var validationMessage: String?
    @State private var isSaving = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: KGMSpacing.md) {
                if let validationMessage {
                    Label(validationMessage, systemImage: "exclamationmark.circle.fill")
                        .font(.kgmCaption)
                        .foregroundColor(Color.kgmError)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(KGMSpacing.base)
                        .background(Color.kgmError.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: KGMRadius.md))
                }

                formSection(title: "Adres Tipi", icon: "tag.fill") {
                    HStack(spacing: KGMSpacing.sm) {
                        ForEach(AddressKind.allCases) { kind in
                            Button {
                                selectedKind = kind
                                if title.isEmpty || AddressKind.allCases.map(\.rawValue).contains(title) {
                                    title = kind.rawValue
                                }
                            } label: {
                                VStack(spacing: KGMSpacing.xs) {
                                    Image(systemName: kind.icon)
                                        .font(.system(size: 18, weight: .semibold))
                                    Text(kind.rawValue)
                                        .font(.kgmCaptionMedium)
                                }
                                .foregroundColor(selectedKind == kind ? .white : .kgmTextPrimary)
                                .frame(maxWidth: .infinity)
                                .frame(height: 66)
                                .background(selectedKind == kind ? Color.kgmPrimary : Color.kgmCardElevated)
                                .clipShape(RoundedRectangle(cornerRadius: KGMRadius.md))
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    KGMTextField(
                        title: "Adres Başlığı",
                        placeholder: "Ev, İş, Depo...",
                        text: $title,
                        leadingIcon: "text.badge.plus"
                    )
                }

                formSection(title: "Alıcı Bilgileri", icon: "person.crop.circle.fill") {
                    HStack(spacing: KGMSpacing.sm) {
                        KGMTextField(title: "Ad", placeholder: "Ad", text: $firstName, leadingIcon: "person.fill")
                        KGMTextField(title: "Soyad", placeholder: "Soyad", text: $lastName, leadingIcon: "person.fill")
                    }
                    KGMTextField(
                        title: "Telefon",
                        placeholder: "05xx xxx xx xx",
                        text: $phone,
                        keyboardType: .phonePad,
                        leadingIcon: "phone.fill"
                    )
                }

                formSection(title: "Adres Bilgileri", icon: "mappin.and.ellipse") {
                    HStack(spacing: KGMSpacing.sm) {
                        KGMTextField(title: "İl", placeholder: "Bursa", text: $city, leadingIcon: "map.fill")
                            .disabled(true)
                            .opacity(0.7)
                        KGMTextField(title: "İlçe", placeholder: "Karacabey", text: $district, leadingIcon: "location.fill")
                            .disabled(true)
                            .opacity(0.7)
                    }
                    KGMTextField(title: "Mahalle", placeholder: "Mahalle", text: $neighborhood, leadingIcon: "signpost.right.fill")
                    KGMTextField(title: "Sokak / Cadde", placeholder: "Sokak veya cadde", text: $street, leadingIcon: "road.lanes")
                    HStack(spacing: KGMSpacing.sm) {
                        KGMTextField(title: "Bina", placeholder: "No", text: $buildingNo, leadingIcon: "building.2.fill")
                        KGMTextField(title: "Kat", placeholder: "Kat", text: $floor, leadingIcon: "square.stack.3d.up.fill")
                        KGMTextField(title: "Daire", placeholder: "Daire", text: $apartmentNo, leadingIcon: "door.left.hand.open")
                    }

                    TextField("Adres tarifi, kapı kodu veya teslimat notu", text: $directions, axis: .vertical)
                        .font(.kgmBody)
                        .lineLimit(3, reservesSpace: true)
                        .padding(KGMSpacing.md)
                        .background(Color.kgmCardElevated)
                        .clipShape(RoundedRectangle(cornerRadius: KGMRadius.md))
                }

                formSection(title: "Konum", icon: "map.circle.fill") {
                    HStack(spacing: KGMSpacing.md) {
                        Image(systemName: latitude == nil ? "location.slash.fill" : "location.fill")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundColor(Color.kgmPrimary)
                            .frame(width: 44, height: 44)
                            .background(Color.kgmPrimary.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: KGMRadius.sm))
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Google Maps konumu")
                                .font(.kgmBodyMedium)
                                .foregroundColor(.kgmTextPrimary)
                            Text(coordinateText)
                                .font(.kgmCaption)
                                .foregroundColor(.kgmTextSecondary)
                        }
                        Spacer()
                        Button("Haritada Seç") { showMapPicker = true }
                            .font(.kgmCaptionMedium)
                            .foregroundColor(Color.kgmPrimary)
                    }

                    if latitude != nil && longitude != nil {
                        Button {
                            latitude = nil
                            longitude = nil
                        } label: {
                            Label("Konumu Temizle", systemImage: "xmark.circle")
                                .font(.kgmCaptionMedium)
                                .foregroundColor(Color.kgmSecondary)
                        }
                        .buttonStyle(.plain)
                    }
                }

                Toggle("Varsayılan adres olarak ayarla", isOn: $isDefault)
                    .font(.kgmBodyMedium)
                    .tint(Color.kgmPrimary)
                    .padding(KGMSpacing.base)
                    .background(Color.kgmCard)
                    .clipShape(RoundedRectangle(cornerRadius: KGMRadius.card))
                    .overlay(RoundedRectangle(cornerRadius: KGMRadius.card).stroke(Color.kgmBorder))
            }
            .padding(KGMSpacing.base)
            .padding(.bottom, 96)
        }
        .background(Color.kgmBackground.ignoresSafeArea())
        .safeAreaInset(edge: .bottom) {
            KGMButton("Adresi Kaydet", isLoading: isSaving, isDisabled: !isFormValid || isSaving) {
                Task { await submit() }
            }
            .padding(KGMSpacing.base)
            .background(.ultraThinMaterial)
        }
        .navigationTitle(existingAddress == nil ? "Yeni Adres" : "Adresi Düzenle")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("İptal") { dismiss() }
                    .disabled(isSaving)
            }
        }
        .disabled(isSaving)
        .overlay {
            if isSaving {
                KGMLoadingOverlay()
            }
        }
        .onAppear {
            if let a = existingAddress {
                title = a.title; firstName = a.firstName; lastName = a.lastName
                phone = a.phone; city = a.city; district = a.district
                neighborhood = a.neighborhood; street = a.street
                buildingNo = a.buildingNo; floor = a.floor; apartmentNo = a.apartmentNo
                directions = a.directions; isDefault = a.isDefault
                latitude = a.latitude; longitude = a.longitude
                selectedKind = AddressKind.allCases.first(where: { $0.rawValue == a.title }) ?? .other
            } else {
                city = city.isEmpty ? "Bursa" : city
                district = district.isEmpty ? "Karacabey" : district
                title = selectedKind.rawValue
            }
        }
        .sheet(isPresented: $showMapPicker) {
            NavigationStack {
                AddressMapPickerView(initialLatitude: latitude, initialLongitude: longitude) { selection in
                    latitude = selection.latitude
                    longitude = selection.longitude
                    if let c = selection.city, !c.isEmpty { city = c }
                    if let d = selection.district, !d.isEmpty { district = d }
                    if let n = selection.neighborhood, !n.isEmpty { neighborhood = n }
                    if let s = selection.street, !s.isEmpty { street = s }
                }
            }
        }
    }

    private var coordinateText: String {
        if let latitude, let longitude {
            return String(format: "%.5f, %.5f", latitude, longitude)
        }
        return "Konum seçilmedi"
    }

    private var isFormValid: Bool {
        AddressInputValidator.isValid(
            firstName: firstName,
            lastName: lastName,
            phone: phone,
            city: city,
            district: district,
            neighborhood: neighborhood,
            street: street
        )
    }

    private func submit() async {
        guard isFormValid else {
            validationMessage = "Lütfen ad, soyad, en az 10 haneli telefon, il, ilçe, mahalle ve sokak alanlarını doldurun."
            return
        }

        validationMessage = nil
        isSaving = true
        defer { isSaving = false }

        let addr = Address(
            id: existingAddress?.id ?? UUID().uuidString,
            title: trimmed(title).isEmpty ? "Adresim" : trimmed(title),
            firstName: trimmed(firstName),
            lastName: trimmed(lastName),
            phone: trimmed(phone),
            city: trimmed(city),
            district: trimmed(district),
            neighborhood: trimmed(neighborhood),
            street: trimmed(street),
            buildingNo: trimmed(buildingNo),
            apartmentNo: trimmed(apartmentNo),
            floor: trimmed(floor),
            directions: trimmed(directions),
            latitude: latitude,
            longitude: longitude,
            isDefault: isDefault
        )

        if await onSave(addr) {
            dismiss()
        } else {
            validationMessage = "Adres kaydedilemedi. Bilgileri kontrol edip tekrar deneyin."
        }
    }

    private func trimmed(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func formSection<Content: View>(
        title: String,
        icon: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: KGMSpacing.md) {
            Label(title, systemImage: icon)
                .font(.kgmHeadline)
                .foregroundColor(.kgmTextPrimary)
            content()
        }
        .padding(KGMSpacing.base)
        .background(Color.kgmCard)
        .clipShape(RoundedRectangle(cornerRadius: KGMRadius.card))
        .overlay(RoundedRectangle(cornerRadius: KGMRadius.card).stroke(Color.kgmBorder))
    }
}
