import Foundation

/// DEBUG-only in-memory `TeamRemoteStore` so the join → publish → pull flow can
/// be exercised in the simulator without a Firebase backend.
///
/// Conventions for testing:
///   • any non-empty code joins a team; a code containing "ADMIN" grants admin,
///     otherwise viewer.
///   • published snapshots are kept in memory keyed by teamID and returned by
///     `fetchSnapshot`, so a "publish then pull" round-trips.
final class MockTeamRemoteStore: TeamRemoteStore, @unchecked Sendable {
    var isConfigured: Bool { true }

    private let lock = NSLock()
    private var snapshots: [String: Data] = [:]

    func createTeam(name: String) async throws -> String {
        "mock-team-\(abs(name.hashValue))"
    }

    func redeem(code: String) async throws -> TeamMembership {
        let trimmed = code.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw TeamSyncError.invalidCode }
        let role: TeamRole = trimmed.uppercased().contains("ADMIN") ? .admin : .viewer
        return TeamMembership(teamID: "mock-team-shared", role: role)
    }

    func publish(teamID: String, snapshotJSON: Data) async throws {
        lock.withLock { snapshots[teamID] = snapshotJSON }
    }

    func fetchSnapshot(teamID: String) async throws -> Data? {
        lock.withLock { snapshots[teamID] }
    }
}
