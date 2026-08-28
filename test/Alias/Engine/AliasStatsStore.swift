import Foundation

/// Lightweight persistence for Alias results — games played and best score — kept
/// separate from the solo-game `GameProgressStore` because Alias is team-based.
/// Backed by a single JSON blob in `UserDefaults`.
final class AliasStatsStore {
    static let shared = AliasStatsStore()

    struct Stats: Codable, Equatable {
        var gamesPlayed = 0
        var bestTeamScore = 0
        var totalCorrect = 0
    }

    private let defaults: UserDefaults
    private let key = "aliasStatsV1"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func current() -> Stats {
        guard let data = defaults.data(forKey: key),
              let stats = try? JSONDecoder().decode(Stats.self, from: data) else {
            return Stats()
        }
        return stats
    }

    func record(winningScore: Int, correctCount: Int) {
        var stats = current()
        stats.gamesPlayed += 1
        stats.bestTeamScore = max(stats.bestTeamScore, winningScore)
        stats.totalCorrect += correctCount
        if let data = try? JSONEncoder().encode(stats) {
            defaults.set(data, forKey: key)
        }
    }

    func reset() {
        defaults.removeObject(forKey: key)
    }
}
