import Foundation

struct ClubSquadPlayer: Codable {
    let id: String
    let name: String
    let image: String?
    let position: String
    let marketValue: Int?
    let nationality: [String]
    /// ISO date `yyyy-MM-dd` when known.
    let dateOfBirth: String?
    /// `left` / `right` / `both`.
    let foot: String?
    let heightCm: Int?
    let highestMarketValue: Int?
    let countryOfBirth: String?

    init(
        id: String,
        name: String,
        image: String?,
        position: String,
        marketValue: Int?,
        nationality: [String],
        dateOfBirth: String? = nil,
        foot: String? = nil,
        heightCm: Int? = nil,
        highestMarketValue: Int? = nil,
        countryOfBirth: String? = nil
    ) {
        self.id = id
        self.name = name
        self.image = image
        self.position = position
        self.marketValue = marketValue
        self.nationality = nationality
        self.dateOfBirth = dateOfBirth
        self.foot = foot
        self.heightCm = heightCm
        self.highestMarketValue = highestMarketValue
        self.countryOfBirth = countryOfBirth
    }
}

struct FormationSlot: Identifiable, Hashable {
    let id: String
    let role: String
    let flag: String
    let playerName: String
    var showsClub: Bool = false
}

struct GameRound {
    let clubID: String
    let clubName: String
    let officialName: String?
    let aliases: [String]
    let formation: [[FormationSlot]]
}
