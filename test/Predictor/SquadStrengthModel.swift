import Foundation

enum SquadStrengthModel {

    /// Home-advantage adjusted win probabilities from squad strength. Uses the exact
    /// same `TeamRatingModel`/`MatchGoalModel` the simulator itself runs on, so these
    /// pre-match hints are an honest preview rather than a separately-tuned guess.
    static func odds(homeClubID: String?, awayClubID: String?, store: ClubDataStore) -> PLModelOdds? {
        guard
            let homeID = homeClubID,
            let awayID = awayClubID,
            let homeClub = store.club(id: homeID),
            let awayClub = store.club(id: awayID)
        else { return nil }

        let homeRating = TeamRatingModel.rating(for: homeClub.players)
        let awayRating = TeamRatingModel.rating(for: awayClub.players)

        let homeXG = MatchGoalModel.expectedGoals(attack: homeRating.attack, defense: awayRating.defense, isHome: true)
        let awayXG = MatchGoalModel.expectedGoals(attack: awayRating.attack, defense: homeRating.defense, isHome: false)

        return poissonWinDrawLoss(homeXG: homeXG, awayXG: awayXG)
    }

    static func squadValue(clubID: String, store: ClubDataStore) -> Int? {
        guard let club = store.club(id: clubID) else { return nil }
        let total = club.players.compactMap(\.marketValue).reduce(0, +)
        return total > 0 ? total : nil
    }

    static func formattedProbability(_ value: Double) -> String {
        "\(Int((value * 100).rounded()))%"
    }

    // MARK: - Private

    /// H/D/A from a Dixon-Coles adjusted score grid — same statistical model the
    /// simulator itself samples from, so these hints stay honest predictors of outcomes.
    private static func poissonWinDrawLoss(homeXG: Double, awayXG: Double) -> PLModelOdds {
        var home = 0.0
        var draw = 0.0
        var away = 0.0
        let maxGoals = 8

        for homeGoals in 0...maxGoals {
            for awayGoals in 0...maxGoals {
                let probability = PoissonMath.pmf(homeGoals, lambda: homeXG)
                    * PoissonMath.pmf(awayGoals, lambda: awayXG)
                    * PoissonMath.dixonColesTau(
                        homeGoals: homeGoals,
                        awayGoals: awayGoals,
                        homeLambda: homeXG,
                        awayLambda: awayXG,
                        rho: MatchGoalModel.dixonColesRho
                    )
                if homeGoals > awayGoals { home += probability }
                else if homeGoals < awayGoals { away += probability }
                else { draw += probability }
            }
        }

        let total = home + draw + away
        guard total > 0 else {
            return PLModelOdds(home: 0.33, draw: 0.34, away: 0.33)
        }
        return PLModelOdds(home: home / total, draw: draw / total, away: away / total)
    }
}
