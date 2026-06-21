import SwiftUI

struct RefundRequestView: View {
    let paymentId: String
    @State private var reason = ""
    @State private var isSubmitting = false

    var body: some View {
        Form {
            Section("İade Talebi") {
                TextField("Talep nedeni", text: $reason, axis: .vertical)
                Button("İade Talebi Gönder") {
                    Task { await submit() }
                }
                .disabled(reason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSubmitting)
            }
        }
        .navigationTitle("İade")
    }

    private func submit() async {
        isSubmitting = true
        defer { isSubmitting = false }
        try? await PaymentRepository.shared.requestRefund(paymentId: paymentId, amountKurus: nil, reason: reason)
    }
}
