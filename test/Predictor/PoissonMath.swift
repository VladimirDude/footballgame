import Foundation

/// Shared statistical helpers used by both the match simulator and the pre-match
/// odds model, so the two stay mathematically consistent with each other.
enum PoissonMath {

    static func pmf(_ k: Int, lambda: Double) -> Double {
        guard k >= 0 else { return 0 }
        guard lambda > 0 else { return k == 0 ? 1 : 0 }
        let logProbability = -lambda + Double(k) * log(lambda) - logFactorial(k)
        return exp(logProbability)
    }

    /// Dixon & Coles (1997) low-score correlation adjustment. Independent Poisson
    /// slightly under-predicts tight, low-scoring results (0-0, 1-0, 0-1, 1-1) because
    /// real teams tactically tighten up rather than trade chances symmetrically in
    /// close games. `rho` is typically -0.1 to -0.15 for top European leagues.
    static func dixonColesTau(homeGoals: Int, awayGoals: Int, homeLambda: Double, awayLambda: Double, rho: Double) -> Double {
        switch (homeGoals, awayGoals) {
        case (0, 0): return 1 - homeLambda * awayLambda * rho
        case (0, 1): return 1 + homeLambda * rho
        case (1, 0): return 1 + awayLambda * rho
        case (1, 1): return 1 - rho
        default: return 1
        }
    }

    private static func logFactorial(_ n: Int) -> Double {
        guard n > 1 else { return 0 }
        var sum = 0.0
        for value in 2...n { sum += log(Double(value)) }
        return sum
    }
}
