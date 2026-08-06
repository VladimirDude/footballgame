import Foundation
import UIKit

/// On-disk store for team images, keyed by the owning entity's `UUID`.
///
/// Images live beside the snapshot rather than inside it for two reasons: JSON is
/// the wrong container for megabytes of JPEG, and `TeamDocument` has to be
/// `Equatable` for the autosave pipeline — `UIImage` identity would make every
/// hydration look like an edit.
///
/// Before this existed nothing persisted images at all: `photo`, `highlightImage`
/// and `teamIcon` were in-memory only, so a local team lost every picture on
/// relaunch. Only `photoPath` (a *cloud* key, set on publish) survived.
enum TeamImageStore {

    private static let compressionQuality: CGFloat = 0.85

    private static var root: URL {
        DataExporter.documentsURL.appendingPathComponent("TeamData/images", isDirectory: true)
    }

    private enum Kind: String {
        case player = "player"
        case highlight = "highlight"
        case icon = "icon"
    }

    private static func url(_ kind: Kind, _ id: UUID) -> URL {
        root.appendingPathComponent("\(kind.rawValue)-\(id.uuidString).jpg")
    }

    /// Team icons are per-team, keyed by the document id.
    private static func iconURL(_ teamID: UUID) -> URL { url(.icon, teamID) }

    // MARK: - Read

    static func playerPhoto(_ playerID: UUID) -> UIImage? { load(url(.player, playerID)) }
    static func highlight(_ gameID: UUID) -> UIImage? { load(url(.highlight, gameID)) }
    static func teamIcon(_ teamID: UUID) -> UIImage? { load(iconURL(teamID)) }

    private static func load(_ url: URL) -> UIImage? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return UIImage(data: data)
    }

    // MARK: - Write

    static func setPlayerPhoto(_ image: UIImage?, for playerID: UUID) { write(image, to: url(.player, playerID)) }
    static func setHighlight(_ image: UIImage?, for gameID: UUID) { write(image, to: url(.highlight, gameID)) }
    static func setTeamIcon(_ image: UIImage?, for teamID: UUID) { write(image, to: iconURL(teamID)) }

    private static func write(_ image: UIImage?, to url: URL) {
        guard let image, let data = image.jpegData(compressionQuality: compressionQuality) else {
            try? FileManager.default.removeItem(at: url)
            return
        }
        try? FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try? data.write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
    }

    // MARK: - Hydrate / prune

    /// Fills a freshly decoded document with its images. Called after every load,
    /// import and cloud pull.
    static func hydrate(_ doc: inout TeamDocument) {
        for i in doc.players.indices {
            doc.players[i].photo = playerPhoto(doc.players[i].id)
        }
        for i in doc.games.indices {
            doc.games[i].highlightImage = highlight(doc.games[i].id)
        }
    }

    /// Writes back any in-memory image that isn't on disk yet. Used after an
    /// import or migration, where images arrive attached to the models rather
    /// than through the normal per-edit write path.
    static func persistAll(_ doc: TeamDocument) {
        for player in doc.players where player.photo != nil {
            setPlayerPhoto(player.photo, for: player.id)
        }
        for game in doc.games where game.highlightImage != nil {
            setHighlight(game.highlightImage, for: game.id)
        }
    }

    /// Deletes images whose owner no longer exists, plus this team's icon.
    static func deleteAll(for doc: TeamDocument) {
        for player in doc.players { setPlayerPhoto(nil, for: player.id) }
        for game in doc.games { setHighlight(nil, for: game.id) }
        setTeamIcon(nil, for: doc.id)
    }
}
