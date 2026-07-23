import Foundation
import UIKit

/// Exports and imports all team data as JSON.
enum DataExporter {

    struct ExportData: Codable {
        var players: [PlayerDTO]
        var games: [GameDTO]
        var exportDate: Date
    }

    struct PlayerDTO: Codable {
        var name: String
        var role: String
        var goals: Int
        var assists: Int
        var bonusPoints: Double
        var gkAttended: Int?
        var gkConceded: Int?
        var gkCleanSheets: Int?
        var coachSpecialty: String?
        var coachTactics: String?
        var coachExperience: String?
        var coachPhilosophy: String?
        var photoPath: String?
    }

    struct GameDTO: Codable {
        var date: Date
        var opponent: String
        var goalsFor: Int
        var goalsAgainst: Int
        var scorers: [String]
        var goals: [GoalDTO]
        var mediaLinks: [MediaLinkDTO]
    }

    struct GoalDTO: Codable {
        var time: String
        var scorer: String
        var assist: String
        var isOpponent: Bool
    }

    struct MediaLinkDTO: Codable {
        var title: String
        var urlString: String
        var type: String
    }

    // MARK: - Export

    static func export(players: [TeamPlayer], games: [TeamGame]) -> Data? {
        let playerDTOs = players.map { p -> PlayerDTO in
            PlayerDTO(
                name: p.name, role: p.role.rawValue,
                goals: p.goals, assists: p.assists, bonusPoints: p.bonusPoints,
                gkAttended: p.goalkeeperStats?.matchesAttended,
                gkConceded: p.goalkeeperStats?.goalsConceded,
                gkCleanSheets: p.goalkeeperStats?.cleanSheets,
                coachSpecialty: p.coachInfo?.specialty,
                coachTactics: p.coachInfo?.tactics,
                coachExperience: p.coachInfo?.experience,
                coachPhilosophy: p.coachInfo?.philosophy,
                photoPath: p.photoPath
            )
        }

        let gameDTOs = games.map { g -> GameDTO in
            GameDTO(
                date: g.date, opponent: g.opponent,
                goalsFor: g.goalsFor, goalsAgainst: g.goalsAgainst,
                scorers: g.scorers,
                goals: g.goalDetails.map { GoalDTO(time: $0.time, scorer: $0.scorer, assist: $0.assist, isOpponent: $0.isOpponent) },
                mediaLinks: g.mediaLinks.map { MediaLinkDTO(title: $0.title, urlString: $0.urlString, type: $0.type.rawValue) }
            )
        }

        let data = ExportData(players: playerDTOs, games: gameDTOs, exportDate: Date())
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try? encoder.encode(data)
    }

    // MARK: - Import

    static func importData(_ data: Data) -> (players: [TeamPlayer], games: [TeamGame])? {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let exported = try? decoder.decode(ExportData.self, from: data) else { return nil }

        let players = exported.players.map { dto -> TeamPlayer in
            let role = PlayerRole(rawValue: dto.role) ?? .player
            var p = TeamPlayer(name: dto.name, role: role, goals: dto.goals, assists: dto.assists, bonusPoints: dto.bonusPoints, photoPath: dto.photoPath)
            if role == .goalkeeper, let att = dto.gkAttended, let con = dto.gkConceded, let cs = dto.gkCleanSheets {
                p.goalkeeperStats = GoalkeeperStats(matchesAttended: att, goalsConceded: con, cleanSheets: cs)
            }
            if role == .coach {
                p.coachInfo = CoachInfo(specialty: dto.coachSpecialty ?? "", tactics: dto.coachTactics ?? "",
                                       experience: dto.coachExperience ?? "", philosophy: dto.coachPhilosophy ?? "")
            }
            return p
        }

        let games = exported.games.map { dto -> TeamGame in
            TeamGame(
                date: dto.date, opponent: dto.opponent,
                goalsFor: dto.goalsFor, goalsAgainst: dto.goalsAgainst,
                scorers: dto.scorers,
                goalDetails: dto.goals.map { GoalDetail(time: $0.time, scorer: $0.scorer, assist: $0.assist, isOpponent: $0.isOpponent) },
                mediaLinks: dto.mediaLinks.map { MediaLink(title: $0.title, urlString: $0.urlString, type: MediaType(rawValue: $0.type) ?? .video) }
            )
        }

        return (players, games)
    }

    // MARK: - File URL

    static var documentsURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    static var saveURL: URL {
        documentsURL.appendingPathComponent("cognaize_team_data.json")
    }

    static func saveToDisk(players: [TeamPlayer], games: [TeamGame]) -> Bool {
        guard let data = export(players: players, games: games) else { return false }
        do { try data.write(to: saveURL); return true } catch { return false }
    }

    static func loadFromDisk() -> (players: [TeamPlayer], games: [TeamGame])? {
        guard let data = try? Data(contentsOf: saveURL) else { return nil }
        return importData(data)
    }
}
