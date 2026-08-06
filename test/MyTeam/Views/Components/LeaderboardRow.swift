import SwiftUI

struct LeaderboardRow: View {
    let rank: Int
    let player: TeamPlayer
    /// Figures for the season currently in scope — passed in rather than read off
    /// `player`, whose counters are legacy mirrors and are not season-aware.
    let stats: PlayerSeasonStats
    let metric: LeaderboardMetric

    private var medal: String {
        switch rank {
        case 1: return "\u{1F947}"
        case 2: return "\u{1F948}"
        case 3: return "\u{1F949}"
        default: return "\(rank)"
        }
    }

    private var accent: Color {
        switch rank {
        case 1: return TeamTheme.gold
        case 2: return TeamTheme.silver
        case 3: return TeamTheme.bronze
        default: return TeamTheme.textSecondary
        }
    }

    var body: some View {
        HStack(spacing: 14) {
            Text(medal)
                .font(.system(size: 30))
                .frame(width: 40)

            VStack(alignment: .leading, spacing: 3) {
                Text(player.name)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(TeamTheme.textPrimary)

                HStack(spacing: 12) {
                    Label("\(stats.goals)", systemImage: "soccerball")
                    Label("\(stats.assists)", systemImage: "arrow.triangle.branch")
                }
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(TeamTheme.textSecondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(metric.display(stats))
                    .font(.system(size: 24, weight: .black, design: .rounded))
                    .foregroundStyle(accent)
                Text(metric.rawValue)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(TeamTheme.textTertiary)
                    .textCase(.uppercase)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(TeamTheme.cardBg, in: RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(accent.opacity(0.2), lineWidth: 1)
        )
    }
}
