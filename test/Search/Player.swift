import Foundation

struct Player: Identifiable, Hashable {
    let id: String
    let name: String
    let clubID: String
    let club: String
    let position: String
    let marketValue: String
    let marketValueRaw: Int
    let nationalities: [String]
}

extension Player {
    init(detail: PlayerDetail) {
        self.init(
            id: detail.id,
            name: detail.name,
            clubID: detail.clubID,
            club: detail.clubName,
            position: detail.position,
            marketValue: detail.formattedMarketValue,
            marketValueRaw: detail.marketValue,
            nationalities: detail.nationalities
        )
    }
}
