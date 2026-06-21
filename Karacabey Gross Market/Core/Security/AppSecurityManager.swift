import UIKit
import Darwin

final class AppSecurityManager {
    static let shared = AppSecurityManager()
    private init() {}

    private weak var privacyOverlay: UIView?
    private var captureObserver: NSObjectProtocol?

    var isDeviceCompromised: Bool {
        #if targetEnvironment(simulator)
        return false
        #else
        return hasJailbreakFiles || canOpenJailbreakSchemes || canWriteOutsideSandbox || hasSuspiciousSymlinks || hasInjectedDynamicLibraries
        #endif
    }

    var isDebuggerAttached: Bool {
        #if DEBUG
        return false
        #else
        var info = kinfo_proc()
        var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_PID, getpid()]
        var size = MemoryLayout<kinfo_proc>.stride
        let result = sysctl(&mib, u_int(mib.count), &info, &size, nil, 0)
        guard result == 0 else { return false }
        return (info.kp_proc.p_flag & P_TRACED) != 0
        #endif
    }

    var isScreenCaptured: Bool {
        UIScreen.main.isCaptured
    }

    func configureRuntimeProtection() {
        captureObserver = NotificationCenter.default.addObserver(
            forName: UIScreen.capturedDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard UIScreen.main.isCaptured else { return }
            self?.showPrivacyOverlay(reason: "Ekran kaydı algılandı")
            CrashReporter.record(
                APIError.insecureTransport,
                context: "screen_capture_detected",
                metadata: ["screen": "runtime"]
            )
        }
    }

    func showPrivacyOverlay(reason: String = "Gizlilik koruması aktif") {
        guard let window = keyWindow(), privacyOverlay == nil else { return }
        let overlay = UIView(frame: window.bounds)
        overlay.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        overlay.backgroundColor = UIColor.systemBackground

        let stack = UIStackView()
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false

        let icon = UIImageView(image: UIImage(systemName: "lock.shield.fill"))
        icon.tintColor = UIColor.systemOrange
        icon.contentMode = .scaleAspectFit
        icon.translatesAutoresizingMaskIntoConstraints = false

        let title = UILabel()
        title.text = "Karacabey Gross Market"
        title.font = UIFont.preferredFont(forTextStyle: .headline)
        title.textColor = UIColor.label
        title.textAlignment = .center

        let message = UILabel()
        message.text = reason
        message.font = UIFont.preferredFont(forTextStyle: .subheadline)
        message.textColor = UIColor.secondaryLabel
        message.textAlignment = .center
        message.numberOfLines = 0

        stack.addArrangedSubview(icon)
        stack.addArrangedSubview(title)
        stack.addArrangedSubview(message)
        overlay.addSubview(stack)
        window.addSubview(overlay)

        NSLayoutConstraint.activate([
            icon.widthAnchor.constraint(equalToConstant: 44),
            icon.heightAnchor.constraint(equalToConstant: 44),
            stack.centerXAnchor.constraint(equalTo: overlay.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: overlay.centerYAnchor),
            stack.leadingAnchor.constraint(greaterThanOrEqualTo: overlay.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: overlay.trailingAnchor, constant: -24)
        ])

        privacyOverlay = overlay
    }

    func hidePrivacyOverlay() {
        privacyOverlay?.removeFromSuperview()
        privacyOverlay = nil
    }

    /// Hassas ekranlarda ekran kaydı açıksa ekrana güvenli uyarı bindirir.
    func protectSensitiveScreen() {
        if isScreenCaptured {
            showPrivacyOverlay(reason: "Ödeme ve kişisel bilgiler ekran kaydı sırasında gizlenir.")
        }
    }

    func preventScreenshot(for window: UIWindow?) {
        // iOS ekran görüntüsünü tamamen engellemez; ancak ödeme/kişisel ekranlarda
        // .privacySensitive(), ekran kaydı tespiti ve arka plan overlay birlikte kullanılır.
        if UIScreen.main.isCaptured {
            showPrivacyOverlay(reason: "Hassas bilgiler güvenlik nedeniyle gizlendi.")
        }
    }

    private var hasJailbreakFiles: Bool {
        let paths = [
            "/Applications/Cydia.app",
            "/Applications/Sileo.app",
            "/Applications/Zebra.app",
            "/Library/MobileSubstrate/MobileSubstrate.dylib",
            "/bin/bash",
            "/usr/sbin/sshd",
            "/etc/apt",
            "/private/var/lib/apt/",
            "/private/var/mobile/Library/SBSettings/Themes"
        ]
        return paths.contains { FileManager.default.fileExists(atPath: $0) }
    }

    private var canOpenJailbreakSchemes: Bool {
        guard Thread.isMainThread else { return false }
        let schemes = ["cydia://package/com.example", "sileo://package/com.example", "zbra://packages"]
        return schemes.compactMap(URL.init(string:)).contains { UIApplication.shared.canOpenURL($0) }
    }

    private var canWriteOutsideSandbox: Bool {
        let path = "/private/kgm_jb_test_\(UUID().uuidString)"
        do {
            try "kgm".write(toFile: path, atomically: true, encoding: .utf8)
            try? FileManager.default.removeItem(atPath: path)
            return true
        } catch {
            return false
        }
    }

    private var hasSuspiciousSymlinks: Bool {
        let paths = ["/Applications", "/Library/Ringtones", "/usr/arm-apple-darwin9"]
        return paths.contains { path in
            guard let attributes = try? FileManager.default.attributesOfItem(atPath: path) else { return false }
            return attributes[.type] as? FileAttributeType == .typeSymbolicLink
        }
    }

    private var hasInjectedDynamicLibraries: Bool {
        guard let dyld = getenv("DYLD_INSERT_LIBRARIES") else { return false }
        return String(cString: dyld).isEmpty == false
    }

    private func keyWindow() -> UIWindow? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }
    }
}
