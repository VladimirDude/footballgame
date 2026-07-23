import Foundation
import Combine
import UIKit

/// Bridges the local `TeamStore` to the sharing backend (`TeamRemoteStore`).
///
/// Responsibilities:
///   • remembers which shared team this device belongs to (+ role) across launches
///   • `redeem(code:)` — join a team, pull its data, apply it locally, set admin role
///   • `publish(from:)` — admin pushes local edits to the backend for everyone
///   • `pull(into:)` — refresh local data from the backend
///
/// Serialization reuses `DataExporter`, so the wire format is the app's existing
/// team-export JSON — nothing new to maintain.
@MainActor
final class TeamSyncService: ObservableObject {
    @Published private(set) var membership: TeamMembership?
    @Published private(set) var isBusy = false
    @Published var lastError: String?
    @Published var lastSyncedAt: Date?

    private let remote: TeamRemoteStore
    private let photos: TeamPhotoStore
    private let analytics: AnalyticsService

    private enum Keys {
        static let teamID = "teamSync.teamID"
        static let role = "teamSync.role"
    }

    /// DEBUG uses in-memory mocks so the whole flow works in the simulator with
    /// no Firebase. Release stays local-only until `FirestoreTeamRemoteStore` /
    /// `FirebaseTeamPhotoStore` are wired in (once the SDK + config are present).
    nonisolated static var defaultRemote: TeamRemoteStore {
        // Storage-only backend (no Firestore/Functions). Swap for
        // `FirestoreTeamRemoteStore()` if you later need multiple admins,
        // server-validated codes, expiry, or real-time updates.
        #if canImport(FirebaseStorage) && canImport(FirebaseAuth)
        return StorageOnlyTeamRemoteStore()
        #elseif DEBUG
        return MockTeamRemoteStore()
        #else
        return LocalTeamRemoteStore()
        #endif
    }
    nonisolated static var defaultPhotos: TeamPhotoStore {
        #if canImport(FirebaseStorage)
        return FirebaseTeamPhotoStore()
        #elseif DEBUG
        return MockTeamPhotoStore()
        #else
        return LocalTeamPhotoStore()
        #endif
    }

    init(remote: TeamRemoteStore = TeamSyncService.defaultRemote,
         photos: TeamPhotoStore = TeamSyncService.defaultPhotos,
         analytics: AnalyticsService = .shared) {
        self.remote = remote
        self.photos = photos
        self.analytics = analytics
        if let teamID = UserDefaults.standard.string(forKey: Keys.teamID),
           let roleRaw = UserDefaults.standard.string(forKey: Keys.role),
           let role = TeamRole(rawValue: roleRaw) {
            self.membership = TeamMembership(teamID: teamID, role: role)
        }
    }

    var isConfigured: Bool { remote.isConfigured }
    var isJoined: Bool { membership != nil }
    var canEdit: Bool { membership?.role.canEdit ?? false }

    // MARK: - Join / redeem

    func redeem(code: String, into store: TeamStore) async {
        await run {
            let membership = try await remote.redeem(code: code)
            persist(membership)
            analytics.log(.featureUnlocked(feature: "team_redeem"))
            if let data = try await remote.fetchSnapshot(teamID: membership.teamID) {
                apply(data, to: store)
                await downloadPhotos(teamID: membership.teamID, into: store)
            }
            store.isAdmin = membership.role.canEdit
        }
    }

    func createTeam(name: String, from store: TeamStore) async {
        await run {
            let teamID = try await remote.createTeam(name: name)
            let membership = TeamMembership(teamID: teamID, role: .owner)
            persist(membership)
            store.isAdmin = true
            if let data = DataExporter.export(players: store.players, games: store.games) {
                try await remote.publish(teamID: teamID, snapshotJSON: data)
            }
        }
    }

    // MARK: - Publish / pull

    /// Admin-only: push local edits to the backend so all members receive them.
    func publish(from store: TeamStore) async {
        guard let membership, membership.role.canEdit else {
            lastError = TeamSyncError.notAuthorized.errorDescription
            return
        }
        await run {
            try await uploadPhotos(teamID: membership.teamID, from: store)
            guard let data = DataExporter.export(players: store.players, games: store.games) else { return }
            try await remote.publish(teamID: membership.teamID, snapshotJSON: data)
            lastSyncedAt = Date()
        }
    }

    /// Refresh local data from the backend (any member).
    func pull(into store: TeamStore) async {
        guard let membership else { return }
        await run {
            if let data = try await remote.fetchSnapshot(teamID: membership.teamID) {
                apply(data, to: store)
                await downloadPhotos(teamID: membership.teamID, into: store)
                lastSyncedAt = Date()
            }
        }
    }

    func leaveTeam(_ store: TeamStore) {
        membership = nil
        store.isAdmin = false
        UserDefaults.standard.removeObject(forKey: Keys.teamID)
        UserDefaults.standard.removeObject(forKey: Keys.role)
    }

    // MARK: - Helpers

    private func apply(_ data: Data, to store: TeamStore) {
        guard let imported = DataExporter.importData(data) else { return }
        store.players = imported.players
        store.games = imported.games
    }

    /// Admin: uploads any local photos that don't yet have a cloud key, assigns
    /// the key so it travels in the published snapshot. No-op when photos aren't
    /// configured (keeps local-only behavior intact).
    private func uploadPhotos(teamID: String, from store: TeamStore) async throws {
        guard photos.isConfigured else { return }
        for index in store.players.indices {
            guard store.players[index].photoPath == nil,
                  let image = store.players[index].photo,
                  let data = image.jpegData(compressionQuality: 0.8) else { continue }
            let key = "players/\(UUID().uuidString).jpg"
            try await photos.upload(imageData: data, teamID: teamID, key: key)
            store.players[index].photoPath = key
        }
    }

    /// Downloads photos referenced by `photoPath` for players that don't already
    /// have a local image, decoding off the main actor.
    private func downloadPhotos(teamID: String, into store: TeamStore) async {
        guard photos.isConfigured else { return }
        for index in store.players.indices {
            guard store.players[index].photo == nil,
                  let key = store.players[index].photoPath else { continue }
            guard let data = try? await photos.download(teamID: teamID, key: key),
                  let image = UIImage(data: data) else { continue }
            store.players[index].photo = image
        }
    }

    private func persist(_ membership: TeamMembership) {
        self.membership = membership
        UserDefaults.standard.set(membership.teamID, forKey: Keys.teamID)
        UserDefaults.standard.set(membership.role.rawValue, forKey: Keys.role)
    }

    private func run(_ work: () async throws -> Void) async {
        isBusy = true
        lastError = nil
        defer { isBusy = false }
        do { try await work() }
        catch {
            let ns = error as NSError
            #if DEBUG
            print("⚠️ TeamSync error [\(ns.domain) code=\(ns.code)]: \(ns.localizedDescription)\n\(ns.userInfo)")
            #endif
            // Prefer our own descriptive errors; otherwise surface the real
            // domain + code so storage/auth failures are diagnosable, not generic.
            if let localized = (error as? TeamSyncError)?.errorDescription {
                lastError = localized
            } else {
                lastError = "\(ns.localizedDescription) [\(ns.domain) \(ns.code)]"
            }
        }
    }
}
