import Foundation

// MARK: - Lineup

struct PLSimPlayer: Codable, Equatable, Identifiable {
    let id: String
    let name: String
    let position: String
    let role: String
}

enum StartingLineupBuilder {

    static func build(from squad: [ClubSquadPlayer]) -> [PLSimPlayer] {
        let formation = FormationBuilder.build(from: squad)
        let byName = Dictionary(uniqueKeysWithValues: squad.map { ($0.name, $0) })

        return formation.flatMap { $0 }.compactMap { slot in
            guard let player = byName[slot.playerName] else { return nil }
            return PLSimPlayer(
                id: player.id,
                name: player.name,
                position: player.position,
                role: slot.role
            )
        }
    }
}

struct TeamRating {
    let attack: Double
    let defense: Double
    let xi: [PLSimPlayer]

    var overall: Double { attack + defense }
}

enum TeamRatingModel {

    private static let valueExponent = 0.62

    static func rating(for squad: [ClubSquadPlayer]) -> TeamRating {
        let xi = StartingLineupBuilder.build(from: squad)
        return TeamRating(
            attack: attackRating(xi: xi, squad: squad),
            defense: defenseRating(xi: xi, squad: squad),
            xi: xi
        )
    }

    private static func scaledValue(_ value: Double) -> Double {
        pow(max(value, 350_000) / 1_000_000, valueExponent)
    }

    private static func attackRating(xi: [PLSimPlayer], squad: [ClubSquadPlayer]) -> Double {
        var score = 0.0
        for player in xi {
            let value = Double(playerValue(player, in: squad))
            let weight: Double
            switch player.role {
            case "ST": weight = 1.0
            case "LW", "RW": weight = 0.84
            case "CM":
                let position = player.position.lowercased()
                weight = position.contains("attacking") || position.contains("offensive") ? 0.58 : 0.36
            default: weight = 0.1
            }
            score += scaledValue(value) * weight
        }
        return max(score, 2.4)
    }

    private static func defenseRating(xi: [PLSimPlayer], squad: [ClubSquadPlayer]) -> Double {
        var score = 0.0
        for player in xi {
            let value = Double(playerValue(player, in: squad))
            switch player.role {
            case "GK": score += scaledValue(value) * 0.95
            case "CB": score += scaledValue(value) * 0.78
            case "LB", "RB": score += scaledValue(value) * 0.5
            case "CM": score += scaledValue(value) * 0.24
            default: score += scaledValue(value) * 0.08
            }
        }
        return max(score, 2.2)
    }

    private static func playerValue(_ player: PLSimPlayer, in squad: [ClubSquadPlayer]) -> Int {
        squad.first { $0.id == player.id }?.marketValue ?? 1_000_000
    }
}

enum MatchGoalModel {

    static let baseGoals = 1.18
    static let homeAdvantage = 1.13
    static let mismatchExponent = 0.48
    static let defenseRatioFloor = 3.0
    static let lambdaFloor = 0.3
    static let lambdaCap = 3.3
    static let dixonColesRho = -0.13

    static func rawExpectedGoals(attack: Double, defense: Double, isHome: Bool) -> Double {
        let ratio = attack / max(defense, defenseRatioFloor)
        var lambda = baseGoals * pow(ratio, mismatchExponent)
        if isHome { lambda *= homeAdvantage }
        return lambda
    }

    static func clamp(_ lambda: Double) -> Double {
        min(lambdaCap, max(lambdaFloor, lambda))
    }

    static func expectedGoals(attack: Double, defense: Double, isHome: Bool) -> Double {
        clamp(rawExpectedGoals(attack: attack, defense: defense, isHome: isHome))
    }
}

// MARK: - Simulation output

struct PLGoalEvent: Codable, Equatable, Identifiable {
    let id: String
    let minute: Int
    let scorerID: String
    let scorerName: String
    let isHome: Bool
    let isPenalty: Bool

    var typeLabel: String { isPenalty ? "Penalty" : "Goal" }

    var minuteLabel: String { "\(minute)'" }
}

struct PLTeamMatchStats: Codable, Equatable {
    let xG: Double
    let possession: Int
    let shots: Int
    let shotsOnTarget: Int
    let corners: Int
    let fouls: Int
    let yellowCards: Int
    let redCards: Int

    var formattedXG: String {
        String(format: "%.2f", xG)
    }
}

