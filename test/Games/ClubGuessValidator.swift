import Foundation

enum ClubGuessValidator {

    static func isCorrect(guess: String, round: GameRound) -> Bool {
        let baseNames = [round.clubName, round.officialName ?? ""] + round.aliases
        var candidates = baseNames

        // Exact, O(1) lookup per known name — the previous loose `contains` scan
        // bled aliases across clubs (e.g. "milan" matched both AC and Inter).
        for name in baseNames {
            let key = FuzzyMatcher.normalize(name)
            if let abbrevs = ClubAbbreviations.map[key] {
                candidates.append(key)
                candidates.append(contentsOf: abbrevs)
            }
        }

        return FuzzyMatcher.matches(
            guess: guess,
            candidates: candidates,
            allowSingleTokenWordMatch: false
        )
    }
}
