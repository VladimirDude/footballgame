import SwiftUI

/// Full scorer/contributor rankings for the team.
///
/// Replaces the old fixed "Top 3 by total + bonus": the metric is selectable, the
/// list is complete, and everything is scoped to the chosen season.
struct LeaderboardView: View {
    @ObservedObject var vm: TeamStore

    var body: some View {
        ScrollView {
            VStack(spacing: DSSpacing.md) {
                controls
                if ranked.isEmpty {
                    DSEmptyState(
                        title: "Nothing to rank yet",
                        systemImage: "trophy",
                        message: emptyMessage
                    )
                    .padding(.top, DSSpacing.xl)
                } else {
                    podium
                    if ranked.count > 3 { rest }
                    footnote
                }
            }
            .padding(.horizontal, DSSpacing.md)
            .padding(.bottom, DSSpacing.xxl)
            .adaptiveContentWidth(AdaptiveLayout.detailMaxWidth)
        }
        .background(TeamTheme.bg.ignoresSafeArea())
        .navigationTitle("Leaderboard")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) { SeasonPickerButton(vm: vm) }
        }
    }

    // MARK: - Pieces

    private var controls: some View {
        VStack(alignment: .leading, spacing: DSSpacing.xs) {
            DSSegmentedControl(items: LeaderboardMetric.allCases, selection: $vm.leaderboardMetric) {
                $0.rawValue
            }
            Text(vm.leaderboardMetric.fullName)
                .dsFont(.caption)
                .foregroundStyle(TeamTheme.textSecondary)
        }
        .padding(.top, DSSpacing.sm)
    }

    private var podium: some View {
        VStack(spacing: DSSpacing.sm) {
            ForEach(ranked.prefix(3)) { entry in
                LeaderboardRow(rank: entry.rank, player: entry.player,
                               stats: entry.stats, metric: vm.leaderboardMetric)
            }
        }
    }

    private var rest: some View {
        VStack(spacing: 0) {
            ForEach(Array(ranked.dropFirst(3))) { entry in
                HStack(spacing: 14) {
                    Text("\(entry.rank)")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(TeamTheme.textTertiary)
                        .frame(width: 32, alignment: .center)
                    Text(entry.player.name)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(TeamTheme.textPrimary)
                    Spacer()
                    Text(vm.leaderboardMetric.display(entry.stats))
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(TeamTheme.textPrimary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                if entry.id != ranked.last?.id { Divider().padding(.leading, 60) }
            }
        }
        .background(TeamTheme.cardBg, in: RoundedRectangle(cornerRadius: 14))
    }

    @ViewBuilder
    private var footnote: some View {
        let unlinked = vm.unlinkedScorerNames
        if !unlinked.isEmpty {
            let goals = unlinked.reduce(0) { $0 + $1.goals }
            Label(
                goals == 1 ? "1 goal isn't credited to a player yet."
                           : "\(goals) goals aren't credited to a player yet.",
                systemImage: "person.fill.questionmark"
            )
            .dsFont(.caption)
            .foregroundStyle(TeamTheme.textSecondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, DSSpacing.xs)
        }
    }

    // MARK: - Data

    private var ranked: [RankedPlayer] {
        vm.rankedPlayers().filter { vm.leaderboardMetric.value($0.stats) > 0 || $0.rank <= 3 }
    }

    private var emptyMessage: String {
        vm.games.isEmpty
            ? "Add a match with scorers and the rankings build themselves."
            : "No goals recorded for \(vm.seasonScopeLabel.lowercased()) yet."
    }
}
