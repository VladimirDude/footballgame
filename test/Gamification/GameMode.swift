import Foundation

/// Stable identifier for every scored activity, used as the key for per-mode
/// progress. Distinct from `GameTab` (which is UI-only) so progress survives UI
/// changes and can include non-tab activities (daily, predictor).
enum GameMode: String, Codable, CaseIterable, Sendable {
    case guessClub
    case guessNation
    case guessPlayer
    case higherLower
    case guessLeague
    case daily
    case predictor

    /// The modes that count toward "play every game" achievements.
    static let coreGames: [GameMode] = [.guessClub, .guessNation, .guessPlayer, .higherLower, .guessLeague]

    var displayName: String {
        switch self {
        case .guessClub: "Guess the Club"
        case .guessNation: "Guess the Nation"
        case .guessPlayer: "Guess the Player"
        case .higherLower: "Higher or Lower"
        case .guessLeague: "Guess the League"
        case .daily: "Daily Challenge"
        case .predictor: "Predictor"
        }
    }

    var icon: String {
        switch self {
        case .guessClub: "shield.lefthalf.filled"
        case .guessNation: "flag.fill"
        case .guessPlayer: "person.crop.circle.fill"
        case .higherLower: "arrow.up.arrow.down.circle.fill"
        case .guessLeague: "trophy.fill"
        case .daily: "calendar.badge.clock"
        case .predictor: "play.circle.fill"
        }
    }
}
