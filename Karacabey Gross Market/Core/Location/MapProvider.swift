import Foundation

enum MapProvider: String, Codable {
    case googleMaps
    case appleMapKit

    static var current: MapProvider {
        EnvironmentConfig.googleMapsAPIKey?.isEmpty == false ? .googleMaps : .appleMapKit
    }
}

protocol StoreMapProvider {
    var provider: MapProvider { get }
}

struct GoogleMapsProvider: StoreMapProvider {
    let provider: MapProvider = .googleMaps
    let apiKey: String
}

struct AppleMapKitProvider: StoreMapProvider {
    let provider: MapProvider = .appleMapKit
}

