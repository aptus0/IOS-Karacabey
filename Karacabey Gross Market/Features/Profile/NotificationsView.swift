import SwiftUI
import Combine

enum NotificationScope: String, CaseIterable, Identifiable {
    case unread
    case read

    var id: String { rawValue }
    var title: String { self == .unread ? "Okunmamış" : "Geçmiş" }
    var repositoryStatus: NotificationListStatus { self == .unread ? .unread : .read }
}

@MainActor
final class NotificationsViewModel: ObservableObject {
    @Published var notifications: [NotificationItem] = []
    @Published var selectedScope: NotificationScope = .unread
    @Published var isLoading = false
    @Published var isLoadingMore = false
    @Published var hasMore = true
    @Published var errorMessage: String?

    private let pageSize = 30
    private var currentPage = 1
    private var deletingIDs = Set<String>()

    var unreadCount: Int { notifications.filter { !$0.isRead }.count }

    func load(reset: Bool = true) async {
        if reset {
            currentPage = 1
            hasMore = true
            isLoading = true
            notifications = []
        } else {
            guard hasMore, !isLoadingMore, !isLoading else { return }
            isLoadingMore = true
        }

        errorMessage = nil
        do {
            let page = currentPage
            let newItems = try await NotificationRepository.shared.getNotifications(
                status: selectedScope.repositoryStatus,
                page: page,
                limit: pageSize
            )

            if reset {
                notifications = newItems
            } else {
                appendUnique(newItems)
            }

            hasMore = newItems.count >= pageSize
            if hasMore { currentPage += 1 }
        } catch {
            errorMessage = error.kgmUserMessage
        }

        isLoading = false
        isLoadingMore = false
    }

    func loadMoreIfNeeded(current item: NotificationItem) async {
        guard hasMore, !isLoadingMore, !isLoading else { return }
        guard notifications.suffix(6).contains(where: { $0.id == item.id }) else { return }
        await load(reset: false)
    }

    func resetAndLoad() async {
        await load(reset: true)
    }

    func markRead(_ item: NotificationItem) async {
        guard !item.isRead else { return }
        if let index = notifications.firstIndex(where: { $0.id == item.id }) {
            notifications[index].isRead = true
            notifications[index].readAt = Date()
        }
        do {
            try await NotificationRepository.shared.markRead(id: item.id)
            if selectedScope == .unread {
                notifications.removeAll { $0.id == item.id }
            }
        } catch {
            errorMessage = error.kgmUserMessage
            await load(reset: true)
        }
    }

    func markAllRead() async {
        guard selectedScope == .unread, !notifications.isEmpty else { return }
        let previous = notifications
        notifications.removeAll()
        do {
            try await NotificationRepository.shared.markAllRead()
        } catch {
            notifications = previous
            errorMessage = error.kgmUserMessage
        }
    }

    func delete(_ item: NotificationItem) async {
        guard deletingIDs.insert(item.id).inserted else { return }
        defer { deletingIDs.remove(item.id) }

        let previous = notifications
        notifications.removeAll { $0.id == item.id }
        do {
            try await NotificationRepository.shared.delete(id: item.id)
        } catch {
            notifications = previous
            errorMessage = error.kgmUserMessage
        }
    }

    private func appendUnique(_ items: [NotificationItem]) {
        var seen = Set(notifications.map(\.id))
        for item in items where seen.insert(item.id).inserted {
            notifications.append(item)
        }
    }
}

struct NotificationsView: View {
    var initialNotificationID: String? = nil
    @StateObject private var vm = NotificationsViewModel()
    @EnvironmentObject private var appState: AppState
    @State private var selectedNotification: NotificationItem?
    @State private var deleteTask: Task<Void, Never>?

