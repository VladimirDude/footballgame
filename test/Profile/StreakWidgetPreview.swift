import SwiftUI

/// Short how-to for adding the Daily Streak widget to the Home Screen.
struct StreakWidgetTutorial: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DSSpacing.lg) {
                    Text("Your streak is pinned here. To also put it on your Home Screen:")
                        .dsFont(.body)
                        .foregroundStyle(DSColor.textSecondary)

                    VStack(alignment: .leading, spacing: DSSpacing.md) {
                        step(number: "1", title: "Go to the Home Screen",
                             detail: "Leave FTMP and long-press an empty area until the icons jiggle.")
                        step(number: "2", title: "Add a widget",
                             detail: "Tap Edit in the top corner, then Add Widget.")
                        step(number: "3", title: "Find Daily Streak",
                             detail: "Search for “FTMP”, open it, choose Daily Streak (small or medium), then tap Add Widget.")
                    }
                    .dsCard()
                }
                .padding(DSSpacing.md)
            }
            .background(DSColor.groupedBackground.ignoresSafeArea())
            .navigationTitle("Home Screen widget")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Got it") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
    }

    private func step(number: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: DSSpacing.sm) {
            Text(number)
                .dsFont(.subheadline)
                .fontWeight(.bold)
                .foregroundStyle(DSColor.onAccent)
                .frame(width: 28, height: 28)
                .background(Circle().fill(DSColor.accent))
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .dsFont(.headline)
                    .foregroundStyle(DSColor.textPrimary)
                Text(detail)
                    .dsFont(.subheadline)
                    .foregroundStyle(DSColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

/// Live streak card shown on the You tab when the user taps “Add streak widget”.
struct DailyStreakWidgetCard: View {
    let streak: Int
    let completedToday: Bool
    let dayLabel: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Daily Streak", systemImage: "flame.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.9))
                Spacer()
                Text(dayLabel)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.white.opacity(0.7))
            }

            Text("\(streak)")
                .font(.system(size: 56, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .minimumScaleFactor(0.6)
                .lineLimit(1)

            Text(streak == 1 ? "day" : "days")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white.opacity(0.85))

            Spacer(minLength: 0)

            Text(completedToday ? "Done for today" : "Play today’s challenge")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.85))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Capsule().fill(.white.opacity(0.18)))
        }
        .padding(18)
        .frame(maxWidth: .infinity, minHeight: 160, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.12, green: 0.55, blue: 0.38),
                            Color(red: 0.06, green: 0.28, blue: 0.42),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(.white.opacity(0.12), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Daily streak \(streak) days. \(completedToday ? "Completed today" : "Not completed today").")
    }
}
