import Foundation

struct ClubProfileSummary: Codable {
    let id: String
    let name: String
    let officialName: String?
}

struct ClubPlayersResponse: Codable {
    let id: String
    let players: [ClubSquadPlayer]
}

struct ClubSquadPlayer: Codable, Identifiable {
    let id: String
    let name: String
    let position: String
    let nationality: [String]
    let marketValue: Int?
}

struct FormationSlot: Identifiable {
    let id = UUID()
    let role: String
    let flag: String
    let playerName: String
}

struct GameRound {
    let clubID: String
    let clubName: String
    let officialName: String?
    let aliases: [String]
    let formation: [[FormationSlot]]
}
