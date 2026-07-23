import Foundation

/// Stores player photos as blobs, keyed by a stable relative `key`
/// (e.g. "players/UUID.jpg") under a team. This is the **Cloud Storage** half of
/// team sharing — Firestore holds the structured data, Storage holds the images.
///
/// Photos are passed as JPEG `Data` (not `UIImage`) to keep the protocol
/// `Sendable` and the heavy encode/decode off the main actor.
protocol TeamPhotoStore: Sendable {
    var isConfigured: Bool { get }
    func upload(imageData: Data, teamID: String, key: String) async throws
    func download(teamID: String, key: String) async throws -> Data?
}

/// No-backend default. Photos stay local-only; sync is a no-op.
struct LocalTeamPhotoStore: TeamPhotoStore {
    var isConfigured: Bool { false }
    func upload(imageData: Data, teamID: String, key: String) async throws {
        throw TeamSyncError.notConfigured
    }
    func download(teamID: String, key: String) async throws -> Data? { nil }
}

/// DEBUG-only in-memory/disk photo store so the publish → download flow can be
/// demonstrated in the simulator without Firebase. Writes into the caches dir,
/// namespaced by team + key, mirroring what Cloud Storage would do.
struct MockTeamPhotoStore: TeamPhotoStore {
    var isConfigured: Bool { true }

    private func fileURL(teamID: String, key: String) -> URL {
        let base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("MockTeamPhotos", isDirectory: true)
            .appendingPathComponent(teamID, isDirectory: true)
        try? FileManager.default.createDirectory(
            at: base.appendingPathComponent((key as NSString).deletingLastPathComponent),
            withIntermediateDirectories: true)
        return base.appendingPathComponent(key)
    }

    func upload(imageData: Data, teamID: String, key: String) async throws {
        try imageData.write(to: fileURL(teamID: teamID, key: key), options: .atomic)
    }

    func download(teamID: String, key: String) async throws -> Data? {
        try? Data(contentsOf: fileURL(teamID: teamID, key: key))
    }
}
