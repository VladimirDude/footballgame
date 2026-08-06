import Foundation
import UIKit

// MARK: - App Configuration

/// Team-management role. The active selection now lives as observable state on
/// `TeamStore.isAdmin` (toggled from the toolbar menu in `MyTeamView`).
enum AppRole: String, CaseIterable {
    case admin = "Admin"
    case user = "User"
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

struct GoalkeeperStats: Equatable {
    var matchesAttended: Int
    var goalsConceded: Int
    var cleanSheets: Int

    var rating: Double {
        guard matchesAttended > 0 else { return 0 }
        return Double(cleanSheets) / Double(matchesAttended) * 10.0
    }
}

// MARK: - Coach Info

struct CoachInfo: Equatable {
    var specialty: String
    var tactics: String
    var experience: String
    var philosophy: String
}

// MARK: - TeamPlayer

struct TeamPlayer: Identifiable, Equatable {
    /// Stable across launches as of snapshot v2. Pre-v2 snapshots carried no ids,
    /// so one is minted during migration and persisted from then on — everything
    /// keyed by player (season stats, tactics slots) depends on that.
    let id: UUID
    var name: String
    var role: PlayerRole
    var goals: Int
    var assists: Int
    var bonusPoints: Double
    var goalkeeperStats: GoalkeeperStats?
    var coachInfo: CoachInfo?
    var photo: UIImage?
    /// Stable relative key of this player's photo in cloud storage (e.g.
    /// "players/UUID.jpg"). Travels in the synced payload so team members can
    /// download the same photo. `nil` until an admin uploads one.
    var photoPath: String?
    /// Pitch position ("GK", "CB", "ST"…). Unused today; persisted so the tactics
    /// board can place players without a second schema migration.
    var position: String?

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
        photo: UIImage? = nil,
        photoPath: String? = nil,
        position: String? = nil
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
        self.photoPath = photoPath
        self.position = position
    }

    /// Compares persisted state only. `photo` is a hydrated side-car image, not
    /// part of the snapshot, and `UIImage` identity would make every hydration
    /// look like an edit and trigger a pointless save.
    static func == (lhs: TeamPlayer, rhs: TeamPlayer) -> Bool {
        lhs.id == rhs.id
            && lhs.name == rhs.name
            && lhs.role == rhs.role
            && lhs.goals == rhs.goals
            && lhs.assists == rhs.assists
            && lhs.bonusPoints == rhs.bonusPoints
            && lhs.goalkeeperStats == rhs.goalkeeperStats
            && lhs.coachInfo == rhs.coachInfo
            && lhs.photoPath == rhs.photoPath
            && lhs.position == rhs.position
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
