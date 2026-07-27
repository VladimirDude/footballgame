import SwiftUI

/// Shown at the end of a turn: every card the team saw, tappable to flip between
/// correct and skipped (the explainer often over/under-counts in the heat of it),
/// then commit to bank the score and rotate to the next team.
struct AliasRoundReviewView: View {
    @ObservedObject var engine: AliasGameEngine

    var body: some View {
        VStack(spacing: DSSpacing.md) {
            VStack(spacing: DSSpacing.xxs) {
                Text("\(engine.currentTeam.name) — Turn Review")
                    .font(.headline)
                    .foregroundStyle(DSColor.textPrimary)
                Text("Tap a card to correct it")
                    .font(.footnote)
                    .foregroundStyle(DSColor.textSecondary)
            }
            .padding(.top, DSSpacing.sm)

            summaryBar

            if engine.currentOutcomes.isEmpty {
                Spacer()
                Text("No cards this turn.")
                    .font(.subheadline)
                    .foregroundStyle(DSColor.textTertiary)
                Spacer()
            } else {
                ScrollView {
                    VStack(spacing: DSSpacing.xs) {
                        ForEach(engine.currentOutcomes) { outcome in
                            outcomeRow(outcome)
                        }
                    }
                }
            }

            Button {
                HapticFeedback.medium()
                withAnimation { engine.commitTurn() }
            } label: {
                Text(engine.status == .finished ? "See Results" : "Continue")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, DSSpacing.md)
                    .background(DSColor.accent, in: RoundedRectangle(cornerRadius: DSRadius.lg, style: .continuous))
                    .foregroundStyle(DSColor.onAccent)
            }
        }
    }

    private var summaryBar: some View {
        HStack {
            metric(value: engine.currentCorrectCount, label: "Correct", tint: DSColor.success)
            metric(value: engine.currentSkipCount, label: "Skipped", tint: DSColor.warning)
            metric(value: engine.currentTurnDelta, label: "Points", tint: DSColor.accent, signed: true)
        }
        .padding(DSSpacing.sm)
        .background(RoundedRectangle(cornerRadius: DSRadius.lg, style: .continuous).fill(DSColor.surface))
    }

    private func metric(value: Int, label: String, tint: Color, signed: Bool = false) -> some View {
        VStack(spacing: 2) {
            Text(signed && value >= 0 ? "+\(value)" : "\(value)")
                .font(.title3.weight(.heavy))
                .foregroundStyle(tint)
            Text(label).font(.caption2).foregroundStyle(DSColor.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func outcomeRow(_ outcome: AliasRoundOutcome) -> some View {
        Button {
            HapticFeedback.selection()
            withAnimation { engine.toggleOutcome(outcome.id) }
        } label: {
            HStack(spacing: DSSpacing.sm) {
                Image(systemName: outcome.result == .correct ? "checkmark.circle.fill" : "arrow.right.circle.fill")
                    .foregroundStyle(outcome.result == .correct ? DSColor.success : DSColor.warning)
                Text(outcome.card.word)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(DSColor.textPrimary)
                Spacer()
                Text(outcome.result == .correct ? "Correct" : "Skipped")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(DSColor.textTertiary)
            }
            .padding(.horizontal, DSSpacing.md)
            .padding(.vertical, DSSpacing.sm)
            .background(RoundedRectangle(cornerRadius: DSRadius.md, style: .continuous).fill(DSColor.surface))
        }
        .buttonStyle(.plain)
    }
}