    var body: some View {
        VStack(spacing: 0) {
            Picker("Bildirim filtresi", selection: $vm.selectedScope) {
                ForEach(NotificationScope.allCases) { scope in
                    Text(scope.title).tag(scope)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, KGMSpacing.base)
            .padding(.top, KGMSpacing.sm)

            Group {
                if vm.isLoading && vm.notifications.isEmpty {
                    KGMLoadingView()
                } else if let error = vm.errorMessage, vm.notifications.isEmpty {
                    KGMErrorView(message: error) { Task { await load() } }
                } else if vm.notifications.isEmpty {
                    KGMEmptyStateView(
                        icon: vm.selectedScope == .unread ? "bell.slash" : "clock.arrow.circlepath",
                        title: vm.selectedScope == .unread ? "Okunmamış Bildirim Yok" : "Bildirim Geçmişi Boş",
                        message: vm.selectedScope == .unread ? "Yeni sipariş, ödeme ve kampanya bildirimleri burada görünür." : "Okunmuş bildirimler 30 gün boyunca geçmişte tutulur."
                    )
                } else {
                    List {
                        ForEach(vm.notifications) { item in
                            Button {
                                Task { await markRead(item) }
                                selectedNotification = item
                            } label: {
                                NotificationRow(item: item)
                            }
                            .buttonStyle(.plain)
                            .onAppear { Task { await vm.loadMoreIfNeeded(current: item) } }
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    deleteTask?.cancel()
                                    deleteTask = Task { await delete(item) }
                                } label: {
                                    Label("Sil", systemImage: "trash")
                                }
                            }
                            .listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                        }

                        if vm.isLoadingMore {
                            HStack { Spacer(); ProgressView().tint(.kgmPrimary); Spacer() }
                                .listRowSeparator(.hidden)
                                .listRowBackground(Color.clear)
                        } else if !vm.hasMore {
                            Text("Tüm bildirimler gösterildi")
                                .font(.kgmSmall)
                                .foregroundColor(.kgmTextMuted)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding(.vertical, KGMSpacing.sm)
                                .listRowSeparator(.hidden)
                                .listRowBackground(Color.clear)
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    .background(Color.kgmBackground)
                }
            }
        }
        .background(Color.kgmBackground.ignoresSafeArea())
        .navigationTitle("Bildirimler")
        .navigationBarTitleDisplayMode(.large)
        .navigationDestination(item: $selectedNotification) { item in
            NotificationDetailView(item: item)
        }
        .toolbar {
            if vm.selectedScope == .unread && !vm.notifications.isEmpty {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Tümünü Okundu Yap") {
                        Task {
                            await vm.markAllRead()
                            await appState.refreshUnreadNotificationCount()
                        }
                    }
                    .font(.kgmCaptionMedium)
                }
            }
        }
        .task { await load() }
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 20_000_000_000)
                guard !Task.isCancelled else { return }
                await load()
            }
        }
        .refreshable { await vm.resetAndLoad(); await appState.refreshUnreadNotificationCount() }
        .onReceive(NotificationCenter.default.publisher(for: .kgmPushNotificationReceived)) { _ in
            Task { await load() }
        }
        .onChange(of: vm.selectedScope) { _, _ in Task { await load() } }
        .onChange(of: vm.notifications) { _, notifications in
            guard selectedNotification == nil, let initialNotificationID else { return }
            selectedNotification = notifications.first(where: { $0.id == initialNotificationID })
        }
        .onDisappear {
            deleteTask?.cancel()
            deleteTask = nil
        }
    }

    private func load() async {
        await vm.load(reset: true)
        await appState.refreshUnreadNotificationCount()
    }

    private func markRead(_ item: NotificationItem) async {
        await vm.markRead(item)
        await appState.refreshUnreadNotificationCount()
    }

    private func delete(_ item: NotificationItem) async {
        if selectedNotification?.id == item.id {
            selectedNotification = nil
        }
        await vm.delete(item)
        await appState.refreshUnreadNotificationCount()
    }
}

