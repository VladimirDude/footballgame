import Foundation

/// Derives player figures from the match log.
///
/// Goals and assists are computed by aggregating `GoalDetail`s, not read from the
/// hand-entered counters on `TeamPlayer`. Those counters remain in the snapshot as
/// legacy mirror fields for v1 clients, but they are no longer the source of truth
/// — before this, the leaderboard and the match log were two unlinked stories that
/// could freely disagree.
enum TeamStatsCalculator {

    /// Stats for every player in `scope`, keyed by player id.
    static func stats(for doc: TeamDocument, scope: SeasonScope) -> [UUID: PlayerSeasonStats] {
        var result: [UUID: PlayerSeasonStats] = [:]
        for player in doc.players {
            result[player.id] = .empty(player.id)
        }

        for game in doc.games where scope.matches(game) {
            for goal in game.goalDetails where !goal.isOpponent {
                if let id = goal.scorerID, result[id] != nil { result[id]?.goals += 1 }
                if let id = goal.assistID, result[id] != nil { result[id]?.assists += 1 }
            }
        }

        // Hand-entered figures, plus the carry-over that keeps migrated numbers
        // from regressing.
        for entry in doc.seasonEntries where entryApplies(entry, scope: scope) {
            guard result[entry.playerID] != nil else { continue }
            result[entry.playerID]?.goals += entry.carryOverGoals
            result[entry.playerID]?.assists += entry.carryOverAssists
            result[entry.playerID]?.bonusPoints += entry.bonusPoints
            if let gk = entry.goalkeeper {
                let existing = result[entry.playerID]?.goalkeeper
                result[entry.playerID]?.goalkeeper = merge(existing, gk)
            }
        }

        return result
    }

    static func stats(for player: TeamPlayer, in doc: TeamDocument, scope: SeasonScope) -> PlayerSeasonStats {
        stats(for: doc, scope: scope)[player.id] ?? .empty(player.id)
    }

    /// Goals the team scored in scope, from the match results rather than the
    /// player counters — so unlinked scorers never make the team total drop.
    static func teamGoals(for doc: TeamDocument, scope: SeasonScope) -> Int {
        doc.games.filter(scope.matches).reduce(0) { $0 + $1.goalsFor }
    }

    static func teamConceded(for doc: TeamDocument, scope: SeasonScope) -> Int {
        doc.games.filter(scope.matches).reduce(0) { $0 + $1.goalsAgainst }
    }

    static func record(for doc: TeamDocument, scope: SeasonScope) -> (wins: Int, draws: Int, losses: Int) {
        let games = doc.games.filter(scope.matches)
        return (games.filter { $0.result == .win }.count,
                games.filter { $0.result == .draw }.count,
                games.filter { $0.result == .loss }.count)
    }

    /// Goals derived purely from the log, ignoring carry-over. Used by migration
    /// to work out how much carry-over a player needs.
    static func derivedTotals(for doc: TeamDocument) -> [UUID: (goals: Int, assists: Int)] {
        var totals: [UUID: (goals: Int, assists: Int)] = [:]
        for game in doc.games {
            for goal in game.goalDetails where !goal.isOpponent {
                if let id = goal.scorerID { totals[id, default: (0, 0)].goals += 1 }
                if let id = goal.assistID { totals[id, default: (0, 0)].assists += 1 }
            }
        }
        return totals
    }

    private static func entryApplies(_ entry: PlayerSeasonEntry, scope: SeasonScope) -> Bool {
        switch scope {
        case .allTime:        return true
        case .season(let id): return entry.seasonID == id
        case .unassigned:     return false   // hand-entered figures always belong to a season
        }
    }

    /// Goalkeeper figures accumulate across seasons when viewing all time.
    private static func merge(_ lhs: GoalkeeperStats?, _ rhs: GoalkeeperStats) -> GoalkeeperStats {
        guard let lhs else { return rhs }
        return GoalkeeperStats(
            matchesAttended: lhs.matchesAttended + rhs.matchesAttended,
            goalsConceded: lhs.goalsConceded + rhs.goalsConceded,
            cleanSheets: lhs.cleanSheets + rhs.cleanSheets
        )
    }
}
