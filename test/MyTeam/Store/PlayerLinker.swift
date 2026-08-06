import Foundation

/// Resolves free-text scorer names in the match log to squad members.
///
/// Before season stats could be derived, goals referenced players by name only
/// (`GoalDetail.scorer`), sometimes aggregated as "Alex x2" in `TeamGame.scorers`.
/// This turns those strings into `TeamPlayer.id` references where it can do so
/// unambiguously, and leaves the rest alone rather than guessing.
enum PlayerLinker {

    /// How confident a match is.
    enum Confidence {
        /// Unambiguous — applied automatically during migration.
        case exact
        /// A near-miss. **Never** applied automatically; only ever offered to the
        /// user as a suggestion.
        case fuzzy
    }

    struct Match {
        let playerID: UUID
        let confidence: Confidence
    }

    // MARK: - Normalization

    /// Strips diacritics, case, punctuation, a trailing "x2" count and stray
    /// whitespace, so "Álex  X2" and "alex" compare equal.
    static func normalize(_ raw: String) -> String {
        var s = raw.folding(options: [.diacriticInsensitive, .caseInsensitive, .widthInsensitive],
                            locale: .current)
        if let range = s.range(of: #"\s*[xX×]\s*\d+\s*$"#, options: .regularExpression) {
            s.removeSubrange(range)
        }
        s = s.components(separatedBy: CharacterSet.alphanumerics.union(.whitespaces).inverted)
            .joined(separator: " ")
        return s.split(separator: " ").joined(separator: " ").trimmingCharacters(in: .whitespaces)
    }

    /// Reads the repeat count off an aggregated scorer string ("Alex x2" → 2).
    static func repeatCount(_ raw: String) -> Int {
        guard let range = raw.range(of: #"[xX×]\s*(\d+)\s*$"#, options: .regularExpression) else { return 1 }
        let digits = raw[range].filter(\.isNumber)
        return max(1, Int(digits) ?? 1)
    }

    // MARK: - Matching

    /// Candidate squad members. Coaches are excluded — they don't score.
    private static func candidates(_ players: [TeamPlayer]) -> [TeamPlayer] {
        players.filter { $0.role != .coach }
    }

    /// Resolves one name.
    ///
    /// Passes run most- to least-certain, and **ambiguity is always a non-match**,
    /// never a coin flip:
    ///   1. exact normalized full name, unique
    ///   2. unique first token ("Alex" → "Alex Petrosyan")
    ///   3. unique token-boundary prefix
    ///   4. Levenshtein ≤ 1 on names ≥ 5 chars — suggestion only
    static func match(_ rawName: String, in players: [TeamPlayer]) -> Match? {
        let needle = normalize(rawName)
        guard !needle.isEmpty else { return nil }
        let pool = candidates(players)

        let exact = pool.filter { normalize($0.name) == needle }
        if exact.count == 1 { return Match(playerID: exact[0].id, confidence: .exact) }
        if exact.count > 1 { return nil }

        let byFirstToken = pool.filter { normalize($0.name).split(separator: " ").first.map(String.init) == needle }
        if byFirstToken.count == 1 { return Match(playerID: byFirstToken[0].id, confidence: .exact) }
        if byFirstToken.count > 1 { return nil }

        let byPrefix = pool.filter { player in
            let full = normalize(player.name)
            guard full.hasPrefix(needle) else { return false }
            // Only at a token boundary, so "sam" doesn't claim "samantha".
            let next = full.index(full.startIndex, offsetBy: needle.count)
            return next == full.endIndex || full[next] == " "
        }
        if byPrefix.count == 1 { return Match(playerID: byPrefix[0].id, confidence: .exact) }
        if byPrefix.count > 1 { return nil }

        guard needle.count >= 5 else { return nil }
        let near = pool.filter { levenshtein(normalize($0.name), needle) <= 1 }
        if near.count == 1 { return Match(playerID: near[0].id, confidence: .fuzzy) }
        return nil
    }

    /// Names in the log that no squad member matches, with how many goals each
    /// accounts for. Drives the "unlinked names" prompt.
    static func unmatchedNames(in doc: TeamDocument) -> [(name: String, goals: Int)] {
        let ignored = Set(doc.ignoredScorerNames.map(normalize))
        var counts: [String: (display: String, count: Int)] = [:]
        for game in doc.games {
            for goal in game.goalDetails where !goal.isOpponent && goal.scorerID == nil {
                let key = normalize(goal.scorer)
                guard !key.isEmpty, !ignored.contains(key) else { continue }
                if match(goal.scorer, in: doc.players)?.confidence == .exact { continue }
                let existing = counts[key]
                counts[key] = (existing?.display ?? goal.scorer, (existing?.count ?? 0) + 1)
            }
        }
        return counts.values
            .map { (name: $0.display, goals: $0.count) }
            .sorted { $0.goals == $1.goals ? $0.name < $1.name : $0.goals > $1.goals }
    }

    // MARK: - Distance

    static func levenshtein(_ a: String, _ b: String) -> Int {
        if a == b { return 0 }
        let x = Array(a), y = Array(b)
        if x.isEmpty { return y.count }
        if y.isEmpty { return x.count }
        var previous = Array(0...y.count)
        var current = [Int](repeating: 0, count: y.count + 1)
        for i in 1...x.count {
            current[0] = i
            for j in 1...y.count {
                let cost = x[i - 1] == y[j - 1] ? 0 : 1
                current[j] = min(previous[j] + 1, current[j - 1] + 1, previous[j - 1] + cost)
            }
            previous = current
        }
        return previous[y.count]
    }
}
