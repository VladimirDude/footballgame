import SwiftUI

struct GuessPlayerGameView: View {
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

    @State private var portraitScale: CGFloat = 0.88
    @State private var portraitOpacity: Double = 0
    @State private var cardOffset: CGFloat = 28
    @State private var hintsRevealed = false
    @State private var glowPulse = false

    private var resultBorder: Color {
        switch gameResult {
        case .won: .green
        case .lost: Color(red: 1, green: 0.35, blue: 0.35)
        case nil: Color.white.opacity(0.14)
        }
    }

    var body: some View {
        VStack(spacing: 12) {
            GPPlayerTopBar(
                streak: streak,
                bestStreak: bestStreak,
                timeRemaining: timeRemaining,
                total: totalTime
            )

            VStack(spacing: 14) {
                Text("Who is this player?")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.9))

                playerCard
                    .offset(y: cardOffset)
                    .opacity(portraitOpacity)
                    .modifier(GPShakeEffect(animatableData: shakeWrong ? 1 : 0))

                guessSection

                if let gameResult {
                    resultBanner(for: gameResult)
                        .transition(.scale(scale: 0.9).combined(with: .opacity))
                }
            }

            Spacer(minLength: 0)
        }
        .frame(maxHeight: .infinity)
        .onAppear { runEntranceAnimation() }
        .onChange(of: round.id) { _, _ in
            runEntranceAnimation()
        }
        .onChange(of: showClubHint) { _, revealed in
            guard revealed else { return }
            withAnimation(.spring(response: 0.45, dampingFraction: 0.72)) {
                hintsRevealed = true
            }
        }
    }

    private var playerCard: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color.white.opacity(glowPulse ? 0.22 : 0.12),
                                .clear,
                            ],
                            center: .center,
                            startRadius: 20,
                            endRadius: 90
                        )
                    )
                    .frame(width: 160, height: 160)
                    .animation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true), value: glowPulse)

                PlayerPortraitImage(playerID: round.id, style: .card)
                    .scaleEffect(portraitScale)
                    .shadow(color: .black.opacity(0.35), radius: 14, y: 8)
            }

            HStack(spacing: 8) {
                hintPill(icon: "figure.soccer", text: round.position, delay: 0)
                hintPill(icon: "flag.fill", text: CountryFlags.primaryFlag(from: round.nationalities), delay: 0.06)

                if showClubHint {
                    hintPill(icon: "shield.fill", text: round.clubName, delay: 0.12)
                        .transition(.asymmetric(
                            insertion: .scale(scale: 0.6).combined(with: .opacity),
                            removal: .opacity
                        ))
                }
            }
            .animation(.spring(response: 0.42, dampingFraction: 0.75), value: showClubHint)

            if !showClubHint, gameResult == nil {
                Button(action: onRevealClubHint) {
                    Label("Reveal Club Hint", systemImage: "lightbulb.fill")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            LinearGradient(
                                colors: [.orange, Color(red: 0.95, green: 0.45, blue: 0.1)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .shadow(color: .orange.opacity(0.35), radius: 8, y: 4)
                }
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.black.opacity(0.22))
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(resultBorder, lineWidth: gameResult == nil ? 1 : 2.5)
                )
        )
        .animation(.spring(response: 0.4, dampingFraction: 0.75), value: gameResult == nil)
    }

    private var guessSection: some View {
        VStack(spacing: 10) {
            TextField("Type player name...", text: $guess)
                .textFieldStyle(.roundedBorder)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.words)
                .onSubmit(onSubmit)
                .disabled(gameResult != nil)

            if gameResult == nil {
                Button(action: onSubmit) {
                    Text("Submit Guess")
                        .font(.headline.weight(.bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .background(Color.white)
                        .foregroundStyle(Color(red: 0.05, green: 0.4, blue: 0.15))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .shadow(color: .black.opacity(0.15), radius: 6, y: 3)
                }
            } else {
                Button(action: onNextRound) {
                    Text(gameResult == .won ? "Next Player →" : "Try Again")
                        .font(.headline.weight(.bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .background(gameResult == .won ? Color.white : Color.red.opacity(0.9))
                        .foregroundStyle(gameResult == .won ? Color(red: 0.05, green: 0.4, blue: 0.15) : .white)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .transition(.scale(scale: 0.95).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.38, dampingFraction: 0.82), value: gameResult == nil)
    }

    private func hintPill(icon: String, text: String, delay: Double) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption.weight(.bold))
            Text(text)
                .font(.caption.weight(.semibold))
                .lineLimit(1)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Capsule().fill(Color.black.opacity(0.32)))
        .foregroundStyle(.white)
        .opacity(hintsRevealed ? 1 : 0)
        .offset(y: hintsRevealed ? 0 : 10)
        .animation(.spring(response: 0.45, dampingFraction: 0.78).delay(delay), value: hintsRevealed)
    }

    private func resultBanner(for result: GameResult) -> some View {
        HStack(spacing: 10) {
            Image(systemName: result == .won ? "checkmark.seal.fill" : "xmark.seal.fill")
            Text(result == .won ? "Correct! \(round.playerName)" : "It was \(round.playerName)")
                .font(.subheadline.weight(.bold))
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(result == .won ? Color.green.opacity(0.82) : Color.red.opacity(0.82))
        )
        .shadow(color: (result == .won ? Color.green : Color.red).opacity(0.35), radius: 10, y: 4)
    }

    private func runEntranceAnimation() {
        portraitScale = 0.88
        portraitOpacity = 0
        cardOffset = 28
        hintsRevealed = false
        glowPulse = false

        withAnimation(.spring(response: 0.55, dampingFraction: 0.78)) {
            portraitScale = 1
            portraitOpacity = 1
            cardOffset = 0
        }

        withAnimation(.spring(response: 0.48, dampingFraction: 0.8).delay(0.12)) {
            hintsRevealed = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            glowPulse = true
        }
    }
}
