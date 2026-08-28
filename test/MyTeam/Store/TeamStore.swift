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
/// A player with their position in the current ranking and the figures behind it.
struct RankedPlayer: Identifiable {
    let rank: Int
    let player: TeamPlayer
    let stats: PlayerSeasonStats

    var id: UUID { player.id }
}

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
    /// Which season the dashboard, match list and leaderboard are showing.
    /// Not persisted: a filter is not part of the team.
    @Published var seasonScope: SeasonScope = .allTime
    /// What the leaderboard ranks by. Separate from `sortOption` on purpose —
    /// sharing one meant changing the table's sort silently reordered the podium.
    @Published var leaderboardMetric: LeaderboardMetric = .goals
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
        guard var document = doc else { return }
        document.remoteCode = code
        doc = document
    }

    // MARK: - Seasons

    var seasons: [Season] { doc?.orderedSeasons ?? [] }
    var currentSeason: Season? { doc?.currentSeason }
    var hasUnassignedGames: Bool { doc?.hasUnassignedGames ?? false }

    /// Label for the active scope, e.g. "2026/27" or "All time".
    var seasonScopeLabel: String {
        switch seasonScope {
        case .allTime:        return "All time"
        case .unassigned:     return "Unassigned"
        case .season(let id): return doc?.season(id)?.name ?? "Season"
        }
    }

    /// Matches in the active scope, newest first.
    var gamesInScope: [TeamGame] {
        games.filter(seasonScope.matches).sorted { $0.date > $1.date }
    }

    /// Derived figures for every player in the active scope.
    var statsInScope: [UUID: PlayerSeasonStats] {
        guard let doc else { return [:] }
        return TeamStatsCalculator.stats(for: doc, scope: seasonScope)
    }

    func stats(for player: TeamPlayer) -> PlayerSeasonStats {
        statsInScope[player.id] ?? .empty(player.id)
    }

    func addSeason(name: String) {
        guard var doc else { return }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let nextIndex = (doc.seasons.map(\.sortIndex).max() ?? -1) + 1
        let season = Season(name: trimmed.isEmpty ? "New Season" : trimmed, sortIndex: nextIndex)
        doc.seasons.append(season)
        doc.currentSeasonID = season.id
        self.doc = doc
    }

    func renameSeason(_ id: UUID, to name: String) {
        guard let i = doc?.seasons.firstIndex(where: { $0.id == id }) else { return }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        doc?.seasons[i].name = trimmed
    }

    func setCurrentSeason(_ id: UUID) {
        doc?.currentSeasonID = id
    }

    /// Removes a season, moving its matches to `reassignTo`.
    ///
    /// Matches are never deleted with the season — losing a year of results to a
    /// mis-tap is not a recoverable mistake.
    func deleteSeason(_ id: UUID, reassignTo destination: UUID?) {
        guard var doc, doc.seasons.count > 1 || destination == nil else { return }
        for i in doc.games.indices where doc.games[i].seasonID == id {
            doc.games[i].seasonID = destination
        }
        doc.seasonEntries.removeAll { $0.seasonID == id }
        doc.seasons.removeAll { $0.id == id }
        if doc.currentSeasonID == id {
            doc.currentSeasonID = destination ?? doc.orderedSeasons.first?.id
        }
        self.doc = doc
        if case .season(let scoped) = seasonScope, scoped == id {
            seasonScope = .allTime
        }
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

    /// Podium for the dashboard, ranked by `leaderboardMetric` within the active
    /// season scope.
    var leaderboard: [RankedPlayer] {
        rankedPlayers(limit: 3)
    }

    /// Players ranked by the active metric, with **dense ranks** so tied players
    /// share a position instead of being handed different medals.
    func rankedPlayers(limit: Int? = nil) -> [RankedPlayer] {
        let stats = statsInScope
        let eligible = players.filter { $0.role == .player || $0.role == .goalkeeper }
        let metric = leaderboardMetric
        let sorted = eligible
            .map { (player: $0, stats: stats[$0.id] ?? .empty($0.id)) }
            .sorted {
                let a = metric.value($0.stats), b = metric.value($1.stats)
                return a == b ? $0.player.name < $1.player.name : a > b
            }

        var ranked: [RankedPlayer] = []
        var lastValue: Double?
        var rank = 0
        for item in sorted {
            let value = metric.value(item.stats)
            if lastValue != value {
                rank += 1
                lastValue = value
            }
            ranked.append(RankedPlayer(rank: rank, player: item.player, stats: item.stats))
        }
        if let limit { return Array(ranked.prefix(limit)) }
        return ranked
    }

    var coaches: [TeamPlayer]      { players.filter { $0.role == .coach } }
    var goalkeepers: [TeamPlayer]  { players.filter { $0.role == .goalkeeper } }
    var playerCount: Int       { players.filter { $0.role == .player }.count }
    var goalkeeperCount: Int   { players.filter { $0.role == .goalkeeper }.count }
    var coachCount: Int        { players.filter { $0.role == .coach }.count }
    /// From match results, not player counters — an unlinked scorer must not make
    /// the team total drop.
    var totalGoals: Int {
        guard let doc else { return 0 }
        return TeamStatsCalculator.teamGoals(for: doc, scope: seasonScope)
    }
    var totalAssists: Int { statsInScope.values.reduce(0) { $0 + $1.assists } }

    /// Scorer names in the log that no squad member matches.
    var unlinkedScorerNames: [(name: String, goals: Int)] {
        guard let doc else { return [] }
        return PlayerLinker.unmatchedNames(in: doc)
    }

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
    var canRestorePreviousSave: Bool { files.hasPrevious }

    private var cancellables = Set<AnyCancellable>()

    /// Where this team is stored. Defaults to the pre-multi-team single-slot path
    /// so any code still constructing a bare `TeamStore()` behaves as before.
    private let files: TeamFileStore
    /// Called after every successful save, so the parent can mirror the active
    /// team to the legacy path and keep the index in step.
    var onSaved: ((TeamDocument) -> Void)?

    // MARK: - Init

    init(files: TeamFileStore = .legacy, autoload: Bool = true) {
        self.files = files
        if autoload { load() }
    }

    /// Adopts an already-decoded document, e.g. a team the parent store just
    /// created or read as part of loading the index.
    convenience init(files: TeamFileStore, document: TeamDocument) {
        self.init(files: files, autoload: false)
        adopt(document)
    }

    private func adopt(_ incoming: TeamDocument) {
        var next = incoming
        TeamImageStore.hydrate(&next)
        doc = next
        teamIconWithoutSaving = TeamImageStore.teamIcon(next.id)
        loadState = .loaded
        installAutosave()
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
            let snapshot = try files.load()
            if var saved = snapshot.document {
                TeamImageStore.hydrate(&saved)
                doc = saved
                teamIconWithoutSaving = TeamImageStore.teamIcon(saved.id)
                loadState = .loaded
                // Persist the upgraded shape now. The ids minted while migrating are
                // only stable if they reach disk before the next launch, and waiting
                // for the user's first edit would re-mint them until then.
                if snapshot.wasMigrated {
                    try? files.save(saved)
                    onSaved?(saved)
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
            let quarantined = files.quarantine()
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
                guard let self, let doc else { return }
                do {
                    try self.files.save(doc)
                    self.onSaved?(doc)
                    self.lastSaveError = nil
                } catch {
                    self.lastSaveError = error.localizedDescription
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
            if var restored = try files.restorePrevious() {
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
        files.delete()
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
        // Every team starts with one season so matches never land unassigned.
        let season = Season(name: Season.conventionalName(for: Date()), sortIndex: 0)
        doc = TeamDocument(
            name: trimmed.isEmpty ? "My Team" : trimmed, mode: mode,
            seasons: [season], currentSeasonID: season.id
        )
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
        files.delete()
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
        var game = game
        if game.seasonID == nil { game.seasonID = doc?.currentSeasonID }
        linkGoals(in: &game)
        games.append(game)
        TeamImageStore.setHighlight(game.highlightImage, for: game.id)
    }

    func removeGame(id: UUID) {
        games.removeAll { $0.id == id }
        TeamImageStore.setHighlight(nil, for: id)
    }

    func updateGame(_ game: TeamGame) {
        guard let i = games.firstIndex(where: { $0.id == game.id }) else { return }
        var game = game
        linkGoals(in: &game)
        games[i] = game
        TeamImageStore.setHighlight(game.highlightImage, for: game.id)
    }

    /// Resolves scorer/assist names to squad members as the match is saved, so new
    /// data arrives already linked and never needs the repair flow.
    private func linkGoals(in game: inout TeamGame) {
        let roster = players
        for i in game.goalDetails.indices where !game.goalDetails[i].isOpponent {
            if game.goalDetails[i].scorerID == nil,
               let m = PlayerLinker.match(game.goalDetails[i].scorer, in: roster), m.confidence == .exact {
                game.goalDetails[i].scorerID = m.playerID
            }
            if game.goalDetails[i].assistID == nil, !game.goalDetails[i].assist.isEmpty,
               let m = PlayerLinker.match(game.goalDetails[i].assist, in: roster), m.confidence == .exact {
                game.goalDetails[i].assistID = m.playerID
            }
        }
        game.scorers = DataExporter.displayScorers(game)
    }

    // MARK: - Scorer linking

    /// Points every goal credited to `name` at `playerID`.
    func linkScorerName(_ name: String, to playerID: UUID) {
        guard var doc else { return }
        let needle = PlayerLinker.normalize(name)
        for g in doc.games.indices {
            for d in doc.games[g].goalDetails.indices {
                let goal = doc.games[g].goalDetails[d]
                guard !goal.isOpponent else { continue }
                if goal.scorerID == nil, PlayerLinker.normalize(goal.scorer) == needle {
                    doc.games[g].goalDetails[d].scorerID = playerID
                }
                if goal.assistID == nil, PlayerLinker.normalize(goal.assist) == needle {
                    doc.games[g].goalDetails[d].assistID = playerID
                }
            }
        }
        self.doc = doc
    }

    /// Adds `name` to the roster and links its goals to the new player.
    func createPlayerForScorerName(_ name: String) {
        let player = TeamPlayer(name: name.trimmingCharacters(in: .whitespaces))
        addPlayer(player)
        linkScorerName(name, to: player.id)
    }

    /// Marks a name as not-a-squad-member (guest, trialist, opponent) so the
    /// unlinked-names prompt stops mentioning it.
    func ignoreScorerName(_ name: String) {
        guard var doc else { return }
        guard !doc.ignoredScorerNames.contains(name) else { return }
        doc.ignoredScorerNames.append(name)
        self.doc = doc
    }

    // MARK: - Season entries

    func seasonEntry(for playerID: UUID, seasonID: UUID) -> PlayerSeasonEntry? {
        doc?.seasonEntries.first { $0.playerID == playerID && $0.seasonID == seasonID }
    }

    /// Writes the hand-entered figures for one player in one season, creating the
    /// row if needed.
    func updateSeasonEntry(
        playerID: UUID,
        seasonID: UUID,
        bonusPoints: Double? = nil,
        goalkeeper: GoalkeeperStats?? = nil,
        carryOverGoals: Int? = nil,
        carryOverAssists: Int? = nil
    ) {
        guard var doc else { return }
        let index = doc.seasonEntries.firstIndex { $0.playerID == playerID && $0.seasonID == seasonID }
        var entry = index.map { doc.seasonEntries[$0] }
            ?? PlayerSeasonEntry(seasonID: seasonID, playerID: playerID)
        if let bonusPoints { entry.bonusPoints = bonusPoints }
        if let goalkeeper { entry.goalkeeper = goalkeeper }
        if let carryOverGoals { entry.carryOverGoals = max(0, carryOverGoals) }
        if let carryOverAssists { entry.carryOverAssists = max(0, carryOverAssists) }
        if let index { doc.seasonEntries[index] = entry } else { doc.seasonEntries.append(entry) }
        self.doc = doc
    }

    // MARK: - Sorting

    private func sorted(_ list: [TeamPlayer]) -> [TeamPlayer] {
        switch sortOption {
        case .total:          return list.sorted { $0.total > $1.total }
        case .totalWithBonus: return list.sorted { $0.totalWithBonus > $1.totalWithBonus }
        }
    }
}
