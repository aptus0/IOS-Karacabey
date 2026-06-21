import SwiftUI

struct CategoriesView: View {
    @State private var categories: [Category] = []
    @State private var isLoading = false
    @State private var selectedCategory: Category? = nil

    private let columns = [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    KGMLoadingView()
                } else {
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: KGMSpacing.sm) {
                            ForEach(categories) { cat in
                                KGMCategoryCard(category: cat) {
                                    selectedCategory = cat
                                }
                            }
                        }
                        .padding(KGMSpacing.base)
                    }
                }
            }
            .navigationTitle("Kategoriler")
            .navigationBarTitleDisplayMode(.large)
            .background(Color.kgmBackground.ignoresSafeArea())
            .navigationDestination(item: $selectedCategory) { cat in
                ProductListView(categoryId: cat.id, title: cat.name)
            }
        }
        .task {
            isLoading = true
            categories = (try? await ProductRepository.shared.getCategories()) ?? []
            isLoading = false
        }
    }
}
