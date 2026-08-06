import Foundation

/// Single switch that takes the app from offline (bundle-only) to online.
///
/// Point `manifestURL` at your hosted `manifest.json` (Firebase Hosting under
/// `web/data/`, or any CDN). The app checks it on launch and downloads a newer
/// `ClubDatabase.json` in the background when `version` increases.
///
/// Publish updates with: `python3 scripts/publish_remote_data.py --upload`
enum RemoteDataConfig {
    /// URL of the small version manifest checked on launch. `nil` = stay offline
    /// (bundled DB only). Publish updates with:
    ///   python3 scripts/publish_remote_data.py --upload
    static let manifestURL = URL(string: "https://ftmp-8a367.web.app/data/manifest.json")

    /// Template for a player portrait, with `{id}` where the player id goes.
    /// e.g. "https://cdn.example.com/portraits/{id}.heic"
    static let portraitURLTemplate: String? = nil

    /// Template for a club logo, with `{id}` where the club id goes.
    /// e.g. "https://cdn.example.com/logos/{id}.png"
    static let logoURLTemplate: String? = nil

    /// Whether online refresh is enabled at all.
    static var isOnline: Bool { manifestURL != nil }

    static func portraitURL(id: String, override template: String? = nil) -> URL? {
        url(from: template ?? portraitURLTemplate, id: id)
    }

    static func logoURL(id: String, override template: String? = nil) -> URL? {
        url(from: template ?? logoURLTemplate, id: id)
    }

    private static func url(from template: String?, id: String) -> URL? {
        guard let template else { return nil }
        let encoded = id.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? id
        return URL(string: template.replacingOccurrences(of: "{id}", with: encoded))
    }
}

/// The version manifest fetched from the CDN. Kept tiny so the launch check is
/// cheap; the app only downloads the (larger) database when `version` increases.
///
/// Example `manifest.json`:
/// ```json
/// {
///   "version": 42,
///   "updatedAt": "2026-07-24T10:00:00Z",
///   "database": { "url": "https://…/ClubDatabase.json", "sha256": "…" },
///   "portraitURLTemplate": "https://…/portraits/{id}.heic",
///   "logoURLTemplate": "https://…/logos/{id}.png"
/// }
/// ```
struct DataManifest: Codable, Equatable, Sendable {
    struct Asset: Codable, Equatable, Sendable {
        let url: URL
        var sha256: String?
    }

    let version: Int
    var updatedAt: Date?
    let database: Asset
    var portraitURLTemplate: String?
    var logoURLTemplate: String?
}
