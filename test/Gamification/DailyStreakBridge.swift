import Foundation
import WidgetKit

/// Shared App Group keys so the Home Screen widget can read the daily streak.
enum DailyStreakBridge {
    static let appGroupID = "group.com.ftmpapp.app"

    enum Key {
        static let streak = "dailyStreak"
        static let completedToday = "dailyCompletedToday"
        static let dayLabel = "dailyDayLabel"
        static let updatedAt = "dailyStreakUpdatedAt"
        /// Start-of-day timestamp for the last completed Daily (widget derives "today").
        static let lastCompletedDay = "dailyLastCompletedDay"
    }

    private static var suite: UserDefaults? {
        UserDefaults(suiteName: appGroupID)
    }

    struct Snapshot: Equatable {
        var streak: Int
        var completedToday: Bool
        var dayLabel: String

        static let empty = Snapshot(streak: 0, completedToday: false, dayLabel: "")
    }

    /// Writes streak state into the App Group and asks WidgetKit to reload.
    /// Always pass `lastCompleted` from `GameProgress.dailyLastCompleted` so the
    /// widget can derive "done today" / dead streaks without waiting for the app.
    static func publish(
        streak: Int,
        completedToday: Bool,
        lastCompleted: Date? = nil,
        dayLabel: String = DailyChallenge.label()
    ) {
        guard let suite else { return }
        suite.set(streak, forKey: Key.streak)
        suite.set(completedToday, forKey: Key.completedToday)
        suite.set(dayLabel, forKey: Key.dayLabel)
        suite.set(Date().timeIntervalSince1970, forKey: Key.updatedAt)
        if let last = lastCompleted {
            let start = Calendar.current.startOfDay(for: last).timeIntervalSince1970
            suite.set(start, forKey: Key.lastCompletedDay)
        } else {
            suite.removeObject(forKey: Key.lastCompletedDay)
        }
        WidgetCenter.shared.reloadTimelines(ofKind: DailyStreakWidgetKind.id)
    }

    /// Wipe App Group streak keys (Settings → Reset All Data).
    static func clear() {
        guard let suite else { return }
        for key in [Key.streak, Key.completedToday, Key.dayLabel, Key.updatedAt, Key.lastCompletedDay] {
            suite.removeObject(forKey: key)
        }
        WidgetCenter.shared.reloadTimelines(ofKind: DailyStreakWidgetKind.id)
    }

    static func load() -> Snapshot {
        guard let suite else { return .empty }
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let lastRaw = suite.double(forKey: Key.lastCompletedDay)
        let lastDay = lastRaw > 0 ? Date(timeIntervalSince1970: lastRaw) : nil

        if let last = lastDay {
            let dayGap = cal.dateComponents([.day], from: cal.startOfDay(for: last), to: today).day ?? 999
            let storedStreak = suite.integer(forKey: Key.streak)
            return Snapshot(
                streak: dayGap <= 2 ? storedStreak : 0,
                completedToday: dayGap == 0,
                dayLabel: suite.string(forKey: Key.dayLabel) ?? DailyChallenge.label()
            )
        }

        // Legacy App Group data (pre–lastCompletedDay): trust the bool + streak.
        return Snapshot(
            streak: suite.integer(forKey: Key.streak),
            completedToday: suite.bool(forKey: Key.completedToday),
            dayLabel: suite.string(forKey: Key.dayLabel) ?? DailyChallenge.label()
        )
    }
}

enum DailyStreakWidgetKind {
    static let id = "DailyStreakWidget"
}

enum FTMPDeepLink {
    static let scheme = "ftmp"
    static let dailyHost = "daily"
    static let dailyURL = URL(string: "ftmp://daily")!

    static func isDaily(_ url: URL) -> Bool {
        url.scheme?.lowercased() == scheme && url.host?.lowercased() == dailyHost
    }
}
