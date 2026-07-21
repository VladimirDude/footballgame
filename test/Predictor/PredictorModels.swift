import Foundation

// MARK: - Fixtures

struct PLFixturesDatabase: Codable {
    let updatedAt: String
    let season: String
    let sourceURL: String
    let gameweeks: [PLGameweek]
}

struct PLGameweek: Codable, Identifiable, Equatable {
    let number: Int
    let startsAt: String
    let endsAt: String
    let matches: [PLMatch]

    var id: Int { number }

    var isComplete: Bool {
        matches.allSatisfy(\.isFinished)
    }

    var finishedCount: Int {
        matches.filter(\.isFinished).count
    }

    var kickoffDate: Date? {
        matches.compactMap(\.kickoffDate).min()
    }

    var deadlineDate: Date? {
        kickoffDate
    }
}

struct PLMatch: Codable, Identifiable, Equatable {
    let id: String
    let gameweek: Int
    let kickoff: String
    let homeTeam: String
    let awayTeam: String
    let homeClubID: String?
    let awayClubID: String?
    let result: PLMatchResult?

    var kickoffDate: Date? {
        PLPredictorFormat.parseISO(kickoff)
    }

    var isFinished: Bool {
        result != nil
    }

    var displayKickoff: String {
        guard let date = kickoffDate else { return kickoff }
        return PLPredictorFormat.kickoffFormatter.string(from: date)
    }
}

struct PLMatchResult: Codable, Equatable {
    let homeGoals: Int
    let awayGoals: Int
    let outcome: String // H, D, A
}

// MARK: - Predictions

enum PLPick: String, Codable, CaseIterable, Identifiable {
    case home
    case draw
    case away

    var id: String { rawValue }

    var label: String {
        switch self {
        case .home: "Home"
        case .draw: "Draw"
        case .away: "Away"
        }
    }

    var shortLabel: String {
        switch self {
        case .home: "H"
        case .draw: "D"
        case .away: "A"
        }
    }

    func matches(result: PLMatchResult) -> Bool {
        switch self {
        case .home: result.outcome == "H"
        case .draw: result.outcome == "D"
        case .away: result.outcome == "A"
        }
    }
}

struct PLGameweekPrediction: Codable, Equatable {
    var picks: [String: PLPick]
    let submittedAt: String?

    static func empty() -> PLGameweekPrediction {
        PLGameweekPrediction(picks: [:], submittedAt: nil)
    }

    func isLocked(for gameweek: PLGameweek, now: Date = .now) -> Bool {
        if submittedAt != nil { return true }
        guard let deadline = gameweek.deadlineDate else { return false }
        return now >= deadline
    }

    func pick(for match: PLMatch) -> PLPick? {
        picks[match.id]
    }

    func isComplete(for gameweek: PLGameweek) -> Bool {
        gameweek.matches.allSatisfy { picks[$0.id] != nil }
    }
}

struct PLGameweekScore: Equatable {
    let points: Int
    let maxPoints: Int
    let correct: Int
    let total: Int

    var summary: String {
        "\(points) pts · \(correct)/\(total) correct"
    }
}

struct PLModelOdds: Equatable {
    let home: Double
    let draw: Double
    let away: Double

    var favorite: PLPick {
        if home >= draw && home >= away { return .home }
        if draw >= home && draw >= away { return .draw }
        return .away
    }

    func probability(for pick: PLPick) -> Double {
        switch pick {
        case .home: home
        case .draw: draw
        case .away: away
        }
    }
}

enum PLPredictorFormat {
    static let kickoffFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE d MMM · HH:mm"
        return formatter
    }()

    static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM"
        return formatter
    }()

    static func parseISO(_ value: String) -> Date? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        return formatter.date(from: value)
    }

    static func isoNow() -> String {
        ISO8601DateFormatter().string(from: Date())
    }
}
