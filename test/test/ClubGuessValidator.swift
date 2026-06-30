import Foundation

enum ClubGuessValidator {

    static func isCorrect(guess: String, round: GameRound) -> Bool {
        let normalizedGuess = normalize(guess)
        guard !normalizedGuess.isEmpty else { return false }

        var candidates = [round.clubName, round.officialName ?? ""]
        candidates.append(contentsOf: round.aliases)

        return candidates.contains { candidate in
            let normalizedCandidate = normalize(candidate)
            guard !normalizedCandidate.isEmpty else { return false }
            return normalizedGuess == normalizedCandidate
                || normalizedCandidate.contains(normalizedGuess)
                || normalizedGuess.contains(normalizedCandidate)
        }
    }

    private static func normalize(_ value: String) -> String {
        value
            .folding(options: .diacriticInsensitive, locale: .current)
            .lowercased()
            .replacingOccurrences(of: ".", with: "")
            .replacingOccurrences(of: "'", with: "")
            .replacingOccurrences(of: " fc", with: "")
            .replacingOccurrences(of: " cf", with: "")
            .replacingOccurrences(of: "football club", with: "")
            .replacingOccurrences(of: "  ", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
