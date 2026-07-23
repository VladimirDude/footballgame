import Foundation
import UIKit
import Combine

final class TeamStore: ObservableObject {

    @Published var players: [TeamPlayer]
    @Published var games: [TeamGame]
    @Published var sortOption: SortOption = .totalWithBonus
    @Published var filterOption: FilterOption = .all
    @Published var searchText: String = ""
    @Published var teamIcon: UIImage?

    /// Admin/User role. Ported from the legacy global `AppConfig.currentRole`
    /// static into proper observable state so SwiftUI reacts automatically
    /// (no manual `objectWillChange.send()` needed).
    @Published var isAdmin: Bool = false

    // MARK: - Computed

    var filteredPlayers: [TeamPlayer] {
        var result = players
        if let role = filterOption.role { result = result.filter { $0.role == role } }
        if !searchText.isEmpty {
            let q = searchText.lowercased()
            result = result.filter { $0.name.lowercased().contains(q) }
        }
        return sorted(result)
    }

    var leaderboard: [TeamPlayer] {
        Array(sorted(players.filter { $0.role == .player || $0.role == .goalkeeper }).prefix(3))
    }

    var coaches: [TeamPlayer]      { players.filter { $0.role == .coach } }
    var goalkeepers: [TeamPlayer]  { players.filter { $0.role == .goalkeeper } }
    var playerCount: Int       { players.filter { $0.role == .player }.count }
    var goalkeeperCount: Int   { players.filter { $0.role == .goalkeeper }.count }
    var coachCount: Int        { players.filter { $0.role == .coach }.count }
    var totalGoals: Int        { players.reduce(0) { $0 + $1.goals } }
    var totalAssists: Int      { players.reduce(0) { $0 + $1.assists } }

    // MARK: - Init

    init(dataService: TeamDataServiceProtocol = TeamDataService()) {
        self.players = dataService.fetchPlayers()
        self.games = dataService.fetchGames()
    }

    // MARK: - TeamPlayer CRUD

    func addPlayer(_ player: TeamPlayer) {
        players.append(player)
    }

    func removePlayer(id: UUID) {
        players.removeAll { $0.id == id }
    }

    func updatePlayer(id: UUID, goals: Int, assists: Int, bonus: Double) {
        guard let i = players.firstIndex(where: { $0.id == id }) else { return }
        players[i].goals = goals
        players[i].assists = assists
        players[i].bonusPoints = bonus
    }

    func updatePlayerPhoto(id: UUID, photo: UIImage?) {
        guard let i = players.firstIndex(where: { $0.id == id }) else { return }
        players[i].photo = photo
    }

    func updateGoalkeeperStats(id: UUID, attended: Int, conceded: Int, cleanSheets: Int) {
        guard let i = players.firstIndex(where: { $0.id == id }) else { return }
        players[i].goalkeeperStats = GoalkeeperStats(matchesAttended: attended, goalsConceded: conceded, cleanSheets: cleanSheets)
    }

    func updateCoachInfo(id: UUID, info: CoachInfo) {
        guard let i = players.firstIndex(where: { $0.id == id }) else { return }
        players[i].coachInfo = info
    }

    // MARK: - TeamGame CRUD

    func addGame(_ game: TeamGame) {
        games.append(game)
    }

    func removeGame(id: UUID) {
        games.removeAll { $0.id == id }
    }

    func updateGame(_ game: TeamGame) {
        guard let i = games.firstIndex(where: { $0.id == game.id }) else { return }
        games[i] = game
    }

    // MARK: - Sorting

    private func sorted(_ list: [TeamPlayer]) -> [TeamPlayer] {
        switch sortOption {
        case .total:          return list.sorted { $0.total > $1.total }
        case .totalWithBonus: return list.sorted { $0.totalWithBonus > $1.totalWithBonus }
        }
    }
}
