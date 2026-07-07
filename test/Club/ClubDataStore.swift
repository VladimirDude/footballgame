import Foundation

struct ClubDatabase: Codable {
    let updatedAt: String
    let clubs: [BundledClub]
}

struct BundledClub: Codable, Identifiable {
    let id: String
    let name: String
    let officialName: String?
    let aliases: [String]
    let players: [ClubSquadPlayer]
}

final class ClubDataStore {

    static let shared = ClubDataStore()

    private let database: ClubDatabase
    private let allPlayers: [IndexedPlayer]
    private let clubsByID: [String: BundledClub]
    private let playersByID: [String: IndexedPlayer]
    private let leagueByClubID: [String: String]
    private let knownNationalities: [String]
    private let guessPlayerPool: [GuessPlayerRound]
    private let nationalTeamSquads: [String: [NationalTeamSquadPlayer]]

    var clubCount: Int { database.clubs.count }
    var playerCount: Int { allPlayers.count }

    private struct IndexedPlayer {
        let player: ClubSquadPlayer
        let clubName: String
        let clubID: String
    }

    private init() {
        if
            let url = Bundle.main.url(forResource: "ClubDatabase", withExtension: "json"),
            let data = try? Data(contentsOf: url),
            let decoded = try? JSONDecoder().decode(ClubDatabase.self, from: data)
        {
            database = decoded
        } else {
            database = ClubDatabase(updatedAt: "", clubs: [])
        }

        allPlayers = database.clubs.flatMap { club in
            club.players.map { player in
                IndexedPlayer(player: player, clubName: club.name, clubID: club.id)
            }
        }
        clubsByID = Dictionary(uniqueKeysWithValues: database.clubs.map { ($0.id, $0) })

        var playerLookup: [String: IndexedPlayer] = [:]
        for indexed in allPlayers {
            playerLookup[indexed.player.id] = indexed
        }
        playersByID = playerLookup

        leagueByClubID = Self.loadLeagueIndex()
        var nationalitySet: Set<String> = []
        for indexed in allPlayers {
            for country in indexed.player.nationality {
                nationalitySet.insert(country)
            }
        }
        knownNationalities = nationalitySet.sorted {
            $0.localizedCaseInsensitiveCompare($1) == .orderedAscending
        }

        guessPlayerPool = Self.buildGuessPlayerPool(
            clubs: database.clubs,
            eliteClubNames: GameDifficulty.easy.associatedClubs
        )

        nationalTeamSquads = Self.buildNationalTeamSquads(from: allPlayers)
    }

    private static func buildNationalTeamSquads(
        from players: [IndexedPlayer]
    ) -> [String: [NationalTeamSquadPlayer]] {
        var squads: [String: [NationalTeamSquadPlayer]] = [:]

        for indexed in players {
            guard let nation = indexed.player.nationality.first else { continue }
            let entry = NationalTeamSquadPlayer(
                id: indexed.player.id,
                name: indexed.player.name,
                position: indexed.player.position,
                marketValue: indexed.player.marketValue ?? 0,
                clubName: indexed.clubName,
                nationalities: indexed.player.nationality
            )
            squads[nation, default: []].append(entry)
        }

        return squads
    }

    func randomNationalTeamRound(for difficulty: NationalTeamDifficulty) -> NationalTeamRound? {
        let allowed = difficulty.associatedNations
        let eligible = allowed.compactMap { nation -> (String, [[FormationSlot]])? in
            guard let squad = nationalTeamSquads[nation] else { return nil }
            let formation = FormationBuilder.buildNationalTeam(from: squad)
            guard formation.flatMap({ $0 }).count >= 8 else { return nil }
            return (nation, formation)
        }

        guard let pick = eligible.randomElement() else { return nil }

        return NationalTeamRound(
            nationName: pick.0,
            flag: CountryFlags.flag(for: pick.0),
            aliases: nationalTeamAliases(for: pick.0),
            formation: pick.1
        )
    }

