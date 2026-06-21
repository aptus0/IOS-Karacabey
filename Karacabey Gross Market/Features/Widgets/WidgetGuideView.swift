import SwiftUI
import WidgetKit

struct WidgetGuideView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("KGM Widget Merkezi")
                    .font(.largeTitle.weight(.black))
                    .foregroundColor(.kgmTextPrimary)

                Text("Kampanya, sepet, arama ve sipariş widgetlarını ana ekrana veya kilit ekranına ekleyebilirsin. iOS güvenlik kuralları nedeniyle uygulamalar widgetı kullanıcı yerine otomatik ekleyemez; ancak widget verileri otomatik hazırlanır ve güncellenir.")
                    .font(.kgmBody)
                    .foregroundColor(.kgmTextSecondary)

                guideCard(title: "Ana ekran", icon: "square.grid.2x2.fill", text: "Ana ekranda boş alana basılı tut, + düğmesine dokun ve Karacabey Gross Market widgetını seç.")
                guideCard(title: "Kilit ekranı", icon: "lock.fill", text: "Kilit ekranına basılı tut, Özelleştir > Kilit Ekranı > Widget Ekle alanından KGM widgetını seç.")
                guideCard(title: "Sesli bildirim", icon: "bell.badge.fill", text: "Bildirim izni açıksa sipariş ve kampanya bildirimleri iPhone varsayılan sesiyle gelir.")
            }
            .padding(20)
        }
        .background(Color.kgmBackground.ignoresSafeArea())
        .navigationTitle("Widgetlar")
    }

    private func guideCard(title: String, icon: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.title3.bold())
                .foregroundColor(.white)
                .frame(width: 42, height: 42)
                .background(Color.kgmPrimary)
                .clipShape(RoundedRectangle(cornerRadius: 13))
            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .font(.headline.weight(.heavy))
                    .foregroundColor(.kgmTextPrimary)
                Text(text)
                    .font(.kgmCaption)
                    .foregroundColor(.kgmTextSecondary)
            }
        }
        .padding(14)
        .background(Color.kgmCard)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}
