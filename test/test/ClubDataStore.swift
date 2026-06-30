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

    private struct IndexedPlayer {
        let player: ClubSquadPlayer
        let clubName: String
        let clubID: String
    }

    private init() {
        guard
            let url = Bundle.main.url(forResource: "ClubDatabase", withExtension: "json"),
            let data = try? Data(contentsOf: url),
            let decoded = try? JSONDecoder().decode(ClubDatabase.self, from: data)
        else {
            fatalError("ClubDatabase.json missing or invalid — run scripts/fetch_club_database.py")
        }

        database = decoded
        allPlayers = decoded.clubs.flatMap { club in
            club.players.map { player in
                IndexedPlayer(player: player, clubName: club.name, clubID: club.id)
            }
        }
    }

    var clubCount: Int { database.clubs.count }
    var playerCount: Int { allPlayers.count }
    var lastUpdated: String { database.updatedAt }

    func randomGameRound() -> GameRound? {
        guard let club = database.clubs.randomElement() else { return nil }

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
                $0.player.name
                    .folding(options: .diacriticInsensitive, locale: .current)
                    .lowercased()
                    .contains(needle)
            }
            .prefix(50)
            .map { indexed in
                Player(
                    id: indexed.player.id,
                    name: indexed.player.name,
                    club: indexed.clubName,
                    position: indexed.player.position,
                    marketValue: formatMarketValue(indexed.player.marketValue ?? 0),
                    nationalities: indexed.player.nationality
                )
            }
    }

    func playerDetail(id: String) -> Player? {
        guard let indexed = allPlayers.first(where: { $0.player.id == id }) else { return nil }
        return Player(
            id: indexed.player.id,
            name: indexed.player.name,
            club: indexed.clubName,
            position: indexed.player.position,
            marketValue: formatMarketValue(indexed.player.marketValue ?? 0),
            nationalities: indexed.player.nationality
        )
    }

    private func formatMarketValue(_ value: Int) -> String {
        if value >= 1_000_000 {
            return "€\(value / 1_000_000)M"
        } else if value >= 1_000 {
            return "€\(value / 1_000)K"
        } else {
            return "€\(value)"
        }
    }
}