    private func nationalTeamAliases(for nation: String) -> [String] {
        let key = FuzzyMatcher.normalize(nation)
        if let abbrevs = NationalTeamAbbreviations.map[key] {
            return abbrevs
        }
        return []
    }

    private static func buildGuessPlayerPool(
        clubs: [BundledClub],
        eliteClubNames: Set<String>
    ) -> [GuessPlayerRound] {
        let minimumMarketValue = 25_000_000
        let portraitAvailable: (String) -> Bool = { id in
            Bundle.main.url(forResource: id, withExtension: "png") != nil
        }

        var pool: [GuessPlayerRound] = []

        for club in clubs where eliteClubNames.contains(club.name) {
            let ranked = club.players.sorted { ($0.marketValue ?? 0) > ($1.marketValue ?? 0) }
            for (index, player) in ranked.enumerated() {
                let marketValue = player.marketValue ?? 0
                let squadRank = index + 1
                let isStar = marketValue >= minimumMarketValue
                    || (squadRank <= 2 && marketValue >= 15_000_000)

                guard isStar, portraitAvailable(player.id) else { continue }

                pool.append(
                    GuessPlayerRound(
                        id: player.id,
                        playerName: player.name,
                        position: player.position,
                        clubName: club.name,
                        nationalities: player.nationality,
                        marketValue: marketValue
                    )
                )
            }
        }

        return pool.sorted {
            if $0.marketValue == $1.marketValue {
                return $0.playerName.localizedCaseInsensitiveCompare($1.playerName) == .orderedAscending
            }
            return $0.marketValue > $1.marketValue
        }
    }

    func guessPlayerPoolCount() -> Int {
        guessPlayerPool.count
    }

    func randomGuessPlayerRound(excluding excludedIDs: Set<String> = []) -> GuessPlayerRound? {
        let available = guessPlayerPool.filter { !excludedIDs.contains($0.id) }
        return available.randomElement() ?? guessPlayerPool.randomElement()
    }

    private static func loadLeagueIndex() -> [String: String] {
        guard
            let url = Bundle.main.url(forResource: "ClubLeagueIndex", withExtension: "json"),
            let data = try? Data(contentsOf: url),
            let decoded = try? JSONDecoder().decode([String: String].self, from: data)
        else {
            return [:]
        }
        return decoded
    }

    func allLeagues() -> [String] {
        Array(Set(leagueByClubID.values)).sorted {
            $0.localizedCaseInsensitiveCompare($1) == .orderedAscending
        }
    }

    func allNationalities() -> [String] {
        knownNationalities
    }

    func league(forClubID clubID: String) -> String? {
        leagueByClubID[clubID]
    }

    func allClubSummaries() -> [ClubSummary] {
        database.clubs
            .map { club in
                ClubSummary(
                    id: club.id,
                    name: club.name,
                    officialName: club.officialName,
                    playerCount: club.players.count,
                    squadValue: club.players.reduce(0) { $0 + ($1.marketValue ?? 0) }
                )
            }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    func searchClubs(_ query: String) -> [ClubSummary] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return allClubSummaries() }

