import SwiftUI

extension View {
    func kgmCardField() -> some View {
        self
            .font(.kgmBody)
            .padding(.horizontal, KGMSpacing.md)
            .frame(minHeight: 50)
            .background(Color.kgmCardElevated)
            .clipShape(RoundedRectangle(cornerRadius: KGMRadius.md))
            .overlay(RoundedRectangle(cornerRadius: KGMRadius.md).stroke(Color.kgmBorder))
    }
}

extension View {
    func kgmCardStyle(padding: CGFloat = 16) -> some View {
        self
            .padding(padding)
            .background(Color.kgmCard)
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
    }

    func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }

    func conditionalModifier<M: ViewModifier>(_ condition: Bool, modifier: M) -> some View {
        condition ? AnyView(self.modifier(modifier)) : AnyView(self)
    }

    @ViewBuilder
    func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition { transform(self) } else { self }
    }
}

public struct ShimmerModifier: ViewModifier {
    @State private var isInitialState = true

    public func body(content: Content) -> some View {
        content
            .mask(
                LinearGradient(
                    gradient: .init(colors: [.black.opacity(0.3), .black, .black.opacity(0.3)]),
                    startPoint: (isInitialState ? .init(x: -0.3, y: -0.3) : .init(x: 1, y: 1)),
                    endPoint: (isInitialState ? .init(x: 0, y: 0) : .init(x: 1.3, y: 1.3))
                )
            )
            .animation(.linear(duration: 1.5).repeatForever(autoreverses: false), value: isInitialState)
            .onAppear {
                isInitialState = false
            }
    }
}

extension View {
    @ViewBuilder
    func shimmering(active: Bool = true) -> some View {
        if active {
            modifier(ShimmerModifier())
        } else {
            self
        }
    }
}
