import Foundation

/// One team in a Classic Alias match. `roundScores` keeps each turn's delta so the
/// results screen can show a per-round breakdown / best round.
struct AliasTeam: Identifiable, Equatable {
    let id: Int
    var name: String
    var score: Int = 0
    var roundScores: [Int] = []
}

/// The outcome of a single card within a turn. Editable in the round-review step.
enum AliasGuess: String, Equatable {
    case correct
    case skipped
}

struct AliasRoundOutcome: Identifiable, Equatable {
    let id: UUID
    let card: AliasCard
    var result: AliasGuess

    init(id: UUID = UUID(), card: AliasCard, result: AliasGuess) {
        self.id = id
        self.card = card
        self.result = result
    }
}

/// The Alias game state machine's phases.
enum AliasGameStatus: Equatable {
    case setup          // not started
    case readyForTeam   // "pass the phone to the explainer" gate before a turn
    case playing        // timer running, drawing cards
    case roundReview    // turn over — review/adjust each card before scoring
    case finished       // a team reached the target score
}
