import SwiftUI

struct StatRowView: View {
    let index: Int
    let player: TeamPlayer
    let highlightBonus: Bool
    let isAdmin: Bool
    var onEdit: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: 0) {
            Text("\(index + 1)")
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .foregroundStyle(index < 3 ? TeamTheme.orange : TeamTheme.textTertiary)
                .frame(width: 28, alignment: .center)

            HStack(spacing: 6) {
                Text(player.name)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(TeamTheme.textPrimary)
                    .lineLimit(1)

                if player.role != .player {
                    roleBadge
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if player.role == .goalkeeper, let gk = player.goalkeeperStats {
                Text("\(gk.matchesAttended)").statCell(color: TeamTheme.textSecondary)
                Text("\(gk.goalsConceded)").statCell(color: TeamTheme.red.opacity(0.8))
                Text("\(gk.cleanSheets)").statCell(color: TeamTheme.green)
            } else {
                Text("\(player.goals)").statCell()
                Text("\(player.assists)").statCell()
                Text("\(player.total)").statCell()
            }

            HStack(spacing: 2) {
                Text(formatScore(player.totalWithBonus))
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .foregroundStyle(highlightBonus && player.bonusPoints > 0 ? TeamTheme.orange : TeamTheme.textPrimary)
                if player.bonusPoints > 0 {
                    Text("*")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(TeamTheme.orange)
                }
            }
            .frame(width: 50, alignment: .trailing)

            if isAdmin {
                Button { onEdit?() } label: {
                    Image(systemName: "pencil.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(TeamTheme.blue.opacity(0.8))
                }
                .buttonStyle(.plain)
                .frame(width: 30)
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .background(index % 2 == 0 ? Color.clear : Color.white.opacity(0.02))
    }

    private var roleBadge: some View {
        Text(player.role == .goalkeeper ? "GK" : "C")
            .font(.system(size: 9, weight: .heavy))
            .foregroundStyle(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(
                player.role == .goalkeeper ? TeamTheme.orange : TeamTheme.purple,
                in: Capsule()
            )
    }

    private func formatScore(_ value: Double) -> String {
        value.truncatingRemainder(dividingBy: 1) == 0
            ? String(format: "%.0f", value)
            : String(format: "%.1f", value)
    }
}

private extension Text {
    func statCell(color: Color = TeamTheme.textPrimary) -> some View {
        self
            .font(.system(size: 13, weight: .medium, design: .monospaced))
            .foregroundStyle(color)
            .frame(width: 32, alignment: .trailing)
    }
}
