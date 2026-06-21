import Foundation
import UserNotifications

final class NotificationService: UNNotificationServiceExtension {
    private var contentHandler: ((UNNotificationContent) -> Void)?
    private var bestAttemptContent: UNMutableNotificationContent?

    override func didReceive(
        _ request: UNNotificationRequest,
        withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void
    ) {
        self.contentHandler = contentHandler
        bestAttemptContent = request.content.mutableCopy() as? UNMutableNotificationContent

        guard let content = bestAttemptContent else {
            contentHandler(request.content)
            return
        }

        // Panelden gelen bildirimlerde özel KGM sesi kullanılır; badge değeri sadece backend açıkça gönderirse güncellenir.
        let soundName = (content.userInfo["sound"] as? String).flatMap { $0.isEmpty ? nil : $0 } ?? "kgm_notification.caf"
        content.sound = UNNotificationSound(named: UNNotificationSoundName(rawValue: soundName))
        if let badge = badgeNumber(from: content.userInfo) {
            content.badge = badge
        }

        guard let rawURL = content.userInfo["image_url"] as? String,
              let url = URL(string: rawURL)
        else {
            contentHandler(content)
            return
        }

        URLSession.shared.downloadTask(with: url) { [weak self] temporaryURL, response, _ in
            guard let self, let content = self.bestAttemptContent else { return }
            defer { contentHandler(content) }
            guard let temporaryURL else { return }

            let fileExtension = response?.suggestedFilename
                .flatMap { URL(fileURLWithPath: $0).pathExtension }
                .flatMap { $0.isEmpty ? nil : $0 } ?? "jpg"
            let localURL = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)
                .appendingPathExtension(fileExtension)
            do {
                try FileManager.default.moveItem(at: temporaryURL, to: localURL)
                let attachment = try UNNotificationAttachment(identifier: "kgm-image", url: localURL)
                content.attachments = [attachment]
            } catch {
                // The original text notification remains usable.
            }
        }.resume()
    }

    override func serviceExtensionTimeWillExpire() {
        if let contentHandler, let bestAttemptContent {
            contentHandler(bestAttemptContent)
        }
    }

    private func badgeNumber(from userInfo: [AnyHashable: Any]) -> NSNumber? {
        for key in ["badge_count", "badge", "unread_count"] {
            if let number = userInfo[key] as? NSNumber {
                return NSNumber(value: max(0, number.intValue))
            }

            if let string = userInfo[key] as? String,
               let value = Int(string.trimmingCharacters(in: .whitespacesAndNewlines)) {
                return NSNumber(value: max(0, value))
            }
        }

        return nil
    }
}
