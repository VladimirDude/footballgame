import SwiftUI

struct GameView: View {

    private let store = ClubDataStore.shared

    @State private var round: GameRound?
    @State private var guess = ""
    @State private var errorMessage: String?
    @State private var gameResult: GameResult?

    enum GameResult {
        case won
        case lost
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.1, green: 0.55, blue: 0.2), Color(red: 0.05, green: 0.4, blue: 0.15)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 12) {
                header

                if let errorMessage = errorMessage {
                    Spacer()
                    Text(errorMessage)
                        .multilineTextAlignment(.center)
                        .foregroundColor(.white)
                        .padding()
                    Button("Try Again") { startNewRound() }
                        .buttonStyle(.borderedProminent)
                    Spacer()
                } else if let round = round {
                    ScrollView {
                        VStack(spacing: 16) {
                            Text("Guess the club from the flags & positions")
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.9))
                                .multilineTextAlignment(.center)

                            Text("Tap a circle to reveal the player")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.65))

                            formationView(round.formation)
                                .id(round.clubID)

                            guessSection

                            if let gameResult = gameResult {
                                resultBanner(for: gameResult, clubName: round.clubName)
                            }
                        }
                        .padding(.bottom, 24)
                    }
                }
            }
            .padding(.horizontal)
        }
        .onAppear {
            if round == nil { startNewRound() }
        }
    }

    private var header: some View {
        HStack {
            Text("Guess the Club")
                .font(.title2.bold())
                .foregroundColor(.white)

            Spacer()

            if round != nil {
                Button("New Game") { startNewRound() }
                    .font(.subheadline.bold())
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.white.opacity(0.2))
                    .clipShape(Capsule())
            }
        }
        .padding(.top, 8)
    }

    private var guessSection: some View {
        VStack(spacing: 10) {
            TextField("Type club name...", text: $guess)
                .textFieldStyle(.roundedBorder)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.words)
                .disabled(gameResult != nil)
                .submitLabel(.done)
                .onSubmit(submitGuess)

            Button(action: submitGuess) {
                Text(gameResult == nil ? "Submit Guess" : "Guess Locked")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(gameResult == nil ? Color.white : Color.white.opacity(0.35))
                    .foregroundColor(gameResult == nil ? Color.green.opacity(0.9) : .white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .disabled(gameResult != nil || guess.trimmingCharacters(in: .whitespaces).isEmpty)
        }
        .padding(.horizontal, 4)
    }

    @ViewBuilder
    private func formationView(_ lines: [[FormationSlot]]) -> some View {
        VStack(spacing: 28) {
            ForEach(Array(lines.enumerated()), id: \.offset) { _, row in
                HStack(spacing: row.count > 3 ? 14 : 22) {
                    ForEach(row) { slot in
                        FlippableFormationSlot(slot: slot)
                    }
                }
            }
        }
        .padding(.vertical, 20)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.15), lineWidth: 1)
                )
        )
    }

    private func resultBanner(for result: GameResult, clubName: String) -> some View {
        VStack(spacing: 8) {
            Text(result == .won ? "Correct!" : "Wrong!")
                .font(.title2.bold())
                .foregroundColor(result == .won ? .yellow : .red.opacity(0.9))

            Text("The club was \(clubName)")
                .font(.headline)
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color.black.opacity(0.25))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func submitGuess() {
        guard gameResult == nil, let round = round else { return }

        let trimmed = guess.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        gameResult = ClubGuessValidator.isCorrect(guess: trimmed, round: round) ? .won : .lost
    }

    private func startNewRound() {
        errorMessage = nil
        gameResult = nil
        guess = ""

        if let newRound = store.randomGameRound() {
            round = newRound
        } else {
            round = nil
            errorMessage = "Could not build a lineup. Try New Game again."
        }
    }
}
