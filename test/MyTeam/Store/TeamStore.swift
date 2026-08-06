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

/// Outcome of reading the saved team at launch.
///
/// `empty` and `failed` used to be the same state (`loadFromDisk() == nil`), which
/// is what made corruption silent: the user landed on onboarding, created a team,
/// and the autosave overwrote the file they still had.
enum TeamLoadState: Equatable {
    /// No save file exists — a genuinely new user.
    case empty
    /// A team was read successfully.
    case loaded
    /// A save file exists but could not be read.
    case failed(message: String, quarantinedAt: URL?)
    /// The save file was written by a newer build than this one.
    case tooNew(message: String)

    var isRecoverable: Bool {
        switch self {
        case .failed, .tooNew: return true
        case .empty, .loaded: return false
        }
    }
}

final class TeamStore: ObservableObject {

    /// All persisted state, as one value. Everything the autosave writes lives
    /// here and nothing else does, so view-only preferences below cannot
    /// accidentally trigger a save.
    ///
    /// `nil` means the user has no team yet (show onboarding).
    @Published private(set) var doc: TeamDocument?

    // View-only state — deliberately outside `doc`.
    @Published var sortOption: SortOption = .totalWithBonus
    @Published var filterOption: FilterOption = .all
    @Published var searchText: String = ""
    @Published var teamIcon: UIImage? {
        didSet {
            guard !isHydratingIcon, let id = doc?.id else { return }
            TeamImageStore.setTeamIcon(teamIcon, for: id)
        }
    }

    /// Set while filling `teamIcon` from disk, so hydration doesn't immediately
    /// re-encode and rewrite the image it just read.
    private var isHydratingIcon = false

    private var teamIconWithoutSaving: UIImage? {
        get { teamIcon }
        set {
            isHydratingIcon = true
            teamIcon = newValue
            isHydratingIcon = false
        }
    }

    // MARK: - Document passthroughs
    //
    // These keep the ~10 views that take `@ObservedObject var vm: TeamStore`
    // working unchanged, including the ones that mutate through a subscript
    // (`vm.players[i].goals = …`), which reads, modifies and writes back.

    var players: [TeamPlayer] {
        get { doc?.players ?? [] }
        set { doc?.players = newValue }
    }

    var games: [TeamGame] {
        get { doc?.games ?? [] }
        set { doc?.games = newValue }
    }

    /// The team's name. `nil` means the user has no team yet (show onboarding).
    var teamName: String? {
        get { doc?.name }
        set {
            guard let newValue else { doc = nil; return }
            doc?.name = newValue
        }
    }

    /// How this device relates to the current team:
    ///   • `.user`   — a local team you own & fully edit; not shared/live.
    ///   • `.admin`  — a live, cloud-shared team you own & edit (Pro); others can
    ///                 follow it with a redeem code (read-only).
    ///   • `.viewer` — a team you joined with a code; read-only.
    /// `nil` means no team yet (onboarding).
    var mode: TeamMode? {
        get { doc?.mode }
        set {
            guard let newValue else { return }
            doc?.mode = newValue
        }
    }

    /// Local identity of the current team. Stable across launches as of v2.
    var teamID: UUID? { doc?.id }

    /// Records the cloud address assigned when the team went live. Identity is
    /// `doc.id` and does not change — only the address is added.
    func setRemoteCode(_ code: String?) {
        doc?.remoteCode = code
    }

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

    /// How the saved team was read at launch. Drives the dashboard / onboarding /
    /// recovery branch in `MyTeamView`.
    @Published private(set) var loadState: TeamLoadState = .empty

    /// Set when a save fails, so a failing write stops being invisible.
    @Published var lastSaveError: String?

    /// Whether a rolling backup is available to restore from.
    var canRestorePreviousSave: Bool { DataExporter.hasPreviousSave }

    private var cancellables = Set<AnyCancellable>()

    // MARK: - Init

    init() {
        load()
    }

    // MARK: - Loading

    /// Reads the saved team and, **only if that succeeded or positively confirmed
    /// there is no file**, installs the autosave subscription.
    ///
    /// The gating is the whole point: an autosave that exists is an autosave that
    /// can fire, so when the load fails we never create one rather than creating
    /// one and hoping every future code path remembers to check a flag.
    private func load() {
        do {
            let snapshot = try DataExporter.loadSnapshotFromDisk()
            if var saved = snapshot.document {
                TeamImageStore.hydrate(&saved)
                doc = saved
                teamIconWithoutSaving = TeamImageStore.teamIcon(saved.id)
                loadState = .loaded
                // Persist the upgraded shape now. The ids minted while migrating are
                // only stable if they reach disk before the next launch, and waiting
                // for the user's first edit would re-mint them until then.
                if snapshot.wasMigrated {
                    try? DataExporter.saveToDisk(saved)
                }
            } else {
                doc = nil
                loadState = .empty
            }
        } catch DataExporter.ImportError.tooNew(let found, let supported) {
            loadState = .tooNew(message: DataExporter.ImportError.tooNew(found: found, supported: supported)
                .errorDescription ?? "This team was saved by a newer version of FTMP.")
            return  // no autosave: writing today's shape would drop what we can't read
        } catch {
            let quarantined = DataExporter.quarantineCurrentSave()
            loadState = .failed(message: error.localizedDescription, quarantinedAt: quarantined)
            return  // no autosave: the next edit must not overwrite a recoverable file
        }

        installAutosave()
    }

