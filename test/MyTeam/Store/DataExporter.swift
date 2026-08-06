import Foundation
import UIKit

/// The single funnel for turning team snapshots into `TeamDocument`s and back.
///
/// Every ingress point goes through here — disk load, file import, cloud pull and
/// redeem — so version handling and migration exist in exactly one place.
///
/// ## Compatibility contract
///
/// The v2 schema is **strictly additive**: no key from v1 changed type, meaning,
/// or disappeared, and every new key is optional. Two consequences, both load
/// bearing:
///
/// * A v1 snapshot (no `version` key) decodes here and is migrated forward.
/// * A v2 snapshot still decodes in a shipped v1 client, because we keep writing
///   the *legacy mirror fields* it reads (`PlayerDTO.goals`, `GameDTO.scorers`,
///   `GoalDTO.scorer`). This matters because the same JSON is the cloud wire
///   format — an admin on v2 must not break a viewer still on v1.
enum DataExporter {

    /// Schema version written into every snapshot. Snapshots authored before
    /// versioning omit the key entirely and are treated as version 1.
    static let currentVersion = 2

    /// Why a snapshot could not be turned into a team.
    ///
    /// These are surfaced to the user rather than swallowed: a snapshot that
    /// fails to decode used to look identical to "this device has no team",
    /// which sent the user to onboarding and let the next edit overwrite their
    /// real data with an empty team.
    enum ImportError: LocalizedError {
        /// The bytes are not a readable snapshot (truncated, malformed, foreign).
        case corrupt(String)
        /// Written by a newer build of FTMP than this one understands.
        case tooNew(found: Int, supported: Int)

        var errorDescription: String? {
            switch self {
            case .corrupt(let detail):
                return "This team file couldn't be read. \(detail)"
            case .tooNew(let found, let supported):
                return "This team was saved by a newer version of FTMP (format \(found); this app supports \(supported)). Update the app to open it."
            }
        }
    }

    // MARK: - Wire shapes

    struct ExportData: Codable {
        var players: [PlayerDTO]
        var games: [GameDTO]
        var exportDate: Date
        /// Optional for backward-compatibility with snapshots authored before teams
        /// had a name.
        var teamName: String?
        /// Local role (`user`/`admin`/`viewer`). Only used for on-device restore; the
        /// cloud/redeem path derives the mode from membership, not the snapshot.
        var teamMode: String?
        /// Schema version. Absent in pre-versioning snapshots, which are version 1.
        var version: Int?
        // MARK: v2 additions — all optional so v1 files still decode
        var teamId: String?
        var remoteCode: String?
        var tacticsPlans: [TacticsPlanDTO]?
    }

    struct PlayerDTO: Codable {
        // Legacy mirror fields (read by v1 clients) ------------------------------
        var name: String
        var role: String
        var goals: Int
        var assists: Int
        var bonusPoints: Double
        var gkAttended: Int?
        var gkConceded: Int?
        var gkCleanSheets: Int?
        var coachSpecialty: String?
        var coachTactics: String?
        var coachExperience: String?
        var coachPhilosophy: String?
        var photoPath: String?
        // v2 additions ----------------------------------------------------------
        var id: String?
        var position: String?
    }

    struct GameDTO: Codable {
        var date: Date
        var opponent: String
        var goalsFor: Int
        var goalsAgainst: Int
        /// Denormalized display list ("Alex x2"). Authority is `goals`.
        var scorers: [String]
        var goals: [GoalDTO]
        var mediaLinks: [MediaLinkDTO]
        // v2 additions
        var id: String?
    }

    struct GoalDTO: Codable {
        var time: String
        var scorer: String
        var assist: String
        var isOpponent: Bool
        // v2 additions
        var id: String?
    }

    struct MediaLinkDTO: Codable {
        var title: String
        var urlString: String
        var type: String
        // v2 additions
        var id: String?
    }

    struct TacticsPlanDTO: Codable {
        var id: String
        var name: String
        var formation: String
        var notes: String
        var assignments: [SlotAssignmentDTO]
        var updatedAt: Date
    }

    struct SlotAssignmentDTO: Codable {
        var slotIndex: Int
        var playerId: String?
    }

    // MARK: - Encode

