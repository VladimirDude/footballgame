import SwiftUI

struct PLMatchDetailView: View {
    let match: PLMatch
    let simulation: PLMatchSimulation

    @Environment(\.dismiss) private var dismiss
    @Environment(\.appPalette) private var palette

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    scoreboard
                    keyStatsGrid
                    goalsSection
                    secondaryStats
                }
                .padding()
            }
            .background(matchDetailBackground.ignoresSafeArea())
            .navigationTitle("Match Report")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
    }

    private var matchDetailBackground: some View {
        LinearGradient(
            colors: [palette.backdropTop, palette.backdropBottom],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    // MARK: - Scoreboard

    private var scoreboard: some View {
        VStack(spacing: 16) {
            Text(match.displayKickoff)
                .font(.caption)
                .foregroundStyle(palette.textMuted)

            HStack(alignment: .top, spacing: 12) {
                teamScoreColumn(
                    name: match.homeTeam,
                    clubID: match.homeClubID,
                    goals: simulation.homeGoals,
                    xG: simulation.homeStats.formattedXG,
                    possession: simulation.homeStats.possession,
                    alignment: .trailing
                )

                VStack(spacing: 4) {
                    Text("\(simulation.homeGoals) – \(simulation.awayGoals)")
                        .font(.system(size: 36, weight: .heavy, design: .rounded))
                        .foregroundStyle(palette.textPrimary)
                    Text("Full Time")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(palette.textMuted)
                    if let halftimeLabel = simulation.halftimeLabel {
                        Text("HT \(halftimeLabel)")
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(palette.textMuted)
                    }
                }
                .frame(minWidth: 88)

                teamScoreColumn(
                    name: match.awayTeam,
                    clubID: match.awayClubID,
                    goals: simulation.awayGoals,
                    xG: simulation.awayStats.formattedXG,
                    possession: simulation.awayStats.possession,
                    alignment: .leading
                )
            }
        }
        .padding(18)
        .background(palette.panel())
    }

    private func teamScoreColumn(
        name: String,
        clubID: String?,
        goals: Int,
        xG: String,
        possession: Int,
        alignment: HorizontalAlignment
    ) -> some View {
        VStack(alignment: alignment, spacing: 6) {
            ClubLogoImage(clubID: clubID, clubName: name, style: .row)
            Text(name)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(palette.textPrimary)
                .multilineTextAlignment(alignment == .trailing ? .trailing : .leading)
                .lineLimit(2)
            Text("\(goals) goal\(goals == 1 ? "" : "s")")
                .font(.caption)
                .foregroundStyle(palette.textMuted)
            Text("\(xG) xG")
                .font(.caption.weight(.semibold))
                .foregroundStyle(DetailStyle.accent)
            Text("\(possession)% poss")
                .font(.caption2)
                .foregroundStyle(palette.textMuted)
        }
        .frame(maxWidth: .infinity, alignment: alignment == .trailing ? .trailing : .leading)
    }

    // MARK: - Key stats

    private var keyStatsGrid: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("Key stats")

            VStack(spacing: 10) {
                statCompareRow(
                    label: "Expected goals",
                    home: simulation.homeStats.formattedXG,
                    away: simulation.awayStats.formattedXG,
                    homeFill: DetailStyle.home,
                    awayFill: DetailStyle.away,
                    homeRatio: simulation.homeStats.xG,
                    awayRatio: simulation.awayStats.xG
                )
                statCompareRow(
                    label: "Shots",
                    home: "\(simulation.homeStats.shots)",
                    away: "\(simulation.awayStats.shots)",
                    homeFill: DetailStyle.home,
                    awayFill: DetailStyle.away,
                    homeRatio: Double(simulation.homeStats.shots),
                    awayRatio: Double(simulation.awayStats.shots)
                )
                statCompareRow(
                    label: "Shots on target",
                    home: "\(simulation.homeStats.shotsOnTarget)",
                    away: "\(simulation.awayStats.shotsOnTarget)",
                    homeFill: DetailStyle.home,
                    awayFill: DetailStyle.away,
                    homeRatio: Double(simulation.homeStats.shotsOnTarget),
                    awayRatio: Double(simulation.awayStats.shotsOnTarget)
                )
                statCompareRow(
                    label: "Possession",
                    home: "\(simulation.homeStats.possession)%",
                    away: "\(simulation.awayStats.possession)%",
                    homeFill: DetailStyle.home,
                    awayFill: DetailStyle.away,
                    homeRatio: Double(simulation.homeStats.possession),
                    awayRatio: Double(simulation.awayStats.possession)
                )
            }
        }
        .padding(16)
        .background(palette.panel())
    }

    private func statCompareRow(
        label: String,
        home: String,
        away: String,
        homeFill: Color,
        awayFill: Color,
        homeRatio: Double,
        awayRatio: Double
    ) -> some View {
        let total = max(homeRatio + awayRatio, 0.001)
        return VStack(spacing: 6) {
            HStack {
                Text(home)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(palette.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text(label)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(palette.textMuted)
                    .frame(minWidth: 100)
                Text(away)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(palette.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }

            GeometryReader { geo in
                HStack(spacing: 3) {
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(homeFill)
                        .frame(width: max(4, geo.size.width * homeRatio / total))
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(awayFill)
                        .frame(width: max(4, geo.size.width * awayRatio / total))
                }
            }
            .frame(height: 8)
        }
    }

    // MARK: - Goals

    private var goalsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("Goals")

            if simulation.goals.isEmpty {
                HStack {
                    Spacer()
                    VStack(spacing: 6) {
                        Image(systemName: "shield.fill")
                            .font(.title2)
                            .foregroundStyle(palette.textMuted)
                        Text("Goalless draw")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(palette.textMuted)
                    }
                    .padding(.vertical, 12)
                    Spacer()
                }
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(simulation.goals.enumerated()), id: \.element.id) { index, goal in
                        goalRow(goal)
                        if index < simulation.goals.count - 1 {
                            Divider().overlay(palette.panelStroke.opacity(0.6))
                        }
                    }
                }
            }
        }
        .padding(16)
        .background(palette.panel())
    }

    private func goalRow(_ goal: PLGoalEvent) -> some View {
        HStack(spacing: 12) {
            Text(goal.minuteLabel)
                .font(.caption.weight(.bold))
                .foregroundStyle(palette.textPrimary)
                .frame(width: 36, height: 28)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(goal.isHome ? DetailStyle.home.opacity(0.35) : DetailStyle.away.opacity(0.35))
                )

            PlayerPortraitImage(playerID: goal.scorerID, style: .hl)
                .scaleEffect(0.44)
                .frame(width: 34, height: 34)

            VStack(alignment: .leading, spacing: 3) {
                Text(goal.scorerName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(palette.textPrimary)
                Text(goal.isHome ? match.homeTeam : match.awayTeam)
                    .font(.caption)
                    .foregroundStyle(palette.textMuted)
            }

            Spacer()

            goalTypeBadge(goal)
        }
        .padding(.vertical, 10)
    }

    private func goalTypeBadge(_ goal: PLGoalEvent) -> some View {
        HStack(spacing: 4) {
            Image(systemName: goal.isPenalty ? "soccerball.inverse" : "soccerball")
                .font(.caption2)
            Text(goal.typeLabel)
                .font(.caption2.weight(.bold))
        }
        .foregroundStyle(goal.isPenalty ? DetailStyle.penalty : DetailStyle.goal)
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(
            Capsule()
                .fill((goal.isPenalty ? DetailStyle.penalty : DetailStyle.goal).opacity(0.15))
        )
    }

    // MARK: - Secondary stats

    private var secondaryStats: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("More stats")

            HStack(spacing: 10) {
                miniStatTile("Corners", home: simulation.homeStats.corners, away: simulation.awayStats.corners)
                miniStatTile("Fouls", home: simulation.homeStats.fouls, away: simulation.awayStats.fouls)
                miniStatTile("Yellows", home: simulation.homeStats.yellowCards, away: simulation.awayStats.yellowCards)
            }
        }
        .padding(16)
        .background(palette.panel())
    }

    private func miniStatTile(_ label: String, home: Int, away: Int) -> some View {
        VStack(spacing: 6) {
            Text(label)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(palette.textMuted)
            HStack(spacing: 8) {
                Text("\(home)")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(palette.textPrimary)
                Text("–")
                    .foregroundStyle(palette.textMuted)
                Text("\(away)")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(palette.textPrimary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(palette.surfaceFill)
        )
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.system(size: 10, weight: .bold))
            .tracking(0.8)
            .foregroundStyle(palette.textMuted)
    }
}

// MARK: - Shared report components

enum PLMatchReportUI {

    static func goalSummaryLine(_ goals: [PLGoalEvent]) -> String {
        goals.map { goal in
            let type = goal.isPenalty ? " (pen)" : ""
            return "\(goal.minuteLabel) \(goal.scorerName)\(type)"
        }.joined(separator: " · ")
    }

    static func compactStatsLine(home: PLTeamMatchStats, away: PLTeamMatchStats) -> String {
        "\(home.formattedXG)–\(away.formattedXG) xG · \(home.shots)–\(away.shots) shots · \(home.shotsOnTarget)–\(away.shotsOnTarget) SOT · \(home.possession)–\(away.possession)%"
    }
}

private enum DetailStyle {
    static let home = Color(red: 0.55, green: 0.38, blue: 0.98)
    static let away = Color(red: 0.22, green: 0.78, blue: 0.48)
    static let accent = Color(red: 0.72, green: 0.84, blue: 1.0)
    static let goal = Color(red: 0.55, green: 0.9, blue: 0.62)
    static let penalty = Color(red: 1.0, green: 0.72, blue: 0.28)
}
