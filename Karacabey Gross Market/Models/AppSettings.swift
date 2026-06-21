import Foundation

struct AppSetting: Identifiable, Codable, Hashable {
    let id: String
    var key: String
    var value: String
    var type: String
    var group: String?
    var isPublic: Bool
    var updatedAt: Date
}

struct AppSettingsBundle: Codable {
    var settings: [AppSetting]

    init(settings: [AppSetting] = []) {
        self.settings = settings
    }

    enum CodingKeys: String, CodingKey {
        case settings
        case data
        case config
    }

    enum BootstrapDataKeys: String, CodingKey {
        case config
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        if let settings = try? container.decode([AppSetting].self, forKey: .settings) {
            self.settings = settings
            return
        }

        if let data = try? container.nestedContainer(keyedBy: BootstrapDataKeys.self, forKey: .data),
           let config = try? data.decode([String: FlexibleSettingValue].self, forKey: .config) {
            settings = Self.settings(from: config)
            return
        }

        if let config = try? container.decode([String: FlexibleSettingValue].self, forKey: .config) {
            settings = Self.settings(from: config)
            return
        }

        settings = []
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(settings, forKey: .settings)
    }

    subscript(key: String) -> String? {
        settings.first { $0.key == key }?.value
    }

    func bool(for key: String) -> Bool {
        settings.first { $0.key == key }?.value == "true"
    }

    func double(for key: String) -> Double? {
        guard let raw = settings.first(where: { $0.key == key })?.value else { return nil }
        return Double(raw)
    }

    func int(for key: String) -> Int? {
        guard let raw = settings.first(where: { $0.key == key })?.value else { return nil }
        return Int(raw)
    }

    private static func settings(from config: [String: FlexibleSettingValue]) -> [AppSetting] {
        config
            .sorted { $0.key < $1.key }
            .map { key, value in
                AppSetting(
                    id: key,
                    key: key,
                    value: value.stringValue,
                    type: value.valueType,
                    group: "mobile",
                    isPublic: true,
                    updatedAt: Date()
                )
            }
    }
}

private enum FlexibleSettingValue: Codable {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)
    case null

    var stringValue: String {
        switch self {
        case .string(let value): return value
        case .int(let value): return String(value)
        case .double(let value): return String(value)
        case .bool(let value): return value ? "true" : "false"
        case .null: return ""
        }
    }

    var valueType: String {
        switch self {
        case .string: return "string"
        case .int: return "integer"
        case .double: return "double"
        case .bool: return "boolean"
        case .null: return "null"
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode(Int.self) {
            self = .int(value)
        } else if let value = try? container.decode(Double.self) {
            self = .double(value)
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else {
            self = .null
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let value): try container.encode(value)
        case .int(let value): try container.encode(value)
        case .double(let value): try container.encode(value)
        case .bool(let value): try container.encode(value)
        case .null: try container.encodeNil()
        }
    }
}

enum AppSettingKey {
    static let minOrderAmount = "min_order_amount"
    static let deliveryFee = "delivery_fee"
    static let freeDeliveryThreshold = "free_delivery_threshold"
    static let maintenanceMode = "maintenance_mode"
    static let maintenanceMessage = "maintenance_message"
    static let supportPhone = "support_phone"
    static let supportEmail = "support_email"
    static let maxCartItems = "max_cart_items"
    static let couponEnabled = "coupon_enabled"
    static let reviewsEnabled = "reviews_enabled"
}
