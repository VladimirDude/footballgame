import SwiftUI

struct GuessNationalTeamGameView: View {
    let round: NationalTeamRound
    @Binding var guess: String
    let gameResult: GameResult?
    let streak: Int
    let bestStreak: Int
    @Binding var revealedSlots: Set<String>
    let hasUsedHint: Bool
    let canUseHint: Bool
    @Binding var difficulty: NationalTeamDifficulty
    let onNewGame: () -> Void
    let onRevealHint: () -> Void
    let onSubmit: () -> Void
    let onNextRound: () -> Void

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: GameDesign.spacingMD) {
                GameScreenToolbar(
                    title: "Guess the Nation",
                    icon: "flag.fill",
                    onNewGame: onNewGame
                )

                GameSegmentedControl(
                    items: NationalTeamDifficulty.allCases,
                    selection: $difficulty,
                    title: \.rawValue
                )

                GameStatsBar(streak: streak, bestStreak: bestStreak)

                GameInstructionPill(
                    icon: "building.2.fill",
                    text: "Identify the nation from clubs & positions"
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
                    placeholder: "Type country name...",
                    inputIcon: "globe",
                    gameResult: gameResult,
                    onSubmit: onSubmit,
                    onContinue: gameResult == .won ? onNextRound : onNewGame,
                    winContinueTitle: "Next Nation",
                    loseContinueTitle: "Try Again"
                )

                if let gameResult {
                    GameAnimatedResultBanner(
                        isSuccess: gameResult == .won,
                        title: gameResult == .won
                            ? "\(round.flag) Correct! \(round.nationName)"
                            : "\(round.flag) It was \(round.nationName)"
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
        GameFormationBoard(entranceToken: round.nationName) {
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

// Legacy wrapper — use GameSegmentedControl directly
struct NationalTeamDifficultyPicker: View {
    @Binding var selectedDifficulty: NationalTeamDifficulty

    var body: some View {
        GameSegmentedControl(
            items: NationalTeamDifficulty.allCases,
            selection: $selectedDifficulty,
            title: \.rawValue
        )
    }
}
