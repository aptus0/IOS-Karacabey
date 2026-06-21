import SwiftUI

struct KGMSearchBar: View {
    @Binding var text: String
    var placeholder: String = "Ürün, marka veya kategori arayın"
    var onSubmit: (() -> Void)? = nil
    var onCancel: (() -> Void)? = nil

    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: KGMSpacing.sm) {
            HStack(spacing: KGMSpacing.sm) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(isFocused ? .kgmPrimary : .secondary)
                TextField(placeholder, text: $text)
                    .font(.kgmBody)
                    .focused($isFocused)
                    .textInputAutocapitalization(.never)
                    .disableAutocorrection(true)
                    .onSubmit { onSubmit?() }
                if !text.isEmpty {
                    Button(action: { text = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, KGMSpacing.md)
            .frame(height: 48)
            .background(Color.kgmCardElevated)
            .clipShape(RoundedRectangle(cornerRadius: KGMRadius.md, style: .continuous))
            .overlay(
                KGMRotatingSearchBorder(isActive: isFocused || !text.isEmpty)
                    .allowsHitTesting(false)
            )

            if isFocused {
                Button("İptal") {
                    text = ""
                    isFocused = false
                    onCancel?()
                }
                .font(.kgmBody)
                .foregroundColor(Color.kgmPrimary)
                .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: isFocused)
    }
}

private struct KGMRotatingSearchBorder: View {
    let isActive: Bool
    @State private var rotation: Double = 0

    var body: some View {
        RoundedRectangle(cornerRadius: KGMRadius.md, style: .continuous)
            .stroke(
                AngularGradient(
                    colors: isActive
                    ? [Color.kgmPrimary.opacity(0.25), Color.kgmPrimary, Color.white.opacity(0.92), Color.kgmPrimary, Color.kgmPrimary.opacity(0.25)]
                    : [Color.kgmBorder, Color.kgmBorder],
                    center: .center
                ),
                lineWidth: isActive ? 1.35 : 1
            )
            .shadow(color: isActive ? Color.kgmPrimary.opacity(0.28) : .clear, radius: 7, x: 0, y: 0)
            .rotationEffect(.degrees(rotation))
            .onAppear {
                guard isActive else { return }
                withAnimation(.linear(duration: 2.4).repeatForever(autoreverses: false)) {
                    rotation = 360
                }
            }
            .onChange(of: isActive) { _, active in
                rotation = 0
                guard active else { return }
                withAnimation(.linear(duration: 2.4).repeatForever(autoreverses: false)) {
                    rotation = 360
                }
            }
    }
}
