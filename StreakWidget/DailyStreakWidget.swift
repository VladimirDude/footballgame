import WidgetKit
import SwiftUI

/// Minimal duplicate of the app-group bridge — widget target can't see `test/`.
private enum WidgetStreakStore {
    static let appGroupID = "group.com.ftmpapp.app"
    static let kind = "DailyStreakWidget"

    static func load() -> (streak: Int, completedToday: Bool, dayLabel: String) {
        let suite = UserDefaults(suiteName: appGroupID)
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())

        let lastCompleted: Date? = {
            let raw = suite?.double(forKey: "dailyLastCompletedDay") ?? 0
            guard raw > 0 else { return nil }
            return Date(timeIntervalSince1970: raw)
        }()

        let label: String = {
            let f = DateFormatter()
            f.dateFormat = "EEE d MMM"
            return f.string(from: Date())
        }()

        if let last = lastCompleted {
            let dayGap = cal.dateComponents([.day], from: cal.startOfDay(for: last), to: today).day ?? 999
            let storedStreak = suite?.integer(forKey: "dailyStreak") ?? 0
            return (
                dayGap <= 2 ? storedStreak : 0,
                dayGap == 0,
                label
            )
        }

        // Legacy keys written before lastCompletedDay existed.
        return (
            suite?.integer(forKey: "dailyStreak") ?? 0,
            suite?.bool(forKey: "dailyCompletedToday") ?? false,
            label
        )
    }
}

struct DailyStreakEntry: TimelineEntry {
    let date: Date
    let streak: Int
    let completedToday: Bool
    let dayLabel: String
}

struct DailyStreakProvider: TimelineProvider {
    func placeholder(in context: Context) -> DailyStreakEntry {
        DailyStreakEntry(date: .now, streak: 7, completedToday: true, dayLabel: "Mon 6 Aug")
    }

    func getSnapshot(in context: Context, completion: @escaping (DailyStreakEntry) -> Void) {
        completion(makeEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<DailyStreakEntry>) -> Void) {
        let entry = makeEntry()
        // Refresh at next local midnight so "Done for today" flips with the calendar day.
        let cal = Calendar.current
        let tomorrow = cal.date(
            byAdding: .day,
            value: 1,
            to: cal.startOfDay(for: Date())
        ) ?? Date().addingTimeInterval(60 * 60)
        completion(Timeline(entries: [entry], policy: .after(tomorrow)))
    }

    private func makeEntry() -> DailyStreakEntry {
        let data = WidgetStreakStore.load()
        return DailyStreakEntry(
            date: .now,
            streak: data.streak,
            completedToday: data.completedToday,
            dayLabel: data.dayLabel
        )
    }
}

struct DailyStreakWidget: Widget {
    let kind = WidgetStreakStore.kind

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: DailyStreakProvider()) { entry in
            DailyStreakWidgetView(entry: entry)
                .containerBackground(for: .widget) {
                    LinearGradient(
                        colors: [
                            Color(red: 0.12, green: 0.55, blue: 0.38),
                            Color(red: 0.06, green: 0.28, blue: 0.42),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                }
                .widgetURL(URL(string: "ftmp://daily")!)
        }
        .configurationDisplayName("Daily Streak")
        .description("Your FTMP daily challenge streak.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct DailyStreakWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: DailyStreakEntry

    var body: some View {
        VStack(alignment: .leading, spacing: family == .systemSmall ? 6 : 10) {
            HStack {
                Label("Daily Streak", systemImage: "flame.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.92))
                Spacer(minLength: 0)
                if family != .systemSmall {
                    Text(entry.dayLabel)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.white.opacity(0.7))
                }
            }

            Text("\(entry.streak)")
                .font(.system(size: family == .systemSmall ? 40 : 48, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .minimumScaleFactor(0.6)

            Text(entry.streak == 1 ? "day" : "days")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white.opacity(0.85))

            Spacer(minLength: 0)

            Text(entry.completedToday ? "Done for today" : "Play today’s challenge")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.white.opacity(0.85))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}
