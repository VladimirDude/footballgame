import Foundation

enum FuzzyMatcher {

    static func matches(guess: String, candidates: [String]) -> Bool {
        let normalizedGuess = normalize(guess)
        guard normalizedGuess.count >= 2 else { return false }

        let expandedCandidates = Set(
            candidates
                .map(normalize)
                .filter { !$0.isEmpty }
        )

        for candidate in expandedCandidates {
            if directMatch(normalizedGuess, candidate) { return true }
            if tokenMatch(normalizedGuess, candidate) { return true }
            if levenshteinMatch(normalizedGuess, candidate) { return true }
        }

        return false
    }

    static func matchesPlayer(guess: String, fullName: String, extraAliases: [String] = []) -> Bool {
        let normalizedGuess = normalize(guess)
        guard normalizedGuess.count >= 2 else { return false }

        var candidates = [fullName] + extraAliases
        if let lastName = fullName.split(separator: " ").last.map(String.init), lastName.count >= 4 {
            candidates.append(lastName)
        }

        return matches(guess: guess, candidates: candidates)
    }

    // MARK: - Private

    private static func directMatch(_ guess: String, _ candidate: String) -> Bool {
        guess == candidate
            || (guess.count >= 3 && candidate.contains(guess))
            || (candidate.count >= 4 && guess.contains(candidate))
    }

    private static func tokenMatch(_ guess: String, _ candidate: String) -> Bool {
        let guessTokens = tokens(from: guess)
        let candidateTokens = tokens(from: candidate)
        guard !guessTokens.isEmpty, !candidateTokens.isEmpty else { return false }

        if guessTokens.count == 1, let single = guessTokens.first, single.count >= 4 {
            return candidateTokens.contains(single)
        }

        return guessTokens.allSatisfy { token in
            candidateTokens.contains(where: { $0.hasPrefix(token) || token.hasPrefix($0) })
        }
    }

    private static func levenshteinMatch(_ guess: String, _ candidate: String) -> Bool {
        let limit: Int
        switch max(guess.count, candidate.count) {
        case ..<5: return false
        case 5...8: limit = 1
        default: limit = 2
        }
        return levenshteinDistance(guess, candidate) <= limit
    }

    private static func tokens(from value: String) -> [String] {
        normalize(value)
            .split(separator: " ")
            .map(String.init)
            .filter { $0.count >= 2 }
    }

    static func normalize(_ value: String) -> String {
        value
            .folding(options: .diacriticInsensitive, locale: .current)
            .lowercased()
            .replacingOccurrences(of: ".", with: "")
            .replacingOccurrences(of: "-", with: " ")
            .replacingOccurrences(of: "'", with: "")
            .replacingOccurrences(of: "  ", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func levenshteinDistance(_ lhs: String, _ rhs: String) -> Int {
        let left = Array(lhs)
        let right = Array(rhs)
        var matrix = Array(repeating: Array(repeating: 0, count: right.count + 1), count: left.count + 1)

        for i in 0...left.count { matrix[i][0] = i }
        for j in 0...right.count { matrix[0][j] = j }

        for i in 1...left.count {
            for j in 1...right.count {
                let cost = left[i - 1] == right[j - 1] ? 0 : 1
                matrix[i][j] = min(
                    matrix[i - 1][j] + 1,
                    matrix[i][j - 1] + 1,
                    matrix[i - 1][j - 1] + cost
                )
            }
        }

        return matrix[left.count][right.count]
    }
}

enum ClubAbbreviations {
    static let map: [String: [String]] = [
        "manchester united": ["man utd", "man u", "man united", "mufc", "man utd fc"],
        "manchester city": ["man city", "mcfc", "city"],
        "tottenham hotspur": ["spurs", "tottenham", "thfc"],
        "real madrid": ["madrid", "real"],
        "atletico de madrid": ["atletico", "atletico madrid", "atleti"],
        "fc barcelona": ["barca", "barcelona", "fcb"],
        "bayern munich": ["bayern", "fcb munich"],
        "borussia dortmund": ["dortmund", "bvb"],
        "paris saint germain": ["psg", "paris sg"],
        "inter milan": ["inter", "internazionale"],
        "ac milan": ["milan", "acm"],
        "juventus fc": ["juve", "juventus"],
        "ssc napoli": ["napoli"],
        "arsenal fc": ["arsenal", "afc"],
        "chelsea fc": ["chelsea", "cfc"],
        "liverpool fc": ["liverpool", "lfc"],
        "inter miami cf": ["inter miami", "miami"],
        "ajax amsterdam": ["ajax"],
        "ca boca juniors": ["boca", "boca juniors"],
        "ca river plate": ["river", "river plate"],
        "cr flamengo": ["flamengo"],
    ]
}
