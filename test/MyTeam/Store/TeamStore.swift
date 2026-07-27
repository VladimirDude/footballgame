import Foundation
import UIKit
import Combine

/// The device's relationship to the current team.
enum TeamMode: String, Codable, Identifiable {
    case user    // local, editable, not shared
    case admin   // live/cloud-shared, editable (Pro)
    case viewer  // joined via code, read-only

    var id: String { rawValue }
}

final class TeamStore: ObservableObject {

    @Published var players: [TeamPlayer]
    @Published var games: [TeamGame]
    /// The team's name. `nil` means the user has no team yet (show onboarding).
    @Published var teamName: String?
    @Published var sortOption: SortOption = .totalWithBonus
    @Published var filterOption: FilterOption = .all
    @Published var searchText: String = ""
    @Published var teamIcon: UIImage?

    /// How this device relates to the current team:
    ///   • `.user`   — a local team you own & fully edit; not shared/live.
    ///   • `.admin`  — a live, cloud-shared team you own & edit (Pro); others can
    ///                 follow it with a redeem code (read-only).
    ///   • `.viewer` — a team you joined with a code; read-only.
    /// `nil` means no team yet (onboarding).
    @Published var mode: TeamMode?

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

    /// Whether the user has set up (or joined) a team. Drives the onboarding vs
    /// dashboard branch in `MyTeamView`.
    var hasTeam: Bool { teamName != nil }

    /// Owners (User or Admin) can edit the roster/games; viewers cannot.
    var canEdit: Bool { mode == .user || mode == .admin }

    /// Admin teams are live/cloud-shared. Only these can publish & share codes.
    var isLive: Bool { mode == .admin }

    /// Back-compat for edit-affordance call sites: showing edit UI == can edit.
    var isAdmin: Bool { canEdit }

    private var cancellables = Set<AnyCancellable>()

    // MARK: - Init

    init() {
        // Load the last saved team if present; otherwise start empty so new users
        // land on the Create / Join onboarding (no hardcoded seed team).
        if let saved = DataExporter.loadFromDisk() {
            self.players = saved.players
            self.games = saved.games
            self.teamName = saved.teamName
            self.mode = saved.teamName != nil ? (saved.mode ?? .user) : nil
        } else {
            self.players = []
            self.games = []
            self.teamName = nil
            self.mode = nil
        }

        // Autosave (debounced) whenever the team's name, roster, games or mode change.
        Publishers.CombineLatest4($players, $games, $teamName, $mode)
            .dropFirst()
            .debounce(for: .seconds(1), scheduler: RunLoop.main)
            .sink { players, games, teamName, mode in
                _ = DataExporter.saveToDisk(players: players, games: games, teamName: teamName, mode: mode)
            }
            .store(in: &cancellables)
    }

    // MARK: - Team lifecycle

    /// Creates an empty local team the user owns and can fully edit. `.user` teams
    /// stay on-device; `.admin` teams (Pro) are made live/shareable by the caller
    /// via `TeamSyncService.createTeam`.
    func createLocalTeam(name: String, mode: TeamMode = .user, icon: UIImage? = nil) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        teamName = trimmed.isEmpty ? "My Team" : trimmed
        self.mode = mode
        if let icon { teamIcon = icon }
    }

    /// Clears the local team and returns the user to onboarding.
    func deleteTeam() {
        teamName = nil
        players = []
        games = []
        teamIcon = nil
        mode = nil
        DataExporter.deleteFromDisk()
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
        // Clear the cloud key so the next publish re-uploads the new image.
        players[i].photoPath = nil
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