struct PLMatchSimulation: Codable, Equatable {
    let matchID: String
    let homeGoals: Int
    let awayGoals: Int
    let outcome: String
    let homeStats: PLTeamMatchStats
    let awayStats: PLTeamMatchStats
    let goals: [PLGoalEvent]
    let homeXI: [PLSimPlayer]
    let awayXI: [PLSimPlayer]
    /// Optional so older cached simulations (pre-halftime-split model) still decode.
    let halftimeHomeGoals: Int?
    let halftimeAwayGoals: Int?

    var result: PLMatchResult {
        PLMatchResult(homeGoals: homeGoals, awayGoals: awayGoals, outcome: outcome)
    }

    var halftimeLabel: String? {
        guard let h = halftimeHomeGoals, let a = halftimeAwayGoals else { return nil }
        return "\(h)-\(a)"
    }
}

// MARK: - Engine

enum MatchSimulator {

    static func simulate(
        match: PLMatch,
        homeSquad: [ClubSquadPlayer],
        awaySquad: [ClubSquadPlayer],
        season: String,
        nonce: Int = 0
    ) -> PLMatchSimulation {
        let homeRating = TeamRatingModel.rating(for: homeSquad)
        let awayRating = TeamRatingModel.rating(for: awaySquad)
        let homeXI = homeRating.xi
        let awayXI = awayRating.xi

        var rng = SeededRNG(seed: seed(for: match.id, season: season, nonce: nonce))

        let homeAttack = homeRating.attack
        let awayAttack = awayRating.attack
        let homeDefense = homeRating.defense
        let awayDefense = awayRating.defense

        // "On the day" form — without this, a fixed quality gap is a guaranteed
        // landslide every time, which is what made weak teams collect almost no points.
        let homeForm = rng.lognormal(sigma: matchdayNoiseSigma)
        let awayForm = rng.lognormal(sigma: matchdayNoiseSigma)

        let homeLambda = expectedGoals(attack: homeAttack, defense: awayDefense, isHome: true, noise: homeForm)
        let awayLambda = expectedGoals(attack: awayAttack, defense: homeDefense, isHome: false, noise: awayForm)

        // Simulate in two halves so the scoreline at the break can push the second-half
        // rates around — teams protecting a lead sit in, teams chasing the game open up.
        // This is what produces realistic comebacks/garbage-time goals instead of every
        // mismatch playing out as one flat 90-minute blowout.
        let (h1Home, h1Away) = sampleScoreline(
            homeLambda: homeLambda * firstHalfShare,
            awayLambda: awayLambda * firstHalfShare,
            rng: &rng
        )

        let (homeMomentum, awayMomentum) = gameStateModifiers(goalDifference: h1Home - h1Away)
        let (h2Home, h2Away) = sampleScoreline(
            homeLambda: homeLambda * secondHalfShare * homeMomentum,
            awayLambda: awayLambda * secondHalfShare * awayMomentum,
            rng: &rng
        )

        let homeGoals = h1Home + h2Home
        let awayGoals = h1Away + h2Away

        let goals = buildGoals(
            firstHalfHomeGoals: h1Home,
            firstHalfAwayGoals: h1Away,
            secondHalfHomeGoals: h2Home,
            secondHalfAwayGoals: h2Away,
            homeXI: homeXI,
            awayXI: awayXI,
            homeSquad: homeSquad,
            awaySquad: awaySquad,
            rng: &rng
        )

        let strengthDelta = (homeRating.overall - awayRating.overall) / max(homeRating.overall + awayRating.overall, 1)
        let homePossession = Int(clamp(34 ... 66, 50 + strengthDelta * 18 + rng.double(-3 ... 3)).rounded())

        // Shots/corners scale off xG using roughly real PL conversion ratios
        // (~0.10-0.11 xG per shot, ~0.4-0.45 corners per shot).
        let homeShots = max(homeGoals + 1, Int((homeLambda * 9.4 + rng.double(0 ... 3)).rounded()))
        let awayShots = max(awayGoals + 1, Int((awayLambda * 9.4 + rng.double(0 ... 3)).rounded()))

        let homeSOT = max(homeGoals, min(homeShots, Int((Double(homeShots) * rng.double(0.30 ... 0.42)).rounded())))
        let awaySOT = max(awayGoals, min(awayShots, Int((Double(awayShots) * rng.double(0.30 ... 0.42)).rounded())))

        let homeCorners = max(1, Int((Double(homeShots) * rng.double(0.38 ... 0.5)).rounded()))
        let awayCorners = max(1, Int((Double(awayShots) * rng.double(0.38 ... 0.5)).rounded()))

        let homeStats = PLTeamMatchStats(
            xG: homeLambda,
            possession: homePossession,
            shots: homeShots,
            shotsOnTarget: homeSOT,
            corners: homeCorners,
            fouls: Int(rng.double(7 ... 15).rounded()),
            yellowCards: Int(rng.double(0 ... 3).rounded()),
            redCards: rng.double(0 ... 1) < 0.018 ? 1 : 0
        )
        let awayStats = PLTeamMatchStats(
            xG: awayLambda,
            possession: 100 - homePossession,
            shots: awayShots,
            shotsOnTarget: awaySOT,
            corners: awayCorners,
            fouls: Int(rng.double(7 ... 15).rounded()),
            yellowCards: Int(rng.double(0 ... 3).rounded()),
            redCards: rng.double(0 ... 1) < 0.018 ? 1 : 0
        )

        let outcome: String
        if homeGoals > awayGoals { outcome = "H" }
        else if homeGoals < awayGoals { outcome = "A" }
        else { outcome = "D" }

        return PLMatchSimulation(
            matchID: match.id,
            homeGoals: homeGoals,
            awayGoals: awayGoals,
            outcome: outcome,
            homeStats: homeStats,
            awayStats: awayStats,
            goals: goals.sorted { $0.minute < $1.minute },
            homeXI: homeXI,
            awayXI: awayXI,
            halftimeHomeGoals: h1Home,
            halftimeAwayGoals: h1Away
        )
    }

