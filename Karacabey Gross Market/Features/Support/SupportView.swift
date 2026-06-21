import SwiftUI
import Foundation
import UIKit

struct SupportView: View {
    @State private var expandedFAQ: String? = nil
    @State private var contactSubject = ""
    @State private var contactMessage = ""
    @State private var isSending = false
    @State private var sendResult: SupportSendResult?

    private let faqs: [(String, String)] = [
        ("Siparişim ne zaman gelir?",
         "Karacabey içi teslimat yoğunluğa göre aynı gün planlanır. Sipariş durumunu Siparişlerim ekranından takip edebilirsiniz."),
        ("İptal veya iade nasıl yapabilirim?",
         "Sipariş hazırlanmaya başlamadan önce iptal talebi oluşturabilirsiniz. Teslim edilen ürünlerde iade/değişim için Yardım & Destek formundan bize ulaşın."),
        ("Minimum sipariş tutarı var mı?",
         "Minimum sipariş tutarı 350₺'dir. Ücretsiz teslimat ve kargo kuralları adres bölgesine göre ödeme adımında gerçek zamanlı hesaplanır."),
        ("Hangi ödeme yöntemlerini kabul ediyorsunuz?",
         "Kartla ödeme, 3D Secure ve mağazanın aktif ettiği kapıda ödeme/yemek kartı seçenekleri ödeme ekranında listelenir."),
        ("Fatura alabilir miyim?",
         "Evet. Checkout ekranında bireysel veya kurumsal fatura bilgisi girerek fatura talebi oluşturabilirsiniz."),
    ]

    private var canSend: Bool {
        !isSending && !contactSubject.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !contactMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: KGMSpacing.lg) {
                contactCard
                faqSection
                messageSection
            }
            .padding(KGMSpacing.base)
            .padding(.bottom, KGMSpacing.xxxl)
        }
        .background(Color.kgmBackground.ignoresSafeArea())
        .navigationTitle("Yardım & Destek")
        .navigationBarTitleDisplayMode(.inline)
        .alert(item: $sendResult) { result in
            Alert(
                title: Text(result.isSuccess ? "Mesaj Gönderildi" : "Gönderilemedi"),
                message: Text(result.message),
                dismissButton: .default(Text("Tamam"))
            )
        }
    }

    private var contactCard: some View {
        VStack(spacing: 0) {
            Button {
                openURL(EnvironmentConfig.supportMailboxURL)
            } label: {
                contactRow(icon: "lifepreserver.fill", title: "Destek Paneli", subtitle: "webmail.karacabeygrossmarket.com", showChevron: true)
            }
            .buttonStyle(.plain)

            Divider().padding(.leading, 58)

            contactRow(icon: "envelope.badge.fill", title: "E-posta", subtitle: "support@karacabeygrossmarket.com")

            Divider().padding(.leading, 58)

            contactRow(icon: "mappin.and.ellipse", title: "Mağaza", subtitle: "Karacabey Gross Market / Erkur AVM, Karacabey - Bursa")

            Divider().padding(.leading, 58)

            contactRow(icon: "clock.fill", title: "Çalışma Saatleri", subtitle: "Her gün 08:00 - 22:00")
        }
        .padding(KGMSpacing.base)
        .background(Color.kgmCard)
        .clipShape(RoundedRectangle(cornerRadius: KGMRadius.card))
        .overlay(RoundedRectangle(cornerRadius: KGMRadius.card).stroke(Color.kgmBorder))
    }

    private var faqSection: some View {
        VStack(alignment: .leading, spacing: KGMSpacing.sm) {
            Text("Sıkça Sorulan Sorular")
                .font(.system(size: 20, weight: .heavy))
                .foregroundColor(.kgmTextSecondary)
                .padding(.horizontal, 2)

            VStack(spacing: 0) {
                ForEach(faqs, id: \.0) { faq in
                    DisclosureGroup(
                        isExpanded: Binding(get: { expandedFAQ == faq.0 }, set: { expanded in expandedFAQ = expanded ? faq.0 : nil })
                    ) {
                        Text(faq.1)
                            .font(.kgmCallout)
                            .foregroundColor(.kgmTextSecondary)
                            .padding(.top, KGMSpacing.xs)
                            .padding(.bottom, KGMSpacing.sm)
                    } label: {
                        Text(faq.0)
                            .font(.kgmBodyMedium)
                            .foregroundColor(.kgmTextPrimary)
                    }
                    .padding(.vertical, KGMSpacing.sm)

                    if faq.0 != faqs.last?.0 { Divider() }
                }
            }
            .padding(.horizontal, KGMSpacing.base)
            .background(Color.kgmCard)
            .clipShape(RoundedRectangle(cornerRadius: KGMRadius.card))
            .overlay(RoundedRectangle(cornerRadius: KGMRadius.card).stroke(Color.kgmBorder))
        }
    }

    private var messageSection: some View {
        VStack(alignment: .leading, spacing: KGMSpacing.sm) {
            Text("Bize Mesaj Gönderin")
                .font(.system(size: 20, weight: .heavy))
                .foregroundColor(.kgmTextSecondary)
                .padding(.horizontal, 2)

            VStack(spacing: KGMSpacing.md) {
                TextField("Konu", text: $contactSubject)
                    .font(.kgmBody)
                    .textInputAutocapitalization(.sentences)
                    .padding(.horizontal, KGMSpacing.md)
                    .frame(height: 48)
                    .background(Color.kgmCardElevated)
                    .clipShape(RoundedRectangle(cornerRadius: KGMRadius.md))

                TextField("Mesajınız...", text: $contactMessage, axis: .vertical)
                    .font(.kgmBody)
                    .lineLimit(4...7)
                    .textInputAutocapitalization(.sentences)
                    .padding(KGMSpacing.md)
                    .background(Color.kgmCardElevated)
                    .clipShape(RoundedRectangle(cornerRadius: KGMRadius.md))

                if let lastError = sendResult, !lastError.isSuccess {
                    Text(lastError.message)
                        .font(.kgmSmall)
                        .foregroundColor(.kgmError)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                Button {
                    Task { await sendSupportMessage() }
                } label: {
                    HStack(spacing: KGMSpacing.sm) {
                        if isSending { ProgressView().tint(.white) }
                        Text(isSending ? "Gönderiliyor" : "Gönder")
                            .font(.system(size: 16, weight: .heavy))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(canSend ? Color.kgmPrimary : Color.kgmPrimary.opacity(0.45))
                    .clipShape(RoundedRectangle(cornerRadius: KGMRadius.md))
                }
                .buttonStyle(.plain)
                .disabled(!canSend)
            }
            .padding(KGMSpacing.base)
            .background(Color.kgmCard)
            .clipShape(RoundedRectangle(cornerRadius: KGMRadius.card))
            .overlay(RoundedRectangle(cornerRadius: KGMRadius.card).stroke(Color.kgmBorder))
        }
    }

    private func contactRow(icon: String, title: String, subtitle: String, showChevron: Bool = false) -> some View {
        HStack(spacing: KGMSpacing.md) {
            Image(systemName: icon)
                .font(.system(size: 17, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 42, height: 42)
                .background(Color.kgmPrimary)
                .clipShape(RoundedRectangle(cornerRadius: KGMRadius.sm))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.kgmBodyMedium)
                    .foregroundColor(.kgmTextPrimary)
                Text(subtitle)
                    .font(.kgmCaption)
                    .foregroundColor(.kgmTextSecondary)
                    .lineLimit(2)
            }

            Spacer()

            if showChevron {
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.kgmPrimary)
            }
        }
        .padding(.vertical, KGMSpacing.sm)
    }

    private func sendSupportMessage() async {
        guard canSend else { return }
        isSending = true
        sendResult = nil

        do {
            try await SupportMailService.send(subject: contactSubject, message: contactMessage)
            contactSubject = ""
            contactMessage = ""
            sendResult = SupportSendResult(isSuccess: true, message: "Mesajınız webmail.karacabeygrossmarket.com destek sistemine gönderildi.")
        } catch {
            sendResult = SupportSendResult(isSuccess: false, message: error.kgmUserMessage)
        }

        isSending = false
    }

    private func openURL(_ url: URL) {
        UIApplication.shared.open(url)
    }
}

