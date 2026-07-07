import Foundation

// MARK: - API Response

struct LineupResponse: Codable {
    let response: [LineupTeam]
}

struct LineupTeam: Codable {
    let startXI: [APIFootballPlayerWrapper]
}

// MARK: - Wrapper (API structure)

struct APIFootballPlayerWrapper: Codable {
    let player: APIPlayerRaw
}

// MARK: - Raw API Player

struct APIPlayerRaw: Codable {
    let id: Int
    let name: String
    let number: Int?
    let pos: String?
}

// MARK: - App Model (USED IN YOUR UI)

struct APIFootballPlayer: Identifiable, Codable {
    let id: Int
    let name: String
    let number: Int?
    let pos: String?
}
