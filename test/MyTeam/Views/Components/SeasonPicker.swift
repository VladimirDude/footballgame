import SwiftUI

/// Season selector, shared by the dashboard, match list and leaderboard.
///
/// A `Menu` rather than a `DSSegmentedControl`: seasons are an unbounded set, and
/// a segmented control stops working past three or four.
struct SeasonPickerButton: View {
    @ObservedObject var vm: TeamStore

    var body: some View {
        Menu {
            Button { vm.seasonScope = .allTime } label: {
                Label("All time", systemImage: vm.seasonScope == .allTime ? "checkmark" : "")
            }
            if !vm.seasons.isEmpty {
                Divider()
                ForEach(vm.seasons) { season in
                    Button { vm.seasonScope = .season(season.id) } label: {
                        Label(label(for: season), systemImage: vm.seasonScope == .season(season.id) ? "checkmark" : "")
                    }
                }
            }
            // Only offered when it would actually match something — a permanent
            // "Unassigned" row on a healthy team is just noise.
            if vm.hasUnassignedGames {
                Divider()
                Button { vm.seasonScope = .unassigned } label: {
                    Label("Unassigned", systemImage: vm.seasonScope == .unassigned ? "checkmark" : "")
                }
            }
        } label: {
            HStack(spacing: 4) {
                Text(vm.seasonScopeLabel)
                    .font(.system(size: 13, weight: .semibold))
                Image(systemName: "chevron.down")
                    .font(.system(size: 10, weight: .bold))
            }
            .foregroundStyle(TeamTheme.blue)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(TeamTheme.blue.opacity(0.12), in: Capsule())
        }
        .accessibilityLabel("Season: \(vm.seasonScopeLabel)")
    }

    private func label(for season: Season) -> String {
        season.id == vm.currentSeason?.id ? "\(season.name) (current)" : season.name
    }
}
