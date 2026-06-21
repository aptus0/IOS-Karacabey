import SwiftUI

struct KGMTextField: View {
    let title: String
    let placeholder: String
    @Binding var text: String
    var isSecure: Bool = false
    var keyboardType: UIKeyboardType = .default
    var errorMessage: String? = nil
    var leadingIcon: String? = nil
    var trailingAction: (() -> Void)? = nil
    var trailingIcon: String? = nil

    @State private var isSecureVisible = false

    var body: some View {
        VStack(alignment: .leading, spacing: KGMSpacing.xs) {
            if !title.isEmpty {
                Text(title)
                    .font(.kgmCaption)
                    .foregroundColor(.secondary)
            }
            HStack(spacing: KGMSpacing.sm) {
                if let icon = leadingIcon {
                    Image(systemName: icon)
                        .foregroundColor(.secondary)
                        .frame(width: 20)
                }
                Group {
                    if isSecure && !isSecureVisible {
                        SecureField(placeholder, text: $text)
                    } else {
                        TextField(placeholder, text: $text)
                            .keyboardType(keyboardType)
                    }
                }
                .font(.kgmBody)
                .autocorrectionDisabled()

                if isSecure {
                    Button(action: { isSecureVisible.toggle() }) {
                        Image(systemName: isSecureVisible ? "eye.slash" : "eye")
                            .foregroundColor(.secondary)
                    }
                } else if let icon = trailingIcon, let action = trailingAction {
                    Button(action: action) {
                        Image(systemName: icon)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.horizontal, KGMSpacing.md)
            .frame(height: 52)
            .background(Color.kgmCardElevated)
            .cornerRadius(KGMRadius.sm)
            .overlay(
                RoundedRectangle(cornerRadius: KGMRadius.sm)
                    .stroke(errorMessage != nil ? Color.kgmSecondary : Color.clear, lineWidth: 1.5)
            )

            if let error = errorMessage {
                Text(error)
                    .font(.kgmSmall)
                    .foregroundColor(Color.kgmSecondary)
            }
        }
    }
}
