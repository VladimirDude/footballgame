import Foundation

/// One multiple-choice question in the Daily Challenge.
struct DailyQuestion: Identifiable, Equatable {
    let id: Int
    let prompt: String
    let clubID: String?       // show a club crest if set
    let portraitID: String?   // show a player portrait if set
    let options: [String]
    let correctIndex: Int

    var correctAnswer: String { options[correctIndex] }
}

/// Deterministic RNG so a given day always produces the same challenge.
struct DailySeededRNG: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) { state = seed == 0 ? 0x9E3779B97F4A7C15 : seed }
    mutating func next() -> UInt64 {
        state ^= state << 13
        state ^= state >> 7
        state ^= state << 17
        return state
    }
}

enum DailyChallenge {
    static let questionCount = 5

    /// A stable seed for the calendar day (YYYYMMDD).
    static func seed(for date: Date = Date()) -> UInt64 {
        let c = Calendar.current.dateComponents([.year, .month, .day], from: date)
        let value = (c.year ?? 2026) * 10_000 + (c.month ?? 1) * 100 + (c.day ?? 1)
        return UInt64(value)
    }

    /// A friendly label for today (e.g. "Mon 27 Jul").
    static func label(for date: Date = Date()) -> String {
        let f = DateFormatter()
        f.dateFormat = "EEE d MMM"
        return f.string(from: date)
    }
}
