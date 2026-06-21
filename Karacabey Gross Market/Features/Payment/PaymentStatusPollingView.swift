import SwiftUI

struct PaymentStatusPollingView: View {
    let paymentId: String
    @StateObject private var poller = PaymentStatusPoller()
    @State private var result: PaymentStatusResponse?
    @State private var errorMessage: String?

    var body: some View {
        Group {
            if let result, result.status == .succeeded {
                PaymentSuccessView(orderId: result.paymentId)
            } else if let errorMessage {
                PaymentFailedView(message: errorMessage) {
                    Task { await poll() }
                }
            } else {
                PaymentProcessingView()
            }
        }
        .task { await poll() }
    }

    private func poll() async {
        errorMessage = nil
        while !Task.isCancelled {
            do {
                let response = try await poller.poll(paymentId: paymentId, maxAttempts: 1)
                result = response
                switch response.status {
                case .succeeded:
                    return
                case .pending, .processing:
                    try? await Task.sleep(nanoseconds: 2_000_000_000)
                case .failed, .cancelled, .refunded, .partiallyRefunded:
                    errorMessage = response.status.displayName
                    return
                }
            } catch {
                guard !Task.isCancelled else { return }
                errorMessage = error.kgmUserMessage
                return
            }
        }
    }
}
