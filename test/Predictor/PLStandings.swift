import Foundation

struct PLStandingRow: Identifiable, Equatable {
    let team: String
    let clubID: String?
    var played: Int
    var won: Int
    var drawn: Int
    var lost: Int
    var goalsFor: Int
    var goalsAgainst: Int

    var id: String { team }

    var goalDifference: Int { goalsFor - goalsAgainst }

    var points: Int { won * 3 + drawn }

    static func empty(team: String, clubID: String?) -> PLStandingRow {
        PLStandingRow(
            team: team,
            clubID: clubID,
            played: 0,
            won: 0,
            drawn: 0,
            lost: 0,
            goalsFor: 0,
            goalsAgainst: 0
        )
    }
}

enum PLStandingsCalculator {

    static func compute(
        gameweeks: [PLGameweek],
        simulations: [String: PLMatchSimulation]
    ) -> [PLStandingRow] {
        var clubIDByTeam: [String: String] = [:]
        for gameweek in gameweeks {
            for match in gameweek.matches {
                clubIDByTeam[match.homeTeam] = match.homeClubID
                clubIDByTeam[match.awayTeam] = match.awayClubID
            }
        }

        var table = Dictionary(
            uniqueKeysWithValues: clubIDByTeam.keys.sorted().map { team in
                (team, PLStandingRow.empty(team: team, clubID: clubIDByTeam[team]))
            }
        )

        for gameweek in gameweeks {
            for match in gameweek.matches {
                guard let simulation = simulations[match.id] else { continue }
                applyResult(
                    table: &table,
                    home: match.homeTeam,
                    away: match.awayTeam,
                    homeGoals: simulation.homeGoals,
                    awayGoals: simulation.awayGoals
                )
            }
        }

        return table.values.sorted { lhs, rhs in
            if lhs.points != rhs.points { return lhs.points > rhs.points }
            if lhs.goalDifference != rhs.goalDifference { return lhs.goalDifference > rhs.goalDifference }
            if lhs.goalsFor != rhs.goalsFor { return lhs.goalsFor > rhs.goalsFor }
            return lhs.team < rhs.team
        }
    }

    private static func applyResult(
        table: inout [String: PLStandingRow],
        home: String,
        away: String,
        homeGoals: Int,
        awayGoals: Int
    ) {
        guard var homeRow = table[home], var awayRow = table[away] else { return }

        homeRow.played += 1
        awayRow.played += 1
        homeRow.goalsFor += homeGoals
        homeRow.goalsAgainst += awayGoals
        awayRow.goalsFor += awayGoals
        awayRow.goalsAgainst += homeGoals

        if homeGoals > awayGoals {
            homeRow.won += 1
            awayRow.lost += 1
        } else if homeGoals < awayGoals {
            homeRow.lost += 1
            awayRow.won += 1
        } else {
            homeRow.drawn += 1
            awayRow.drawn += 1
        }

        table[home] = homeRow
        table[away] = awayRow
    }
}

enum PLTableZone {
    case championsLeague
    case relegation
    case mid

    static func zone(for position: Int) -> PLTableZone {
        if position <= 4 { return .championsLeague }
        if position >= 18 { return .relegation }
        return .mid
    }
}
