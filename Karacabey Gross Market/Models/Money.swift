import Foundation

// DB'deki BIGINT UNSIGNED kuruş alanı için type alias
typealias Kurus = Int64

extension Kurus {
    // 12990 → "₺129,90"
    var formattedTRY: String {
        let lira = Double(self) / 100.0
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.minimumFractionDigits = 2
        f.maximumFractionDigits = 2
        f.decimalSeparator = ","
        f.groupingSeparator = "."
        return "₺\(f.string(from: NSNumber(value: lira)) ?? "\(lira)")"
    }

    var asDouble: Double { Double(self) / 100.0 }
}

extension Double {
    var toKurus: Kurus { Kurus((self * 100).rounded()) }

    var formattedAsTurkishLira: String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.minimumFractionDigits = 2
        f.maximumFractionDigits = 2
        f.decimalSeparator = ","
        f.groupingSeparator = "."
        return "₺\(f.string(from: NSNumber(value: self)) ?? "\(self)")"
    }
}
