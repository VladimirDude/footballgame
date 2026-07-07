import SwiftUI

struct HigherOrLowerGameView: View {
    let streak: Int
    let bestStreak: Int
    let timeRemaining: Int?
    let left: HLPlayer?
    let right: HLPlayer?
    let revealState: HLRevealState
    let slideIn: Bool
    let shakeTrigger: Bool
    let showRightValue: Bool
    let isGameOver: Bool
    let lastGuessCorrect: Bool?
    let onHigher: () -> Void
    let onLower: () -> Void
    let onContinue: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            HLTopBar(
                streak: streak,
                bestStreak: bestStreak,
                timeRemaining: timeRemaining,
                total: 5
            )

            if let left, let right {
                HLArena(
                    left: left,
                    right: right,
                    revealState: revealState,
                    slideIn: slideIn,
                    shakeTrigger: shakeTrigger
                )

                Spacer(minLength: 0)

                VStack(spacing: 10) {
                    if showRightValue, let wasCorrect = lastGuessCorrect {
                        HLResultBanner(isCorrect: wasCorrect)
                    }

                    if !showRightValue {
                        HLActionDock(onHigher: onHigher, onLower: onLower)
                    } else {
                        HLContinueButton(isGameOver: isGameOver, action: onContinue)
                    }
                }
            } else {
                Spacer()
                VStack(spacing: 10) {
                    ProgressView().tint(.white)
                    Text("Loading players...")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.8))
                }
                Spacer()
            }
        }
        .frame(maxHeight: .infinity)
    }
}