        let needle = trimmed.folding(options: .diacriticInsensitive, locale: .current).lowercased()
        return allClubSummaries().filter { club in
            club.name.folding(options: .diacriticInsensitive, locale: .current).lowercased().contains(needle)
                || (club.officialName?.folding(options: .diacriticInsensitive, locale: .current).lowercased().contains(needle) ?? false)
        }
    }

    func club(id: String) -> BundledClub? {
        clubsByID[id]
    }

    func groupedPlayers(for clubID: String) -> [(PositionGroup, [ClubSquadPlayer])] {
        guard let club = clubsByID[clubID] else { return [] }

        let sortedPlayers = club.players.sorted { ($0.marketValue ?? 0) > ($1.marketValue ?? 0) }
        var grouped: [PositionGroup: [ClubSquadPlayer]] = [:]

        for player in sortedPlayers {
            let group = PositionGroup.from(position: player.position)
            grouped[group, default: []].append(player)
        }

        return PositionGroup.allCases.compactMap { group in
            guard let players = grouped[group], !players.isEmpty else { return nil }
            return (group, players)
        }
    }

    func playerDetail(id: String) -> PlayerDetail? {
        guard let indexed = playersByID[id], let club = clubsByID[indexed.clubID] else { return nil }

        let rankedSquad = club.players.sorted { ($0.marketValue ?? 0) > ($1.marketValue ?? 0) }
        let squadRank = (rankedSquad.firstIndex { $0.id == id } ?? 0) + 1
        let hasPortrait = Bundle.main.url(forResource: id, withExtension: "png") != nil

        return PlayerDetail(
            id: indexed.player.id,
            name: indexed.player.name,
            clubID: indexed.clubID,
            clubName: indexed.clubName,
            position: indexed.player.position,
            positionGroup: PositionGroup.from(position: indexed.player.position),
            marketValue: indexed.player.marketValue ?? 0,
            nationalities: indexed.player.nationality,
            squadRank: squadRank,
            squadSize: club.players.count,
            hasPortrait: hasPortrait
        )
    }

    func randomGameRound(for difficulty: GameDifficulty) -> GameRound? {
        let allowedClubs = difficulty.associatedClubs
        let eligibleClubs = database.clubs.filter { club in
            guard allowedClubs.contains(club.name) else { return false }
            let formation = FormationBuilder.build(from: club.players)
            return formation.flatMap { $0 }.count >= 8
        }

        guard let club = eligibleClubs.randomElement() else { return nil }

        let formation = FormationBuilder.build(from: club.players)
        guard formation.flatMap({ $0 }).count >= 8 else { return nil }

        return GameRound(
            clubID: club.id,
            clubName: club.name,
            officialName: club.officialName,
            aliases: club.aliases,
            formation: formation
        )
    }

    func searchPlayers(_ query: String, filters: PlayerSearchFilters = PlayerSearchFilters()) -> [Player] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let hasQuery = trimmed.count >= 2
        guard hasQuery || filters.isActive else { return [] }

        let needle = trimmed.folding(options: .diacriticInsensitive, locale: .current).lowercased()

        return allPlayers
            .filter { indexed in
                if hasQuery {
                    let name = indexed.player.name
                        .folding(options: .diacriticInsensitive, locale: .current)
                        .lowercased()
                    guard name.contains(needle) else { return false }
                }

                if let clubID = filters.clubID, indexed.clubID != clubID {
                    return false
                }

                if let league = filters.league {
                    guard leagueByClubID[indexed.clubID] == league else { return false }
                }

                if let group = filters.positionGroup {
                    guard PositionGroup.from(position: indexed.player.position) == group else { return false }
                }

                if let nationality = filters.nationality {
                    let matches = indexed.player.nationality.contains {
                        $0.compare(nationality, options: .caseInsensitive) == .orderedSame
                    }
                    guard matches else { return false }
                }

                return true
            }
            .prefix(filters.isActive && !hasQuery ? 100 : 50)
            .map { indexed in
                Player(
                    id: indexed.player.id,
                    name: indexed.player.name,
                    clubID: indexed.clubID,
                    club: indexed.clubName,
                    position: indexed.player.position,
                    marketValue: MarketValueFormatter.format(indexed.player.marketValue ?? 0),
                    marketValueRaw: indexed.player.marketValue ?? 0,
                    nationalities: indexed.player.nationality
                )
            }
    }

    func fetchHigherOrLowerPool() -> [HLPlayer] {
        allPlayers.map { indexed in
            HLPlayer(
                id: indexed.player.id,
                name: indexed.player.name,
                clubName: indexed.clubName,
                marketValue: indexed.player.marketValue ?? 0
            )
        }
    }
}
