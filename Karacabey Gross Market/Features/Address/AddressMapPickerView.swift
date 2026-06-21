import CoreLocation
import MapKit
import SwiftUI
import UIKit

struct AddressMapSelection: Hashable {
    let latitude: Double
    let longitude: Double
    var city: String?
    var district: String?
    var neighborhood: String?
    var street: String?
}

struct AddressMapPickerView: View {
    var onSelect: (AddressMapSelection) -> Void

    @Environment(\.dismiss) private var dismiss
    @StateObject private var locationManager = LocationManager()
    @StateObject private var permissionManager = LocationPermissionManager()
    @State private var cameraPosition: MapCameraPosition
    @State private var selectedCoordinate: CLLocationCoordinate2D?
    @State private var errorMessage: String?
    @State private var isLocating = false
    @State private var isGeocoding = false

    init(
        initialLatitude: Double? = nil,
        initialLongitude: Double? = nil,
        onSelect: @escaping (AddressMapSelection) -> Void
    ) {
        self.onSelect = onSelect
        let coordinate: CLLocationCoordinate2D?
        if let initialLatitude, let initialLongitude {
            coordinate = CLLocationCoordinate2D(latitude: initialLatitude, longitude: initialLongitude)
        } else {
            coordinate = nil
        }

        _selectedCoordinate = State(initialValue: coordinate)
        _cameraPosition = State(initialValue: coordinate.map {
            .region(MKCoordinateRegion(center: $0, span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)))
        } ?? .region(MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 40.2153, longitude: 28.3617),
            span: MKCoordinateSpan(latitudeDelta: 0.08, longitudeDelta: 0.08)
        )))
    }

    var body: some View {
        VStack(spacing: 0) {
            Map(position: $cameraPosition) {
                if let selectedCoordinate {
                    Marker("Teslimat konumu", coordinate: selectedCoordinate)
                        .tint(.kgmPrimary)
                }
            }
            .mapControls {
                MapUserLocationButton()
                MapCompass()
                MapScaleView()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            VStack(spacing: KGMSpacing.sm) {
                if let selectedCoordinate {
                    HStack(spacing: KGMSpacing.sm) {
                        Image(systemName: "mappin.circle.fill")
                            .foregroundColor(.kgmPrimary)
                        Text(String(format: "%.5f, %.5f", selectedCoordinate.latitude, selectedCoordinate.longitude))
                            .font(.kgmCaptionMedium)
                            .foregroundColor(.kgmTextPrimary)
                        Spacer()
                    }
                }

                if let errorMessage {
                    Text(errorMessage)
                        .font(.kgmCaption)
                        .foregroundColor(.kgmError)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                HStack(spacing: KGMSpacing.sm) {
                    KGMButton(isLocating ? "Alınıyor..." : "Konumumu Kullan", style: .outline, isDisabled: isLocating) {
                        Task { await useCurrentLocation() }
                    }

                    KGMButton("Google Maps", style: .ghost, isDisabled: selectedCoordinate == nil) {
                        openInGoogleMaps()
                    }
                }

                KGMButton(isGeocoding ? "Konum Çözümleniyor..." : "Bu Konumu Seç", style: .primary, isDisabled: selectedCoordinate == nil || isGeocoding) {
                    guard let selectedCoordinate else { return }
                    Task {
                        isGeocoding = true
                        let location = CLLocation(latitude: selectedCoordinate.latitude, longitude: selectedCoordinate.longitude)
                        let geocoder = CLGeocoder()
                        var city: String?
                        var district: String?
                        var neighborhood: String?
                        var street: String?
                        
                        if let placemark = try? await geocoder.reverseGeocodeLocation(location).first {
                            city = placemark.administrativeArea ?? placemark.locality
                            district = placemark.subAdministrativeArea ?? placemark.locality
                            neighborhood = placemark.subLocality
                            street = placemark.thoroughfare
                        }
                        
                        onSelect(AddressMapSelection(
                            latitude: selectedCoordinate.latitude,
                            longitude: selectedCoordinate.longitude,
                            city: city,
                            district: district,
                            neighborhood: neighborhood,
                            street: street
                        ))
                        isGeocoding = false
                        dismiss()
                    }
                }
            }
            .padding(KGMSpacing.base)
            .background(Color.kgmCard)
        }
        .navigationTitle("Adres Konumu")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Kapat") { dismiss() }
            }
        }
    }

    private func useCurrentLocation() async {
        isLocating = true
        errorMessage = nil

        if permissionManager.status == .notDetermined {
            permissionManager.requestWhenInUse()
            try? await Task.sleep(nanoseconds: 650_000_000)
        }

        do {
            let location = try await locationManager.requestCurrentLocation()
            selectedCoordinate = location.coordinate
            withAnimation(.easeInOut(duration: 0.25)) {
                cameraPosition = .region(MKCoordinateRegion(
                    center: location.coordinate,
                    span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                ))
            }
        } catch {
            errorMessage = "Konum alınamadı. Lütfen izinleri kontrol edin."
        }

        isLocating = false
    }

    private func openInGoogleMaps() {
        guard let selectedCoordinate,
              let url = URL(string: "https://www.google.com/maps/search/?api=1&query=\(selectedCoordinate.latitude),\(selectedCoordinate.longitude)") else {
            return
        }
        UIApplication.shared.open(url)
    }
}
