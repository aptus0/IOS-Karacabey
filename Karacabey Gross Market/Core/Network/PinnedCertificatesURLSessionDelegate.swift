import Foundation
import Security
import CryptoKit

/// Production TLS sertifika pinning desteği.
/// Info.plist içindeki `KGM_TLS_CERT_SHA256_PINS` değeri virgül/boşluk ayrılmış
/// SHA-256 pin listesi olarak verilir. Pin yoksa sistem trust zinciri geçerli kabul edilir;
/// pin varsa api/web hostları için sertifika hash'i eşleşmek zorundadır.
final class PinnedCertificatesURLSessionDelegate: NSObject, URLSessionDelegate {
    private let pinnedHosts: Set<String>
    private let certificatePins: Set<String>

    override init() {
        let hosts = [EnvironmentConfig.apiBaseURL.host, EnvironmentConfig.webBaseURL.host]
            .compactMap { $0?.lowercased() }
        pinnedHosts = Set(hosts)
        certificatePins = EnvironmentConfig.tlsCertificateSHA256Pins
        super.init()
    }

    func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
              let trust = challenge.protectionSpace.serverTrust else {
            completionHandler(.performDefaultHandling, nil)
            return
        }

        let host = challenge.protectionSpace.host.lowercased()
        guard pinnedHosts.contains(host) else {
            completionHandler(.performDefaultHandling, nil)
            return
        }

        var error: CFError?
        guard SecTrustEvaluateWithError(trust, &error) else {
            CrashReporter.record(
                APIError.insecureTransport,
                context: "tls_trust_failed",
                metadata: ["host": host]
            )
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }

        guard !certificatePins.isEmpty else {
            completionHandler(.useCredential, URLCredential(trust: trust))
            return
        }

        let serverPins = certificateSHA256Pins(from: trust)
        guard !serverPins.isDisjoint(with: certificatePins) else {
            CrashReporter.record(
                APIError.insecureTransport,
                context: "tls_pin_mismatch",
                metadata: ["host": host]
            )
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }

        completionHandler(.useCredential, URLCredential(trust: trust))
    }

    private func certificateSHA256Pins(from trust: SecTrust) -> Set<String> {
        var pins = Set<String>()
        let certificates = (SecTrustCopyCertificateChain(trust) as? [SecCertificate]) ?? []

        for certificate in certificates {
            let data = SecCertificateCopyData(certificate) as Data
            let digest = SHA256.hash(data: data)
            pins.insert(Data(digest).base64EncodedString())
            pins.insert(digest.map { String(format: "%02x", $0) }.joined())
        }
        return pins
    }
}
