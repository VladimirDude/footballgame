import SwiftUI
import Combine

struct GameView: View {
    private let store = ClubDataStore.shared

    // Global Game Mode Selector (0 = Guess Club, 1 = Higher/Lower)
    @State private var selectedGameMode: Int = 0

    // --- Tab 1: Guess the Club States ---
    @State private var round: GameRound?
    @State private var guess = ""
    @State private var errorMessage: String?
    @State private var gameResult: GameResult?
    @State private var currentDifficulty: GameDifficulty = .easy
    @State private var revealedSlots: Set<String> = []
    @State private var hasUsedHint = false

    enum GameResult { case won, lost }

    // --- Tab 2: Higher or Lower States ---
    @State private var hlScore: Int = 0
    // Uses AppStorage to permanently save the high score to the device storage
    @AppStorage("higherOrLowerHighScore") private var hlHighScore: Int = 0
    @State private var hlPlayerLeft: HLPlayer?
    @State private var hlPlayerRight: HLPlayer?
    @State private var hlShowRightValue: Bool = false
    @State private var hlIsGameOver: Bool = false
    @State private var hlSlideIn: Bool = false
    @State private var hlShakeTrigger: Bool = false

    // --- Timer States for Higher or Lower ---
    @State private var timeRemaining: Int = 5
    @State private var hlTimerActive: Bool = false
    private let countdownTimer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            // Pitch Gradient Background
            LinearGradient(
                colors: [Color(red: 0.1, green: 0.55, blue: 0.2), Color(red: 0.05, green: 0.4, blue: 0.15)],
                startPoint: .top, endPoint: .bottom
            ).ignoresSafeArea()

