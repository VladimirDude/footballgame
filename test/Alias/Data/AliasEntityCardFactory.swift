import Foundation

/// Generates Alias cards for **players, clubs and national teams** straight from
/// the offline club database. The point of an Alias card is a good *word* plus the
/// *forbidden words* that would give it away — both are derived here:
///
/// - Player → forbidden: club, league, nationality, position (+ synonyms).
/// - Club   → forbidden: league, country, official-name tokens, its two star players.
/// - Nation → forbidden: confederation/continent, its two star players.
///
/// Difficulty is derived from market value / squad strength so that famous, easy-to-
/// explain entities land in Easy and obscure ones in Hard/Expert.
struct AliasEntityCardFactory {
    let clubs: [BundledClub]
    let leagueByClubID: [String: String]

    init(store: ClubDataStore = .shared) {
        self.clubs = store.allClubs
        self.leagueByClubID = store.leagueIndex
    }

    init(clubs: [BundledClub], leagueByClubID: [String: String]) {
        self.clubs = clubs
        self.leagueByClubID = leagueByClubID
    }

    func makeCards() -> [AliasCard] {
        makePlayerCards() + makeClubCards() + makeNationCards()
    }

    // MARK: - Players

    /// Only players with a market value are used (keeps the pool to recognizable
    /// names). Value thresholds set the difficulty tier.
    func makePlayerCards() -> [AliasCard] {
        var cards: [AliasCard] = []
        for club in clubs {
            let league = leagueByClubID[club.id]
            for player in club.players {
                guard let value = player.marketValue, value >= 1_000_000 else { continue }
                var forbidden: [String] = [club.name]
                if let league { forbidden.append(league) }
                forbidden.append(contentsOf: player.nationality)
                forbidden.append(contentsOf: Self.positionForbidden(player.position))
                cards.append(
                    AliasCard(
                        id: "player_\(player.id)",
                        word: player.name,
                        category: .players,
                        difficulty: Self.playerDifficulty(marketValue: value),
                        forbiddenWords: Self.dedupe(forbidden, excluding: player.name),
                        hints: Self.playerHints(player, club: club, league: league)
                    )
                )
            }
        }
        return cards
    }

    static func playerDifficulty(marketValue: Int) -> AliasDifficulty {
        switch marketValue {
        case 50_000_000...: .easy
        case 20_000_000..<50_000_000: .medium
        case 5_000_000..<20_000_000: .hard
        default: .expert
        }
    }

    private static func playerHints(_ player: ClubSquadPlayer, club: BundledClub, league: String?) -> [String] {
        var hints = [player.position]
        if let nat = player.nationality.first { hints.append("Plays internationally for \(nat)") }
        if let league { hints.append("Plays in the \(league)") }
        return hints
    }

    // MARK: - Clubs

    func makeClubCards() -> [AliasCard] {
        clubs.compactMap { club in
            guard !club.players.isEmpty else { return nil }
            let league = leagueByClubID[club.id]
            let stars = topPlayers(in: club, count: 2).map(\.name)
            var forbidden: [String] = []
            if let league { forbidden.append(league) }
            if let league, let country = Self.leagueCountry[league] { forbidden.append(country) }
            if let official = club.officialName { forbidden.append(contentsOf: Self.nameTokens(official)) }
            forbidden.append(contentsOf: stars)
            var hints: [String] = []
            if let league { hints.append("Plays in the \(league)") }
            if let star = stars.first { hints.append("One of their stars: \(star)") }
            return AliasCard(
                id: "club_\(club.id)",
                word: club.name,
                category: .clubs,
                difficulty: Self.clubDifficulty(club, league: league),
                forbiddenWords: Self.dedupe(forbidden, excluding: club.name),
                hints: hints
            )
        }
    }

    static let bigLeagues: Set<String> = [
        "Premier League", "LaLiga", "La Liga", "Bundesliga", "Serie A", "Ligue 1"
    ]

    static let leagueCountry: [String: String] = [
        "Premier League": "England", "LaLiga": "Spain", "La Liga": "Spain",
        "Bundesliga": "Germany", "Serie A": "Italy", "Ligue 1": "France",
        "Eredivisie": "Netherlands", "Primeira Liga": "Portugal",
        "Süper Lig": "Turkey", "Serie A Brazil": "Brazil"
    ]

    static func clubDifficulty(_ club: BundledClub, league: String?) -> AliasDifficulty {
        let squadValue = club.players.compactMap(\.marketValue).reduce(0, +)
        let isBig = league.map { bigLeagues.contains($0) } ?? false
        switch (isBig, squadValue) {
        case (true, 400_000_000...): return .easy
        case (true, _): return .medium
        case (false, 150_000_000...): return .medium
        default: return .hard
        }
    }

    // MARK: - National teams

