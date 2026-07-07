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

    func searchPlayers(_ query: String) -> [Player] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        let needle = trimmed.folding(options: .diacriticInsensitive, locale: .current).lowercased()

        return allPlayers
            .filter {
                $0.player.name.folding(options: .diacriticInsensitive, locale: .current).lowercased().contains(needle)
            }
            .prefix(50)
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
