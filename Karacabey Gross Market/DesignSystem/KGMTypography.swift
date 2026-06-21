import SwiftUI

extension Font {
    static var kgmLargeTitle: Font  { .system(.largeTitle, design: .default, weight: .bold) }
    static var kgmTitle: Font       { .system(.title2, design: .default, weight: .bold) }
    static var kgmTitle2: Font      { .system(.title3, design: .default, weight: .semibold) }
    static var kgmHeadline: Font    { .system(.headline, design: .default, weight: .semibold) }
    static var kgmBody: Font        { .system(.body, design: .default, weight: .regular) }
    static var kgmBodyMedium: Font  { .system(.body, design: .default, weight: .medium) }
    static var kgmCallout: Font     { .system(.callout, design: .default, weight: .regular) }
    static var kgmCaption: Font     { .system(.caption, design: .default, weight: .regular) }
    static var kgmCaptionMedium: Font { .system(.caption, design: .default, weight: .medium) }
    static var kgmSmall: Font       { .system(.caption2, design: .default, weight: .regular) }
    static var kgmPrice: Font       { .system(.title3, design: .rounded, weight: .bold) }
    static var kgmPriceSmall: Font  { .system(.callout, design: .rounded, weight: .bold) }
}
