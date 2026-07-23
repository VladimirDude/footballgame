import Foundation

/// Parses a text block into a `TeamGame`.
///
/// Expected format:
/// ```
/// Opponent.  +GF:GA  (or -GA:GF for loss, =G:G for draw)
/// - MM:SS  - Scorer/Assist
/// - MM:SS  - opponent_name  (treated as opponent goal)
/// https://youtube.com/...   (optional video URL)
/// ```
enum GameParser {

    static func parse(_ text: String) -> TeamGame? {
        let lines = text.components(separatedBy: .newlines).map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        guard !lines.isEmpty else { return nil }

        // First line: "Opponent.  +GF:GA"
        var opponent = ""
        var goalsFor = 0
        var goalsAgainst = 0
        parseHeader(lines[0], opponent: &opponent, goalsFor: &goalsFor, goalsAgainst: &goalsAgainst)
        guard !opponent.isEmpty else { return nil }

        var goals: [GoalDetail] = []
        var links: [MediaLink] = []

        for line in lines.dropFirst() {
            let trimmed = line.trimmingCharacters(in: CharacterSet(charactersIn: "- ."))

            // URL line
            if trimmed.hasPrefix("http") {
                let parts = trimmed.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
                let urlStr = parts[0]
                links.append(MediaLink(title: "Full Match", urlString: urlStr, type: .video))
                continue
            }

            // Goal line: "MM:SS  - Scorer/Assist" or "MM:SS - opponent"
            if let goal = parseGoalLine(trimmed, opponent: opponent) {
                goals.append(goal)
            }
        }

        let scorers = goals.filter { !$0.isOpponent }.map { $0.scorer }
        let scorerCounts = Dictionary(scorers.map { ($0, 1) }, uniquingKeysWith: +)
        let scorerList = scorerCounts.sorted(by: { $0.value > $1.value }).map { $0.value > 1 ? "\($0.key) x\($0.value)" : $0.key }

        return TeamGame(
            date: Date(),
            opponent: opponent,
            goalsFor: goalsFor,
            goalsAgainst: goalsAgainst,
            scorers: scorerList,
            goalDetails: goals,
            mediaLinks: links
        )
    }

    private static func parseHeader(_ line: String, opponent: inout String, goalsFor: inout Int, goalsAgainst: inout Int) {
        // Find score pattern like "+9:0" or "+3:2"
        let pattern = "[+\\-=]\\s*(\\d+)\\s*:\\s*(\\d+)"
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)),
              let r1 = Range(match.range(at: 1), in: line),
              let r2 = Range(match.range(at: 2), in: line),
              let g1 = Int(line[r1]),
              let g2 = Int(line[r2])
        else { return }

        goalsFor = g1
        goalsAgainst = g2

        // Everything before the score pattern is the opponent name
        let scoreRange = Range(match.range, in: line)!
        opponent = String(line[line.startIndex..<scoreRange.lowerBound])
            .trimmingCharacters(in: CharacterSet.whitespacesAndNewlines.union(CharacterSet(charactersIn: ".")))
    }

    private static func parseGoalLine(_ line: String, opponent: String) -> GoalDetail? {
        // Expected: "MM:SS  - Scorer/Assist" or "MM:SS - opponentName"
        // Split on " - " (with surrounding spaces)
        let parts = line.components(separatedBy: " - ").map { $0.trimmingCharacters(in: .whitespaces) }
        guard parts.count >= 2 else {
            // Try splitting on just "-"
            let fallback = line.components(separatedBy: "-").map { $0.trimmingCharacters(in: .whitespaces) }
            guard fallback.count >= 2 else { return nil }
            return parseGoalParts(time: fallback[0], rest: fallback.dropFirst().joined(separator: "-").trimmingCharacters(in: .whitespaces), opponent: opponent)
        }
        return parseGoalParts(time: parts[0], rest: parts[1], opponent: opponent)
    }

    private static func parseGoalParts(time: String, rest: String, opponent: String) -> GoalDetail? {
        // Validate time looks like MM:SS
        guard time.contains(":"), time.count <= 8 else { return nil }

        // Check if it's an opponent goal (rest is just the opponent name, case-insensitive)
        let restLower = rest.lowercased()
        let oppLower = opponent.lowercased()
        if restLower == oppLower || restLower.hasPrefix(oppLower) {
            return GoalDetail(time: time, scorer: opponent, isOpponent: true)
        }

        // Scorer/Assist
        let scorerParts = rest.components(separatedBy: "/").map { $0.trimmingCharacters(in: .whitespaces) }
        let scorer = scorerParts[0]
        let assist = scorerParts.count > 1 ? scorerParts[1] : ""

        return GoalDetail(time: time, scorer: scorer, assist: assist)
    }
}
