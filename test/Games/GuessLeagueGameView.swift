import SwiftUI

struct GuessLeagueRound: Identifiable, Equatable {
    let id: String
    let clubID: String
    let clubName: String
    let correctLeague: String
    let options: [String]
}

/// Multiple-choice: show a club, pick its league. No text input (so no fuzzy
/// matching); reuses the shared game components + club theme.
struct GuessLeagueGameView: View {
    @Environment(\.gameTheme) private var theme

    let round: GuessLeagueRound
    let gameResult: GameResult?
    let streak: Int
    let bestStreak: Int
    let selected: String?
    let onSelect: (String) -> Void
    let onNext: () -> Void

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: GameDesign.spacingMD) {
                GameStatsBar(streak: streak, bestStreak: bestStreak)
                GameInstructionPill(icon: "trophy.fill", text: "Which league does this club play in?")

                VStack(spacing: GameDesign.spacingSM) {
                    ClubLogoImage(clubID: round.clubID, clubName: round.clubName, style: .hero)
                    Text(round.clubName)
                        .font(.title3.bold())
                        .foregroundStyle(theme.textPrimary)
                        .multilineTextAlignment(.center)
                }
                .padding(GameDesign.spacingLG)
                .frame(maxWidth: .infinity)
                .background(theme.panelFill, in: RoundedRectangle(cornerRadius: GameDesign.radiusLG, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: GameDesign.radiusLG, style: .continuous)
                        .stroke(theme.panelStroke, lineWidth: 1)
                )

                VStack(spacing: 10) {
                    ForEach(round.options, id: \.self) { league in
                        optionButton(league)
                    }
                }

                if let gameResult {
                    GameContinueButton(won: gameResult == .won, winTitle: "Next Club", loseTitle: "Next Club", action: onNext)
                        .transition(.gamePresent)
                }
            }
            .padding(.bottom, GameDesign.spacingXL)
        }
        .animation(GameMotion.silky, value: gameResult == nil)
    }

    @ViewBuilder
    private func optionButton(_ league: String) -> some View {
        let decided = gameResult != nil
        let isCorrect = league == round.correctLeague
        let isChosen = league == selected
        let fill: Color = decided ? (isCorrect ? GameDesign.success.opacity(0.22)
                                     : (isChosen ? GameDesign.danger.opacity(0.22) : theme.surfaceFill))
                                   : theme.surfaceFill
        let border: Color = decided ? (isCorrect ? GameDesign.success
                                       : (isChosen ? GameDesign.danger : theme.panelStroke))
                                     : theme.panelStroke

        Button {
            if !decided { onSelect(league) }
        } label: {
            HStack {
                Text(league).font(.headline).foregroundStyle(theme.textPrimary)
                Spacer()
                if decided && isCorrect {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(GameDesign.success)
                } else if decided && isChosen {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(GameDesign.danger)
                }
            }
            .padding(.horizontal, GameDesign.spacingMD)
            .padding(.vertical, 15)
            .frame(maxWidth: .infinity)
            .background(fill, in: RoundedRectangle(cornerRadius: GameDesign.radiusMD, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: GameDesign.radiusMD, style: .continuous)
                    .stroke(border, lineWidth: 1.5)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(decided)
        .accessibilityLabel(league)
    }
}
