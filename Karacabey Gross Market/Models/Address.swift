import Foundation

// Go API addresses cevabı:
// {id (int64), title, recipient_name, phone, city, district, neighborhood,
//  address_line, postal_code, is_default}
//
// Mobile UI form'u tarihsel olarak firstName/lastName ve street/buildingNo/...
// gibi ayrı alanlar topluyor. Burada backend uyumunu korumak için decode/encode
// custom yapılır; UI form alanları korunur, fakat backend ile sadece
// {title, recipient_name, phone, city, district, neighborhood, address_line,
//  postal_code, is_default} alanları taşınır.
struct Address: Identifiable, Codable, Hashable {
    var id: String          // server için Int64; local UUID kullanımına izin vermek için String
    var title: String
    var firstName: String
    var lastName: String
    var phone: String
    var city: String
    var district: String
    var neighborhood: String
    var street: String      // backend: address_line satırının ana içeriği
    var buildingNo: String
    var apartmentNo: String
    var floor: String
    var directions: String
    var postalCode: String
    var latitude: Double?
    var longitude: Double?
    var isDefault: Bool

    init(
        id: String,
        title: String,
        firstName: String,
        lastName: String,
        phone: String,
        city: String,
        district: String,
        neighborhood: String,
        street: String,
        buildingNo: String,
        apartmentNo: String,
        floor: String,
        directions: String,
        postalCode: String = "",
        latitude: Double? = nil,
        longitude: Double? = nil,
        isDefault: Bool
    ) {
        self.id = id
        self.title = title
        self.firstName = firstName
        self.lastName = lastName
        self.phone = phone
        self.city = city
        self.district = district
        self.neighborhood = neighborhood
        self.street = street
        self.buildingNo = buildingNo
        self.apartmentNo = apartmentNo
        self.floor = floor
        self.directions = directions
        self.postalCode = postalCode
        self.latitude = latitude
        self.longitude = longitude
        self.isDefault = isDefault
    }

    var recipientName: String {
        let combined = "\(firstName) \(lastName)".trimmingCharacters(in: .whitespaces)
        return combined.isEmpty ? title : combined
    }

    var addressLine: String {
        var parts: [String] = []
        if !street.isEmpty { parts.append(street) }
        if !buildingNo.isEmpty { parts.append("No:\(buildingNo)") }
        if !floor.isEmpty { parts.append("Kat:\(floor)") }
        if !apartmentNo.isEmpty { parts.append("D:\(apartmentNo)") }
        if !directions.isEmpty { parts.append(directions) }
        return parts.joined(separator: " ")
    }

    var fullAddress: String {
        var parts: [String] = [addressLine]
        if !neighborhood.isEmpty { parts.append(neighborhood) }
        parts.append("\(district)/\(city)")
        return parts.joined(separator: ", ")
    }

    // MARK: - Codable

    enum CodingKeys: String, CodingKey {
        case id, title, phone, city, district, neighborhood, isDefault, postalCode
        case recipientName, addressLine
        case latitude, longitude, lat, lng
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        // id Int64 olarak gelir; String'e dönüştür.
        if let intId = try? c.decode(Int64.self, forKey: .id) {
            id = String(intId)
        } else {
            id = (try? c.decode(String.self, forKey: .id)) ?? UUID().uuidString
        }
        title = (try? c.decode(String.self, forKey: .title)) ?? ""
        phone = (try? c.decode(String.self, forKey: .phone)) ?? ""
        city = (try? c.decode(String.self, forKey: .city)) ?? ""
        district = (try? c.decode(String.self, forKey: .district)) ?? ""
        neighborhood = (try? c.decodeIfPresent(String.self, forKey: .neighborhood)) ?? ""
        postalCode = (try? c.decodeIfPresent(String.self, forKey: .postalCode)) ?? ""
        latitude = (try? c.decodeIfPresent(Double.self, forKey: .latitude))
            ?? (try? c.decodeIfPresent(Double.self, forKey: .lat))
        longitude = (try? c.decodeIfPresent(Double.self, forKey: .longitude))
            ?? (try? c.decodeIfPresent(Double.self, forKey: .lng))
        isDefault = (try? c.decode(Bool.self, forKey: .isDefault)) ?? false

        let recipient = (try? c.decode(String.self, forKey: .recipientName)) ?? ""
        let parts = recipient.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: true).map(String.init)
        firstName = parts.first ?? recipient
        lastName = parts.count > 1 ? parts[1] : ""

        street = (try? c.decode(String.self, forKey: .addressLine)) ?? ""
        buildingNo = ""
        apartmentNo = ""
        floor = ""
        directions = ""
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(title, forKey: .title)
        try c.encode(recipientName, forKey: .recipientName)
        try c.encode(phone, forKey: .phone)
        try c.encode(city, forKey: .city)
        try c.encode(district, forKey: .district)
        if !neighborhood.isEmpty {
            try c.encode(neighborhood, forKey: .neighborhood)
        }
        try c.encode(addressLine, forKey: .addressLine)
        if !postalCode.isEmpty {
            try c.encode(postalCode, forKey: .postalCode)
        }
        try c.encode(isDefault, forKey: .isDefault)
    }
}

enum AddressInputValidator {
    nonisolated static func isValid(
        firstName: String,
        lastName: String,
        phone: String,
        city: String,
        district: String,
        neighborhood: String,
        street: String
    ) -> Bool {
        !trimmed(firstName).isEmpty &&
        !trimmed(lastName).isEmpty &&
        phone.filter(\.isNumber).count >= 10 &&
        !trimmed(city).isEmpty &&
        !trimmed(district).isEmpty &&
        !trimmed(neighborhood).isEmpty &&
        !trimmed(street).isEmpty
    }

    nonisolated private static func trimmed(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
