import SwiftUI

/// End-of-match screen: winner (or tie), final standings, best single turn, and
/// rematch / home actions.
struct AliasResultsView: View {
    @ObservedObject var engine: AliasGameEngine
    var onRematch: () -> Void
    var onHome: () -> Void

    var body: some View {
        VStack(spacing: DSSpacing.lg) {
            Spacer(minLength: 0)

            Image(systemName: "trophy.fill")
                .font(.system(size: 52))
                .foregroundStyle(DSColor.gold)

            VStack(spacing: DSSpacing.xxs) {
                if let winner = engine.winner {
                    Text("\(winner.name) win!")
                        .font(.system(size: 30, weight: .heavy, design: .rounded))
                        .foregroundStyle(DSColor.textPrimary)
                        .multilineTextAlignment(.center)
                } else {
                    Text("It's a tie!")
                        .font(.system(size: 30, weight: .heavy, design: .rounded))
                        .foregroundStyle(DSColor.textPrimary)
                }
                if let best = bestTurn {
                    Text("Best turn: \(best.name) (+\(best.points))")
                        .font(.footnote)
                        .foregroundStyle(DSColor.textSecondary)
                }
            }

            standings

            Spacer(minLength: 0)

            VStack(spacing: DSSpacing.sm) {
                Button {
                    HapticFeedback.medium()
                    onRematch()
                } label: {
                    Text("Rematch")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, DSSpacing.md)
                        .background(DSColor.accent, in: RoundedRectangle(cornerRadius: DSRadius.lg, style: .continuous))
                        .foregroundStyle(DSColor.onAccent)
                }
                Button(action: onHome) {
                    Text("Home")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, DSSpacing.md)
                        .foregroundStyle(DSColor.textSecondary)
                }
            }
        }
    }

    private var standings: some View {
        VStack(spacing: DSSpacing.xs) {
            ForEach(Array(engine.rankedTeams.enumerated()), id: \.element.id) { index, team in
                HStack(spacing: DSSpacing.md) {
                    Text("\(index + 1)")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(index == 0 ? DSColor.gold : DSColor.textTertiary)
                        .frame(width: 24)
                    Text(team.name)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(DSColor.textPrimary)
                    Spacer()
                    Text("\(team.score)")
                        .font(.title3.weight(.heavy))
                        .foregroundStyle(DSColor.textPrimary)
                }
                .padding(.horizontal, DSSpacing.md)
                .padding(.vertical, DSSpacing.sm)
                .background(RoundedRectangle(cornerRadius: DSRadius.md, style: .continuous).fill(DSColor.surface))
            }
        }
    }

    private var bestTurn: (name: String, points: Int)? {
        var best: (name: String, points: Int)?
        for team in engine.teams {
            for delta in team.roundScores where delta > (best?.points ?? Int.min) {
                best = (team.name, delta)
            }
        }
        if let best, best.points > 0 { return best }
        return nil
    }
}
