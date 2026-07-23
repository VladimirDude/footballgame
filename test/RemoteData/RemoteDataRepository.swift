import Foundation
import CryptoKit

/// Offline-first data repository.
///
/// **Read path (synchronous, used at launch):** `currentDatabaseURL` returns the
/// downloaded copy if one exists, otherwise the bundled seed. So the app always
/// has data instantly and works with no network.
///
/// **Refresh path (async, background):** `refreshIfNeeded()` checks the CDN
/// manifest; if a newer `version` is available it downloads and validates the
/// database, then caches it. The new data is picked up on the **next launch** —
/// a deliberately low-risk "download now, apply next launch" model that avoids
/// rewriting the synchronous read path in `ClubDataStore`.
final class RemoteDataRepository: @unchecked Sendable {
    static let shared = RemoteDataRepository()

    private let source: RemoteDataSource
    private let cache: DataCache

    init(source: RemoteDataSource = HTTPRemoteDataSource(), cache: DataCache = .shared) {
        self.source = source
        self.cache = cache
    }

    /// The database file the app should read right now: cache first, bundle seed
    /// as fallback. Never `nil` in a correctly-built app (the seed always ships).
    var currentDatabaseURL: URL? {
        cache.cachedDatabaseURL() ?? Bundle.main.url(forResource: "ClubDatabase", withExtension: "json")
    }

    /// Image URL templates currently in effect (manifest overrides the static
    /// config once we've seen a manifest). Used by the image loaders.
    var portraitURLTemplate: String? {
        cache.cachedManifest()?.portraitURLTemplate ?? RemoteDataConfig.portraitURLTemplate
    }
    var logoURLTemplate: String? {
        cache.cachedManifest()?.logoURLTemplate ?? RemoteDataConfig.logoURLTemplate
    }

    /// Fetches a remote image by URL, caching it to disk. Returns the local file
    /// URL of the cached copy, or `nil` on failure. Safe to call off-main.
    func remoteImage(url: URL, cacheKey: String) async -> URL? {
        if let cached = cache.cachedImageURL(for: cacheKey) { return cached }
        guard let data = try? await source.fetchData(from: url), !data.isEmpty else { return nil }
        cache.storeImage(data, for: cacheKey)
        return cache.cachedImageURL(for: cacheKey)
    }

    /// Checks the manifest and downloads a newer database if available. No-op
    /// when offline (`RemoteDataConfig.manifestURL == nil`). Call once at launch.
    @discardableResult
    func refreshIfNeeded() async -> Bool {
        guard RemoteDataConfig.isOnline else { return false }
        do {
            let manifest = try await source.fetchManifest()
            let currentVersion = cache.cachedManifest()?.version ?? 0
            guard manifest.version > currentVersion else {
                // Still store it so image templates stay fresh.
                cache.store(manifest: manifest)
                return false
            }

            let data = try await source.fetchData(from: manifest.database.url)
            if let expected = manifest.database.sha256 {
                let actual = Self.sha256(of: data)
                guard actual.caseInsensitiveCompare(expected) == .orderedSame else {
                    throw RemoteDataError.checksumMismatch
                }
            }
            try cache.storeDatabase(data)
            cache.store(manifest: manifest)
            AnalyticsService.shared.log(.screenViewed(name: "data_refreshed_v\(manifest.version)"))
            return true
        } catch {
            #if DEBUG
            print("⚠️ RemoteDataRepository refresh failed: \(error)")
            #endif
            return false
        }
    }

    private static func sha256(of data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}
