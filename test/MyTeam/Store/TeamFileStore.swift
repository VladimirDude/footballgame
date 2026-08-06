import Foundation

/// Where one team's snapshot lives on disk, and the safe read/write rules for it.
///
/// Teams get a file each rather than sharing one blob: a corrupt file then costs
/// one team instead of all of them, and the cloud unit of sharing is a single team
/// anyway.
///
/// The legacy single-slot path (`Documents/team_data.json`) is still written for
/// whichever team is active, so installing an older build finds a team where it
/// expects one instead of showing onboarding over live data.
struct TeamFileStore {
    let directory: URL
    let basename: String

    /// The pre-multi-team location. Kept forever.
    static let legacy = TeamFileStore(
        directory: DataExporter.documentsURL,
        basename: "team_data"
    )

    static func team(_ id: UUID) -> TeamFileStore {
        TeamFileStore(
            directory: DataExporter.documentsURL
                .appendingPathComponent("TeamData/teams/\(id.uuidString)", isDirectory: true),
            basename: "team"
        )
    }

    var fileURL: URL { directory.appendingPathComponent("\(basename).json") }
    var previousURL: URL { directory.appendingPathComponent("\(basename).previous.json") }

    // MARK: - Read

    func load() throws -> (document: TeamDocument?, wasMigrated: Bool) {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return (nil, false) }
        let data: Data
        do {
            data = try Data(contentsOf: fileURL)
        } catch {
            throw DataExporter.ImportError.corrupt(error.localizedDescription)
        }
        guard !data.isEmpty else { throw DataExporter.ImportError.corrupt("The file is empty.") }
        let result = try DataExporter.decodeSnapshot(data)
        return (result.document, result.version < DataExporter.currentVersion)
    }

    // MARK: - Write

    func save(_ doc: TeamDocument) throws {
        guard let data = DataExporter.encode(doc) else {
            throw DataExporter.ImportError.corrupt("The team could not be encoded.")
        }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        // Rotate before overwriting, so a bad write or a bad edit is always one
        // step from recoverable.
        if let existing = try? Data(contentsOf: fileURL), !existing.isEmpty {
            try? existing.write(to: previousURL, options: [.atomic])
        }
        // `.atomic`: a write killed mid-flight would otherwise leave a truncated
        // file that reads as "no team".
        try data.write(to: fileURL, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
    }

    func restorePrevious() throws -> TeamDocument? {
        let data = try Data(contentsOf: previousURL)
        let restored = try DataExporter.decode(data)
        try data.write(to: fileURL, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        return restored
    }

    var hasPrevious: Bool {
        guard let values = try? previousURL.resourceValues(forKeys: [.fileSizeKey]) else { return false }
        return (values.fileSize ?? 0) > 0
    }

    /// Copies an unreadable snapshot aside. The original stays put — quarantine
    /// must never be the thing that loses the data.
    @discardableResult
    func quarantine() -> URL? {
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        let stamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")
        let destination = DataExporter.quarantineDirectory
            .appendingPathComponent("\(stamp)-\(basename).json")
        do {
            try FileManager.default.createDirectory(at: DataExporter.quarantineDirectory, withIntermediateDirectories: true)
            try data.write(to: destination, options: [.atomic])
            return destination
        } catch {
            return nil
        }
    }

    func delete() {
        try? FileManager.default.removeItem(at: fileURL)
        try? FileManager.default.removeItem(at: previousURL)
    }
}

/// Which teams exist and which one is open.
///
/// A cache of a fact that lives elsewhere — if it goes missing it is rebuilt by
/// scanning the teams directory rather than failing.
struct TeamsIndex: Codable {
    struct Entry: Codable, Identifiable {
        var id: UUID
        var name: String
        var mode: String
        var remoteCode: String?
    }

    var version: Int = 1
    var teams: [Entry] = []
    var activeTeamID: UUID?

    static var fileURL: URL {
        DataExporter.documentsURL.appendingPathComponent("TeamData/index.json")
    }

    static func load() -> TeamsIndex? {
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        return try? JSONDecoder().decode(TeamsIndex.self, from: data)
    }

    func save() {
        guard let data = try? JSONEncoder().encode(self) else { return }
        let dir = Self.fileURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try? data.write(to: Self.fileURL, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
    }

    /// Team ids that actually have a folder on disk.
    static func teamIDsOnDisk() -> [UUID] {
        let root = DataExporter.documentsURL.appendingPathComponent("TeamData/teams", isDirectory: true)
        let contents = (try? FileManager.default.contentsOfDirectory(atPath: root.path)) ?? []
        return contents.compactMap(UUID.init(uuidString:))
    }
}
