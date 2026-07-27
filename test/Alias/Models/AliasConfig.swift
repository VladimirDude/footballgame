import Foundation

/// The user-chosen setup for a Classic Alias match. Value type — passed to the
/// container to build a deck + engine.
struct AliasConfig: Equatable {
    var timerSeconds: Int
    var categories: Set<AliasCategory>
    var minDifficulty: AliasDifficulty
    var maxDifficulty: AliasDifficulty
    var skipPenalty: Int          // points removed per skip (>= 0)
    var pointsPerCorrect: Int
    var targetScore: Int          // first team to reach this (after a full turn) wins
    var language: String

    /// Selectable round lengths (seconds).
    static let timerOptions = [30, 60, 90, 120]
    /// Selectable target scores.
    static let targetScoreOptions = [15, 20, 30, 40]

    static let `default` = AliasConfig(
        timerSeconds: 60,
        categories: [.players, .terms],
        minDifficulty: .easy,
        maxDifficulty: .hard,
        skipPenalty: 1,
        pointsPerCorrect: 1,
        targetScore: 20,
        language: "en"
    )

    /// Normalized min…max (guards against the user setting min > max).
    var difficultyRange: ClosedRange<AliasDifficulty> {
        let lo = Swift.min(minDifficulty, maxDifficulty)
        let hi = Swift.max(minDifficulty, maxDifficulty)
        return lo...hi
    }
}
