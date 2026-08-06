import Foundation

/// A named competition period a match belongs to.
///
/// Seasons are **explicit and admin-created**, never inferred from match dates.
/// That is not a style choice: `GameParser` stamps `Date()` on every pasted match
/// (`GameParser.swift`), so dates are unreliable for anything already in the log.
/// Explicit seasons also express cups and tournaments, which a calendar cutover
/// cannot.
struct Season: Identifiable, Equatable, Hashable {
    let id: UUID
    var name: String
    /// Informational only — never used to decide which season a match belongs to.
    var startDate: Date?
    var endDate: Date?
    /// Explicit ordering. Do not parse `name` to sort; "Summer Cup" has no year.
    var sortIndex: Int

    init(id: UUID = UUID(), name: String, startDate: Date? = nil, endDate: Date? = nil, sortIndex: Int = 0) {
        self.id = id
        self.name = name
        self.startDate = startDate
        self.endDate = endDate
        self.sortIndex = sortIndex
    }

    /// Conventional label for the season containing `date`, e.g. "2026/27".
    /// Used only to name the season created during migration — after that the
    /// admin owns the name.
    static func conventionalName(for date: Date, calendar: Calendar = .current) -> String {
        let parts = calendar.dateComponents([.year, .month], from: date)
        guard let year = parts.year, let month = parts.month else { return "Season 1" }
        // Northern-hemisphere seasons roll over in summer; July is the cutover.
        let startYear = month >= 7 ? year : year - 1
        let endYear = (startYear + 1) % 100
        return String(format: "%d/%02d", startYear, endYear)
    }
}

/// Which season the UI is currently showing.
///
/// View-only state — deliberately not part of `TeamDocument`, so changing the
/// filter never writes to disk.
enum SeasonScope: Hashable {
    case allTime
    case season(UUID)
    /// Matches with no season, which only arrive from a pre-season-support client.
    case unassigned

    func matches(_ game: TeamGame) -> Bool {
        switch self {
        case .allTime:          return true
        case .season(let id):   return game.seasonID == id
        case .unassigned:       return game.seasonID == nil
        }
    }
}
