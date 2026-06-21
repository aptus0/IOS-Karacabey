import SwiftUI

struct KGMOrderStatusTimeline: View {
    let order: Order

    private var timelineStatuses: [OrderStatus] {
        if order.status == .cancelled {
            return [.pending, .cancelled]
        }

        let hasReviewing = order.status == .reviewing || order.statusHistory.contains { $0.status == .reviewing }
        if hasReviewing {
            return [.pending, .reviewing, .received, .preparing, .onTheWay, .delivered]
        }

        return [.pending, .received, .preparing, .onTheWay, .delivered]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: KGMSpacing.md) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Sipariş Durumu")
                        .font(.kgmHeadline)
                        .foregroundColor(.kgmTextPrimary)
                    Text(order.status.displayName)
                        .font(.kgmCaptionMedium)
                        .foregroundColor(order.status == .cancelled ? .kgmError : .kgmPrimary)
                }
                Spacer()
                Image(systemName: order.status.systemIconName)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(order.status == .cancelled ? .kgmError : .kgmPrimary)
                    .frame(width: 38, height: 38)
                    .background((order.status == .cancelled ? Color.kgmError : Color.kgmPrimary).opacity(0.10))
                    .clipShape(Circle())
            }

            VStack(spacing: 0) {
                ForEach(Array(timelineStatuses.enumerated()), id: \.offset) { index, status in
                    HStack(alignment: .top, spacing: KGMSpacing.md) {
                        VStack(spacing: 0) {
                            ZStack {
                                Circle()
                                    .fill(statusColor(status))
                                    .frame(width: 32, height: 32)
                                Image(systemName: icon(for: status))
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundColor(isCompleted(status) || isActive(status) ? .white : .secondary)
                            }
                            if index < timelineStatuses.count - 1 {
                                Rectangle()
                                    .fill(isCompleted(timelineStatuses[index + 1]) ? Color.kgmPrimary : Color(.systemGray5))
                                    .frame(width: 2, height: 34)
                            }
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(status.displayName)
                                .font(.kgmBodyMedium)
                                .foregroundColor(isCompleted(status) || isActive(status) ? .kgmTextPrimary : .kgmTextSecondary)
                            if let event = statusEvent(for: status) {
                                Text(event.timestamp.formatted(date: .abbreviated, time: .shortened))
                                    .font(.kgmSmall)
                                    .foregroundColor(.kgmTextMuted)
                                if let note = event.note, !note.isEmpty {
                                    Text(note)
                                        .font(.kgmSmall)
                                        .foregroundColor(.kgmTextSecondary)
                                }
                            } else if isActive(status) {
                                Text("Aktif aşama")
                                    .font(.kgmSmall)
                                    .foregroundColor(.kgmPrimary)
                            }
                        }
                        .padding(.top, KGMSpacing.xs)
                        Spacer(minLength: 0)
                    }
                }
            }
        }
        .padding(KGMSpacing.base)
    }

    private func isActive(_ status: OrderStatus) -> Bool {
        order.status == status
    }

    private func isCompleted(_ status: OrderStatus) -> Bool {
        guard order.status != .cancelled else { return status == .cancelled }
        return order.statusHistory.contains { $0.status == status } || order.status.progressRank > status.progressRank
    }

    private func statusEvent(for status: OrderStatus) -> OrderStatusEvent? {
        order.statusHistory
            .filter { $0.status == status }
            .sorted { $0.timestamp > $1.timestamp }
            .first
    }

    private func statusColor(_ status: OrderStatus) -> Color {
        if status == .cancelled { return isActive(status) ? .kgmError : Color(.systemGray5) }
        if isActive(status) { return .kgmPrimary }
        if isCompleted(status) { return .kgmPrimary }
        return Color(.systemGray5)
    }

    private func icon(for status: OrderStatus) -> String {
        if isCompleted(status), !isActive(status), status != .cancelled {
            return "checkmark"
        }
        return status.systemIconName
    }
}
