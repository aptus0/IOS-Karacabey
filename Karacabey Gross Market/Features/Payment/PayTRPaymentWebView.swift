import SwiftUI
import WebKit

enum PayTRPaymentResult: Equatable {
    case success
    case failure
}

struct PayTRPaymentWebView: UIViewRepresentable {
    private let source: Source
    private let onResult: (PayTRPaymentResult) -> Void

    init(url: URL, onResult: @escaping (PayTRPaymentResult) -> Void = { _ in }) {
        source = .url(url)
        self.onResult = onResult
    }

    init(postURL: URL, fields: [String: String], card: PayTRCardForm, onResult: @escaping (PayTRPaymentResult) -> Void = { _ in }) {
        source = .postForm(postURL: postURL, fields: fields, card: card)
        self.onResult = onResult
    }

    static func isTrustedDirectPaymentURL(_ url: URL) -> Bool {
        guard url.scheme?.lowercased() == "https",
              let host = url.host?.lowercased() else {
            return false
        }
        return host == "paytr.com" || host.hasSuffix(".paytr.com")
    }

    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.navigationDelegate = context.coordinator
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        let signature = source.signature
        guard context.coordinator.loadedSignature != signature else { return }
        context.coordinator.loadedSignature = signature

        switch source {
        case .url(let url):
            webView.load(URLRequest(url: url))
        case .postForm(let postURL, let fields, let card):
            webView.loadHTMLString(Self.paytrPostHTML(postURL: postURL, fields: fields, card: card), baseURL: postURL)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onResult: onResult)
    }

    final class Coordinator: NSObject, WKNavigationDelegate {
        var loadedSignature: String?
        private let onResult: (PayTRPaymentResult) -> Void
        private let redirectHandler = PayTRRedirectHandler()
        private var didResolve = false

        init(onResult: @escaping (PayTRPaymentResult) -> Void) {
            self.onResult = onResult
        }

        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction) async -> WKNavigationActionPolicy {
            guard let url = navigationAction.request.url else { return .allow }
            guard let result = redirectHandler.result(for: url) else { return .allow }
            guard !didResolve else { return .cancel }
            didResolve = true
            await MainActor.run { onResult(result) }
            return .cancel
        }
    }

    private enum Source {
        case url(URL)
        case postForm(postURL: URL, fields: [String: String], card: PayTRCardForm)

        var signature: String {
            switch self {
            case .url(let url):
                return "url:\(url.absoluteString)"
            case .postForm(let postURL, let fields, let card):
                return "post:\(postURL.absoluteString):\(fields.count):\(card.sanitizedNumber.suffix(4))"
            }
        }
    }

    private static func paytrPostHTML(postURL: URL, fields: [String: String], card: PayTRCardForm) -> String {
        var payload = fields
        payload["cc_owner"] = card.holderName.trimmingCharacters(in: .whitespacesAndNewlines)
        payload["card_number"] = card.sanitizedNumber
        payload["cvv"] = card.sanitizedCVV
        if let expiry = card.expiryParts {
            payload["expiry_month"] = expiry.month
            payload["expiry_year"] = expiry.year
        }

        let inputs = payload
            .sorted { $0.key < $1.key }
            .map { key, value in
                "<input type=\"hidden\" name=\"\(htmlEscape(key))\" value=\"\(htmlEscape(value))\" />"
            }
            .joined(separator: "\n")

        return """
        <!doctype html>
        <html lang="tr">
        <head>
          <meta charset="utf-8" />
          <meta name="viewport" content="width=device-width, initial-scale=1" />
          <style>
            body { font-family: -apple-system, BlinkMacSystemFont, sans-serif; display: grid; min-height: 100vh; place-items: center; color: #1f2937; }
            .box { text-align: center; padding: 24px; }
          </style>
        </head>
        <body>
          <form id="paytr-form" method="POST" action="\(htmlEscape(postURL.absoluteString))">
            \(inputs)
          </form>
          <div class="box">PayTR güvenli ödeme ekranı açılıyor...</div>
          <script>document.getElementById('paytr-form').submit();</script>
        </body>
        </html>
        """
    }

    private static func htmlEscape(_ value: String) -> String {
        value
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&#39;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
    }
}
