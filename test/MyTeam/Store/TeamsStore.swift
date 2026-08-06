import Foundation
import UIKit
import Combine

/// Owns every team on the device and which one is open.
///
/// `TeamStore` stays exactly as it was from a view's point of view — the ~10
/// screens taking `@ObservedObject var vm: TeamStore` are unchanged. All this adds
/// is a layer above: a registry, an active pointer, and the cap.
@MainActor
final class TeamsStore: ObservableObject {

    /// How many teams one device may hold. A product limit, not a security
    /// boundary: `StorageOnlyTeamRemoteStore.createTeam` makes no network call, so
    /// there is nothing server-side to enforce against.
    static let maxTeams = 2

    @Published private(set) var order: [UUID] = []
    @Published private(set) var activeID: UUID?
    /// Bumped whenever a team is added, removed or renamed, so SwiftUI redraws the
    /// switcher — `stores` itself holds reference types.
    @Published private(set) var revision = 0

    private var stores: [UUID: TeamStore] = [:]
    /// Used before any team exists: a real store bound to a real folder, which
    /// only gets registered once it actually saves something.
    private var pending: TeamStore?

    init() {
        restore()
    }

    // MARK: - Access

    /// The open team. Never nil — when the device has no teams this is an empty
    /// store that onboarding writes into.
    ///
    /// Read during view body evaluation, so it must not mutate anything: the
    /// pending store is created up-front in `restore()`/`beginNewTeam()` rather
    /// than lazily here.
    var active: TeamStore {
        if let activeID, let store = stores[activeID] { return store }
        return pending ?? ensurePending()
    }

    @discardableResult
    private func ensurePending() -> TeamStore {
        if let pending { return pending }
        let store = makePending()
        pending = store
        return store
    }

    var teams: [(id: UUID, store: TeamStore)] {
        order.compactMap { id in stores[id].map { (id, $0) } }
    }

    var count: Int { order.count }

    func store(for id: UUID) -> TeamStore? { stores[id] }

    /// Whether another team may be created. Pro-gated *and* capped.
    func canCreateTeam(isPro: Bool) -> Bool {
        guard count >= 1 else { return true }   // the first team is always free
        return isPro && count < Self.maxTeams
    }

    var isAtCap: Bool { count >= Self.maxTeams }

    // MARK: - Lifecycle

    func setActive(_ id: UUID) {
        guard stores[id] != nil else { return }
        activeID = id
        persistIndex()
        mirrorActiveToLegacyPath()
    }

    /// Prepares an empty store for a new team and makes it active. The team is not
    /// registered until it saves, so an abandoned "Add team" leaves nothing behind.
    func beginNewTeam() {
        pending = makePending()
        activeID = nil
    }

    func deleteActiveTeam() {
        guard let id = activeID, let store = stores[id] else {
            active.deleteTeam()
            return
        }
        store.deleteTeam()
        stores[id] = nil
        order.removeAll { $0 == id }
        try? FileManager.default.removeItem(at: TeamFileStore.team(id).directory)
        activeID = order.first
        revision += 1
        persistIndex()
        mirrorActiveToLegacyPath()
    }

    // MARK: - Restore

    private func restore() {
        let index = TeamsIndex.load()
        var ids = index?.teams.map(\.id) ?? []

        // The index is a cache of a fact that lives in the filesystem. If it's
        // missing or stale, believe the folders.
        let onDisk = TeamsIndex.teamIDsOnDisk()
        for id in onDisk where !ids.contains(id) { ids.append(id) }
        ids.removeAll { !onDisk.contains($0) }

        if ids.isEmpty {
            adoptLegacyTeamIfPresent()
            if activeID == nil { ensurePending() }
            return
        }

        for id in ids {
            let store = TeamStore(files: .team(id))
            attach(store, id: id)
            stores[id] = store
        }
        order = ids
        activeID = index?.activeTeamID.flatMap { ids.contains($0) ? $0 : nil } ?? ids.first
        persistIndex()
        mirrorActiveToLegacyPath()
    }

    /// First launch after multi-team: move the single-slot team into its own
    /// folder. The legacy file is kept and kept up to date, so installing an older
    /// build still finds the team.
    private func adoptLegacyTeamIfPresent() {
        let legacy = TeamStore(files: .legacy)
        guard let doc = legacy.doc else {
            // Nothing to adopt — but if the legacy file was unreadable, keep that
            // store so the recovery screen is shown rather than onboarding.
            if legacy.loadState.isRecoverable { pending = legacy }
            return
        }
        let id = doc.id
        let files = TeamFileStore.team(id)
        try? files.save(doc)
        let store = TeamStore(files: files, document: doc)
        attach(store, id: id)
        stores[id] = store
        order = [id]
        activeID = id
        persistIndex()
    }

    // MARK: - Wiring

    private func makePending() -> TeamStore {
        let id = UUID()
        let store = TeamStore(files: .team(id), autoload: false)
        attach(store, id: id)
        return store
    }

    /// Registers a team the moment it first writes, and keeps the index and the
    /// legacy mirror in step on every save afterwards.
    ///
    /// Registration is keyed by the **slot** id the store was created against, not
    /// by `doc.id`. Those can differ — importing a file or pulling a shared team
    /// replaces the document wholesale, bringing a different id with it — and
    /// keying on the document would register a phantom team and silently switch
    /// the user to it.
    private func attach(_ store: TeamStore, id: UUID) {
        store.onSaved = { [weak self, weak store] _ in
            guard let self, let store else { return }
            Task { @MainActor in
                if self.stores[id] == nil {
                    self.stores[id] = store
                    if !self.order.contains(id) { self.order.append(id) }
                    self.activeID = id
                    if self.pending === store { self.pending = nil }
                    self.revision += 1
                } else if self.pending === store {
                    self.pending = nil
                }
                self.persistIndex()
                self.mirrorActiveToLegacyPath()
            }
        }
    }

    private func persistIndex() {
        var index = TeamsIndex()
        index.teams = order.compactMap { id in
            guard let doc = stores[id]?.doc else { return nil }
            return TeamsIndex.Entry(id: id, name: doc.name, mode: doc.mode.rawValue, remoteCode: doc.remoteCode)
        }
        index.activeTeamID = activeID
        index.save()
    }

    /// Keeps `Documents/team_data.json` pointing at whichever team is open, so a
    /// downgrade to a pre-multi-team build opens something sensible instead of
    /// showing onboarding on top of live data.
    private func mirrorActiveToLegacyPath() {
        guard let doc = activeID.flatMap({ stores[$0]?.doc }) else { return }
        try? TeamFileStore.legacy.save(doc)
    }
}