    // MARK: - Goal expectation

    /// Match-to-day form swing (log-normal sigma). This is what lets a weak side
    /// occasionally hold a big side, and stops elite teams winning every match by the same margin.
    private static let matchdayNoiseSigma = 0.13
    /// Share of full-match xG allocated to each half. Real PL scoring is tilted
    /// toward the second half (fatigue, subs, chasing the game), matching the
    /// existing goal-minute distribution below.
    private static let firstHalfShare = 0.42
    private static let secondHalfShare = 0.58

    private static func expectedGoals(attack: Double, defense: Double, isHome: Bool, noise: Double) -> Double {
        let raw = MatchGoalModel.rawExpectedGoals(attack: attack, defense: defense, isHome: isHome)
        return MatchGoalModel.clamp(raw * noise)
    }

    /// Samples a joint (home, away) scoreline for one half from a Dixon-Coles
    /// adjusted distribution, rather than drawing home/away goals independently.
    private static func sampleScoreline(homeLambda: Double, awayLambda: Double, rng: inout SeededRNG) -> (home: Int, away: Int) {
        let maxGoals = 8
        var weights: [Double] = []
        weights.reserveCapacity((maxGoals + 1) * (maxGoals + 1))
        for home in 0...maxGoals {
            for away in 0...maxGoals {
                let base = PoissonMath.pmf(home, lambda: homeLambda) * PoissonMath.pmf(away, lambda: awayLambda)
                let tau = PoissonMath.dixonColesTau(
                    homeGoals: home,
                    awayGoals: away,
                    homeLambda: homeLambda,
                    awayLambda: awayLambda,
                    rho: MatchGoalModel.dixonColesRho
                )
                weights.append(max(base * tau, 0))
            }
        }

        let total = weights.reduce(0, +)
        guard total > 0 else { return (0, 0) }

        var roll = rng.double(0 ..< total)
        var index = 0
        for home in 0...maxGoals {
            for away in 0...maxGoals {
                roll -= weights[index]
                if roll <= 0 { return (home, away) }
                index += 1
            }
        }
        return (maxGoals, maxGoals)
    }

    /// Second-half rate adjustment based on the halftime scoreline: teams protecting
    /// a lead ease off, teams chasing the game push harder and leak more at the back.
    private static func gameStateModifiers(goalDifference: Int) -> (home: Double, away: Double) {
        switch goalDifference {
        case ..<(-1): return (1.18, 0.88)
        case -1: return (1.08, 0.95)
        case 0: return (1.0, 1.0)
        case 1: return (0.95, 1.08)
        default: return (0.88, 1.18)
        }
    }

    // MARK: - Goals

