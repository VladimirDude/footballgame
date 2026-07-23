//  Cloud Storage implementation of `TeamPhotoStore`.
//  Inert until FirebaseStorage is added to the target (SPM: firebase-ios-sdk →
//  FirebaseStorage), so it never breaks the build in its absence.
//
//  Photo path in the bucket:  teams/{teamID}/{key}   e.g. teams/abc/players/UUID.jpg
//  Access is gated by `storage.rules` using the `teams`/`adminTeams` custom
//  claims set by the redeem/create Cloud Functions.

#if canImport(FirebaseStorage)
import Foundation
import FirebaseStorage

struct FirebaseTeamPhotoStore: TeamPhotoStore {
    private let storage = Storage.storage()
    var isConfigured: Bool { true }

    private func ref(teamID: String, key: String) -> StorageReference {
        storage.reference().child("teams/\(teamID)/\(key)")
    }

    func upload(imageData: Data, teamID: String, key: String) async throws {
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"
        _ = try await ref(teamID: teamID, key: key).putDataAsync(imageData, metadata: metadata)
    }

    func download(teamID: String, key: String) async throws -> Data? {
        // 5 MB cap matches storage.rules.
        try await ref(teamID: teamID, key: key).data(maxSize: 5 * 1024 * 1024)
    }
}
#endif
