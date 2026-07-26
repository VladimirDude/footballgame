import Foundation

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
    let isSatisfied: (GameProgress) -> Bool
}

extension Achievement: Equatable {
    static func == (lhs: Achievement, rhs: Achievement) -> Bool { lhs.id == rhs.id }
}

enum AchievementCatalog {
    static let all: [Achievement] = [
        Achievement(id: "first_win", title: "First Win", detail: "Win your first game", icon: "star.fill", tier: .bronze) { $0.totalWins >= 1 },
        Achievement(id: "games_25", title: "Getting Started", detail: "Play 25 games", icon: "gamecontroller.fill", tier: .bronze) { $0.totalGames >= 25 },
        Achievement(id: "games_100", title: "Dedicated", detail: "Play 100 games", icon: "gamecontroller.fill", tier: .silver) { $0.totalGames >= 100 },
        Achievement(id: "wins_50", title: "Sharpshooter", detail: "Win 50 games", icon: "target", tier: .silver) { $0.totalWins >= 50 },
        Achievement(id: "streak_5", title: "On Fire", detail: "Reach a 5-win streak", icon: "flame.fill", tier: .bronze) { $0.bestStreakOverall >= 5 },
        Achievement(id: "streak_10", title: "Unstoppable", detail: "Reach a 10-win streak", icon: "flame.fill", tier: .silver) { $0.bestStreakOverall >= 10 },
        Achievement(id: "streak_20", title: "Untouchable", detail: "Reach a 20-win streak", icon: "flame.fill", tier: .gold) { $0.bestStreakOverall >= 20 },
        Achievement(id: "play_all", title: "All-Rounder", detail: "Play every game mode", icon: "square.grid.2x2.fill", tier: .silver) { p in
            GameMode.coreGames.allSatisfy { p.stats(for: $0).gamesPlayed >= 1 }
        },
        Achievement(id: "club_master", title: "Badge Expert", detail: "10-win streak in Guess the Club", icon: "shield.lefthalf.filled", tier: .gold) { $0.stats(for: .guessClub).bestStreak >= 10 },
        Achievement(id: "player_master", title: "Scout", detail: "10-win streak in Guess the Player", icon: "person.crop.circle.fill", tier: .gold) { $0.stats(for: .guessPlayer).bestStreak >= 10 },
        Achievement(id: "hl_15", title: "Market Guru", detail: "15-win streak in Higher or Lower", icon: "arrow.up.arrow.down.circle.fill", tier: .gold) { $0.stats(for: .higherLower).bestStreak >= 15 },
        Achievement(id: "level_5", title: "Level 5", detail: "Reach level 5", icon: "chevron.up.circle.fill", tier: .bronze) { XPCurve.level(forXP: $0.totalXP).level >= 5 },
        Achievement(id: "level_10", title: "Level 10", detail: "Reach level 10", icon: "chevron.up.circle.fill", tier: .silver) { XPCurve.level(forXP: $0.totalXP).level >= 10 },
        Achievement(id: "level_20", title: "Level 20", detail: "Reach level 20", icon: "crown.fill", tier: .gold) { XPCurve.level(forXP: $0.totalXP).level >= 20 },
        Achievement(id: "daily_3", title: "Habit", detail: "3-day daily streak", icon: "calendar", tier: .bronze) { $0.dailyStreak >= 3 },
        Achievement(id: "daily_7", title: "Week Warrior", detail: "7-day daily streak", icon: "calendar.badge.clock", tier: .silver) { $0.dailyStreak >= 7 },
        Achievement(id: "daily_30", title: "Ever-Present", detail: "30-day daily streak", icon: "calendar.badge.checkmark", tier: .gold, isPro: true) { $0.dailyStreak >= 30 },
    ]

    /// Achievements now satisfied but not yet unlocked.
    static func newlyUnlocked(in progress: GameProgress) -> [Achievement] {
        all.filter { !progress.unlockedAchievements.contains($0.id) && $0.isSatisfied(progress) }
    }

    static func byID(_ id: String) -> Achievement? { all.first { $0.id == id } }
}
