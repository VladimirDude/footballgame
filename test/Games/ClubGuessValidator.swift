import Foundation

enum ClubGuessValidator {

    static func isCorrect(guess: String, round: GameRound) -> Bool {
        var candidates = [round.clubName, round.officialName ?? ""] + round.aliases

        for name in candidates {
            let key = FuzzyMatcher.normalize(name)
            for (canonical, abbrevs) in ClubAbbreviations.map {
                if key == canonical || key.contains(canonical) || canonical.contains(key) {
                    candidates.append(canonical)
                    candidates.append(contentsOf: abbrevs)
                }
            }
        }

        return FuzzyMatcher.matches(guess: guess, candidates: candidates)
    }
}
