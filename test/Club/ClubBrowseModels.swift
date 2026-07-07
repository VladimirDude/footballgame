import Foundation

enum PositionGroup: String, CaseIterable, Identifiable {
    case goalkeepers = "Goalkeepers"
    case defenders = "Defenders"
    case midfielders = "Midfielders"
    case forwards = "Forwards"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .goalkeepers: "hand.raised.fill"
        case .defenders: "shield.fill"
        case .midfielders: "circle.grid.2x2.fill"
        case .forwards: "bolt.fill"
        }
    }

    static func from(position: String) -> PositionGroup {
        let lower = position.lowercased()
        if lower.contains("goalkeeper") || lower == "gk" {
            return .goalkeepers
        }
        if lower.contains("back") || lower.contains("defender") {
            return .defenders
        }
        if lower.contains("midfield") || lower.contains("midfielder") {
            return .midfielders
        }
        return .forwards
    }
}

struct ClubSummary: Identifiable, Hashable {
    let id: String
    let name: String
    let officialName: String?
    let playerCount: Int
    let squadValue: Int

    var formattedSquadValue: String {
        MarketValueFormatter.format(squadValue)
    }
}

struct PlayerDetail: Identifiable, Hashable {
    let id: String
    let name: String
    let clubID: String
    let clubName: String
    let position: String
    let positionGroup: PositionGroup
    let marketValue: Int
    let nationalities: [String]
    let squadRank: Int
    let squadSize: Int
    let hasPortrait: Bool

    var formattedMarketValue: String {
        MarketValueFormatter.format(marketValue)
    }
}

enum MarketValueFormatter {
    static func format(_ value: Int) -> String {
        if value >= 1_000_000 {
            return "€\(value / 1_000_000)M"
        }
        if value >= 1_000 {
            return "€\(value / 1_000)K"
        }
        return "€\(value)"
    }
}
