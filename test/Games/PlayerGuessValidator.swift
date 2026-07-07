import Foundation

enum PlayerGuessValidator {

    static func isCorrect(guess: String, round: GuessPlayerRound) -> Bool {
        FuzzyMatcher.matchesPlayer(guess: guess, fullName: round.playerName)
    }
}