    /// Aggregates players by nationality across all clubs; a nation qualifies once
    /// it has enough players in the database to feel real.
    func makeNationCards() -> [AliasCard] {
        var byNation: [String: [ClubSquadPlayer]] = [:]
        for club in clubs {
            for player in club.players {
                for nation in player.nationality {
                    byNation[nation, default: []].append(player)
                }
            }
        }
        return byNation.compactMap { nation, players in
            guard players.count >= 11 else { return nil }
            let stars = players
                .sorted { ($0.marketValue ?? 0) > ($1.marketValue ?? 0) }
                .prefix(2).map(\.name)
            var forbidden: [String] = []
            if let confed = Self.confederation[nation] { forbidden.append(confed) }
            forbidden.append(contentsOf: stars)
            var hints: [String] = []
            if let confed = Self.confederation[nation] { hints.append("Competes in \(confed)") }
            if let star = stars.first { hints.append("A famous player from here: \(star)") }
            return AliasCard(
                id: "nation_\(nation.lowercased().replacingOccurrences(of: " ", with: "_"))",
                word: nation,
                category: .nationalTeams,
                difficulty: Self.nationDifficulty(nation, playerCount: players.count),
                forbiddenWords: Self.dedupe(forbidden, excluding: nation),
                hints: hints
            )
        }
    }

    static let majorNations: Set<String> = [
        "Brazil", "Argentina", "France", "Germany", "Spain", "England",
        "Italy", "Portugal", "Netherlands", "Belgium"
    ]

    static let confederation: [String: String] = {
        var map: [String: String] = [:]
        let uefa = ["France", "Germany", "Spain", "England", "Italy", "Portugal",
                    "Netherlands", "Belgium", "Croatia", "Poland", "Denmark",
                    "Switzerland", "Austria", "Serbia", "Turkey", "Scotland",
                    "Ukraine", "Sweden", "Norway", "Czech Republic"]
        let conmebol = ["Brazil", "Argentina", "Uruguay", "Colombia", "Chile",
                        "Peru", "Ecuador", "Paraguay", "Bolivia", "Venezuela"]
        let concacaf = ["United States", "Mexico", "Canada", "Costa Rica", "Jamaica"]
        let caf = ["Nigeria", "Senegal", "Egypt", "Morocco", "Ghana", "Cameroon",
                   "Ivory Coast", "Algeria", "Tunisia", "Mali"]
        let afc = ["Japan", "South Korea", "Australia", "Iran", "Saudi Arabia", "Qatar"]
        for n in uefa { map[n] = "UEFA (Europe)" }
        for n in conmebol { map[n] = "CONMEBOL (South America)" }
        for n in concacaf { map[n] = "CONCACAF (North America)" }
        for n in caf { map[n] = "CAF (Africa)" }
        for n in afc { map[n] = "AFC (Asia)" }
        return map
    }()

    static func nationDifficulty(_ nation: String, playerCount: Int) -> AliasDifficulty {
        if majorNations.contains(nation) { return .easy }
        if playerCount >= 40 { return .medium }
        if playerCount >= 20 { return .hard }
        return .expert
    }

    // MARK: - Helpers

    private func topPlayers(in club: BundledClub, count: Int) -> [ClubSquadPlayer] {
        club.players
            .sorted { ($0.marketValue ?? 0) > ($1.marketValue ?? 0) }
            .prefix(count)
            .map { $0 }
    }

    /// Turns a raw position ("Centre-Back", "Right Winger") into the giveaway words
    /// the explainer must avoid.
    static func positionForbidden(_ position: String) -> [String] {
        let p = position.lowercased()
        var words: [String] = [position]
        if p.contains("keeper") { words.append("goalkeeper") }
        if p.contains("back") || p.contains("defen") { words.append("defender") }
        if p.contains("midfield") { words.append("midfielder") }
        if p.contains("wing") { words.append("winger") }
        if p.contains("forward") || p.contains("striker") || p.contains("attack") {
            words.append(contentsOf: ["forward", "striker", "attacker"])
        }
        return words
    }

    /// Splits an official club name into meaningful tokens (drops noise like "FC").
    static func nameTokens(_ name: String) -> [String] {
        let noise: Set<String> = ["fc", "cf", "sc", "ac", "afc", "1", "the", "club", "de", "of"]
        return name
            .components(separatedBy: CharacterSet(charactersIn: " .-"))
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { $0.count > 1 && !noise.contains($0.lowercased()) }
    }

    private static func dedupe(_ words: [String], excluding word: String) -> [String] {
        var seen = Set<String>()
        var result: [String] = []
        let wordLower = word.lowercased()
        for w in words {
            let key = w.lowercased()
            guard !w.isEmpty, key != wordLower, !seen.contains(key) else { continue }
            seen.insert(key)
            result.append(w)
        }
        return result
    }
}