    private static func buildGoals(
        firstHalfHomeGoals: Int,
        firstHalfAwayGoals: Int,
        secondHalfHomeGoals: Int,
        secondHalfAwayGoals: Int,
        homeXI: [PLSimPlayer],
        awayXI: [PLSimPlayer],
        homeSquad: [ClubSquadPlayer],
        awaySquad: [ClubSquadPlayer],
        rng: inout SeededRNG
    ) -> [PLGoalEvent] {
        var events: [PLGoalEvent] = []
        events.reserveCapacity(firstHalfHomeGoals + firstHalfAwayGoals + secondHalfHomeGoals + secondHalfAwayGoals)

        func append(
            count: Int,
            xi: [PLSimPlayer],
            squad: [ClubSquadPlayer],
            isHome: Bool,
            half: Int,
            idPrefix: String
        ) {
            for index in 0..<count {
                let scorer = pickScorer(from: xi, squad: squad, rng: &rng)
                let isPenalty = rng.double(0 ... 1) < 0.09
                events.append(
                    PLGoalEvent(
                        id: "\(idPrefix)\(index)",
                        minute: goalMinute(half: half, rng: &rng),
                        scorerID: scorer.id,
                        scorerName: scorer.name,
                        isHome: isHome,
                        isPenalty: isPenalty
                    )
                )
            }
        }

        append(count: firstHalfHomeGoals, xi: homeXI, squad: homeSquad, isHome: true, half: 1, idPrefix: "h1h")
        append(count: firstHalfAwayGoals, xi: awayXI, squad: awaySquad, isHome: false, half: 1, idPrefix: "h1a")
        append(count: secondHalfHomeGoals, xi: homeXI, squad: homeSquad, isHome: true, half: 2, idPrefix: "h2h")
        append(count: secondHalfAwayGoals, xi: awayXI, squad: awaySquad, isHome: false, half: 2, idPrefix: "h2a")

        return events
    }

    private static func pickScorer(
        from xi: [PLSimPlayer],
        squad: [ClubSquadPlayer],
        rng: inout SeededRNG
    ) -> PLSimPlayer {
        // Bench/rotation: subs and squad depth take a slice of goals so one
        // starting striker is not credited with every team goal all season.
        if rng.double(0 ... 1) < 0.25, let benchScorer = pickBenchScorer(squad: squad, excludingXI: xi, rng: &rng) {
            return benchScorer
        }

        let weights = xi.map { scorerWeight(for: $0, in: squad) }
        let total = weights.reduce(0, +)
        guard total > 0, let fallback = xi.first else {
            return PLSimPlayer(id: "unknown", name: "Unknown", position: "Forward", role: "ST")
        }

        var roll = rng.double(0 ..< total)
        for (player, weight) in zip(xi, weights) {
            roll -= weight
            if roll <= 0 { return player }
        }
        return fallback
    }

    private static func pickBenchScorer(
        squad: [ClubSquadPlayer],
        excludingXI: [PLSimPlayer],
        rng: inout SeededRNG
    ) -> PLSimPlayer? {
        let xiIDs = Set(excludingXI.map(\.id))
        let candidates = squad.filter { !xiIDs.contains($0.id) && isAttackingPlayer($0) }
        guard !candidates.isEmpty else { return nil }

        let weights = candidates.map { benchScorerWeight(for: $0) }
        let total = weights.reduce(0, +)
        guard total > 0 else { return nil }

        var roll = rng.double(0 ..< total)
        for (player, weight) in zip(candidates, weights) {
            roll -= weight
            if roll <= 0 {
                return PLSimPlayer(
                    id: player.id,
                    name: player.name,
                    position: player.position,
                    role: benchRole(for: player)
                )
            }
        }

        let fallback = candidates[0]
        return PLSimPlayer(
            id: fallback.id,
            name: fallback.name,
            position: fallback.position,
            role: benchRole(for: fallback)
        )
    }

    private static func benchRole(for player: ClubSquadPlayer) -> String {
        let position = player.position.lowercased()
        if position.contains("left") && position.contains("winger") { return "LW" }
        if position.contains("right") && position.contains("winger") { return "RW" }
        if position.contains("attacking") { return "CM" }
        return "ST"
    }

    private static func isAttackingPlayer(_ player: ClubSquadPlayer) -> Bool {
        let position = player.position.lowercased()
        return position.contains("forward")
            || position.contains("striker")
            || position.contains("winger")
            || position.contains("attacking midfield")
    }

