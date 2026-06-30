import Foundation

final class LocalCache {

    static let shared = LocalCache()

    private init() {}

    func saveLineup(_ players: [APIFootballPlayer], matchID: String) {
        let encoder = JSONEncoder()

        if let data = try? encoder.encode(players) {
            let url = getURL(for: matchID)
            try? data.write(to: url)
        }
    }

    func loadLineup(matchID: String) -> [APIFootballPlayer]? {
        let url = getURL(for: matchID)

        guard let data = try? Data(contentsOf: url) else { return nil }

        return try? JSONDecoder().decode([APIFootballPlayer].self, from: data)
    }

    private func getURL(for id: String) -> URL {
        FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("\(id).json")
    }
}
