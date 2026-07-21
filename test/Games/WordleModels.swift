import Foundation

struct WordlePlayer: Identifiable, Equatable, Hashable {
    let id: String
    let name: String
    let clubName: String
    let league: String
    let nation: String
    let position: String
    let marketValue: Int

    var formattedMarketValue: String {
        MarketValueFormatter.format(marketValue)
    }

    var nationFlag: String {
        CountryFlags.flag(for: nation)
    }
}

enum WordleTileState: Equatable {
    case correct
    case wrong
    case higher
    case lower
}

struct WordleFeedback: Equatable {
    let nation: WordleTileState
    let league: WordleTileState
    let club: WordleTileState
    let position: WordleTileState
    let value: WordleTileState
}

struct WordleGuess: Identifiable, Equatable {
    let id: String
    let player: WordlePlayer
    let feedback: WordleFeedback
}

enum WordleEvaluator {

    static let maxGuesses = 6
    private static let valueTolerance = 0.15

    static func evaluate(guess: WordlePlayer, target: WordlePlayer) -> WordleFeedback {
        WordleFeedback(
            nation: compareNation(guess: guess, target: target),
            league: compareExact(guess.league, target.league),
            club: compareExact(guess.clubName, target.clubName),
            position: compareExact(guess.position, target.position),
            value: compareValue(guess: guess, target: target)
        )
    }

    static func isWinningGuess(_ guess: WordlePlayer, target: WordlePlayer) -> Bool {
        guess.id == target.id
    }

    private static func compareNation(guess: WordlePlayer, target: WordlePlayer) -> WordleTileState {
        compareExact(guess.nation, target.nation)
    }

    private static func compareExact(_ lhs: String, _ rhs: String) -> WordleTileState {
        let left = lhs.folding(options: .diacriticInsensitive, locale: .current).lowercased()
        let right = rhs.folding(options: .diacriticInsensitive, locale: .current).lowercased()
        return left == right ? .correct : .wrong
    }

    private static func compareValue(guess: WordlePlayer, target: WordlePlayer) -> WordleTileState {
        guard target.marketValue > 0 else {
            return guess.marketValue == target.marketValue ? .correct : .wrong
        }

        let ratio = Double(guess.marketValue) / Double(target.marketValue)
        if abs(ratio - 1.0) <= valueTolerance {
            return .correct
        }
        // Arrow hints where the answer is relative to this guess, not the guess itself.
        return guess.marketValue > target.marketValue ? .lower : .higher
    }
}