    private func installAutosave() {
        guard cancellables.isEmpty else { return }
        // Autosave (debounced) whenever any persisted state changes. `removeDuplicates`
        // is safe because `TeamDocument`'s equality covers persisted fields only —
        // hydrating a photo doesn't look like an edit.
        $doc
            .dropFirst()
            .removeDuplicates()
            .debounce(for: .seconds(1), scheduler: RunLoop.main)
            .sink { [weak self] doc in
                guard let doc else { return }
                do {
                    try DataExporter.saveToDisk(doc)
                    self?.lastSaveError = nil
                } catch {
                    self?.lastSaveError = error.localizedDescription
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - Recovery

    /// Re-reads the save file, e.g. after the user fixed things externally.
    func retryLoad() {
        guard loadState.isRecoverable else { return }
        load()
    }

    /// Replaces the unreadable save with the rolling backup.
    func restorePreviousSave() {
        do {
            if var restored = try DataExporter.restorePreviousSave() {
                TeamImageStore.hydrate(&restored)
                doc = restored
                teamIconWithoutSaving = TeamImageStore.teamIcon(restored.id)
            } else {
                doc = nil
            }
            loadState = doc == nil ? .empty : .loaded
            installAutosave()
        } catch {
            lastSaveError = error.localizedDescription
        }
    }

    /// Discards the unreadable save and starts over. Destructive, and gated behind
    /// a typed confirmation in the UI.
    func startFresh() {
        DataExporter.deleteFromDisk()
        doc = nil
        teamIconWithoutSaving = nil
        loadState = .empty
        installAutosave()
    }

    // MARK: - Team lifecycle

    /// Creates an empty local team the user owns and can fully edit. `.user` teams
    /// stay on-device; `.admin` teams (Pro) are made live/shareable by the caller
    /// via `TeamSyncService.createTeam`.
    func createLocalTeam(name: String, mode: TeamMode = .user, icon: UIImage? = nil) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        doc = TeamDocument(name: trimmed.isEmpty ? "My Team" : trimmed, mode: mode)
        loadState = .loaded
        if let icon { teamIcon = icon }   // didSet persists it against the new team id
    }

    /// Replaces the whole document, e.g. after a file import or a cloud pull.
    func replaceDocument(_ incoming: TeamDocument, keepingMode: Bool = false) {
        var next = incoming
        if keepingMode, let current = doc?.mode { next.mode = current }
        TeamImageStore.hydrate(&next)
        TeamImageStore.persistAll(next)
        doc = next
        teamIconWithoutSaving = TeamImageStore.teamIcon(next.id)
        loadState = .loaded
        installAutosave()
    }

    /// Clears the local team and returns the user to onboarding.
    func deleteTeam() {
        if let doc { TeamImageStore.deleteAll(for: doc) }
        self.doc = nil
        teamIconWithoutSaving = nil
        loadState = .empty
        DataExporter.deleteFromDisk()
    }

    // MARK: - TeamPlayer CRUD

    func addPlayer(_ player: TeamPlayer) {
        players.append(player)
        TeamImageStore.setPlayerPhoto(player.photo, for: player.id)
    }

    func removePlayer(id: UUID) {
        players.removeAll { $0.id == id }
        TeamImageStore.setPlayerPhoto(nil, for: id)
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
        // Images live outside the snapshot, so they need an explicit write —
        // clearing `photoPath` is what makes the document itself look changed.
        TeamImageStore.setPlayerPhoto(photo, for: id)
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
        TeamImageStore.setHighlight(game.highlightImage, for: game.id)
    }

    func removeGame(id: UUID) {
        games.removeAll { $0.id == id }
        TeamImageStore.setHighlight(nil, for: id)
    }

    func updateGame(_ game: TeamGame) {
        guard let i = games.firstIndex(where: { $0.id == game.id }) else { return }
        games[i] = game
        TeamImageStore.setHighlight(game.highlightImage, for: game.id)
    }

    // MARK: - Sorting

    private func sorted(_ list: [TeamPlayer]) -> [TeamPlayer] {
        switch sortOption {
        case .total:          return list.sorted { $0.total > $1.total }
        case .totalWithBonus: return list.sorted { $0.totalWithBonus > $1.totalWithBonus }
        }
    }
}
