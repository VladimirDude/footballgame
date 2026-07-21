import SwiftUI

struct GuessPlayerGameView: View {
    @Environment(\.gameTheme) private var theme

    let round: GuessPlayerRound
    @Binding var guess: String
    let gameResult: GameResult?
    let streak: Int
    let bestStreak: Int
    let timeRemaining: Int?
    let totalTime: Int
    let showClubHint: Bool
    let shakeWrong: Bool
    let onRevealClubHint: () -> Void
    let onSubmit: () -> Void
    let onNextRound: () -> Void

    @State private var portraitProgress: CGFloat = 0
    @State private var cardProgress: CGFloat = 0
    @State private var hintsProgress: CGFloat = 0

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let portraitSize: CGFloat = 120
    private let portraitRadius: CGFloat = 14

    private var resultBorder: Color {
        switch gameResult {
        case .won: GameDesign.success.opacity(0.85)
        case .lost: GameDesign.danger.opacity(0.9)
        case nil: theme.panelStroke
        }
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: GameDesign.spacingMD) {
                GameStatsBar(
                    streak: streak,
                    bestStreak: bestStreak,
                    timeRemaining: timeRemaining,
                    total: totalTime
                )

                VStack(spacing: GameDesign.spacingMD) {
                    GameInstructionPill(icon: "eye.fill", text: "Who is this player?")
                    playerSpotlightCard
                    guessPanel

                    if let gameResult {
                        GameAnimatedResultBanner(
                            isSuccess: gameResult == .won,
                            title: gameResult == .won
                                ? "Correct! \(round.playerName)"
                                : "It was \(round.playerName)"
                        )
                        .transition(.gamePresent)
                    }
                }
                .silkyProgress(cardProgress, lift: 8)
            }
            .padding(.bottom, GameDesign.spacingXL)
        }
        .scrollBounceBehavior(.basedOnSize)
        .onAppear { runEntranceAnimation() }
        .onChange(of: round.id) { _, _ in runEntranceAnimation() }
        .onChange(of: showClubHint) { _, revealed in
            guard revealed else { return }
            withAnimation(GameMotion.silky) { hintsProgress = 1 }
        }
    }

    private var playerSpotlightCard: some View {
        VStack(spacing: GameDesign.spacingMD) {
            portraitSection

            HStack(spacing: 8) {
                GameHintChip(
                    title: "Position",
                    displayValue: round.position,
                    symbol: "figure.soccer",
                    tint: .cyan,
                    progress: hintsProgress
                )
                GameHintChip(
                    title: "Nation",
                    displayValue: round.nationalities.first ?? "—",
                    emoji: CountryFlags.primaryFlag(from: round.nationalities),
                    tint: .blue,
                    progress: hintsProgress
                )

                if showClubHint {
                    GameHintChip(
                        title: "Club",
                        displayValue: round.clubName,
                        symbol: "shield.fill",
                        tint: theme.accent,
                        progress: 1
                    )
                    .transition(.gamePresent)
                }
            }
            .animation(GameMotion.silky, value: showClubHint)

            if !showClubHint, gameResult == nil {
                GameHintButton(
                    title: "Reveal club hint",
                    usedTitle: "Club revealed",
                    isUsed: false,
                    isEnabled: true,
                    action: onRevealClubHint
                )
                .transition(.gamePresent)
            }
        }
        .padding(GameDesign.spacingLG)
        .gameThemedPanel(cornerRadius: GameDesign.radiusXL)
        .overlay(
            RoundedRectangle(cornerRadius: GameDesign.radiusXL, style: .continuous)
                .stroke(resultBorder, lineWidth: gameResult == nil ? 0 : 2)
        )
        .animation(GameMotion.dissolve, value: gameResult == nil)
    }

    private var portraitSection: some View {
        ZStack {
            RoundedRectangle(cornerRadius: portraitRadius + 5, style: .continuous)
                .fill(theme.surfaceFill)
                .frame(width: portraitSize + 16, height: portraitSize + 16)

            RoundedRectangle(cornerRadius: portraitRadius, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [theme.gold.opacity(0.75), Color.white.opacity(0.25)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 2.5
                )
                .frame(width: portraitSize, height: portraitSize)

            PlayerPortraitImage(playerID: round.id, style: .hero)
                .shadow(color: .black.opacity(0.25), radius: 6, y: 3)
                .silkyProgress(portraitProgress, lift: 5, scaleFrom: 0.985)
                .overlay(alignment: .topLeading) {
                    mysteryBadge.padding(5)
                }
        }
        .frame(height: portraitSize + 12)
        .gameShake(trigger: shakeWrong)
    }

    private var mysteryBadge: some View {
        Text("?")
            .font(.caption2.weight(.black))
            .foregroundStyle(.white)
            .frame(width: 24, height: 24)
            .background(
                Circle()
                    .fill(LinearGradient(
                        colors: [theme.gold, theme.amber],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
            )
    }

    private var guessPanel: some View {
        GameGuessPanel(
            guess: $guess,
            placeholder: "Type player name...",
            inputIcon: "person.text.rectangle",
            gameResult: gameResult,
            onSubmit: onSubmit,
            onContinue: onNextRound,
            winContinueTitle: "Next Player",
            loseContinueTitle: "Try Again"
        )
    }

    private func runEntranceAnimation() {
        portraitProgress = 0
        cardProgress = 0
        hintsProgress = 0

        let curve = GameMotion.adaptive(GameMotion.silky, reduceMotion: reduceMotion)

        withAnimation(curve) {
            portraitProgress = 1
            cardProgress = 1
        }

        withAnimation(curve.delay(0.1)) {
            hintsProgress = 1
        }
    }
}
