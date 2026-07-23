import Foundation
import UIKit

struct GoalDetail: Identifiable {
    let id: UUID
    var time: String
    var scorer: String
    var assist: String
    var isOpponent: Bool

    init(id: UUID = UUID(), time: String, scorer: String, assist: String = "", isOpponent: Bool = false) {
        self.id = id; self.time = time; self.scorer = scorer; self.assist = assist; self.isOpponent = isOpponent
    }

    var display: String {
        if isOpponent { return "\(time) - \(scorer)" }
        return assist.isEmpty ? "\(time) - \(scorer)" : "\(time) - \(scorer)/\(assist)"
    }
}

struct TeamGame: Identifiable {
    let id: UUID
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
        self.date = date
        self.opponent = opponent
        self.goalsFor = goalsFor
        self.goalsAgainst = goalsAgainst
        self.scorers = scorers
        self.goalDetails = goalDetails
        self.mediaLinks = mediaLinks
        self.highlightImage = highlightImage
    }
}

enum TeamGameResult: String {
    case win = "W"
    case loss = "L"
    case draw = "D"
}

struct MediaLink: Identifiable {
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
