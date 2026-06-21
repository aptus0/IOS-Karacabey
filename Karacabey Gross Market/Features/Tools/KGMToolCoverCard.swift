import SwiftUI

struct KGMTool: Identifiable, Hashable {
    let id: String
    let title: String
    let subtitle: String
    let iconName: String
    let badge: String?
    let tint: Color
    let deepLink: String
}

struct KGMToolCoverCard: View {
    let tool: KGMTool
    let action: (KGMTool) -> Void

    var body: some View {
        Button {
            action(tool)
        } label: {
            VStack(alignment: .leading, spacing: KGMSpacing.sm) {
                HStack(alignment: .top) {
                    Image(systemName: tool.iconName)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 42, height: 42)
                        .background(tool.tint)
                        .clipShape(RoundedRectangle(cornerRadius: KGMRadius.sm))

                    Spacer()

                    if let badge = tool.badge {
                        Text(badge)
                            .font(.kgmSmall)
                            .foregroundColor(tool.tint)
                            .padding(.horizontal, KGMSpacing.sm)
                            .padding(.vertical, KGMSpacing.xs)
                            .background(tool.tint.opacity(0.12))
                            .clipShape(Capsule())
                    }
                }

                Spacer(minLength: KGMSpacing.md)

                Text(tool.title)
                    .font(.kgmHeadline)
                    .foregroundColor(.kgmTextPrimary)
                    .lineLimit(1)

                Text(tool.subtitle)
                    .font(.kgmCaption)
                    .foregroundColor(.kgmTextSecondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }
            .padding(KGMSpacing.base)
            .frame(maxWidth: .infinity, minHeight: 150, alignment: .leading)
            .background(
                LinearGradient(
                    colors: [Color.kgmCardElevated, tool.tint.opacity(0.12)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: KGMRadius.card)
                    .stroke(Color.kgmBorder, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: KGMRadius.card))
        }
        .buttonStyle(.plain)
    }
}