            VStack(spacing: 12) {
                // Top Custom Mode Switching Bar
                gameModeSelector
                
                if selectedGameMode == 0 {
                    // --- MODE 1: GUESS THE CLUB ---
                    VStack(spacing: 12) {
                        header
                        
                        if let errorMessage = errorMessage {
                            Spacer()
                            Text(errorMessage).foregroundColor(.white).padding()
                            Button("Try Again") { startNewRound() }.buttonStyle(.borderedProminent)
                            Spacer()
                        } else if let round = round {
                            ScrollView {
                                VStack(spacing: 16) {
                                    Text("Guess the club from the flags & positions")
                                        .font(.subheadline)
                                        .foregroundColor(.white.opacity(0.9))
                                    
                                    formationView(round.formation).id(round.clubID)
                                    hintButton
                                    guessSection
                                    
                                    if let gameResult = gameResult {
                                        resultBanner(for: gameResult, clubName: round.clubName)
                                    }
                                }.padding(.bottom, 80)
                            }
                        }
                    }
                } else {
                    // --- MODE 2: HIGHER OR LOWER ---
                    higherOrLowerGameInterface
                }
            }
            .padding(.horizontal)
        }
        .onAppear {
            if round == nil { startNewRound() }
        }
        // Strict Time-Out Listener Loop
        .onReceive(countdownTimer) { _ in
            guard selectedGameMode == 1, hlTimerActive, !hlShowRightValue, !hlIsGameOver else { return }
            
            if timeRemaining > 0 {
                timeRemaining -= 1
            } else {
                // Time Expired: Automatically trigger loss sequence
                hlTimerActive = false
                hlIsGameOver = true
                withAnimation(.easeOut(duration: 0.25)) {
                    hlShowRightValue = true
                }
                withAnimation(.default) {
                    hlShakeTrigger = true
                }
            }
        }
    }

    // Modern Custom Tab Picker Switch
    private var gameModeSelector: some View {
        HStack(spacing: 0) {
            Button(action: { withAnimation(.easeInOut(duration: 0.2)) { selectedGameMode = 0 } }) {
                Text("Guess the Club")
                    .font(.subheadline.bold())
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(selectedGameMode == 0 ? Color.white.opacity(0.15) : Color.clear)
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            
            Button(action: {
                withAnimation(.easeInOut(duration: 0.2)) { selectedGameMode = 1 }
                if hlPlayerLeft == nil { setupInitialHLRound() }
            }) {
                Text("Higher or Lower")
                    .font(.subheadline.bold())
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(selectedGameMode == 1 ? Color.white.opacity(0.15) : Color.clear)
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .padding(4)
        .background(Color.black.opacity(0.2))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.top, 8)
    }

    // ==========================================
    // MARK: - GUESS THE CLUB COMPONENT VIEWS
    // ==========================================
    
    private var header: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Guess the Club").font(.title2.bold()).foregroundColor(.white)
                Spacer()
                if round != nil {
                    Button("New Game") { startNewRound() }
                        .padding(.horizontal, 12).padding(.vertical, 6)
                        .background(Color.white.opacity(0.2)).clipShape(Capsule())
                        .foregroundColor(.white)
                }
            }
            DifficultyPicker(selectedDifficulty: $currentDifficulty)
        }.padding(.top, 8)
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
        }.padding(20).background(RoundedRectangle(cornerRadius: 16).fill(Color.white.opacity(0.08)))
    }

    private var canUseHint: Bool {
        guard let round = round, !hasUsedHint, gameResult == nil else { return false }
        return revealedSlots.count < round.formation.flatMap { $0 }.count
    }

    private var hintButton: some View {
        Button {
            revealRandomPlayer()
            withAnimation { hasUsedHint = true }
        } label: {
            HStack {
                Image(systemName: hasUsedHint ? "lightbulb.slash.fill" : "lightbulb.fill")
                Text(hasUsedHint ? "Hint Used" : "Reveal Random Player")
            }
            .frame(maxWidth: .infinity).padding(14)
            .background(canUseHint ? Color.orange : Color.black.opacity(0.3))
            .foregroundColor(canUseHint ? .white : .white.opacity(0.4))
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }.disabled(!canUseHint)
    }

    private var guessSection: some View {
        VStack(spacing: 10) {
            TextField("Type club name...", text: $guess)
                .textFieldStyle(.roundedBorder).autocorrectionDisabled().onSubmit(submitGuess)
            Button(action: submitGuess) {
                Text(gameResult == nil ? "Submit Guess" : "Guess Locked")
                    .frame(maxWidth: .infinity).padding(12)
                    .background(gameResult == nil ? Color.white : Color.white.opacity(0.35))
                    .foregroundColor(gameResult == nil ? .green : .white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }.disabled(gameResult != nil)
        }
    }

    private func resultBanner(for result: GameResult, clubName: String) -> some View {
        Text(result == .won ? "Correct! \(clubName)" : "Wrong! It was \(clubName)")
            .foregroundColor(.white)
            .padding().background(Color.black.opacity(0.25)).clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func submitGuess() {
        guard gameResult == nil, let round = round else { return }
        gameResult = ClubGuessValidator.isCorrect(guess: guess, round: round) ? .won : .lost
        for slot in round.formation.flatMap({ $0 }) { revealedSlots.insert(slot.id) }
    }

    private func revealRandomPlayer() {
        guard let round = round, let random = round.formation.flatMap({ $0 }).filter({ !revealedSlots.contains($0.id) }).randomElement() else { return }
        revealedSlots.insert(random.id)
    }

    private func startNewRound() {
        errorMessage = nil; gameResult = nil; guess = ""; revealedSlots.removeAll(); hasUsedHint = false
        if let newRound = store.randomGameRound(for: currentDifficulty) {
            round = newRound
        } else {
            errorMessage = "No clubs found for \(currentDifficulty.rawValue) mode."
        }
    }

    // ==========================================
    // MARK: - HIGHER OR LOWER MODE INTERFACE
    // ==========================================
    
    private var higherOrLowerGameInterface: some View {
        VStack(spacing: 16) {
            // Score tracking row
            HStack {
                VStack(alignment: .leading) {
                    Text("Streak").font(.caption).foregroundColor(.white.opacity(0.7))
                    Text("\(hlScore)").font(.title2.bold()).foregroundColor(.white)
                }
                Spacer()
                VStack(alignment: .trailing) {
                    Text("Best Streak").font(.caption).foregroundColor(.white.opacity(0.7))
                    Text("\(hlHighScore)").font(.title2.bold()).foregroundColor(.orange)
                }
            }
            .padding(.horizontal, 8)
            .padding(.top, 4)

            // Anti-Cheat Progress Bar UI
            if !hlShowRightValue && !hlIsGameOver {
                VStack(spacing: 4) {
                    ProgressView(value: Double(timeRemaining), total: 5.0)
                        .progressViewStyle(.linear)
                        .tint(timeRemaining <= 2 ? .red : .orange)
                        .scaleEffect(x: 1, y: 1.5, anchor: .center)
                        .animation(.easeInOut(duration: 0.2), value: timeRemaining)
                    
                    Text("\(timeRemaining) seconds left!")
                        .font(.caption.bold())
                        .foregroundColor(timeRemaining <= 2 ? .red : .white.opacity(0.8))
                }
                .padding(.horizontal, 8)
            }

            if let left = hlPlayerLeft, let right = hlPlayerRight {
                VStack(spacing: 12) {
                    HLPlayerCard(player: left, displayValue: true)
                    
                    Text("VS")
                        .font(.caption.bold())
                        .foregroundColor(.white)
                        .padding(.vertical, 4).padding(.horizontal, 14)
                        .background(Capsule().fill(Color.black.opacity(0.3)))
                    
                    HLPlayerCard(player: right, displayValue: hlShowRightValue)
                        .offset(x: hlSlideIn ? 0 : 350)
                        .opacity(hlSlideIn ? 1 : 0)
                        .modifier(HLShakeEffect(animatableData: hlShakeTrigger ? 1 : 0))
                }
                
                if !hlShowRightValue {
                    HStack(spacing: 16) {
                        Button(action: { processHLGuess(guessedHigher: true) }) {
                            Text("HIGHER ⬆️")
                                .font(.headline).bold()
                                .frame(maxWidth: .infinity).padding(.vertical, 14)
                                .background(Color.orange)
                                .foregroundColor(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        
                        Button(action: { processHLGuess(guessedHigher: false) }) {
                            Text("LOWER ⬇️")
                                .font(.headline).bold()
                                .frame(maxWidth: .infinity).padding(.vertical, 14)
                                .background(Color.white.opacity(0.2))
                                .foregroundColor(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }
                    .padding(.top, 10)
                } else {
                    Button(action: cycleToNextHLRound) {
                        Text(hlIsGameOver ? "Try Again 🔄" : "Next Matchup ➡️")
                            .font(.headline).bold()
                            .frame(maxWidth: .infinity).padding(.vertical, 14)
                            .background(hlIsGameOver ? Color.red : Color.white)
                            .foregroundColor(hlIsGameOver ? .white : .green)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .padding(.top, 10)
                }
            } else {
                Spacer()
                Text("Loading database elements...").foregroundColor(.white)
                Spacer()
            }
            Spacer()
        }
    }

    // ==========================================
    // MARK: - HIGHER OR LOWER GAME LOGIC
    // ==========================================
    
    private func fetchAllPlayersFromStore() -> [HLPlayer] {
        return store.fetchHigherOrLowerPool()
    }

    private func setupInitialHLRound() {
        let pool = fetchAllPlayersFromStore()
        guard pool.count >= 2 else { return }
        
        let randomized = pool.shuffled()
        hlPlayerLeft = randomized[0]
        hlPlayerRight = randomized[1]
        
        hlShowRightValue = false
        hlIsGameOver = false
        hlShakeTrigger = false
        
        timeRemaining = 5
        hlTimerActive = true
        
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            hlSlideIn = true
        }
    }

    private func processHLGuess(guessedHigher: Bool) {
        guard let left = hlPlayerLeft, let right = hlPlayerRight else { return }
        
        hlTimerActive = false // Pause countdown instantly on guess submit
        
        withAnimation(.easeOut(duration: 0.25)) {
            hlShowRightValue = true
        }
        
        let isCorrect: Bool
        if right.marketValue == left.marketValue {
            isCorrect = true // Equal values count as a point win!
        } else if guessedHigher {
            isCorrect = right.marketValue > left.marketValue
        } else {
            isCorrect = right.marketValue < left.marketValue
        }
        
        if isCorrect {
            hlScore += 1
            if hlScore > hlHighScore { hlHighScore = hlScore }
            hlIsGameOver = false
        } else {
            hlIsGameOver = true
            withAnimation(.default) {
                hlShakeTrigger = true
            }
        }
    }

    private func cycleToNextHLRound() {
        if hlIsGameOver {
            hlScore = 0
            setupInitialHLRound()
        } else {
            hlPlayerLeft = hlPlayerRight
            let pool = fetchAllPlayersFromStore().filter { $0.name != hlPlayerLeft?.name }
            
            if let newRight = pool.randomElement() {
                hlPlayerRight = newRight
            }
            
            hlSlideIn = false
            hlShowRightValue = false
            hlShakeTrigger = false
            
            timeRemaining = 5
            hlTimerActive = true
            
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                hlSlideIn = true
            }
        }
    }
}

// ==========================================
// MARK: - EXTERNAL STRUCTS & COMPONENTS
// ==========================================

struct DifficultyPicker: View {
    @Binding var selectedDifficulty: GameDifficulty
    var body: some View {
        HStack {
            ForEach(GameDifficulty.allCases, id: \.self) { diff in
                Button(diff.rawValue) { withAnimation { selectedDifficulty = diff } }
                    .font(.subheadline.bold())
                    .frame(maxWidth: .infinity).padding(10)
                    .background(selectedDifficulty == diff ? Color.orange : Color.white.opacity(0.08))
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }.padding(6).background(Color.black.opacity(0.2)).clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct HLPlayer: Equatable {
    let id: String
    let name: String
    let clubName: String
    let marketValue: Int
    let image: String
}

struct HLPlayerCard: View {
    let player: HLPlayer
    let displayValue: Bool

    var body: some View {
        VStack(spacing: 12) {
            PlayerPortraitImage(
                playerID: player.id,
                imageValue: player.image,
                style: .card
            )

            VStack(spacing: 4) {
                Text(player.name)
                    .font(.headline)
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)

                Text(player.clubName)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.72))
                    .multilineTextAlignment(.center)
                    .lineLimit(1)

                if displayValue {
                    Text(formatCurrency(player.marketValue))
                        .font(.title3.bold())
                        .foregroundColor(.yellow)
                        .padding(.top, 2)
                } else {
                    Text("Market Value: ???")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.white.opacity(0.45))
                        .padding(.top, 2)
                }
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 14)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.1))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.14), lineWidth: 1)
        )
    }

    private func formatCurrency(_ val: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "EUR"
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: val)) ?? "€\(val)"
    }
}

struct HLShakeEffect: GeometryEffect {
    var animatableData: CGFloat
    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(CGAffineTransform(translationX: 8 * sin(animatableData * .pi * 4), y: 0))
    }
}
