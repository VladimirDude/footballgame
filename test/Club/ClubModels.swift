import Foundation

struct ClubSquadPlayer: Codable {
    let id: String
    let name: String
    let image: String?
    let position: String
    let marketValue: Int?
    let nationality: [String]
}

struct FormationSlot: Identifiable, Hashable {
    let id: String
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
