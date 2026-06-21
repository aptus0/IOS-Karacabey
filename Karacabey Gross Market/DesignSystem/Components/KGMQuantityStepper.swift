import SwiftUI

struct KGMQuantityStepper: View {
    @Binding var quantity: Int
    var min: Int = 1
    var max: Int = 99
    var size: StepperSize = .medium
    var onIncrement: (() -> Void)? = nil
    var onDecrement: (() -> Void)? = nil

    enum StepperSize { case small, medium, large }

    private var safeMax: Int { max >= min ? max : min }

    private var buttonSize: CGFloat {
        switch size { case .small: return 28; case .medium: return 34; case .large: return 40 }
    }

    private var textWidth: CGFloat {
        switch size { case .small: return 30; case .medium: return 36; case .large: return 44 }
    }

    private var fontSize: CGFloat {
        switch size { case .small: return 12; case .medium: return 14; case .large: return 16 }
    }

    var body: some View {
        HStack(spacing: 0) {
            stepButton(systemName: quantity <= min ? "trash" : "minus", isPrimary: false, isDisabled: quantity <= 0) {
                guard quantity > 0 else { return }
                withAnimation(.spring(response: 0.24, dampingFraction: 0.78)) {
                    if let onDecrement {
                        onDecrement()
                    } else if quantity > min {
                        quantity -= 1
                    }
                }
            }

            Text("\(quantity)")
                .font(.system(size: fontSize, weight: .bold, design: .rounded))
                .foregroundColor(.kgmTextPrimary)
                .frame(width: textWidth, height: buttonSize)
                .background(Color.white)
                .monospacedDigit()
                .accessibilityLabel("Ürün adedi")
                .accessibilityValue("\(quantity)")

            stepButton(systemName: "plus", isPrimary: true, isDisabled: quantity >= safeMax) {
                guard quantity < safeMax else { return }
                withAnimation(.spring(response: 0.24, dampingFraction: 0.78)) {
                    if let onIncrement {
                        onIncrement()
                    } else {
                        quantity += 1
                    }
                }
            }
        }
        .background(Color.white)
        .clipShape(Capsule())
        .overlay(Capsule().stroke(Color.kgmBorder, lineWidth: 1))
        .kgmShadow(KGMShadow(color: .black.opacity(0.045), radius: 5, x: 0, y: 2))
    }

    private func stepButton(
        systemName: String,
        isPrimary: Bool,
        isDisabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            action()
        }) {
            Image(systemName: systemName)
                .font(.system(size: fontSize, weight: .heavy))
                .foregroundColor(isPrimary ? .white : .kgmPrimary)
                .frame(width: buttonSize, height: buttonSize)
                .background(isPrimary ? Color.kgmPrimary : Color.white)
                .opacity(isDisabled ? 0.45 : 1)
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .accessibilityLabel(systemName == "plus" ? "Adedi artır" : "Adedi azalt")
    }
}
