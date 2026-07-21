import SwiftUI

struct PLSeasonStatsSection: View {
    @ObservedObject var store: PredictorStore
    @Environment(\.appPalette) private var palette

    private var stats: PLSeasonStats { store.seasonStats() }

    var body: some View {
        VStack(spacing: 16) {
            overviewCard
            if stats.hasData {
                goldenBootCard
                teamLeadersCard
                if let biggestWin = stats.biggestWin {
                    biggestWinCard(biggestWin)
                }
            } else {
                emptyState
            }
        }
    }

    private var overviewCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Season Stats")
                .font(.headline.weight(.bold))
                .foregroundStyle(palette.textPrimary)

            if stats.hasData {
                HStack(spacing: 10) {
                    overviewTile(title: "Matches", value: "\(stats.totalMatches)", icon: "sportscourt.fill")
                    overviewTile(title: "Goals", value: "\(stats.totalGoals)", icon: "soccerball")
                    overviewTile(title: "Avg / Game", value: String(format: "%.2f", stats.averageGoalsPerMatch), icon: "chart.bar.fill")
                }
            } else {
                Text("Simulate matches to unlock season statistics.")
                    .font(.subheadline)
                    .foregroundStyle(SimulateStyle.muted(palette))
            }
        }
        .padding(16)
        .background(SimulateStyle.panel(palette))
    }

    private func overviewTile(title: String, value: String, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: icon)
                .font(.caption.weight(.bold))
                .foregroundStyle(SimulateStyle.accent)
            Text(value)
                .font(.headline.weight(.bold))
                .foregroundStyle(palette.textPrimary)
                .monospacedDigit()
            Text(title)
                .font(.caption2)
                .foregroundStyle(SimulateStyle.muted(palette))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(palette.surfaceFill)
        )
    }

    private var goldenBootCard: some View {
        statsCard(title: "Golden Boot", icon: "trophy.fill", tint: SimulateStyle.gold) {
            if stats.topScorers.isEmpty {
                Text("No goals recorded yet.")
                    .font(.subheadline)
                    .foregroundStyle(SimulateStyle.muted(palette))
            } else {
                ForEach(Array(stats.topScorers.prefix(10).enumerated()), id: \.element.id) { index, scorer in
                    scorerRow(scorer, rank: index + 1)
                    if index < min(9, stats.topScorers.count - 1) {
                        Divider().overlay(palette.panelStroke.opacity(0.6))
                    }
                }
            }
        }
    }

    private var teamLeadersCard: some View {
        statsCard(title: "Team Leaders", icon: "shield.fill", tint: SimulateStyle.accent) {
            leaderGroup(title: "Most Goals Scored", teams: stats.highestScoringTeams) { "\($0.goalsScored)" }
            Divider().overlay(palette.panelStroke.opacity(0.6)).padding(.vertical, 4)
            leaderGroup(title: "Best Defense", teams: stats.bestDefenses) { "\($0.goalsConceded) conceded" }
            Divider().overlay(palette.panelStroke.opacity(0.6)).padding(.vertical, 4)
            leaderGroup(title: "Most Clean Sheets", teams: stats.mostCleanSheets) { "\($0.cleanSheets)" }
            Divider().overlay(palette.panelStroke.opacity(0.6)).padding(.vertical, 4)
            leaderGroup(title: "Most Wins", teams: stats.mostWins) { "\($0.wins)" }
        }
    }

    private func biggestWinCard(_ win: PLBiggestWin) -> some View {
        statsCard(title: "Biggest Win", icon: "flame.fill", tint: .orange) {
            HStack(spacing: 10) {
                ClubLogoImage(clubID: win.homeClubID, clubName: win.homeTeam, style: .row)
                VStack(spacing: 4) {
                    Text(win.scoreline)
                        .font(.title3.weight(.heavy))
                        .foregroundStyle(palette.textPrimary)
                        .monospacedDigit()
                    Text("GW \(win.gameweek)")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(SimulateStyle.muted(palette))
                }
                .frame(minWidth: 72)
                ClubLogoImage(clubID: win.awayClubID, clubName: win.awayTeam, style: .row)
            }
            .frame(maxWidth: .infinity)

            HStack {
                Text(win.homeTeam)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(palette.textSecondary)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                Text(win.awayTeam)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(palette.textSecondary)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "chart.bar.doc.horizontal")
                .font(.largeTitle)
                .foregroundStyle(SimulateStyle.muted(palette))
            Text("No season stats yet")
                .font(.headline)
                .foregroundStyle(palette.textPrimary)
            Text("Run a gameweek or simulate the full season to populate leaderboards.")
                .font(.subheadline)
                .foregroundStyle(SimulateStyle.muted(palette))
                .multilineTextAlignment(.center)
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(SimulateStyle.panel(palette))
    }

    private func statsCard<Content: View>(
        title: String,
        icon: String,
        tint: Color,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .foregroundStyle(tint)
                Text(title)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(palette.textPrimary)
            }
            content()
        }
        .padding(16)
        .background(SimulateStyle.panel(palette))
    }

    private func scorerRow(_ scorer: PLScorerStat, rank: Int) -> some View {
        HStack(spacing: 10) {
            Text("\(rank)")
                .font(.caption.weight(.bold))
                .foregroundStyle(rank == 1 ? SimulateStyle.gold : SimulateStyle.muted(palette))
                .frame(width: 18, alignment: .leading)

            PlayerPortraitImage(playerID: scorer.playerID, style: .compact)

            VStack(alignment: .leading, spacing: 2) {
                Text(scorer.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(palette.textPrimary)
                    .lineLimit(1)
                HStack(spacing: 6) {
                    ClubLogoImage(clubID: scorer.clubID, clubName: scorer.clubName, style: .compact)
                    Text(scorer.clubName)
                        .font(.caption2)
                        .foregroundStyle(SimulateStyle.muted(palette))
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 0)

            Text(scorer.displayGoals)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(palette.textPrimary)
                .monospacedDigit()
        }
        .padding(.vertical, 4)
    }

    private func leaderGroup(
        title: String,
        teams: [PLTeamSeasonStat],
        value: @escaping (PLTeamSeasonStat) -> String
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption.weight(.bold))
                .foregroundStyle(SimulateStyle.muted(palette))

            if teams.isEmpty {
                Text("—")
                    .font(.subheadline)
                    .foregroundStyle(SimulateStyle.muted(palette))
            } else {
                ForEach(Array(teams.prefix(3).enumerated()), id: \.element.id) { index, team in
                    HStack(spacing: 10) {
                        Text("\(index + 1)")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(SimulateStyle.muted(palette))
                            .frame(width: 14, alignment: .leading)
                        ClubLogoImage(clubID: team.clubID, clubName: team.team, style: .compact)
                        Text(team.team)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(palette.textPrimary)
                            .lineLimit(1)
                        Spacer(minLength: 0)
                        Text(value(team))
                            .font(.caption.weight(.bold))
                            .foregroundStyle(SimulateStyle.accent)
                            .monospacedDigit()
                    }
                }
            }
        }
    }
}
