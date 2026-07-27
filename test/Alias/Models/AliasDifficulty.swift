import Foundation

/// Difficulty tiers, ordered so setup can offer a min…max range filter.
enum AliasDifficulty: String, Codable, CaseIterable, Identifiable, Comparable {
    case easy
    case medium
    case hard
    case expert

    var id: String { rawValue }

    private var order: Int {
        switch self {
        case .easy: 0
        case .medium: 1
        case .hard: 2
        case .expert: 3
        }
    }

    static func < (lhs: AliasDifficulty, rhs: AliasDifficulty) -> Bool {
        lhs.order < rhs.order
    }

    var displayName: String {
        switch self {
        case .easy: "Easy"
        case .medium: "Medium"
        case .hard: "Hard"
        case .expert: "Expert"
        }
    }
}
