import Foundation

/// A user's role in a shared team. Maps to `TeamStore.isAdmin` (owner/admin → true).
enum TeamRole: String, Codable, Sendable {
    case owner
    case admin
    case viewer

    var canEdit: Bool { self == .owner || self == .admin }
}

/// Result of joining a team (via redeem code or creation).
struct TeamMembership: Codable, Equatable, Sendable {
    let teamID: String
    let role: TeamRole
}

enum TeamSyncError: LocalizedError {
    case notConfigured
    case notAuthorized
    case invalidCode
    case network(String)

    var errorDescription: String? {
        switch self {
        case .notConfigured: "Team sync isn't set up yet."
        case .notAuthorized: "Only team admins can publish changes."
        case .invalidCode: "That code isn't valid."
        case .network(let m): m
        }
    }
}

/// The seam between the app and the team-sharing backend. Firestore lives behind
/// this (`FirestoreTeamRemoteStore`, added once the Firebase SDK is present); a
/// `LocalTeamRemoteStore` keeps the app fully functional and offline today.
///
/// The payload is the app's existing exported-team JSON (`DataExporter`), so no
/// new serialization is introduced — the backend just stores that blob per team.
protocol TeamRemoteStore: Sendable {
    /// Whether a backend is wired up. When false the UI hides sync affordances.
    var isConfigured: Bool { get }

    /// Creates a new shared team owned by the current user. Returns its id.
    func createTeam(name: String) async throws -> String

    /// Redeems a code, joining the caller to a team. Returns the membership.
    func redeem(code: String) async throws -> TeamMembership

    /// Admin: publishes the current team snapshot (exported JSON) to the backend.
    func publish(teamID: String, snapshotJSON: Data) async throws

    /// Fetches the latest snapshot for a team, or `nil` if none exists.
    func fetchSnapshot(teamID: String) async throws -> Data?
}

/// Default no-backend implementation. The app keeps working entirely locally;
/// sync calls throw `.notConfigured` so the UI can stay hidden until Firebase
/// is wired in.
struct LocalTeamRemoteStore: TeamRemoteStore {
    var isConfigured: Bool { false }
    func createTeam(name: String) async throws -> String { throw TeamSyncError.notConfigured }
    func redeem(code: String) async throws -> TeamMembership { throw TeamSyncError.notConfigured }
    func publish(teamID: String, snapshotJSON: Data) async throws { throw TeamSyncError.notConfigured }
    func fetchSnapshot(teamID: String) async throws -> Data? { throw TeamSyncError.notConfigured }
}
