import SwiftUI

enum LegalDocument: String, CaseIterable, Identifiable {
    case kvkk           = "KVKK Aydınlatma Metni"
    case privacy        = "Gizlilik Politikası"
    case distanceSales  = "Mesafeli Satış Sözleşmesi"
    case terms          = "Kullanım Şartları"

    var id: String { rawValue }

    var content: String {
        switch self {
        case .kvkk:
            return """
            KVKK AYDINLATMA METNİ

            Karacabey Gross Market mobil uygulaması ve karacabeygrossmarket.com üzerinden verilen hizmetlerde kişisel verileriniz; 6698 sayılı Kişisel Verilerin Korunması Kanunu kapsamında, siparişin alınması, ödeme ve teslimat süreçlerinin yürütülmesi, müşteri destek taleplerinin yanıtlanması ve yasal yükümlülüklerin yerine getirilmesi amaçlarıyla işlenir.

            Veri Sorumlusu
            Karacabey Gross Market / Erkur AVM
            Hizmet Bölgesi: Karacabey, Bursa ve tanımlı teslimat bölgeleri
            Web: https://karacabeygrossmarket.com
            Destek: support@karacabeygrossmarket.com

            İşlenen Veri Kategorileri
            • Kimlik ve iletişim bilgileri: ad, soyad, telefon, e-posta
            • Teslimat bilgileri: adres, konum izni verilirse yaklaşık konum, teslimat notu
            • Sipariş bilgileri: sepet, ürün, ödeme tipi, fatura tercihi, teslimat durumu
            • İşlem güvenliği: cihaz bilgisi, oturum kayıtları, uygulama kullanım ve hata kayıtları
            • Müşteri destek kayıtları: konu, mesaj içeriği ve başvuru tarihi

            İşleme Amaçları
            • Siparişinizi oluşturmak, hazırlamak ve teslim etmek
            • Ödeme, iade, iptal ve fatura süreçlerini yönetmek
            • Kampanya ve bildirimleri yalnızca izin vermeniz halinde iletmek
            • Dolandırıcılık ve kötüye kullanım risklerini önlemek
            • Destek taleplerinizi sonuçlandırmak ve hizmet kalitesini artırmak

            Aktarım
            Kişisel verileriniz; siparişin gerektirdiği ölçüde ödeme altyapısı, kargo/teslimat hizmet sağlayıcıları, teknik altyapı sağlayıcıları ve yetkili kamu kurumları ile paylaşılabilir. Gereksiz üçüncü taraf paylaşımı yapılmaz.

            Saklama Süresi
            Verileriniz; ilgili mevzuatta öngörülen süreler boyunca veya işleme amacı devam ettiği sürece saklanır. Süre sonunda silinir, yok edilir veya anonim hale getirilir.

            Haklarınız
            KVKK'nın 11. maddesi kapsamındaki erişim, düzeltme, silme, itiraz ve bilgi talebi haklarınızı support@karacabeygrossmarket.com adresinden iletebilirsiniz. Başvurular makul süre içinde değerlendirilir.
            """
        case .privacy:
            return """
            GİZLİLİK POLİTİKASI

            Karacabey Gross Market olarak mobil uygulama ve web mağazasında müşteri gizliliğini temel ilke kabul ederiz. Uygulama yalnızca alışveriş, teslimat, ödeme, destek ve güvenlik süreçleri için gerekli verileri işler.

            Hesap ve Sipariş Verileri
            Ad, soyad, telefon, e-posta, adres, sepet ve sipariş geçmişi; siparişlerin doğru kişiye, doğru adrese ve doğru içerikle ulaştırılması için kullanılır.

            Konum Kullanımı
            Konum izni verirseniz teslimat bölgesi kontrolü, yakındaki mağaza gösterimi ve adres oluşturma işlemlerinde kullanılır. Konum izni kapalıysa adresinizi manuel girebilirsiniz.

            Bildirimler
            Bildirim izni verirseniz sipariş durumu, teslimat bilgilendirmesi ve kampanya duyuruları gönderilebilir. Bildirim tercihlerinizi iOS Ayarları üzerinden dilediğiniz zaman kapatabilirsiniz.

            Ödeme Güvenliği
            Kart işlemleri güvenli ödeme altyapısı üzerinden yürütülür. Uygulama kart bilgilerinizi cihazda saklamaz. 3D Secure ve ödeme doğrulama ekranları ödeme sağlayıcısının güvenli sayfası üzerinden tamamlanır.

            Çerez ve Analitik
            Hizmet kalitesi, hata tespiti ve performans ölçümü için sınırlı teknik kayıtlar tutulabilir. Bu kayıtlar müşteri deneyimini iyileştirmek ve güvenliği sağlamak amacıyla kullanılır.

            İletişim
            Gizlilik talepleriniz ve destek başvurularınız için support@karacabeygrossmarket.com adresinden bize ulaşabilirsiniz.
            """
        case .distanceSales:
            return """
            MESAFELİ SATIŞ SÖZLEŞMESİ

            1. Taraflar
            Satıcı: Karacabey Gross Market / Erkur AVM
            Alıcı: Mobil uygulama veya web sitesi üzerinden sipariş veren müşteri.

            2. Konu
            Bu sözleşme; alıcının Karacabey Gross Market uygulaması veya web sitesi üzerinden elektronik ortamda sipariş verdiği ürünlerin satışı, ödemesi, teslimatı, iptali ve iadesine ilişkin hak ve yükümlülükleri düzenler.

            3. Ürün, Fiyat ve Ödeme
            Ürün adı, miktarı, birim fiyatı, indirim, teslimat ücreti ve toplam ödeme tutarı sipariş özetinde gösterilir. Ödeme seçenekleri ödeme adımında mağazanın aktif ettiği yöntemlere göre listelenir.

            4. Teslimat
            Teslimat; alıcının belirttiği adrese, seçilen teslimat bölgesi ve operasyon yoğunluğuna göre yapılır. Minimum sipariş tutarı ve ücretsiz teslimat/kargo koşulları ödeme adımında güncel olarak gösterilir.

            5. Cayma ve İade
            Mevzuat gereği hızlı bozulan veya son kullanma tarihi kısa olan gıda ürünleri, hijyen açısından iadesi uygun olmayan ürünler ve teslimden sonra ambalajı açılmış ürünler cayma hakkı kapsamı dışında olabilir. Hasarlı, eksik veya hatalı teslim edilen ürünler için teslimat sonrası destek talebi oluşturabilirsiniz.

            6. İptal
            Sipariş hazırlık aşamasına geçmeden önce iptal talebi oluşturulabilir. Hazırlanan veya teslimata çıkan siparişlerde iptal değerlendirmesi operasyon durumuna göre yapılır.

            7. Uyuşmazlık
            Tüketici işlemlerinde yürürlükteki tüketici mevzuatı uygulanır. Başvurular için öncelikle support@karacabeygrossmarket.com destek adresinden iletişime geçebilirsiniz.
            """
        case .terms:
            return """
            KULLANIM ŞARTLARI

            Karacabey Gross Market mobil uygulamasını kullanarak aşağıdaki kullanım koşullarını kabul etmiş olursunuz.

            Hesap Kullanımı
            Hesabınızdaki iletişim, adres ve sipariş bilgilerinin doğru olması müşterinin sorumluluğundadır. Hesabınız üzerinden yapılan işlemlerin güvenliği için telefon ve e-posta bilgilerinizi güncel tutmanız önerilir.

            Sipariş ve Stok
            Ürün fiyatları, stok durumları ve kampanyalar operasyonel nedenlerle değişebilir. Sipariş onayı sırasında güncel stok ve fiyat bilgisi esas alınır. Stokta olmayan ürünler için mağaza müşteriyle iletişime geçebilir veya ödeme/iade süreci işletilebilir.

            Teslimat Kuralları
            Teslimat bölgesi, minimum sepet tutarı, teslimat ücreti ve ücretsiz teslimat koşulları adresinize göre ödeme adımında gösterilir.

            Uygulama Güvenliği
            Uygulamanın kötüye kullanılması, sahte sipariş oluşturulması, ödeme sistemlerinin manipüle edilmesi veya başka kullanıcıların verilerine erişilmeye çalışılması yasaktır.

            Fikri Haklar
            Uygulamadaki marka, logo, tasarım, metin ve görsel içerikler Karacabey Gross Market'e veya ilgili hak sahiplerine aittir. İzinsiz kopyalanamaz ve ticari amaçla kullanılamaz.

            Destek
            Yardım, iade, iptal ve teslimat talepleriniz için uygulamadaki Yardım & Destek ekranını veya support@karacabeygrossmarket.com adresini kullanabilirsiniz.
            """
        }
    }
}

struct LegalMenuView: View {
    @State private var selectedDoc: LegalDocument? = nil

    var body: some View {
        List(LegalDocument.allCases) { doc in
            Button(action: { selectedDoc = doc }) {
                HStack {
                    Image(systemName: "doc.text.fill")
                        .foregroundColor(Color.kgmAccent)
                    Text(doc.rawValue)
                        .foregroundColor(.primary)
                    Spacer()
                    Image(systemName: "chevron.right").foregroundColor(.secondary)
                }
            }
        }
        .navigationTitle("Yasal Metinler")
        .navigationBarTitleDisplayMode(.large)
        .navigationDestination(item: $selectedDoc) { doc in
            LegalDetailView(document: doc)
        }
    }
}

struct LegalDetailView: View {
    let document: LegalDocument

    var body: some View {
        ScrollView {
            Text(document.content)
                .font(.kgmBody)
                .foregroundColor(.secondary)
                .padding(KGMSpacing.base)
        }
        .navigationTitle(document.rawValue)
        .navigationBarTitleDisplayMode(.inline)
    }
}
