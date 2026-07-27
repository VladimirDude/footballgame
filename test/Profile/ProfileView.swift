import SwiftUI

/// The "You" tab: level/XP, aggregate + per-mode stats, and the achievements
/// grid. Reads the `GameProgressStore` and reuses the design system throughout.
struct ProfileView: View {
    @EnvironmentObject private var progress: GameProgressStore
    @EnvironmentObject private var entitlements: EntitlementService
    @State private var showDaily = false

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: DSSpacing.lg) {
                    levelHeader
                    if !entitlements.isSubscribed && !entitlements.progressionUnlocked {
                        proProgressCard
                    }
                    playSection
                    dailyCard
                    statsGrid
                    perModeSection
                    achievementsSection
                }
                .padding(DSSpacing.md)
                .adaptiveContentWidth(AdaptiveLayout.settingsMaxWidth)
            }
            .background(DSColor.groupedBackground.ignoresSafeArea())
            .navigationTitle("You")
        }
        .fullScreenCover(isPresented: $showDaily) {
            DailyChallengeView(questions: ClubDataStore.shared.makeDailyQuestions(seed: DailyChallenge.seed()))
        }
    }

    // MARK: - Play & explore

    private var playSection: some View {
        VStack(spacing: DSSpacing.sm) {
            NavigationLink {
                GameView()
                    .navigationTitle("Games")
                    .navigationBarTitleDisplayMode(.inline)
            } label: {
                entryRow(title: "Games", subtitle: "Guess the club, nation, player, league & more",
                         icon: "gamecontroller.fill", tint: DSColor.accent)
            }
            .buttonStyle(.plain)

            NavigationLink {
                AliasHomeView()
            } label: {
                entryRow(title: "Football Alias", subtitle: "Explain & guess — the football party game",
                         icon: "person.2.fill", tint: DSColor.accent)
            }
            .buttonStyle(.plain)

            NavigationLink {
                SearchView()
            } label: {
                entryRow(title: "Search", subtitle: "Browse players and clubs in the offline database",
                         icon: "magnifyingglass", tint: DSColor.accent)
            }
            .buttonStyle(.plain)
        }
    }

    private func entryRow(title: String, subtitle: String, icon: String, tint: Color) -> some View {
        HStack(spacing: DSSpacing.md) {
            ZStack {
                Circle().fill(tint.opacity(0.15)).frame(width: 46, height: 46)
                Image(systemName: icon).font(.title3).foregroundStyle(tint)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title).dsFont(.headline).foregroundStyle(DSColor.textPrimary)
                Text(subtitle).dsFont(.subheadline).foregroundStyle(DSColor.textSecondary)
                    .lineLimit(2)
            }
            Spacer(minLength: 0)
            DSChevron()
        }
        .contentShape(Rectangle())
        .dsCard()
    }

    // MARK: - Daily challenge

    private var dailyCard: some View {
        Button { showDaily = true } label: {
            HStack(spacing: DSSpacing.md) {
                ZStack {
                    Circle().fill(DSColor.accent.opacity(0.15)).frame(width: 46, height: 46)
                    Image(systemName: "calendar.badge.clock").font(.title3).foregroundStyle(DSColor.accent)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Daily Challenge").dsFont(.headline).foregroundStyle(DSColor.textPrimary)
                    Text(progress.dailyCompletedToday
                         ? "Done today · \(progress.progress.dailyStreak)-day streak"
                         : "\(DailyChallenge.questionCount) questions · \(DailyChallenge.label())")
                        .dsFont(.subheadline).foregroundStyle(DSColor.textSecondary)
                }
                Spacer(minLength: 0)
                Text(progress.dailyCompletedToday ? "Replay" : "Play")
                    .dsFont(.subheadline).fontWeight(.bold)
                    .foregroundStyle(DSColor.onAccent)
                    .padding(.horizontal, DSSpacing.sm).padding(.vertical, DSSpacing.xxs)
                    .background(Capsule().fill(DSColor.accent))
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .dsCard()
    }

    // MARK: - Level header

    private var levelHeader: some View {
        let lvl = progress.level
        return HStack(spacing: DSSpacing.md) {
            ZStack {
                Circle().stroke(DSColor.separator, lineWidth: 7).frame(width: 76, height: 76)
                Circle()
                    .trim(from: 0, to: max(0.02, lvl.progress))
                    .stroke(DSColor.accent, style: StrokeStyle(lineWidth: 7, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .frame(width: 76, height: 76)
                VStack(spacing: 0) {
                    Text("\(lvl.level)").font(DSFont.statValue)
                    Text("LVL").dsFont(.caption2).foregroundStyle(DSColor.textTertiary)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Level \(lvl.level)")

            VStack(alignment: .leading, spacing: DSSpacing.xxs) {
                HStack(spacing: DSSpacing.xs) {
                    Text(lvl.title).dsFont(.title3).foregroundStyle(DSColor.textPrimary)
                    if entitlements.progressionUnlocked && !entitlements.isSubscribed {
                        PremiumBadge()
                    }
                }
                Text("\(lvl.xpIntoLevel) / \(lvl.xpForNext) XP to next level")
                    .dsFont(.subheadline).foregroundStyle(DSColor.textSecondary)
                ProgressView(value: lvl.progress).tint(DSColor.accent)
            }
        }
        .dsCard()
    }

    // MARK: - Pro progress (earn Pro by leveling up)

    /// Cumulative XP needed to reach the Pro-unlock level (level L→L+1 costs L×100).
    private var proUnlockXP: Int {
        let n = ProgressionRewards.proUnlockLevel
        return 100 * (n - 1) * n / 2
    }

    private var proProgressCard: some View {
        let lvl = progress.level
        let fraction = min(1.0, Double(progress.progress.totalXP) / Double(max(1, proUnlockXP)))
        return VStack(alignment: .leading, spacing: DSSpacing.sm) {
            HStack(spacing: DSSpacing.md) {
                ZStack {
                    Circle().fill(DSColor.gold.opacity(0.15)).frame(width: 46, height: 46)
                    Image(systemName: "crown.fill").font(.title3).foregroundStyle(DSColor.gold)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Unlock Pro for free").dsFont(.headline).foregroundStyle(DSColor.textPrimary)
                    Text("Reach Level \(ProgressionRewards.proUnlockLevel) — you're at Level \(lvl.level)")
                        .dsFont(.subheadline).foregroundStyle(DSColor.textSecondary)
                }
                Spacer(minLength: 0)
            }
            ProgressView(value: fraction).tint(DSColor.gold)
        }
        .dsCard()
    }

    // MARK: - Aggregate stats

    private var statsGrid: some View {
        let p = progress.progress
        return VStack(spacing: DSSpacing.sm) {
            DSCard {
                HStack(spacing: DSSpacing.sm) {
                    DSStatTile(value: "\(p.totalGames)", label: "Games", icon: "gamecontroller.fill")
                    DSStatTile(value: "\(p.totalWins)", label: "Wins", icon: "trophy.fill", tint: DSColor.gold)
                    DSStatTile(value: "\(Int((p.winRate * 100).rounded()))%", label: "Win Rate", icon: "percent")
                }
            }
            DSCard {
                HStack(spacing: DSSpacing.sm) {
                    DSStatTile(value: "\(p.bestStreakOverall)", label: "Best Streak", icon: "flame.fill", tint: DSColor.warning)
                    DSStatTile(value: "\(p.dailyStreak)", label: "Day Streak", icon: "calendar", tint: DSColor.success)
                    DSStatTile(value: "\(p.totalXP)", label: "Total XP", icon: "star.fill", tint: DSColor.accent)
                }
            }
        }
    }

    // MARK: - Per-mode breakdown

    private var perModeSection: some View {
        VStack(alignment: .leading, spacing: DSSpacing.sm) {
            DSSectionHeader(title: "By Mode", icon: "chart.bar.fill")
            DSCard(padding: DSSpacing.xs) {
                VStack(spacing: 0) {
                    ForEach(Array(playedModes.enumerated()), id: \.element) { index, mode in
                        let s = progress.progress.stats(for: mode)
                        DSRow(title: mode.displayName, subtitle: "\(s.wins)/\(s.gamesPlayed) won · best \(s.bestStreak)", icon: mode.icon) {
                            Text("\(s.bestStreak)")
                                .font(DSFont.statValue)
                                .foregroundStyle(DSColor.accent)
                        }
                        .padding(.horizontal, DSSpacing.xs)
                        if index < playedModes.count - 1 {
                            Divider().padding(.leading, 46)
                        }
                    }
                    if playedModes.isEmpty {
                        Text("Play a game to start tracking your stats.")
                            .dsFont(.subheadline)
                            .foregroundStyle(DSColor.textSecondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(DSSpacing.xs)
                    }
                }
            }
        }
    }

    private var playedModes: [GameMode] {
        (GameMode.coreGames + [.daily, .predictor]).filter { progress.progress.stats(for: $0).gamesPlayed > 0 }
    }

    // MARK: - Achievements

    private var achievementsSection: some View {
        let unlockedCount = progress.progress.unlockedAchievements.count
        return VStack(alignment: .leading, spacing: DSSpacing.sm) {
            DSSectionHeader(title: "Achievements", icon: "rosette") {
                Text("\(unlockedCount)/\(AchievementCatalog.all.count)")
                    .dsFont(.subheadline).foregroundStyle(DSColor.textSecondary)
            }
            DSCard {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: DSSpacing.sm), count: 4), spacing: DSSpacing.md) {
                    ForEach(AchievementCatalog.all) { achievement in
                        achievementBadge(achievement)
                    }
                }
            }
        }
    }

    private func achievementBadge(_ achievement: Achievement) -> some View {
        let unlocked = progress.progress.unlockedAchievements.contains(achievement.id)
        let proLocked = achievement.isPro && !entitlements.isPro && !unlocked
        let color = unlocked ? tierColor(achievement.tier) : DSColor.textTertiary
        return VStack(spacing: DSSpacing.xxs) {
            ZStack {
                Circle().fill(color.opacity(unlocked ? 0.2 : 0.1)).frame(width: 52, height: 52)
                Image(systemName: unlocked ? achievement.icon : (proLocked ? "lock.fill" : achievement.icon))
                    .font(.title3)
                    .foregroundStyle(color)
                    .opacity(unlocked ? 1 : 0.5)
            }
            Text(achievement.title)
                .dsFont(.caption2)
                .foregroundStyle(unlocked ? DSColor.textPrimary : DSColor.textTertiary)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .frame(height: 26)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(achievement.title). \(unlocked ? "Unlocked" : "Locked"). \(achievement.detail)")
    }

    private func tierColor(_ tier: Achievement.Tier) -> Color {
        switch tier {
        case .bronze: DSColor.bronze
        case .silver: DSColor.silver
        case .gold: DSColor.gold
        }
    }
}
