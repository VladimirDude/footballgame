import Foundation

final class APIFootballService {

    private let apiKey = "f2278951eea86eab0bbd9fd7f5d92352"
    private let baseURL = "https://v3.football.api-sports.io"

    func getLineups(fixtureID: Int) async throws -> [APIFootballPlayer] {

        let url = URL(string: "\(baseURL)/fixtures/lineups?fixture=\(fixtureID)")!

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(apiKey, forHTTPHeaderField: "x-apisports-key")

        let (data, _) = try await URLSession.shared.data(for: request)

        let decoded = try JSONDecoder().decode(LineupResponse.self, from: data)

        return decoded.response.flatMap { team in
            team.startXI.map { wrapper in
                APIFootballPlayer(
                    id: wrapper.player.id,
                    name: wrapper.player.name,
                    number: wrapper.player.number,
                    pos: wrapper.player.pos
                )
            }
        }
    }
}