private struct NotificationDetailView: View {
    let item: NotificationItem

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: KGMSpacing.base) {
                if let rawURL = item.imageURL, let url = EnvironmentConfig.resolveMediaURL(rawURL) {
                    KGMCachedImage(url: url) {
                        Color.kgmPrimary.opacity(0.08)
                            .overlay(Image(systemName: "photo").foregroundColor(.kgmPrimary))
                    }
                    .scaledToFit()
                    .frame(maxWidth: .infinity)
                    .frame(maxHeight: 380)
                    .background(Color.kgmCard)
                    .clipShape(RoundedRectangle(cornerRadius: KGMRadius.card))
                }

                Label(item.category.displayName, systemImage: iconName)
                    .font(.kgmCaptionMedium)
                    .foregroundColor(.kgmPrimary)

                Text(item.title)
                    .font(.kgmLargeTitle)
                    .foregroundColor(.kgmTextPrimary)

                Text(item.body)
                    .font(.kgmBody)
                    .foregroundColor(.kgmTextSecondary)
                    .lineSpacing(5)

                Text(item.createdAt.formatted(date: .long, time: .shortened))
                    .font(.kgmCaption)
                    .foregroundColor(.kgmTextMuted)

                if let deepLink = item.deepLink, !deepLink.isEmpty {
                    Button {
                        DeepLinkRouter.shared.open(deepLink)
                    } label: {
                        Label(item.ctaTitle?.isEmpty == false ? item.ctaTitle! : "Detayları Gör", systemImage: "arrow.right.circle.fill")
                            .font(.kgmBodyMedium)
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .foregroundColor(.white)
                            .background(Color.kgmPrimary)
                            .clipShape(RoundedRectangle(cornerRadius: KGMRadius.card))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(KGMSpacing.base)
        }
        .background(Color.kgmBackground.ignoresSafeArea())
        .navigationTitle("Bildirim")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var iconName: String {
        switch item.category {
        case .order: return "bag.fill"
        case .campaign: return "tag.fill"
        case .system: return "bell.fill"
        case .delivery: return "bicycle"
        case .payment: return "creditcard.fill"
        }
    }
}

private struct NotificationRow: View {
    let item: NotificationItem

    var body: some View {
        HStack(alignment: .top, spacing: KGMSpacing.md) {
            if let rawURL = item.imageURL, let url = EnvironmentConfig.resolveMediaURL(rawURL) {
                KGMCachedImage(url: url) {
                    Image(systemName: iconName)
                        .foregroundColor(.white)
                        .frame(width: 44, height: 44)
                        .background(tint)
                }
                .scaledToFill()
                .frame(width: 44, height: 44)
                .clipShape(RoundedRectangle(cornerRadius: KGMRadius.sm))
            } else {
                Image(systemName: iconName)
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
                    .background(tint)
                    .clipShape(RoundedRectangle(cornerRadius: KGMRadius.sm))
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline) {
                    Text(item.title)
                        .font(.kgmBodyMedium)
                        .foregroundColor(.kgmTextPrimary)
                        .lineLimit(2)
                    Spacer(minLength: KGMSpacing.sm)
                    if !item.isRead {
                        Circle()
                            .fill(Color.kgmPrimary)
                            .frame(width: 8, height: 8)
                    }
                }

                Text(item.body)
                    .font(.kgmCaption)
                    .foregroundColor(.kgmTextSecondary)
                    .lineLimit(3)

                Text(item.createdAt, style: .date)
                    .font(.kgmSmall)
                    .foregroundColor(.kgmTextMuted)
            }
        }
        .padding(KGMSpacing.base)
        .background(item.isRead ? Color.kgmCard : Color.kgmPrimary.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: KGMRadius.card))
        .overlay(RoundedRectangle(cornerRadius: KGMRadius.card).stroke(Color.kgmBorder))
    }

    private var iconName: String {
        switch item.category {
        case .order: return "bag.fill"
        case .campaign: return "tag.fill"
        case .system: return "bell.fill"
        case .delivery: return "bicycle"
        case .payment: return "creditcard.fill"
        }
    }

    private var tint: Color {
        switch item.category {
        case .order: return .kgmPrimary
        case .campaign: return .kgmWarning
        case .system: return .kgmInfo
        case .delivery: return .kgmSuccess
        case .payment: return .kgmSecondary
        }
    }
}
