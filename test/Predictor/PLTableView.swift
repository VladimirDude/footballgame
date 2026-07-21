import SwiftUI

struct PLStandingsSection: View {
    @ObservedObject var store: PredictorStore

    var body: some View {
        VStack(spacing: 16) {
            seasonCard
            if store.standings().contains(where: { $0.played > 0 }) {
                tableCard
                legend
            } else {
                emptyState
            }
        }
    }

    private var seasonCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Season Table")
                        .font(.headline.weight(.bold))
                    Text(progressText)
                        .font(.caption)
                        .foregroundStyle(SimulateStyle.muted)
                }
                Spacer()
                if store.isSimulatingSeason {
                    ProgressView().tint(.white)
                }
            }

            if store.isSeasonFullySimulated {
                HStack(spacing: 8) {
                    simulateButton("Re-simulate", icon: "arrow.clockwise") {
                        store.simulateFullSeason(reroll: true)
                        HapticFeedback.success()
                    }
                    simulateButton("Clear", icon: "trash") {
                        store.resetSeasonSimulations()
                        HapticFeedback.light()
                    }
                }
            } else {
                Button {
                    store.simulateFullSeason(reroll: false)
                    HapticFeedback.success()
                } label: {
                    Text(store.isSimulatingSeason ? "Simulating…" : "Simulate Full Season")
                        .font(.headline.weight(.bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .foregroundStyle(store.isSimulatingSeason ? .white.opacity(0.5) : Color(red: 0.08, green: 0.1, blue: 0.14))
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(store.isSimulatingSeason ? Color.white.opacity(0.08) : .white)
                        )
                }
                .disabled(store.isSimulatingSeason)
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .background(SimulateStyle.panel())
    }

    private var progressText: String {
        if store.isSimulatingSeason {
            return "\(store.simulatedMatchCount)/\(store.totalMatchCount) matches"
        }
        if store.isSeasonFullySimulated {
            return "All \(store.totalMatchCount) matches complete"
        }
        if store.simulatedMatchCount > 0 {
            return "\(store.simulatedMatchCount)/\(store.totalMatchCount) matches played"
        }
        return "Run all 38 gameweeks to build the table"
    }

    private var tableCard: some View {
        VStack(spacing: 0) {
            tableHeader
            ForEach(Array(store.standings().enumerated()), id: \.element.id) { index, row in
                tableRow(row, position: index + 1)
                if index + 1 < 20 {
                    Divider().overlay(Color.white.opacity(0.06))
                }
            }
        }
        .background(SimulateStyle.panel())
    }

    private var tableHeader: some View {
        HStack(spacing: 8) {
            Text("#").frame(width: 22, alignment: .leading)
            Text("Club").frame(maxWidth: .infinity, alignment: .leading)
            headerStat("P")
            headerStat("W")
            headerStat("D")
            headerStat("L")
            headerStat("GD")
            headerStat("Pts")
        }
        .font(.caption2.weight(.bold))
        .foregroundStyle(SimulateStyle.muted)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color.white.opacity(0.04))
    }

    private func headerStat(_ label: String) -> some View {
        Text(label).frame(width: 26)
    }

    private func tableRow(_ row: PLStandingRow, position: Int) -> some View {
        let zone = PLTableZone.zone(for: position)
        return HStack(spacing: 8) {
            HStack(spacing: 6) {
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(zoneColor(zone))
                    .frame(width: 3, height: 28)
                Text("\(position)")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(SimulateStyle.muted)
                    .frame(width: 16, alignment: .leading)
            }
            .frame(width: 22, alignment: .leading)

            HStack(spacing: 8) {
                ClubLogoImage(clubID: row.clubID, clubName: row.team, style: .compact)
                    .layoutPriority(1)
                Text(row.team)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            rowStat("\(row.played)")
            rowStat("\(row.won)")
            rowStat("\(row.drawn)")
            rowStat("\(row.lost)")
            rowStat(row.goalDifference >= 0 ? "+\(row.goalDifference)" : "\(row.goalDifference)")
            Text("\(row.points)")
                .font(.subheadline.weight(.bold))
                .frame(width: 26)
                .foregroundStyle(position == 1 ? SimulateStyle.gold : .white)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private func rowStat(_ value: String) -> some View {
        Text(value)
            .font(.caption.weight(.medium))
            .foregroundStyle(.white.opacity(0.85))
            .frame(width: 26)
            .monospacedDigit()
    }

    private func zoneColor(_ zone: PLTableZone) -> Color {
        switch zone {
        case .championsLeague: SimulateStyle.ucl
        case .relegation: SimulateStyle.relegation
        case .mid: .clear
        }
    }

    private var legend: some View {
        HStack(spacing: 16) {
            legendItem(color: SimulateStyle.ucl, label: "Top 4")
            legendItem(color: SimulateStyle.relegation, label: "Relegation")
        }
        .font(.caption2)
        .foregroundStyle(SimulateStyle.muted)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func legendItem(color: Color, label: String) -> some View {
        HStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 2).fill(color).frame(width: 10, height: 10)
            Text(label)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "tablecells")
                .font(.title)
                .foregroundStyle(SimulateStyle.muted)
            Text("No standings yet")
                .font(.subheadline.weight(.semibold))
            Text("Simulate the full season or individual gameweeks to populate the table.")
                .font(.caption)
                .foregroundStyle(SimulateStyle.muted)
                .multilineTextAlignment(.center)
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(SimulateStyle.panel())
    }

    private func simulateButton(_ title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(.caption.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .foregroundStyle(.white.opacity(0.9))
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.white.opacity(0.1))
                )
        }
        .buttonStyle(.plain)
    }
}

enum SimulateStyle {
    static let purple = Color(red: 0.55, green: 0.38, blue: 0.98)
    static let green = Color(red: 0.22, green: 0.78, blue: 0.48)
    static let danger = Color(red: 0.92, green: 0.28, blue: 0.32)
    static let accent = Color(red: 0.72, green: 0.84, blue: 1.0)
    static let goal = Color(red: 0.55, green: 0.9, blue: 0.62)
    static let penalty = Color(red: 1.0, green: 0.72, blue: 0.28)
    static let gold = Color(red: 1.0, green: 0.84, blue: 0.38)
    static let ucl = Color(red: 0.22, green: 0.55, blue: 0.95)
    static let relegation = Color(red: 0.92, green: 0.28, blue: 0.32)
    static let muted = Color.white.opacity(0.45)

    static func panel() -> some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(Color.white.opacity(0.08))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
            )
    }
}
