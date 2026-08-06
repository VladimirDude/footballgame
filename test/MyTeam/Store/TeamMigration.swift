import Foundation

/// Brings a decoded snapshot up to today's shape.
///
/// Deliberately **pure and idempotent**: no file I/O, no `Date()`, no randomness
/// beyond the ids it must mint. It runs on every decode — including a cloud pull
/// on a viewer device with no roster and no edit rights — so it can never prompt
/// the user or depend on ambient state. Running it twice on the same bytes
/// produces the same document.
enum TeamMigration {

    static func apply(to doc: inout TeamDocument, referenceDate: Date) {
        let hadNoSeasons = doc.seasons.isEmpty
        ensureSeason(&doc, referenceDate: referenceDate)
        if hadNoSeasons {
            // Only a pre-season-support snapshot gets its matches swept into the
            // new season. Once seasons exist, a `nil` means the publisher's client
            // genuinely had no season for it — that shows as "Unassigned" rather
            // than being silently rewritten.
            assignAllGamesToCurrentSeason(&doc)
        }
        backfillGoalDetails(&doc)
        linkScorers(&doc)
        seedCarryOver(&doc)
    }

    // MARK: - Seasons

    private static func ensureSeason(_ doc: inout TeamDocument, referenceDate: Date) {
        if doc.seasons.isEmpty {
            // Name it after the most recent match, falling back to when the
            // snapshot was written. Never `Date()` — that would make the result
            // depend on when migration happened to run.
            let latest = doc.games.map(\.date).max() ?? referenceDate
            let season = Season(name: Season.conventionalName(for: latest), sortIndex: 0)
            doc.seasons = [season]
            doc.currentSeasonID = season.id
        }
        // A dangling pointer (season deleted by a newer client) falls back to the
        // newest season rather than leaving the app with no current season.
        if doc.currentSeason == nil {
            doc.currentSeasonID = doc.orderedSeasons.first?.id
        }
    }

    private static func assignAllGamesToCurrentSeason(_ doc: inout TeamDocument) {
        guard let current = doc.currentSeasonID else { return }
        for i in doc.games.indices where doc.games[i].seasonID == nil {
            doc.games[i].seasonID = current
        }
    }

    // MARK: - Goal details

    /// Rebuilds structured goals for matches that only ever had the flat `scorers`
    /// list, which is what `EditGameSheet`'s free-text field produced.
    ///
    /// Capped at `goalsFor` so a typo ("Alex x40") cannot invent goals. Where
    /// `goalDetails` already exists it is left alone, even if it accounts for
    /// fewer goals than the scoreline — inventing the difference would be guessing.
    private static func backfillGoalDetails(_ doc: inout TeamDocument) {
        for i in doc.games.indices {
            let game = doc.games[i]
            guard game.goalDetails.isEmpty, !game.scorers.isEmpty, game.goalsFor > 0 else { continue }

            var rebuilt: [GoalDetail] = []
            for entry in game.scorers {
                let name = entry.replacingOccurrences(of: #"\s*[xX×]\s*\d+\s*$"#, with: "",
                                                     options: .regularExpression)
                    .trimmingCharacters(in: .whitespaces)
                guard !name.isEmpty else { continue }
                for _ in 0..<PlayerLinker.repeatCount(entry) {
                    guard rebuilt.count < game.goalsFor else { break }
                    rebuilt.append(GoalDetail(time: "", scorer: name, isInferred: true))
                }
            }
            doc.games[i].goalDetails = rebuilt
        }
    }

    // MARK: - Linking

    /// Attaches player ids to goals whose scorer name resolves unambiguously.
    /// Fuzzy near-misses are never applied here — they are only ever offered as
    /// suggestions in `LinkScorersView`.
    private static func linkScorers(_ doc: inout TeamDocument) {
        let players = doc.players
        for g in doc.games.indices {
            for d in doc.games[g].goalDetails.indices {
                let goal = doc.games[g].goalDetails[d]
                guard !goal.isOpponent else { continue }
                if goal.scorerID == nil,
                   let m = PlayerLinker.match(goal.scorer, in: players), m.confidence == .exact {
                    doc.games[g].goalDetails[d].scorerID = m.playerID
                }
                if goal.assistID == nil, !goal.assist.isEmpty,
                   let m = PlayerLinker.match(goal.assist, in: players), m.confidence == .exact {
                    doc.games[g].goalDetails[d].assistID = m.playerID
                }
            }
        }
    }

    // MARK: - Carry-over

    /// Creates the per-season entry that preserves hand-entered figures.
    ///
    /// Without this, switching to derived stats is a visible downgrade: a team
    /// that entered 40 goals but logged 12 would watch every player's number
    /// collapse. Carry-over absorbs the difference so a displayed total is always
    /// `max(entered, derived)`.
    ///
    /// Only runs where no entry exists yet, which is what makes it idempotent.
    private static func seedCarryOver(_ doc: inout TeamDocument) {
        guard let seasonID = doc.currentSeasonID else { return }
        let derived = TeamStatsCalculator.derivedTotals(for: doc)
        let existing = Set(doc.seasonEntries.filter { $0.seasonID == seasonID }.map(\.playerID))

        for player in doc.players where !existing.contains(player.id) {
            let d = derived[player.id] ?? (goals: 0, assists: 0)
            let carryGoals = max(0, player.goals - d.goals)
            let carryAssists = max(0, player.assists - d.assists)
            // Nothing to preserve and nothing hand-entered — skip, so a clean team
            // doesn't accumulate empty rows.
            if carryGoals == 0, carryAssists == 0, player.bonusPoints == 0, player.goalkeeperStats == nil {
                continue
            }
            doc.seasonEntries.append(
                PlayerSeasonEntry(
                    seasonID: seasonID,
                    playerID: player.id,
                    bonusPoints: player.bonusPoints,
                    goalkeeper: player.goalkeeperStats,
                    carryOverGoals: carryGoals,
                    carryOverAssists: carryAssists
                )
            )
        }
    }
}
