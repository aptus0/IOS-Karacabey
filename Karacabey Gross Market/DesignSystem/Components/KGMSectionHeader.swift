import SwiftUI

struct KGMSectionHeader: View {
    let title: String
    var subtitle: String? = nil
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.kgmTitle2)
                    .foregroundColor(.primary)
                if let sub = subtitle {
                    Text(sub)
                        .font(.kgmCaption)
                        .foregroundColor(.secondary)
                }
            }
            Spacer()
            if let actionTitle = actionTitle {
                Button(action: { action?() }) {
                    Text(actionTitle)
                        .font(.kgmCallout)
                        .foregroundColor(Color.kgmPrimary)
                }
            }
        }
        .padding(.horizontal, KGMSpacing.base)
    }
}
