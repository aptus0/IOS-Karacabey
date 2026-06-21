import Foundation

struct MobileDeviceRegisterRequest: Codable {
    let deviceId: String
    let platform: String
    let appVersion: String
    let osVersion: String
    let deviceModel: String
    let pushToken: String
    let locale: String
    let timezone: String
}

struct MobileEventRequest: Codable {
    let deviceId: String
    let sessionId: String
    let eventName: String
    let screen: String
    let appVersion: String
    let platform: String
    let payload: [String: AnyCodableValue]?
    let occurredAt: Date?
}

enum AnyCodableValue: Codable {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)
    case null

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