    private static func benchScorerWeight(for player: ClubSquadPlayer) -> Double {
        let position = player.position.lowercased()
        var base = 1.0
        if position.contains("centre-forward") || position.contains("center forward") || position.contains("striker") {
            base = 1.35
        } else if position.contains("winger") {
            base = 1.05
        } else if position.contains("attacking midfield") {
            base = 0.85
        } else if position.contains("second striker") {
            base = 1.15
        }

        let value = Double(player.marketValue ?? 1_000_000)
        let valueFactor = pow(max(value, 500_000) / 12_000_000, 0.38)
        return base * min(1.5, max(0.45, valueFactor))
    }

    private static func scorerWeight(for player: PLSimPlayer, in squad: [ClubSquadPlayer]) -> Double {
        let roleBase = roleScorerWeight(for: player)
        let value = Double(squadValue(for: player, in: squad))
        // Dampen market-value skew so one elite striker does not hoard every goal.
        let valueFactor = pow(max(value, 500_000) / 18_000_000, 0.34)
        return roleBase * min(1.35, max(0.6, valueFactor))
    }

    private static func squadValue(for player: PLSimPlayer, in squad: [ClubSquadPlayer]) -> Int {
        squad.first { $0.id == player.id }?.marketValue ?? 1_000_000
    }

    private static func roleScorerWeight(for player: PLSimPlayer) -> Double {
        switch player.role {
        case "ST": return 2.2
        case "LW", "RW": return 2.3
        case "CM":
            let position = player.position.lowercased()
            if position.contains("attacking") || position.contains("offensive") { return 1.05 }
            if position.contains("defensive") { return 0.14 }
            return 0.36
        case "LB", "RB": return 0.06
        case "CB": return 0.035
        case "GK": return 0.015
        default: return 0.16
        }
    }

    /// Goals skew toward the end of each half — fatigue, late pressure, and stoppage
    /// time all mean more goals go in during the closing minutes than the opening ones.
    private static func goalMinute(half: Int, rng: inout SeededRNG) -> Int {
        let bucket = rng.double(0 ... 1)
        if half == 1 {
            let minute: Int
            if bucket < 0.22 {
                minute = Int(rng.double(1 ... 15).rounded())
            } else if bucket < 0.52 {
                minute = Int(rng.double(16 ... 30).rounded())
            } else {
                minute = Int(rng.double(31 ... 45).rounded())
            }
            return min(45, max(1, minute))
        } else {
            let minute: Int
            if bucket < 0.26 {
                minute = Int(rng.double(46 ... 60).rounded())
            } else if bucket < 0.56 {
                minute = Int(rng.double(61 ... 75).rounded())
            } else {
                minute = Int(rng.double(76 ... 90).rounded())
            }
            return min(90, max(46, minute))
        }
    }

    private static func seed(for matchID: String, season: String, nonce: Int) -> UInt64 {
        var hash: UInt64 = 14_695_981_039_346_656_037
        for byte in "\(season)|\(matchID)|n\(nonce)".utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 1_099_511_628_211
        }
        return hash
    }

    private static func clamp(_ range: ClosedRange<Double>, _ value: Double) -> Double {
        min(range.upperBound, max(range.lowerBound, value))
    }
}

// MARK: - RNG

struct SeededRNG {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed == 0 ? 0xDEAD_BEEF : seed
    }

    mutating func next() -> UInt64 {
        state ^= state >> 12
        state ^= state << 25
        state ^= state >> 27
        return state &* 2_685_821_657_736_338_717
    }

    mutating func double(_ range: ClosedRange<Double>) -> Double {
        let unit = Double(next() % 10_000) / 10_000
        return range.lowerBound + unit * (range.upperBound - range.lowerBound)
    }

    mutating func double(_ range: Range<Double>) -> Double {
        double(range.lowerBound ... range.upperBound.nextDown)
    }

    /// Standard normal sample via Box-Muller, using this RNG's own uniforms.
    mutating func gaussian() -> Double {
        let u1 = max(double(0 ... 1), 0.0001)
        let u2 = double(0 ... 1)
        return sqrt(-2 * log(u1)) * cos(2 * Double.pi * u2)
    }

    /// Multiplicative log-normal noise centered on 1.0 — models "on the day" form swings.
    mutating func lognormal(sigma: Double) -> Double {
        exp(sigma * gaussian())
    }
}
