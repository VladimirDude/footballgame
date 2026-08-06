import Foundation

/// Hand-entered figures for one player in one season.
///
/// Goals and assists are *not* here — those are derived from the match log. What
/// remains is what the log cannot tell us: bonus points, and goalkeeper figures
/// (nothing in the model records who played, so appearances and clean sheets
/// can't be computed).
struct PlayerSeasonEntry: Equatable {
    var seasonID: UUID
    var playerID: UUID
    var bonusPoints: Double
    var goalkeeper: GoalkeeperStats?
    /// Goals recorded before match-level logging existed.
    ///
    /// Migration is otherwise a visible downgrade: a team that entered 40 goals by
    /// hand but only logged 12 matches would watch every player's number collapse.
    /// Carry-over is `max(0, entered − derived)`, so a displayed total is always
    /// `max(whatTheyEntered, whatTheLogProves)` and never regresses.
    var carryOverGoals: Int
    var carryOverAssists: Int

    init(
        seasonID: UUID,
        playerID: UUID,
        bonusPoints: Double = 0,
        goalkeeper: GoalkeeperStats? = nil,
        carryOverGoals: Int = 0,
        carryOverAssists: Int = 0
    ) {
        self.seasonID = seasonID
        self.playerID = playerID
        self.bonusPoints = bonusPoints
        self.goalkeeper = goalkeeper
        self.carryOverGoals = carryOverGoals
        self.carryOverAssists = carryOverAssists
    }
}

/// A player's figures for a scope — computed on demand, never stored.
struct PlayerSeasonStats: Equatable {
    let playerID: UUID
    var goals: Int
    var assists: Int
    var bonusPoints: Double
    var goalkeeper: GoalkeeperStats?

    var contributions: Int { goals + assists }
    var points: Double { Double(contributions) + bonusPoints }

    static func empty(_ playerID: UUID) -> PlayerSeasonStats {
        PlayerSeasonStats(playerID: playerID, goals: 0, assists: 0, bonusPoints: 0, goalkeeper: nil)
    }
}

/// What a leaderboard ranks by.
///
/// Deliberately separate from `SortOption`, which drives the Full Statistics
/// table. Sharing one enum meant changing the table's sort silently reordered
/// the podium.
enum LeaderboardMetric: String, CaseIterable, Identifiable {
    case goals = "G"
    case assists = "A"
    case contributions = "G+A"
    case points = "PTS"

    var id: String { rawValue }

    var fullName: String {
        switch self {
        case .goals:         return "Goals"
        case .assists:       return "Assists"
        case .contributions: return "Goals + Assists"
        case .points:        return "Points with bonus"
        }
    }

    func value(_ stats: PlayerSeasonStats) -> Double {
        switch self {
        case .goals:         return Double(stats.goals)
        case .assists:       return Double(stats.assists)
        case .contributions: return Double(stats.contributions)
        case .points:        return stats.points
        }
    }

    func display(_ stats: PlayerSeasonStats) -> String {
        switch self {
        case .goals, .assists, .contributions:
            return String(Int(value(stats)))
        case .points:
            let v = value(stats)
            return v == v.rounded() ? String(Int(v)) : String(format: "%.1f", v)
        }
    }
}
