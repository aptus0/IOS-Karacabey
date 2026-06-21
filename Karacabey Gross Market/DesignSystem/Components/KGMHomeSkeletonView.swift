import SwiftUI

struct KGMHomeSkeletonView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: KGMSpacing.md) {
                // Header skeleton
                HStack {
                    Circle().fill(Color.kgmCardElevated).frame(width: 42, height: 42)
                    Rectangle().fill(Color.kgmCardElevated).frame(height: 24)
                    Circle().fill(Color.kgmCardElevated).frame(width: 42, height: 42)
                }
                .padding(.horizontal, KGMSpacing.base)
                .padding(.top, KGMSpacing.md)
                
                // Search skeleton
                Rectangle().fill(Color.kgmCardElevated)
                    .frame(height: 56)
                    .cornerRadius(KGMRadius.md)
                    .padding(.horizontal, KGMSpacing.base)
                
                // Banner skeleton
                Rectangle().fill(Color.kgmCardElevated)
                    .frame(height: 180)
                    .cornerRadius(KGMRadius.md)
                    .padding(.horizontal, KGMSpacing.base)
                
                // Categories skeleton
                ScrollView(.horizontal) {
                    HStack(spacing: KGMSpacing.sm) {
                        ForEach(0..<5) { _ in
                            VStack {
                                Circle().fill(Color.kgmCardElevated).frame(width: 64, height: 64)
                                Rectangle().fill(Color.kgmCardElevated).frame(width: 60, height: 16)
                            }
                            .frame(width: 104, height: 112)
                            .background(Color.kgmCard)
                        }
                    }
                    .padding(.horizontal, KGMSpacing.base)
                }
                
                // Products skeleton
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: KGMSpacing.sm) {
                    ForEach(0..<4) { _ in
                        Rectangle().fill(Color.kgmCardElevated)
                            .frame(height: 240)
                            .cornerRadius(KGMRadius.card)
                    }
                }
                .padding(.horizontal, KGMSpacing.base)
            }
        }
        .redacted(reason: .placeholder)
        .shimmering()
    }
}
