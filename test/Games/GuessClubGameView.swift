import SwiftUI

struct GuessClubGameView: View {
    let round: GameRound
    @Binding var guess: String
    let gameResult: GameResult?
    let streak: Int
    let bestStreak: Int
    @Binding var revealedSlots: Set<String>
    let hasUsedHint: Bool
    let canUseHint: Bool
    @Binding var difficulty: GameDifficulty
    let onNewGame: () -> Void
    let onRevealHint: () -> Void
    let onSubmit: () -> Void
    let onNextRound: () -> Void

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: GameDesign.spacingMD) {
                GameScreenToolbar(
                    title: "Guess the Club",
                    icon: "shield.lefthalf.filled",
                    onNewGame: onNewGame
                )

                GameSegmentedControl(
                    items: GameDifficulty.allCases,
                    selection: $difficulty,
                    title: \.rawValue
                )

                GameStatsBar(streak: streak, bestStreak: bestStreak)

                GameInstructionPill(
                    icon: "flag.fill",
                    text: "Identify the club from flags & positions"
                )

                formationView(round.formation)

                GameHintButton(
                    title: "Reveal random player",
                    usedTitle: "Hint used",
                    isUsed: hasUsedHint,
                    isEnabled: canUseHint,
                    action: onRevealHint
                )

                GameGuessPanel(
                    guess: $guess,
                    placeholder: "Type club name...",
                    inputIcon: "shield",
                    gameResult: gameResult,
                    onSubmit: onSubmit,
                    onContinue: gameResult == .won ? onNextRound : onNewGame,
                    winContinueTitle: "Next Club",
                    loseContinueTitle: "Try Again"
                )

                if let gameResult {
                    GameAnimatedResultBanner(
                        isSuccess: gameResult == .won,
                        title: gameResult == .won ? "Correct! \(round.clubName)" : "It was \(round.clubName)"
                    )
                    .transition(.gamePresent)
                }
            }
            .padding(.bottom, GameDesign.spacingXL)
        }
        .scrollBounceBehavior(.basedOnSize)
    }

    @ViewBuilder
    private func formationView(_ lines: [[FormationSlot]]) -> some View {
        GameFormationBoard(entranceToken: round.clubID) {
            VStack(spacing: 24) {
                ForEach(Array(lines.enumerated()), id: \.offset) { _, row in
                    HStack(spacing: row.count > 3 ? 12 : 18) {
                        ForEach(row, id: \.id) { slot in
                            FlippableFormationSlot(
                                slot: slot,
                                revealedPlayerIds: $revealedSlots
                            )
                            .allowsHitTesting(!hasUsedHint && gameResult == nil)
                        }
                    }
                }
            }
        }
    }
}