    static func encode(_ doc: TeamDocument) -> Data? {
        let playerDTOs = doc.players.map { p -> PlayerDTO in
            PlayerDTO(
                name: p.name, role: p.role.rawValue,
                goals: p.goals, assists: p.assists, bonusPoints: p.bonusPoints,
                gkAttended: p.goalkeeperStats?.matchesAttended,
                gkConceded: p.goalkeeperStats?.goalsConceded,
                gkCleanSheets: p.goalkeeperStats?.cleanSheets,
                coachSpecialty: p.coachInfo?.specialty,
                coachTactics: p.coachInfo?.tactics,
                coachExperience: p.coachInfo?.experience,
                coachPhilosophy: p.coachInfo?.philosophy,
                photoPath: p.photoPath,
                id: p.id.uuidString,
                position: p.position
            )
        }

        let gameDTOs = doc.games.map { g -> GameDTO in
            GameDTO(
                date: g.date, opponent: g.opponent,
                goalsFor: g.goalsFor, goalsAgainst: g.goalsAgainst,
                scorers: g.scorers,
                goals: g.goalDetails.map {
                    GoalDTO(time: $0.time, scorer: $0.scorer, assist: $0.assist,
                            isOpponent: $0.isOpponent, id: $0.id.uuidString)
                },
                mediaLinks: g.mediaLinks.map {
                    MediaLinkDTO(title: $0.title, urlString: $0.urlString,
                                 type: $0.type.rawValue, id: $0.id.uuidString)
                },
                id: g.id.uuidString
            )
        }

        let tacticsDTOs = doc.tacticsPlans.map { plan in
            TacticsPlanDTO(
                id: plan.id.uuidString, name: plan.name, formation: plan.formation,
                notes: plan.notes,
                assignments: plan.assignments.map {
                    SlotAssignmentDTO(slotIndex: $0.slotIndex, playerId: $0.playerID?.uuidString)
                },
                updatedAt: plan.updatedAt
            )
        }

        let payload = ExportData(
            players: playerDTOs, games: gameDTOs, exportDate: Date(),
            teamName: doc.name, teamMode: doc.mode.rawValue, version: currentVersion,
            teamId: doc.id.uuidString, remoteCode: doc.remoteCode,
            tacticsPlans: tacticsDTOs.isEmpty ? nil : tacticsDTOs
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try? encoder.encode(payload)
    }

    // MARK: - Decode

    /// Decodes any supported snapshot version into today's shape.
    ///
    /// Returns `nil` when the snapshot describes *no team* (a v1 file written
    /// before the user created one). That is distinct from throwing, which means
    /// the bytes exist but cannot be trusted.
    static func decode(_ data: Data) throws -> TeamDocument? {
        try decodeSnapshot(data).document
    }

    /// Decode plus the version the bytes were written at, so the caller can tell a
    /// migration happened and persist the upgraded shape.
    static func decodeSnapshot(_ data: Data) throws -> (document: TeamDocument?, version: Int) {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        // Read the version before the payload: a snapshot from a future build may
        // decode "successfully" into today's shape while silently dropping fields,
        // and writing that back would destroy whatever we failed to understand.
        if let probe = try? decoder.decode(VersionProbe.self, from: data),
           let found = probe.version, found > currentVersion {
            throw ImportError.tooNew(found: found, supported: currentVersion)
        }

        let exported: ExportData
        do {
            exported = try decoder.decode(ExportData.self, from: data)
        } catch {
            throw ImportError.corrupt(describe(error))
        }

        let version = exported.version ?? 1
        guard let name = exported.teamName else { return (nil, version) }

        let players = exported.players.map { dto -> TeamPlayer in
            let role = PlayerRole(rawValue: dto.role) ?? .player
            var p = TeamPlayer(
                id: uuid(dto.id), name: dto.name, role: role,
                goals: dto.goals, assists: dto.assists, bonusPoints: dto.bonusPoints,
                photoPath: dto.photoPath, position: dto.position
            )
            if role == .goalkeeper, let att = dto.gkAttended, let con = dto.gkConceded, let cs = dto.gkCleanSheets {
                p.goalkeeperStats = GoalkeeperStats(matchesAttended: att, goalsConceded: con, cleanSheets: cs)
            }
            if role == .coach {
                p.coachInfo = CoachInfo(specialty: dto.coachSpecialty ?? "", tactics: dto.coachTactics ?? "",
                                       experience: dto.coachExperience ?? "", philosophy: dto.coachPhilosophy ?? "")
            }
            return p
        }

        let games = exported.games.map { dto -> TeamGame in
            TeamGame(
                id: uuid(dto.id),
                date: dto.date, opponent: dto.opponent,
                goalsFor: dto.goalsFor, goalsAgainst: dto.goalsAgainst,
                scorers: dto.scorers,
                goalDetails: dto.goals.map {
                    GoalDetail(id: uuid($0.id), time: $0.time, scorer: $0.scorer,
                               assist: $0.assist, isOpponent: $0.isOpponent)
                },
                mediaLinks: dto.mediaLinks.map {
                    MediaLink(id: uuid($0.id), title: $0.title, urlString: $0.urlString,
                              type: MediaType(rawValue: $0.type) ?? .video)
                }
            )
        }

        let plans = (exported.tacticsPlans ?? []).map { dto in
            TacticsPlan(
                id: uuid(dto.id), name: dto.name, formation: dto.formation, notes: dto.notes,
                assignments: dto.assignments.map { SlotAssignment(slotIndex: $0.slotIndex, playerID: uuid($0.playerId)) },
                updatedAt: dto.updatedAt
            )
        }

        let document = TeamDocument(
            id: uuid(exported.teamId),
            name: name,
            mode: exported.teamMode.flatMap(TeamMode.init(rawValue:)) ?? .user,
            remoteCode: exported.remoteCode,
            players: players,
            games: games,
            tacticsPlans: plans
        )
        return (document, version)
    }

    /// Minimal shape used to read `version` without committing to the full payload.
    private struct VersionProbe: Codable { var version: Int? }

    /// Pre-v2 snapshots carry no ids, so identity is minted on first migration and
    /// persisted from then on.
    private static func uuid(_ raw: String?) -> UUID {
        raw.flatMap(UUID.init(uuidString:)) ?? UUID()
    }

    private static func describe(_ error: Error) -> String {
        guard let decoding = error as? DecodingError else { return error.localizedDescription }
        switch decoding {
        case .dataCorrupted(let ctx):
            return ctx.debugDescription
        case .keyNotFound(let key, _):
            return "Missing field '\(key.stringValue)'."
        case .typeMismatch(_, let ctx), .valueNotFound(_, let ctx):
            let path = ctx.codingPath.map(\.stringValue).joined(separator: ".")
            return path.isEmpty ? ctx.debugDescription : "Unexpected value at '\(path)'."
        @unknown default:
            return decoding.localizedDescription
        }
    }

    // MARK: - File URLs

    static var documentsURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    static var saveURL: URL {
        documentsURL.appendingPathComponent("team_data.json")
    }

    /// One-deep rolling backup, rotated in before each successful overwrite. This
    /// is what "Load Last Save" and the recovery screen restore from.
    static var previousSaveURL: URL {
        documentsURL.appendingPathComponent("team_data.previous.json")
    }

    /// Where unreadable snapshots are *copied* (never moved) so the user can still
    /// export them for support while the app carries on.
    static var quarantineDirectory: URL {
        documentsURL.appendingPathComponent("TeamData/quarantine", isDirectory: true)
    }

    // MARK: - Disk

    static func saveToDisk(_ doc: TeamDocument) throws {
        guard let data = encode(doc) else {
            throw ImportError.corrupt("The team could not be encoded.")
        }
        // Rotate the current save to `.previous` before overwriting, so a bad write
        // or a bad edit is always one step from recoverable.
        if let existing = try? Data(contentsOf: saveURL), !existing.isEmpty {
            try? existing.write(to: previousSaveURL, options: [.atomic])
        }
        // `.atomic` matters: a non-atomic write killed mid-flight leaves a truncated
        // file, which is indistinguishable from "no team" on the next launch.
        try data.write(to: saveURL, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
    }

    /// Reads the saved team. Returns `nil` only when there is genuinely no team —
    /// a file that exists but cannot be read throws, and must not be confused with
    /// a first-run empty state.
    static func loadFromDisk() throws -> TeamDocument? {
        try loadSnapshotFromDisk().document
    }

    /// As `loadFromDisk`, plus whether the bytes needed migrating. Callers should
    /// write the document straight back when `wasMigrated` is true — otherwise the
    /// ids minted during migration are thrown away and re-minted next launch,
    /// which defeats the whole point of persisting them.
    static func loadSnapshotFromDisk() throws -> (document: TeamDocument?, wasMigrated: Bool) {
        guard FileManager.default.fileExists(atPath: saveURL.path) else { return (nil, false) }
        let data: Data
        do {
            data = try Data(contentsOf: saveURL)
        } catch {
            throw ImportError.corrupt(error.localizedDescription)
        }
        guard !data.isEmpty else { throw ImportError.corrupt("The file is empty.") }
        let result = try decodeSnapshot(data)
        return (result.document, result.version < currentVersion)
    }

    /// Restores the rolling backup over the main save. Returns the restored team.
    static func restorePreviousSave() throws -> TeamDocument? {
        let data = try Data(contentsOf: previousSaveURL)
        let restored = try decode(data)
        try data.write(to: saveURL, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        return restored
    }

    static var hasPreviousSave: Bool {
        guard let values = try? previousSaveURL.resourceValues(forKeys: [.fileSizeKey]) else { return false }
        return (values.fileSize ?? 0) > 0
    }

    /// Copies an unreadable snapshot aside for support/export. The original is left
    /// exactly where it is — quarantine must never be the thing that loses the data.
    @discardableResult
    static func quarantineCurrentSave() -> URL? {
        guard let data = try? Data(contentsOf: saveURL) else { return nil }
        let stamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")
        let destination = quarantineDirectory.appendingPathComponent("\(stamp)-team_data.json")
        do {
            try FileManager.default.createDirectory(at: quarantineDirectory, withIntermediateDirectories: true)
            try data.write(to: destination, options: [.atomic])
            return destination
        } catch {
            return nil
        }
    }

    static func deleteFromDisk() {
        try? FileManager.default.removeItem(at: saveURL)
        try? FileManager.default.removeItem(at: previousSaveURL)
    }
}
