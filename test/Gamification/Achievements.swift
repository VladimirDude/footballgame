import Foundation

/// Progress toward an achievement goal (e.g. 4/10 wins).
struct AchievementProgress: Equatable {
    let current: Int
    let target: Int

    var clampedCurrent: Int { min(max(0, current), max(target, 0)) }
    var fraction: Double {
        guard target > 0 else { return 0 }
        return Double(clampedCurrent) / Double(target)
    }
    var label: String { "\(clampedCurrent)/\(target)" }
    var isComplete: Bool { target > 0 && current >= target }
}

/// A single achievement definition. Data-driven (mirrors `FeatureCatalog`): a
/// predicate over `GameProgress` decides when it's satisfied, so the evaluator is
/// generic and adding one is a single list entry.
struct Achievement: Identifiable {
    enum Tier: String { case bronze, silver, gold }

    let id: String
    let title: String
    let detail: String
    let icon: String
    let tier: Tier
    /// Pro-only cosmetic/prestige achievements (still visible, shown locked for free users).
    var isPro: Bool = false
    /// Live progress used by the detail sheet.
    let progress: (GameProgress) -> AchievementProgress
    let isSatisfied: (GameProgress) -> Bool

    init(
        id: String,
        title: String,
        detail: String,
        icon: String,
        tier: Tier,
        isPro: Bool = false,
        target: Int,
        current: @escaping (GameProgress) -> Int
    ) {
        self.id = id
        self.title = title
        self.detail = detail
        self.icon = icon
        self.tier = tier
        self.isPro = isPro
        self.progress = { AchievementProgress(current: current($0), target: target) }
        self.isSatisfied = { current($0) >= target }
    }
}

extension Achievement: Equatable {
    static func == (lhs: Achievement, rhs: Achievement) -> Bool { lhs.id == rhs.id }
}

enum AchievementCatalog {
    static let all: [Achievement] = [
        Achievement(
            id: "first_win", title: "First Win", detail: "Win your first game",
            icon: "star.fill", tier: .bronze, target: 1
        ) { $0.totalWins },
        Achievement(
            id: "games_25", title: "Getting Started", detail: "Play 25 games",
            icon: "gamecontroller.fill", tier: .bronze, target: 25
        ) { $0.totalGames },
        Achievement(
            id: "games_100", title: "Dedicated", detail: "Play 100 games",
            icon: "gamecontroller.fill", tier: .silver, target: 100
        ) { $0.totalGames },
        Achievement(
            id: "wins_50", title: "Sharpshooter", detail: "Win 50 games",
            icon: "target", tier: .silver, target: 50
        ) { $0.totalWins },
        Achievement(
            id: "streak_5", title: "On Fire", detail: "Reach a 5-win streak",
            icon: "flame.fill", tier: .bronze, target: 5
        ) { $0.bestStreakOverall },
        Achievement(
            id: "streak_10", title: "Unstoppable", detail: "Reach a 10-win streak",
            icon: "flame.fill", tier: .silver, target: 10
        ) { $0.bestStreakOverall },
        Achievement(
            id: "streak_20", title: "Untouchable", detail: "Reach a 20-win streak",
            icon: "flame.fill", tier: .gold, target: 20
        ) { $0.bestStreakOverall },
        Achievement(
            id: "play_all", title: "All-Rounder", detail: "Play every game mode",
            icon: "square.grid.2x2.fill", tier: .silver, target: GameMode.coreGames.count
        ) { p in
            GameMode.coreGames.filter { p.stats(for: $0).gamesPlayed >= 1 }.count
        },
        Achievement(
            id: "club_master", title: "Badge Expert", detail: "10-win streak in Guess the Club",
            icon: "shield.lefthalf.filled", tier: .gold, target: 10
        ) { $0.stats(for: .guessClub).bestStreak },
        Achievement(
            id: "nation_master", title: "Flag Bearer", detail: "10-win streak in Guess the Nation",
            icon: "flag.fill", tier: .gold, target: 10
        ) { $0.stats(for: .guessNation).bestStreak },
        Achievement(
            id: "player_master", title: "Scout", detail: "10-win streak in Guess the Player",
            icon: "person.crop.circle.fill", tier: .gold, target: 10
        ) { $0.stats(for: .guessPlayer).bestStreak },
        Achievement(
            id: "league_master", title: "Competition Buff", detail: "10-win streak in Guess the League",
            icon: "trophy.fill", tier: .gold, target: 10
        ) { $0.stats(for: .guessLeague).bestStreak },
        Achievement(
            id: "hl_15", title: "Market Guru", detail: "15-win streak in Higher or Lower",
            icon: "arrow.up.arrow.down.circle.fill", tier: .gold, target: 15
        ) { $0.stats(for: .higherLower).bestStreak },
        Achievement(
            id: "level_5", title: "Level 5", detail: "Reach level 5",
            icon: "chevron.up.circle.fill", tier: .bronze, target: 5
        ) { XPCurve.level(forXP: $0.totalXP).level },
        Achievement(
            id: "level_10", title: "Level 10", detail: "Reach level 10",
            icon: "chevron.up.circle.fill", tier: .silver, target: 10
        ) { XPCurve.level(forXP: $0.totalXP).level },
        Achievement(
            id: "level_20", title: "Level 20", detail: "Reach level 20",
            icon: "crown.fill", tier: .gold, target: 20
        ) { XPCurve.level(forXP: $0.totalXP).level },
        Achievement(
            id: "pro_unlocked",
            title: "Pro Unlocked",
            detail: "Reach level \(ProgressionRewards.proUnlockLevel) — all premium features are yours",
            icon: "crown.fill",
            tier: .gold,
            target: ProgressionRewards.proUnlockLevel
        ) { XPCurve.level(forXP: $0.totalXP).level },
        Achievement(
            id: "daily_3", title: "Habit", detail: "3-day daily streak",
            icon: "calendar", tier: .bronze, target: 3
        ) { $0.dailyStreak },
        Achievement(
            id: "daily_7", title: "Week Warrior", detail: "7-day daily streak",
            icon: "calendar.badge.clock", tier: .silver, target: 7
        ) { $0.dailyStreak },
        Achievement(
            id: "daily_30", title: "Ever-Present", detail: "30-day daily streak",
            icon: "calendar.badge.checkmark", tier: .gold, isPro: true, target: 30
        ) { $0.dailyStreak },
    ]

    /// Achievements now satisfied but not yet unlocked.
    /// Pro-gated ones stay locked unless `allowPro` is true.
    static func newlyUnlocked(in progress: GameProgress, allowPro: Bool = false) -> [Achievement] {
        all.filter {
            !progress.unlockedAchievements.contains($0.id)
                && $0.isSatisfied(progress)
                && (!$0.isPro || allowPro)
        }
    }

    static func byID(_ id: String) -> Achievement? { all.first { $0.id == id } }
}
