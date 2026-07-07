import Foundation

struct PlayerSearchFilters: Equatable {
    var clubID: String?
    var league: String?
    var positionGroup: PositionGroup?
    var nationality: String?

    var isActive: Bool {
        clubID != nil || league != nil || positionGroup != nil || nationality != nil
    }

    mutating func clear() {
        clubID = nil
        league = nil
        positionGroup = nil
        nationality = nil
    }
}
