import Foundation
import UIKit

struct GoalDetail: Identifiable, Equatable {
    let id: UUID
    var time: String
    /// The scorer's name as written. **Always kept**, even once `scorerID` is
    /// resolved: opponent goals name the opposing club, a guest may never join the
    /// roster, and a v1 client reads this field.
    var scorer: String
    var assist: String
    var isOpponent: Bool
    /// Resolved squad member, when the name could be matched. `nil` means unlinked
    /// — the goal still counts for the team, just not for any player.
    var scorerID: UUID?
    var assistID: UUID?
    /// Synthesized by migration from the flat `scorers` list, so it has no real
    /// minute. Rendered differently, and skipped by any future re-derive pass.
    var isInferred: Bool

    init(
        id: UUID = UUID(),
        time: String,
        scorer: String,
        assist: String = "",
        isOpponent: Bool = false,
        scorerID: UUID? = nil,
        assistID: UUID? = nil,
        isInferred: Bool = false
    ) {
        self.id = id
        self.time = time
        self.scorer = scorer
        self.assist = assist
        self.isOpponent = isOpponent
        self.scorerID = scorerID
        self.assistID = assistID
        self.isInferred = isInferred
    }

    var display: String {
        if isOpponent { return "\(time) - \(scorer)" }
        return assist.isEmpty ? "\(time) - \(scorer)" : "\(time) - \(scorer)/\(assist)"
    }
}

struct TeamGame: Identifiable, Equatable {
    /// Stable across launches as of snapshot v2 (see `TeamPlayer.id`).
    let id: UUID
    /// Which season this match counts towards. `nil` ("Unassigned") only arrives
    /// from a client older than season support — never coerce it to the current
    /// season on read, that would rewrite history.
    var seasonID: UUID?
    var date: Date
    var opponent: String
    var goalsFor: Int
    var goalsAgainst: Int
    var scorers: [String]
    var goalDetails: [GoalDetail]
    var mediaLinks: [MediaLink]
    var highlightImage: UIImage?

    var score: String { "\(goalsFor) - \(goalsAgainst)" }

    var result: TeamGameResult {
        if goalsFor > goalsAgainst { return .win }
        if goalsFor < goalsAgainst { return .loss }
        return .draw
    }

    init(
        id: UUID = UUID(),
        seasonID: UUID? = nil,
        date: Date = Date(),
        opponent: String = "",
        goalsFor: Int = 0,
        goalsAgainst: Int = 0,
        scorers: [String] = [],
        goalDetails: [GoalDetail] = [],
        mediaLinks: [MediaLink] = [],
        highlightImage: UIImage? = nil
    ) {
        self.id = id
        self.seasonID = seasonID
        self.date = date
        self.opponent = opponent
        self.goalsFor = goalsFor
        self.goalsAgainst = goalsAgainst
        self.scorers = scorers
        self.goalDetails = goalDetails
        self.mediaLinks = mediaLinks
        self.highlightImage = highlightImage
    }

    /// Persisted state only — `highlightImage` is a hydrated side-car image
    /// (see `TeamPlayer.==`).
    static func == (lhs: TeamGame, rhs: TeamGame) -> Bool {
        lhs.id == rhs.id
            && lhs.seasonID == rhs.seasonID
            && lhs.date == rhs.date
            && lhs.opponent == rhs.opponent
            && lhs.goalsFor == rhs.goalsFor
            && lhs.goalsAgainst == rhs.goalsAgainst
            && lhs.scorers == rhs.scorers
            && lhs.goalDetails == rhs.goalDetails
            && lhs.mediaLinks == rhs.mediaLinks
    }
}

enum TeamGameResult: String {
    case win = "W"
    case loss = "L"
    case draw = "D"
}

struct MediaLink: Identifiable, Equatable {
    let id: UUID
    var title: String
    var urlString: String
    var type: MediaType

    var url: URL? { URL(string: urlString) }

    init(id: UUID = UUID(), title: String = "", urlString: String = "", type: MediaType = .video) {
        self.id = id
        self.title = title
        self.urlString = urlString
        self.type = type
    }
}

enum MediaType: String, CaseIterable, Identifiable {
    case video = "Video"
    case photo = "Photo"
    case highlights = "Highlights"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .video:      return "play.rectangle.fill"
        case .photo:      return "photo.fill"
        case .highlights: return "star.square.on.square.fill"
        }
    }
}
