import SwiftUI

/// Browse the available word categories with card counts. Premium categories are
/// marked and open the paywall on tap for non-subscribers.
struct AliasCategoriesView: View {
    @EnvironmentObject private var alias: AliasContainer
    @EnvironmentObject private var entitlements: EntitlementService
    @State private var showPaywall = false

    private let language = "en"
    private let columns = [GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: DSSpacing.sm) {
                ForEach(AliasCategory.allCases) { category in
                    tile(category)
                }
            }
            .padding(DSSpacing.lg)
        }
        .background(DSColor.groupedBackground.ignoresSafeArea())
        .navigationTitle("Categories")
        .navigationBarTitleDisplayMode(.inline)
        .paywallSheet(isPresented: $showPaywall, source: "alias_categories")
    }

    private func tile(_ category: AliasCategory) -> some View {
        let count = alias.cardCount(in: category, language: language)
        let locked = !category.isFree && !entitlements.isPro
        return Button {
            if locked {
                AnalyticsService.shared.log(.featureBlocked(feature: PremiumFeature.aliasPremiumPacks.rawValue))
                showPaywall = true
            }
        } label: {
            VStack(alignment: .leading, spacing: DSSpacing.sm) {
                HStack {
                    Image(systemName: category.icon)
                        .font(.title2)
                        .foregroundStyle(DSColor.accent)
                    Spacer()
                    if locked { PremiumBadge() }
                }
                Text(category.displayName)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(DSColor.textPrimary)
                    .lineLimit(1)
                Text("\(count) cards")
                    .font(.caption)
                    .foregroundStyle(DSColor.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(DSSpacing.md)
            .background(RoundedRectangle(cornerRadius: DSRadius.lg, style: .continuous).fill(DSColor.surface))
            .overlay(
                RoundedRectangle(cornerRadius: DSRadius.lg, style: .continuous)
                    .stroke(DSColor.separator, lineWidth: 0.5)
            )
            .opacity(locked ? 0.7 : 1)
        }
        .buttonStyle(.plain)
    }
}
