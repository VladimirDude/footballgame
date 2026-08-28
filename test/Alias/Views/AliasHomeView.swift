import SwiftUI

/// Landing screen for Football Alias, pushed from the Profile hub. Only Classic
/// Alias is playable in this MVP; Training and Leaderboard are shown as "Soon".
struct AliasHomeView: View {
    @EnvironmentObject private var alias: AliasContainer

    var body: some View {
        ScrollView {
            VStack(spacing: DSSpacing.lg) {
                hero
                VStack(spacing: DSSpacing.sm) {
                    NavigationLink { AliasSetupView() } label: {
                        menuRow(title: "Play", subtitle: "Classic Alias — two teams, explain & guess",
                                icon: "play.fill", prominent: true)
                    }
                    .buttonStyle(.plain)

                    NavigationLink { AliasCategoriesView() } label: {
                        menuRow(title: "Categories", subtitle: "Browse the word packs",
                                icon: "square.grid.2x2.fill")
                    }
                    .buttonStyle(.plain)

                    NavigationLink { AliasHowToView() } label: {
                        menuRow(title: "How to Play", subtitle: "Rules in 30 seconds",
                                icon: "questionmark.circle.fill")
                    }
                    .buttonStyle(.plain)

                    comingSoonRow(title: "Solo Training", icon: "figure.run")
                    comingSoonRow(title: "Leaderboard", icon: "list.number")
                }
            }
            .padding(DSSpacing.lg)
            .adaptiveContentWidth(AdaptiveLayout.gameMaxWidth)
        }
        .background(DSColor.groupedBackground.ignoresSafeArea())
        .navigationTitle("Football Alias")
        .navigationBarTitleDisplayMode(.large)
    }

    private var hero: some View {
        VStack(spacing: DSSpacing.sm) {
            Image(systemName: "soccerball")
                .font(.system(size: 44))
                .foregroundStyle(DSColor.accent)
            Text("Explain the word.\nDon't say it.")
                .font(.system(size: 22, weight: .heavy, design: .rounded))
                .multilineTextAlignment(.center)
                .foregroundStyle(DSColor.textPrimary)
            Text("The football party game")
                .font(.subheadline)
                .foregroundStyle(DSColor.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DSSpacing.xl)
        .background(RoundedRectangle(cornerRadius: DSRadius.xxl, style: .continuous).fill(DSColor.surface))
        .dsElevation(DSElevation.sm)
    }

    private func menuRow(title: String, subtitle: String, icon: String, prominent: Bool = false) -> some View {
        HStack(spacing: DSSpacing.md) {
            ZStack {
                Circle().fill(prominent ? DSColor.accent : DSColor.accentSoft).frame(width: 46, height: 46)
                Image(systemName: icon)
                    .font(.headline)
                    .foregroundStyle(prominent ? DSColor.onAccent : DSColor.accent)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline).foregroundStyle(DSColor.textPrimary)
                Text(subtitle).font(.caption).foregroundStyle(DSColor.textSecondary)
            }
            Spacer()
            Image(systemName: "chevron.right").font(.caption.weight(.bold)).foregroundStyle(DSColor.textTertiary)
        }
        .padding(DSSpacing.md)
        .background(RoundedRectangle(cornerRadius: DSRadius.lg, style: .continuous).fill(DSColor.surface))
    }

    private func comingSoonRow(title: String, icon: String) -> some View {
        HStack(spacing: DSSpacing.md) {
            ZStack {
                Circle().fill(DSColor.fill).frame(width: 46, height: 46)
                Image(systemName: icon).font(.headline).foregroundStyle(DSColor.textTertiary)
            }
            Text(title).font(.headline).foregroundStyle(DSColor.textTertiary)
            Spacer()
            Text("SOON")
                .font(.system(size: 10, weight: .bold))
                .padding(.horizontal, 8).padding(.vertical, 4)
                .background(Capsule().fill(DSColor.fill))
                .foregroundStyle(DSColor.textTertiary)
        }
        .padding(DSSpacing.md)
        .background(RoundedRectangle(cornerRadius: DSRadius.lg, style: .continuous).fill(DSColor.surface.opacity(0.6)))
    }
}

/// Compact rules screen.
struct AliasHowToView: View {
    private let rules: [(String, String)] = [
        ("1", "Split into teams. Each turn, one player is the explainer."),
        ("2", "Describe the word on the card WITHOUT saying it or any forbidden word."),
        ("3", "Teammates shout guesses. Tap Correct when they get it."),
        ("4", "Stuck? Skip — but skips cost a point if penalties are on."),
        ("5", "When the timer ends, review the turn and fix any miscounts."),
        ("6", "First team to the winning score takes the match.")
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DSSpacing.md) {
                ForEach(rules, id: \.0) { rule in
                    HStack(alignment: .top, spacing: DSSpacing.md) {
                        Text(rule.0)
                            .font(.headline.weight(.bold))
                            .foregroundStyle(DSColor.onAccent)
                            .frame(width: 30, height: 30)
                            .background(Circle().fill(DSColor.accent))
                        Text(rule.1)
                            .font(.subheadline)
                            .foregroundStyle(DSColor.textPrimary)
                        Spacer(minLength: 0)
                    }
                }
            }
            .padding(DSSpacing.lg)
        }
        .background(DSColor.groupedBackground.ignoresSafeArea())
        .navigationTitle("How to Play")
        .navigationBarTitleDisplayMode(.inline)
    }
}
