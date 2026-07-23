//  Firebase Remote Config wrapper.
//  Guarded so the app builds without the SDK. Fetches server-driven config —
//  currently the admin passphrase — and applies it to `AdminAccess`.
//
//  In the Firebase console: Engage → Remote Config → add a parameter
//  `admin_passphrase` with your secret, then Publish. The app picks it up on the
//  next fetch (immediately in DEBUG; within `minimumFetchInterval` in release).

#if canImport(FirebaseRemoteConfig)
import Foundation
import FirebaseRemoteConfig

@MainActor
final class RemoteConfigService {
    static let shared = RemoteConfigService()

    private let remoteConfig: RemoteConfig

    private init() {
        remoteConfig = RemoteConfig.remoteConfig()
        let settings = RemoteConfigSettings()
        // DEBUG fetches on every launch; release throttles to hourly.
        #if DEBUG
        settings.minimumFetchInterval = 0
        #else
        settings.minimumFetchInterval = 3600
        #endif
        remoteConfig.configSettings = settings
        // Seed defaults so a value exists before the first fetch completes.
        remoteConfig.setDefaults([
            AdminAccess.remoteConfigKey: AdminAccess.fallbackPassphrase as NSObject
        ])
    }

    /// Call once at launch (after `FirebaseApp.configure()`).
    func start() {
        applyCachedValues()
        Task {
            do {
                try await remoteConfig.fetchAndActivate()
                applyCachedValues()
            } catch {
                #if DEBUG
                print("⚠️ RemoteConfig fetch failed: \(error.localizedDescription)")
                #endif
            }
        }
    }

    private func applyCachedValues() {
        let value = remoteConfig[AdminAccess.remoteConfigKey].stringValue
        if !value.isEmpty {
            AdminAccess.remotePassphrase = value
        }
    }
}
#endif
