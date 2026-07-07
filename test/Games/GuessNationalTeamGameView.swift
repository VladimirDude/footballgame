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
        VStack(spacing: 12) {
            header

            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    GameStreakBar(streak: streak, bestStreak: bestStreak)

                    Text("Guess the national team from the clubs & positions")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.9))
                        .multilineTextAlignment(.center)

                    formationView(round.formation)
                        .id(round.nationName)
                        .transition(.scale(scale: 0.96).combined(with: .opacity))

                    hintButton
                    guessSection

                    if let gameResult {
                        resultBanner(for: gameResult, nationName: round.nationName)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
                .padding(.bottom, 80)
            }
        }
    }

    private var header: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Guess the Nation")
                    .font(.title2.bold())
                    .foregroundStyle(.white)
                Spacer()
                Button("New Game", action: onNewGame)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.white.opacity(0.2))
                    .clipShape(Capsule())
                    .foregroundStyle(.white)
            }
            NationalTeamDifficultyPicker(selectedDifficulty: $difficulty)
        }
        .padding(.top, 8)
    }

    @ViewBuilder
    private func formationView(_ lines: [[FormationSlot]]) -> some View {
        VStack(spacing: 28) {
            ForEach(Array(lines.enumerated()), id: \.offset) { _, row in
                HStack(spacing: row.count > 3 ? 14 : 22) {
                    ForEach(row, id: \.id) { slot in
                        FlippableFormationSlot(slot: slot, revealedPlayerIds: $revealedSlots)
                            .allowsHitTesting(!hasUsedHint && gameResult == nil)
                    }
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.08))
        )
    }

    private var hintButton: some View {
        Button(action: onRevealHint) {
            HStack {
                Image(systemName: hasUsedHint ? "lightbulb.slash.fill" : "lightbulb.fill")
                Text(hasUsedHint ? "Hint Used" : "Reveal Random Player")
            }
            .frame(maxWidth: .infinity)
            .padding(14)
            .background(canUseHint ? Color.orange : Color.black.opacity(0.3))
            .foregroundStyle(canUseHint ? .white : .white.opacity(0.4))
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .disabled(!canUseHint)
    }

    private var guessSection: some View {
        VStack(spacing: 10) {
            TextField("Type country name...", text: $guess)
                .textFieldStyle(.roundedBorder)
                .autocorrectionDisabled()
                .onSubmit(onSubmit)
                .disabled(gameResult != nil)

            if gameResult == nil {
                Button(action: onSubmit) {
                    Text("Submit Guess")
                        .frame(maxWidth: .infinity)
                        .padding(12)
                        .background(Color.white)
                        .foregroundStyle(.green)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            } else {
                Button(action: gameResult == .won ? onNextRound : onNewGame) {
                    Text(gameResult == .won ? "Next Nation →" : "Try Again")
                        .frame(maxWidth: .infinity)
                        .padding(12)
                        .background(gameResult == .won ? Color.white : Color.red.opacity(0.9))
                        .foregroundStyle(gameResult == .won ? .green : .white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
        }
    }

    private func resultBanner(for result: GameResult, nationName: String) -> some View {
        HStack(spacing: 8) {
            Text(round.flag)
                .font(.title3)
            Text(result == .won ? "Correct! \(nationName)" : "Wrong! It was \(nationName)")
                .font(.subheadline.weight(.semibold))
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color.black.opacity(0.25))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

struct NationalTeamDifficultyPicker: View {
    @Binding var selectedDifficulty: NationalTeamDifficulty

    var body: some View {
        HStack {
            ForEach(NationalTeamDifficulty.allCases) { diff in
                Button(diff.rawValue) {
                    withAnimation { selectedDifficulty = diff }
                }
                .font(.subheadline.bold())
                .frame(maxWidth: .infinity)
                .padding(10)
                .background(selectedDifficulty == diff ? Color.orange : Color.white.opacity(0.08))
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }
        .padding(6)
        .background(Color.black.opacity(0.2))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
