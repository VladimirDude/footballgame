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
    let league: String?
    let position: String
    let positionGroup: PositionGroup
    let marketValue: Int
    let highestMarketValue: Int?
    let nationalities: [String]
    let countryOfBirth: String?
    let dateOfBirth: String?
    let foot: String?
    let heightCm: Int?
    let squadRank: Int
    let squadSize: Int
    let hasPortrait: Bool

    var formattedMarketValue: String {
        MarketValueFormatter.format(marketValue)
    }

    var formattedPeakValue: String? {
        guard let highestMarketValue, highestMarketValue > 0 else { return nil }
        return MarketValueFormatter.format(highestMarketValue)
    }

    var age: Int? {
        guard let dateOfBirth,
              let born = Self.dobFormatter.date(from: String(dateOfBirth.prefix(10))) else {
            return nil
        }
        return Calendar.current.dateComponents([.year], from: born, to: Date()).year
    }

    var formattedFoot: String? {
        switch foot?.lowercased() {
        case "left": "Left"
        case "right": "Right"
        case "both": "Both"
        default: nil
        }
    }

    var formattedHeight: String? {
        guard let heightCm, heightCm > 0 else { return nil }
        return "\(heightCm) cm"
    }

    private static let dobFormatter: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(secondsFromGMT: 0)
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()
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
