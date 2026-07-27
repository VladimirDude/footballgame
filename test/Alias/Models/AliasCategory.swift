import Foundation

/// A themed group of Alias cards. Player / club / nation categories are generated
/// from the offline club database; the rest come from the curated language pack.
enum AliasCategory: String, Codable, CaseIterable, Identifiable, Hashable {
    case players
    case clubs
    case nationalTeams
    case terms
    case tactics
    case competitions
    case events

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .players: "Players"
        case .clubs: "Clubs"
        case .nationalTeams: "National Teams"
        case .terms: "Football Terms"
        case .tactics: "Tactics"
        case .competitions: "Competitions"
        case .events: "Events & Moments"
        }
    }

    /// SF Symbol used in the setup / categories UI.
    var icon: String {
        switch self {
        case .players: "person.crop.circle.fill"
        case .clubs: "shield.lefthalf.filled"
        case .nationalTeams: "flag.fill"
        case .terms: "text.book.closed.fill"
        case .tactics: "rectangle.3.group.fill"
        case .competitions: "trophy.fill"
        case .events: "sparkles"
        }
    }

    /// Categories playable without Pro. Everything else needs `.aliasPremiumPacks`.
    /// This is the single free/premium content split for Alias (see `AliasDeckBuilder`).
    static let freeCategories: Set<AliasCategory> = [.players, .terms]

    var isFree: Bool { Self.freeCategories.contains(self) }
}
