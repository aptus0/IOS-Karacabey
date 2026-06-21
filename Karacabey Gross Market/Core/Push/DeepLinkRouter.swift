import Foundation
import Combine
import SwiftUI

@MainActor
final class DeepLinkRouter: ObservableObject {
    static let shared = DeepLinkRouter()
    @Published private(set) var pendingURL: URL?

    private init() {}

    func open(_ rawValue: String?) {
        guard let rawValue, let url = URL(string: rawValue) else { return }
        pendingURL = url
    }

    func consume() {
        pendingURL = nil
    }
}
