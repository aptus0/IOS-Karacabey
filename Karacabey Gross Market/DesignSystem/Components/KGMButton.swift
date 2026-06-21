import SwiftUI

enum KGMButtonStyle {
    case primary, secondary, outline, ghost, destructive
}

struct KGMButton: View {
    let title: String
    let style: KGMButtonStyle
    let isLoading: Bool
    let isDisabled: Bool
    let fullWidth: Bool
    let action: () -> Void
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    init(
        _ title: String,
        style: KGMButtonStyle = .primary,
        isLoading: Bool = false,
        isDisabled: Bool = false,
        fullWidth: Bool = true,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.style = style
        self.isLoading = isLoading
        self.isDisabled = isDisabled
        self.fullWidth = fullWidth
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: KGMSpacing.sm) {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: foregroundColor))
                        .scaleEffect(0.8)
                }
                Text(title)
                    .font(.kgmBodyMedium)
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? 2 : 1)
                    .minimumScaleFactor(0.82)
            }
            .frame(maxWidth: fullWidth ? .infinity : nil)
            .frame(minHeight: 52)
            .padding(.vertical, dynamicTypeSize.isAccessibilitySize ? KGMSpacing.xs : 0)
            .padding(.horizontal, KGMSpacing.base)
            .background(backgroundColor)
            .foregroundColor(foregroundColor)
            .cornerRadius(KGMRadius.md)
            .contentShape(RoundedRectangle(cornerRadius: KGMRadius.md))
            .overlay(
                RoundedRectangle(cornerRadius: KGMRadius.md)
                    .stroke(borderColor, lineWidth: style == .outline ? 1.5 : 0)
            )
            .opacity(isDisabled || isLoading ? 0.6 : 1)
        }
        .disabled(isDisabled || isLoading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityValue(isLoading ? "İşlem devam ediyor" : "")
        .accessibilityHint(accessibilityHint)
    }

    private var accessibilityHint: String {
        if isLoading { return "Lütfen bekleyin." }
        if isDisabled { return "Bu işlem şu anda kullanılamıyor." }
        return style == .destructive ? "Bu işlem geri alınamayabilir." : ""
    }

    private var backgroundColor: Color {
        switch style {
        case .primary:     return Color.kgmPrimary
        case .secondary:   return Color.kgmSecondary
        case .outline:     return .clear
        case .ghost:       return Color.kgmPrimary.opacity(0.1)
        case .destructive: return Color.kgmSecondary
        }
    }

    private var foregroundColor: Color {
        switch style {
        case .primary, .secondary, .destructive: return .white
        case .outline, .ghost: return Color.kgmPrimary
        }
    }

    private var borderColor: Color {
        style == .outline ? Color.kgmPrimary : .clear
    }
}
