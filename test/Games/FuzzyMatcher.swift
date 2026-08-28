import Foundation

enum FuzzyMatcher {

    static func matches(
        guess: String,
        candidates: [String],
        allowSingleTokenWordMatch: Bool = true
    ) -> Bool {
        let normalizedGuess = normalize(guess)
        guard normalizedGuess.count >= 2 else { return false }

        let expandedCandidates = Set(
            candidates
                .map(normalize)
                .filter { !$0.isEmpty }
        )

        for candidate in expandedCandidates {
            if directMatch(normalizedGuess, candidate) { return true }
            if tokenMatch(normalizedGuess, candidate, allowSingleTokenWordMatch: allowSingleTokenWordMatch) {
                return true
            }
            if levenshteinMatch(normalizedGuess, candidate) { return true }
        }

        return false
    }

    static func matchesPlayer(guess: String, fullName: String, extraAliases: [String] = []) -> Bool {
        let normalizedGuess = normalize(guess)
        guard normalizedGuess.count >= 2 else { return false }

        var candidates = [fullName] + extraAliases
        // Last-name-only guesses need enough letters to stay unambiguous
        // ("Silva" ok; "Lee" / "Son" too risky).
        if let lastName = fullName.split(separator: " ").last.map(String.init), lastName.count >= 5 {
            candidates.append(lastName)
        }

        return matches(guess: guess, candidates: candidates)
    }

    // MARK: - Private

    private static func directMatch(_ guess: String, _ candidate: String) -> Bool {
        // Exact only. Partial/short matches must go through the alias list
        // (exact-matched here) or `tokenMatch`/`levenshteinMatch`. Accepting any
        // substring produced false positives (e.g. "sen" → "arsenal").
        guess == candidate
    }

    private static func tokenMatch(
        _ guess: String,
        _ candidate: String,
        allowSingleTokenWordMatch: Bool = true
    ) -> Bool {
        let guessTokens = tokens(from: guess)
        let candidateTokens = tokens(from: candidate)
        guard !guessTokens.isEmpty, !candidateTokens.isEmpty else { return false }

        // A single-word guess must equal a full candidate word and be long
        // enough to be unambiguous — no prefixes (blocks "man" → "manchester").
        // Clubs disable this so "madrid" / "united" / "inter" can't match every
        // team that contains that word — only exact aliases / full names.
        if guessTokens.count == 1 {
            guard allowSingleTokenWordMatch else { return false }
            guard let single = guessTokens.first, single.count >= 5 else { return false }
            return candidateTokens.contains(single)
        }

        // Multi-word: every guess token must match a candidate word; prefix
        // matching is only allowed when the token is long and covers most of
        // the candidate word (blocks "man che" → "manchester chelsea").
        return guessTokens.allSatisfy { token in
            candidateTokens.contains { candidateToken in
                if candidateToken == token { return true }
                guard token.count >= 5 else { return false }
                let shorter = min(token.count, candidateToken.count)
                let longer = max(token.count, candidateToken.count)
                guard Double(shorter) / Double(longer) >= 0.75 else { return false }
                return candidateToken.hasPrefix(token) || token.hasPrefix(candidateToken)
            }
        }
    }

    private static func levenshteinMatch(_ guess: String, _ candidate: String) -> Bool {
        let maxLen = max(guess.count, candidate.count)
        let limit: Int
        switch maxLen {
        case ..<6: return false
        case 6...10: limit = 1
        default: limit = 2
        }
        // Same first letter keeps "ronaldo" from matching "ronaldinho" with limit 2
        // when lengths diverge a lot — still allow small typos on the same name.
        guard guess.first == candidate.first else { return false }
        let distance = levenshteinDistance(guess, candidate)
        guard distance <= limit else { return false }
        // Relative cap: typos can't be a large fraction of a long name.
        return Double(distance) / Double(maxLen) <= 0.2
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
