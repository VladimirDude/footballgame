import Foundation

/// Everything persisted for one team.
///
/// Collapsing the store's saved state into a single value type is what lets the
/// autosave pipeline be `$doc.removeDuplicates().debounce(...)` instead of a
/// `CombineLatest` over individual properties. "What gets saved" becomes one
/// reviewable type rather than an emergent property of a Combine operator, and
/// view-only state (search text, sort order, season scope) cannot accidentally
/// enrol itself in the save path.
struct TeamDocument: Equatable {
    /// Local identity, minted at creation and never changed. Distinct from
    /// `remoteCode`: going live assigns a code, it does not re-identify the team.
    let id: UUID
    var name: String
    var mode: TeamMode
    /// Cloud address ("FTMP-8XK2Q-P4M9"). `nil` until the team is published.
    var remoteCode: String?
    var players: [TeamPlayer]
    var games: [TeamGame]
    /// Empty until the tactics board ships. Persisted now so that feature needs no
    /// further schema migration — its slot assignments reference `TeamPlayer.id`,
    /// which only becomes stable with snapshot v2.
    var tacticsPlans: [TacticsPlan]

    init(
        id: UUID = UUID(),
        name: String,
        mode: TeamMode = .user,
        remoteCode: String? = nil,
        players: [TeamPlayer] = [],
        games: [TeamGame] = [],
        tacticsPlans: [TacticsPlan] = []
    ) {
        self.id = id
        self.name = name
        self.mode = mode
        self.remoteCode = remoteCode
        self.players = players
        self.games = games
        self.tacticsPlans = tacticsPlans
    }
}

// MARK: - Tactics seam

/// A saved formation and its player assignments.
///
/// Declared and persisted ahead of the tactics board so the board is later pure
/// UI. `formation` is free text for now; it can become an enum without a format
/// change because the wire representation stays a string.
struct TacticsPlan: Identifiable, Equatable {
    let id: UUID
    var name: String
    var formation: String
    var notes: String
    var assignments: [SlotAssignment]
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        name: String = "",
        formation: String = "",
        notes: String = "",
        assignments: [SlotAssignment] = [],
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.formation = formation
        self.notes = notes
        self.assignments = assignments
        self.updatedAt = updatedAt
    }
}

struct SlotAssignment: Equatable {
    var slotIndex: Int
    var playerID: UUID?

    init(slotIndex: Int, playerID: UUID? = nil) {
        self.slotIndex = slotIndex
        self.playerID = playerID
    }
}
