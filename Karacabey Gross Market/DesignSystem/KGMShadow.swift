import SwiftUI

struct KGMShadow {
    let color: Color
    let radius: CGFloat
    let x: CGFloat
    let y: CGFloat

    static let card    = KGMShadow(color: .black.opacity(0.07), radius: 6,  x: 0, y: 2)
    static let elevated = KGMShadow(color: .black.opacity(0.12), radius: 12, x: 0, y: 4)
    static let modal   = KGMShadow(color: .black.opacity(0.20), radius: 24, x: 0, y: 8)
    static let button  = KGMShadow(color: .kgmPrimary.opacity(0.25), radius: 8, x: 0, y: 4)
}

extension View {
    func kgmShadow(_ shadow: KGMShadow = .card) -> some View {
        self.shadow(color: shadow.color, radius: shadow.radius, x: shadow.x, y: shadow.y)
    }
}
