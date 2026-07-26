import Foundation

/// Per-mode aggregate stats. `currentStreak` is persisted here (unlike the old
/// ephemeral `@State` in GameView) so streaks survive relaunch.
struct ModeStats: Codable, Equatable {
    var gamesPlayed: Int = 0
    var wins: Int = 0
    var currentStreak: Int = 0
    var bestStreak: Int = 0

    var winRate: Double { gamesPlayed > 0 ? Double(wins) / Double(gamesPlayed) : 0 }
}

/// The whole player-progress record. Codable → persisted as one JSON blob in
/// UserDefaults (key `gameProgressV1`). Replaces the 5 scattered best-streak ints.
struct GameProgress: Codable, Equatable {
    var modeStats: [String: ModeStats] = [:]   // keyed by GameMode.rawValue
    var totalXP: Int = 0
    var unlockedAchievements: Set<String> = []
    var dailyLastCompleted: Date? = nil
    var dailyStreak: Int = 0
    var lastPlayed: Date? = nil

    func stats(for mode: GameMode) -> ModeStats { modeStats[mode.rawValue] ?? ModeStats() }

    var totalGames: Int { modeStats.values.reduce(0) { $0 + $1.gamesPlayed } }
    var totalWins: Int { modeStats.values.reduce(0) { $0 + $1.wins } }
    var winRate: Double { totalGames > 0 ? Double(totalWins) / Double(totalGames) : 0 }
    /// The best streak across every mode.
    var bestStreakOverall: Int { modeStats.values.map(\.bestStreak).max() ?? 0 }
}

/// XP awards and the level curve.
enum XPCurve {
    /// XP for a single result: a small amount for playing, more for a win, plus a
    /// capped streak bonus to reward hot streaks.
    static func xp(won: Bool, streak: Int) -> Int {
        guard won else { return 3 }
        return 15 + min(streak, 10) * 2
    }

    /// Resolves total XP into a level. Level L→L+1 needs `L * 100` XP, so higher
    /// levels take progressively more.
    static func level(forXP xp: Int) -> LevelInfo {
        var level = 1
        var remaining = max(0, xp)
        var need = 100
        while remaining >= need {
            remaining -= need
            level += 1
            need += 100
        }
        return LevelInfo(
            level: level,
            xpIntoLevel: remaining,
            xpForNext: need,
            progress: need > 0 ? Double(remaining) / Double(need) : 0,
            totalXP: xp
        )
    }
}

struct LevelInfo: Equatable {
    let level: Int
    let xpIntoLevel: Int
    let xpForNext: Int
    let progress: Double
    let totalXP: Int

    /// Flavor title shown on the profile.
    var title: String {
        switch level {
        case ..<3: "Rookie"
        case 3..<6: "Prospect"
        case 6..<10: "Regular"
        case 10..<15: "Veteran"
        case 15..<25: "Star"
        default: "Legend"
        }
    }
}
