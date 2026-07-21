import Foundation

struct PLScorerStat: Identifiable, Equatable {
    let playerID: String
    let name: String
    let clubID: String?
    let clubName: String
    let goals: Int
    let penalties: Int

    var id: String { playerID }

    var displayGoals: String {
        penalties > 0 ? "\(goals) (\(penalties) pen)" : "\(goals)"
    }
}

struct PLTeamSeasonStat: Identifiable, Equatable {
    let team: String
    let clubID: String?
    var goalsScored: Int
    var goalsConceded: Int
    var cleanSheets: Int
    var wins: Int

    var id: String { team }

    var goalDifference: Int { goalsScored - goalsConceded }
}

struct PLBiggestWin: Equatable {
    let homeTeam: String
    let awayTeam: String
    let homeClubID: String?
    let awayClubID: String?
    let homeGoals: Int
    let awayGoals: Int
    let gameweek: Int
    let margin: Int

    var scoreline: String { "\(homeGoals)–\(awayGoals)" }
}

struct PLSeasonStats: Equatable {
    let totalMatches: Int
    let totalGoals: Int
    let averageGoalsPerMatch: Double
    let topScorers: [PLScorerStat]
    let highestScoringTeams: [PLTeamSeasonStat]
    let bestDefenses: [PLTeamSeasonStat]
    let mostCleanSheets: [PLTeamSeasonStat]
    let mostWins: [PLTeamSeasonStat]
    let biggestWin: PLBiggestWin?

    static let empty = PLSeasonStats(
        totalMatches: 0,
        totalGoals: 0,
        averageGoalsPerMatch: 0,
        topScorers: [],
        highestScoringTeams: [],
        bestDefenses: [],
        mostCleanSheets: [],
        mostWins: [],
        biggestWin: nil
    )

    var hasData: Bool { totalMatches > 0 }
}

enum PLSeasonStatsCalculator {

    static func compute(
        gameweeks: [PLGameweek],
        simulations: [String: PLMatchSimulation]
    ) -> PLSeasonStats {
        guard !simulations.isEmpty else { return .empty }

        var scorerGoals: [String: (name: String, clubID: String?, clubName: String, goals: Int, penalties: Int)] = [:]
        var teamStats: [String: PLTeamSeasonStat] = [:]
        var biggestWin: PLBiggestWin?

        var totalGoals = 0
        var totalMatches = 0

        for gameweek in gameweeks {
            for match in gameweek.matches {
                guard let simulation = simulations[match.id] else { continue }

                totalMatches += 1
                totalGoals += simulation.homeGoals + simulation.awayGoals

                updateTeamStats(
                    table: &teamStats,
                    team: match.homeTeam,
                    clubID: match.homeClubID,
                    goalsFor: simulation.homeGoals,
                    goalsAgainst: simulation.awayGoals,
                    won: simulation.homeGoals > simulation.awayGoals
                )
                updateTeamStats(
                    table: &teamStats,
                    team: match.awayTeam,
                    clubID: match.awayClubID,
                    goalsFor: simulation.awayGoals,
                    goalsAgainst: simulation.homeGoals,
                    won: simulation.awayGoals > simulation.homeGoals
                )

                for goal in simulation.goals {
                    let clubID = goal.isHome ? match.homeClubID : match.awayClubID
                    let clubName = goal.isHome ? match.homeTeam : match.awayTeam
                    var entry = scorerGoals[goal.scorerID] ?? (
                        name: goal.scorerName,
                        clubID: clubID,
                        clubName: clubName,
                        goals: 0,
                        penalties: 0
                    )
                    entry.goals += 1
                    if goal.isPenalty { entry.penalties += 1 }
                    scorerGoals[goal.scorerID] = entry
                }

                let margin = abs(simulation.homeGoals - simulation.awayGoals)
                if margin > 0 {
                    let candidate = PLBiggestWin(
                        homeTeam: match.homeTeam,
                        awayTeam: match.awayTeam,
                        homeClubID: match.homeClubID,
                        awayClubID: match.awayClubID,
                        homeGoals: simulation.homeGoals,
                        awayGoals: simulation.awayGoals,
                        gameweek: gameweek.number,
                        margin: margin
                    )
                    if let current = biggestWin {
                        if margin > current.margin { biggestWin = candidate }
                    } else {
                        biggestWin = candidate
                    }
                }
            }
        }

        let scorers = scorerGoals.map { playerID, entry in
            PLScorerStat(
                playerID: playerID,
                name: entry.name,
                clubID: entry.clubID,
                clubName: entry.clubName,
                goals: entry.goals,
                penalties: entry.penalties
            )
        }
        .sorted {
            if $0.goals != $1.goals { return $0.goals > $1.goals }
            return $0.name < $1.name
        }

        let teams = Array(teamStats.values)
        let highestScoring = teams.sorted {
            if $0.goalsScored != $1.goalsScored { return $0.goalsScored > $1.goalsScored }
            return $0.team < $1.team
        }
        let bestDefense = teams.sorted {
            if $0.goalsConceded != $1.goalsConceded { return $0.goalsConceded < $1.goalsConceded }
            return $0.team < $1.team
        }
        let cleanSheets = teams.sorted {
            if $0.cleanSheets != $1.cleanSheets { return $0.cleanSheets > $1.cleanSheets }
            return $0.team < $1.team
        }
        let mostWins = teams.sorted {
            if $0.wins != $1.wins { return $0.wins > $1.wins }
            return $0.team < $1.team
        }

        return PLSeasonStats(
            totalMatches: totalMatches,
            totalGoals: totalGoals,
            averageGoalsPerMatch: totalMatches > 0 ? Double(totalGoals) / Double(totalMatches) : 0,
            topScorers: Array(scorers.prefix(15)),
            highestScoringTeams: Array(highestScoring.prefix(5)),
            bestDefenses: Array(bestDefense.prefix(5)),
            mostCleanSheets: Array(cleanSheets.prefix(5)),
            mostWins: Array(mostWins.prefix(5)),
            biggestWin: biggestWin
        )
    }

    private static func updateTeamStats(
        table: inout [String: PLTeamSeasonStat],
        team: String,
        clubID: String?,
        goalsFor: Int,
        goalsAgainst: Int,
        won: Bool
    ) {
        var row = table[team] ?? PLTeamSeasonStat(
            team: team,
            clubID: clubID,
            goalsScored: 0,
            goalsConceded: 0,
            cleanSheets: 0,
            wins: 0
        )
        row.goalsScored += goalsFor
        row.goalsConceded += goalsAgainst
        if goalsAgainst == 0 { row.cleanSheets += 1 }
        if won { row.wins += 1 }
        table[team] = row
    }
}
