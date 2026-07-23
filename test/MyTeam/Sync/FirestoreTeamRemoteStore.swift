//  Firestore implementation of `TeamRemoteStore`.
//
//  This whole file is inert until the Firebase SDK is added to the app target
//  (SPM: firebase-ios-sdk → FirebaseAuth, FirebaseFirestore, FirebaseFunctions),
//  so it never breaks the build in its absence. Once the SDK is present and
//  `FirebaseApp.configure()` runs at launch, wire it up in place of
//  `LocalTeamRemoteStore`:
//
//      let remote = FirestoreTeamRemoteStore()
//      let sync = TeamSyncService(remote: remote)
//
//  Team creation and code redemption go through the Cloud Functions in
//  `firebase/functions/index.js` (they must run server-side); publishing and
//  fetching team data talk to Firestore directly, gated by `firestore.rules`.

#if canImport(FirebaseFirestore) && canImport(FirebaseFunctions) && canImport(FirebaseAuth)
import Foundation
import FirebaseAuth
import FirebaseFirestore
import FirebaseFunctions

struct FirestoreTeamRemoteStore: TeamRemoteStore {
    private let db = Firestore.firestore()
    private let functions = Functions.functions()

    var isConfigured: Bool { true }

    /// Ensures we have a (possibly anonymous) auth session before any call.
    private func ensureSignedIn() async throws {
        if Auth.auth().currentUser == nil {
            try await Auth.auth().signInAnonymously()
        }
    }

    func createTeam(name: String) async throws -> String {
        try await ensureSignedIn()
        let result = try await functions.httpsCallable("createTeam").call(["name": name])
        guard let dict = result.data as? [String: Any], let teamID = dict["teamId"] as? String else {
            throw TeamSyncError.network("Unexpected server response.")
        }
        try await refreshClaims()
        return teamID
    }

    func redeem(code: String) async throws -> TeamMembership {
        try await ensureSignedIn()
        do {
            let result = try await functions.httpsCallable("redeemCode").call(["code": code])
            guard let dict = result.data as? [String: Any],
                  let teamID = dict["teamId"] as? String,
                  let roleRaw = dict["role"] as? String,
                  let role = TeamRole(rawValue: roleRaw) else {
                throw TeamSyncError.invalidCode
            }
            try await refreshClaims()
            return TeamMembership(teamID: teamID, role: role)
        } catch let error as NSError where error.domain == FunctionsErrorDomain {
            throw TeamSyncError.network(error.localizedDescription)
        }
    }

    func publish(teamID: String, snapshotJSON: Data) async throws {
        try await ensureSignedIn()
        let object = try JSONSerialization.jsonObject(with: snapshotJSON)
        guard let payload = object as? [String: Any] else {
            throw TeamSyncError.network("Could not encode team data.")
        }
        try await db.collection("teams").document(teamID).setData([
            "data": payload,
            "updatedAt": FieldValue.serverTimestamp(),
            "updatedBy": Auth.auth().currentUser?.uid ?? "",
        ], merge: true)
    }

    func fetchSnapshot(teamID: String) async throws -> Data? {
        try await ensureSignedIn()
        let snapshot = try await db.collection("teams").document(teamID).getDocument()
        guard let payload = snapshot.data()?["data"] as? [String: Any] else { return nil }
        return try JSONSerialization.data(withJSONObject: payload)
    }

    /// Custom claims (team access, used by Storage rules) update on the server;
    /// force a token refresh so they take effect on this device immediately.
    private func refreshClaims() async throws {
        _ = try await Auth.auth().currentUser?.getIDTokenResult(forcingRefresh: true)
    }
}
#endif
