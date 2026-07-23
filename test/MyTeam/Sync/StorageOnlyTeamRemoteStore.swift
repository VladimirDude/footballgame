//  Storage-only team backend — no Firestore, no Cloud Functions.
//
//  Design ("capability code"):
//    • A team is a folder keyed by an unguessable code: teams/{code}/team.json
//    • The redeem code IS the access key — knowing it grants access.
//    • Roles use an *owner-write* rule: the first publisher's UID is stamped into
//      the file's `ownerUid` metadata; `storage.rules` only lets that UID edit,
//      so everyone else who has the code is read-only (a viewer).
//
//  Needs FirebaseStorage + FirebaseAuth (Anonymous). Guarded so the app builds
//  without them.

#if canImport(FirebaseStorage) && canImport(FirebaseAuth)
import Foundation
import FirebaseStorage
import FirebaseAuth

struct StorageOnlyTeamRemoteStore: TeamRemoteStore {
    private let storage = Storage.storage()
    var isConfigured: Bool { true }

    private func teamRef(_ code: String) -> StorageReference {
        storage.reference().child("teams/\(code)/team.json")
    }

    /// Anonymous sign-in gives each device a stable UID for the owner-write rule
    /// and lets Storage rules require auth (basic abuse protection).
    @discardableResult
    private func ensureSignedIn() async throws -> String {
        if let uid = Auth.auth().currentUser?.uid { return uid }
        let result = try await Auth.auth().signInAnonymously()
        return result.user.uid
    }

    func createTeam(name: String) async throws -> String {
        try await ensureSignedIn()
        // The team is materialized on first publish; here we just mint the code.
        return Self.generateCode()
    }

    func redeem(code: String) async throws -> TeamMembership {
        let uid = try await ensureSignedIn()
        let normalized = code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !normalized.isEmpty else { throw TeamSyncError.invalidCode }

        // The team exists iff its data file exists. Its metadata tells us the owner.
        let metadata: StorageMetadata
        do {
            metadata = try await teamRef(normalized).getMetadata()
        } catch {
            throw TeamSyncError.invalidCode
        }
        let ownerUid = metadata.customMetadata?["ownerUid"]
        let role: TeamRole = (ownerUid == uid) ? .admin : .viewer
        return TeamMembership(teamID: normalized, role: role)
    }

    func publish(teamID: String, snapshotJSON: Data) async throws {
        let uid = try await ensureSignedIn()
        let metadata = StorageMetadata()
        metadata.contentType = "application/json"
        // Stamp ownership so storage.rules can restrict future edits to this UID.
        metadata.customMetadata = ["ownerUid": uid]
        _ = try await teamRef(teamID).putDataAsync(snapshotJSON, metadata: metadata)
    }

    func fetchSnapshot(teamID: String) async throws -> Data? {
        try await ensureSignedIn()
        do {
            return try await teamRef(teamID).data(maxSize: 5 * 1024 * 1024)
        } catch {
            return nil
        }
    }

    /// Human-friendly, hard-to-guess code, e.g. "FTMP-8XK2Q-P4M9".
    static func generateCode() -> String {
        let alphabet = Array("ABCDEFGHJKLMNPQRSTUVWXYZ23456789")
        func block(_ n: Int) -> String { String((0..<n).map { _ in alphabet.randomElement()! }) }
        return "FTMP-\(block(5))-\(block(4))"
    }
}
#endif
