import SwiftUI

struct KGMAddressCard: View {
    let address: Address
    var isSelected: Bool = false
    var onSelect: (() -> Void)? = nil
    var onEdit: (() -> Void)? = nil
    var onDelete: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: KGMSpacing.sm) {
            HStack {
                HStack(spacing: KGMSpacing.sm) {
                    Image(systemName: "mappin.circle.fill")
                        .foregroundColor(Color.kgmPrimary)
                    Text(address.title)
                        .font(.kgmHeadline)
                    if address.isDefault {
                        Text("Varsayılan")
                            .font(.kgmSmall)
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.kgmPrimary)
                            .cornerRadius(4)
                    }
                }
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(Color.kgmPrimary)
                }
            }
            Text(address.fullAddress)
                .font(.kgmCallout)
                .foregroundColor(.secondary)
                .lineLimit(2)
            Text(address.phone)
                .font(.kgmCaption)
                .foregroundColor(.secondary)

            if onEdit != nil || onDelete != nil {
                HStack(spacing: KGMSpacing.md) {
                    if let edit = onEdit {
                        Button("Düzenle", action: edit)
                            .font(.kgmCaption)
                            .foregroundColor(Color.kgmPrimary)
                            .accessibilityLabel("\(address.title) adresini düzenle")
                    }
                    if let del = onDelete {
                        Button("Sil", action: del)
                            .font(.kgmCaption)
                            .foregroundColor(Color.kgmSecondary)
                            .accessibilityLabel("\(address.title) adresini sil")
                    }
                }
            }
        }
        .padding(KGMSpacing.base)
        .background(isSelected ? Color.kgmPrimary.opacity(0.05) : Color(.systemBackground))
        .cornerRadius(KGMRadius.md)
        .overlay(
            RoundedRectangle(cornerRadius: KGMRadius.md)
                .stroke(isSelected ? Color.kgmPrimary : Color(.systemGray5), lineWidth: isSelected ? 2 : 1)
        )
        .onTapGesture { onSelect?() }
        .accessibilityElement(children: .contain)
        .accessibilityAction(named: "Adresi seç") {
            onSelect?()
        }
    }
}
