import Combine
import Foundation
import PassKit

@MainActor
final class ApplePayService: NSObject, ObservableObject {
    static let shared = ApplePayService()
    
    @Published var isApplePayAvailable: Bool = false
    @Published var isPaymentPending: Bool = false
    @Published var paymentError: Error?
    
    private var paymentController: PKPaymentAuthorizationController?
    override private init() {
        super.init()
        checkAvailability()
    }
    
    private func checkAvailability() {
        isApplePayAvailable = PKPaymentAuthorizationController.canMakePayments()
    }
    
    func startPayment(amount: Double, orderNumber: String) {
        let request = PKPaymentRequest()
        request.merchantIdentifier = "merchant.com.karacabeygross.app" // Replace with actual Apple Developer Merchant ID
        request.supportedNetworks = [.visa, .masterCard]
        request.merchantCapabilities = .threeDSecure
        request.countryCode = "TR"
        request.currencyCode = "TRY"
        
        let paymentItem = PKPaymentSummaryItem(label: "Karacabey Gross Market Sipariş: \(orderNumber)", amount: NSDecimalNumber(value: amount))
        request.paymentSummaryItems = [paymentItem]
        
        paymentController = PKPaymentAuthorizationController(paymentRequest: request)
        paymentController?.delegate = self
        
        isPaymentPending = true
        paymentController?.present(completion: { presented in
            if !presented {
                Task { @MainActor in
                    ApplePayService.shared.handlePresentationFailure()
                }
            }
        })
    }

    private func handlePresentationFailure() {
        isPaymentPending = false
        paymentError = NSError(
            domain: "ApplePay",
            code: -1,
            userInfo: [NSLocalizedDescriptionKey: "Apple Pay ekranı açılamadı."]
        )
    }
}

extension ApplePayService: PKPaymentAuthorizationControllerDelegate {
    nonisolated func paymentAuthorizationController(_ controller: PKPaymentAuthorizationController, didAuthorizePayment payment: PKPayment, handler completion: @escaping (PKPaymentAuthorizationResult) -> Void) {
        Task { @MainActor in
            // Here you would normally send the payment.token.paymentData to your backend.
            // backend.processApplePay(token: payment.token.paymentData)
            
            // For now we simulate success
            let result = PKPaymentAuthorizationResult(status: .success, errors: nil)
            completion(result)
        }
    }
    
    nonisolated func paymentAuthorizationControllerDidFinish(_ controller: PKPaymentAuthorizationController) {
        Task { @MainActor in
            self.isPaymentPending = false
            await controller.dismiss()
        }
    }
}