private struct SupportSendResult: Identifiable {
    let id = UUID()
    let isSuccess: Bool
    let message: String
}

private enum SupportMailService {
    static func send(subject: String, message: String) async throws {
        var request = URLRequest(url: EnvironmentConfig.supportMailEndpointURL)
        request.httpMethod = "POST"
        request.timeoutInterval = EnvironmentConfig.requestTimeout
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let payload = SupportMailPayload(
            subject: subject.trimmingCharacters(in: .whitespacesAndNewlines),
            message: message.trimmingCharacters(in: .whitespacesAndNewlines),
            source: "ios_app",
            appVersion: EnvironmentConfig.appVersion,
            buildNumber: EnvironmentConfig.buildNumber,
            submittedAt: ISO8601DateFormatter().string(from: Date())
        )

        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        request.httpBody = try encoder.encode(payload)

        let session = URLSession(configuration: .default, delegate: PinnedCertificatesURLSessionDelegate(), delegateQueue: nil)
        let (_, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw SupportMailError.invalidResponse
        }
        guard (200...299).contains(http.statusCode) else {
            throw SupportMailError.server(statusCode: http.statusCode)
        }
    }
}

private struct SupportMailPayload: Encodable {
    let subject: String
    let message: String
    let source: String
    let appVersion: String
    let buildNumber: String
    let submittedAt: String
}

private enum SupportMailError: LocalizedError {
    case invalidResponse
    case server(statusCode: Int)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Destek sunucusundan geçerli yanıt alınamadı."
        case .server(let statusCode):
            return "Destek mesajı gönderilemedi. webmail.karacabeygrossmarket.com HTTP \(statusCode) döndürdü."
        }
    }
}
