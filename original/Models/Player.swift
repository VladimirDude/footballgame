import Foundation
import UIKit

// MARK: - App Configuration

enum AppRole: String, CaseIterable {
    case admin = "Admin"
    case user = "User"
}

struct AppConfig {
    static var currentRole: AppRole = .user
    static var isAdmin: Bool { currentRole == .admin }
}

// MARK: - Player Role

enum PlayerRole: String, CaseIterable, Identifiable {
    case player = "Player"
    case goalkeeper = "Goalkeeper"
    case coach = "Coach"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .player:      return "figure.run"
        case .goalkeeper:  return "hand.raised.fill"
        case .coach:       return "person.badge.clock.fill"
        }
    }
}

// MARK: - Goalkeeper Stats

struct GoalkeeperStats {
    var matchesAttended: Int
    var goalsConceded: Int
    var cleanSheets: Int

    var rating: Double {
        guard matchesAttended > 0 else { return 0 }
        return Double(cleanSheets) / Double(matchesAttended) * 10.0
    }
}

// MARK: - Coach Info

struct CoachInfo {
    var specialty: String
    var tactics: String
    var experience: String
    var philosophy: String
}

// MARK: - Player

struct Player: Identifiable {
    let id: UUID
    var name: String
    var role: PlayerRole
    var goals: Int
    var assists: Int
    var bonusPoints: Double
    var goalkeeperStats: GoalkeeperStats?
    var coachInfo: CoachInfo?
    var photo: UIImage?

    var total: Int { goals + assists }
    var totalWithBonus: Double { Double(total) + bonusPoints }

    init(
        id: UUID = UUID(),
        name: String,
        role: PlayerRole = .player,
        goals: Int = 0,
        assists: Int = 0,
        bonusPoints: Double = 0,
        goalkeeperStats: GoalkeeperStats? = nil,
        coachInfo: CoachInfo? = nil,
        photo: UIImage? = nil
    ) {
        self.id = id
        self.name = name
        self.role = role
        self.goals = goals
        self.assists = assists
        self.bonusPoints = bonusPoints
        self.goalkeeperStats = goalkeeperStats
        self.coachInfo = coachInfo
        self.photo = photo
    }
}

// MARK: - Sort & Filter

enum SortOption: String, CaseIterable, Identifiable {
    case total = "Total"
    case totalWithBonus = "Total + Bonus"
    var id: String { rawValue }
}

enum FilterOption: String, CaseIterable, Identifiable {
    case all = "All"
    case players = "Players"
    case goalkeepers = "Goalkeepers"
    case coaches = "Coaches"
    var id: String { rawValue }

    var role: PlayerRole? {
        switch self {
        case .all:         return nil
        case .players:     return .player
        case .goalkeepers: return .goalkeeper
        case .coaches:     return .coach
        }
    }
}
