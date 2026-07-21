import SwiftUI
import Combine

struct GameView: View {
    private let store = ClubDataStore.shared
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.scenePhase) private var scenePhase

    private var theme: GameModeTheme {
        GameModeTheme.theme(for: selectedTab, colorScheme: colorScheme)
    }

    @State private var selectedTab: GameTab = .guessClub

    // Guess the Club
    @State private var round: GameRound?
    @State private var guess = ""
    @State private var errorMessage: String?
    @State private var gameResult: GameResult?
    @State private var currentDifficulty: GameDifficulty = .easy
    @State private var revealedSlots: Set<String> = []
    @State private var hasUsedHint = false
    @State private var gcStreak = 0
    @AppStorage("guessClubBestStreak") private var gcBestStreak = 0

    // Guess the National Team
    @State private var gnRound: NationalTeamRound?
    @State private var gnGuess = ""
    @State private var gnErrorMessage: String?
    @State private var gnResult: GameResult?
    @State private var gnDifficulty: NationalTeamDifficulty = .easy
    @State private var gnRevealedSlots: Set<String> = []
    @State private var gnHasUsedHint = false
    @State private var gnStreak = 0
    @AppStorage("guessNationBestStreak") private var gnBestStreak = 0

    // Guess the Player
    @State private var gpRound: GuessPlayerRound?
    @State private var gpGuess = ""
    @State private var gpResult: GameResult?
    @State private var gpShowClubHint = false
    @State private var gpShakeWrong = false
    @State private var gpStreak = 0
    @AppStorage("guessPlayerBestStreak") private var gpBestStreak = 0
    @State private var gpTimeRemaining = 10
    @State private var gpTimerActive = false

    private let gpTotalTime = 10

    // Higher or Lower
    @State private var hlScore = 0
    @AppStorage("higherOrLowerHighScore") private var hlHighScore = 0
    @State private var hlPlayerLeft: HLPlayer?
    @State private var hlPlayerRight: HLPlayer?
    @State private var hlShowRightValue = false
    @State private var hlIsGameOver = false
    @State private var hlShakeTrigger = false
    @State private var hlRevealState: HLRevealState = .hidden
    @State private var hlLastGuessCorrect: Bool?
    @State private var hlTimeRemaining = 5
    @State private var hlTimerActive = false

    // Wordle
    @State private var wordleTarget: WordlePlayer?
    @State private var wordleGuesses: [WordleGuess] = []
    @State private var wordleResult: GameResult?
    @State private var wordleSearchQuery = ""
    @State private var wordleSelectedPlayer: WordlePlayer?
    @State private var wordleDuplicateGuess = false

    private let countdownTimer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            GameModeBackdrop(tab: selectedTab)
                .animation(GameMotion.dissolve, value: selectedTab)

            VStack(spacing: GameDesign.spacingMD) {
                GameModeSwitcher(selection: $selectedTab, onSelect: handleTabSelection)

                Group {
                    switch selectedTab {
                    case .guessClub:
                        guessClubContent
                    case .guessNation:
                        guessNationContent
                    case .guessPlayer:
                        guessPlayerContent
                    case .wordle:
                        wordleContent
                    case .higherLower:
                        higherLowerContent
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .transition(.opacity)
                .id(selectedTab)
            }
            .environment(\.gameTheme, GameModeTheme.theme(for: selectedTab, colorScheme: colorScheme))
            .animation(GameMotion.dissolve, value: selectedTab)
            .animation(.easeInOut(duration: 0.25), value: colorScheme)
            .safeAreaPadding(.top, 8)
            .frame(maxHeight: .infinity, alignment: .top)
            .padding(.horizontal)
            .adaptiveContentWidth(AdaptiveLayout.gameMaxWidth)
        }
        .onAppear {
            if round == nil { startNewRound() }
        }
        .onChange(of: currentDifficulty) { _, _ in
            gcStreak = 0
            startNewRound()
        }
        .onChange(of: gnDifficulty) { _, _ in
            gnStreak = 0
            startNewNationRound()
        }
        .onChange(of: selectedTab) { _, tab in
            gpTimerActive = tab == .guessPlayer && gpResult == nil
            hlTimerActive = tab == .higherLower && !hlShowRightValue && !hlIsGameOver
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active:
                if selectedTab == .guessPlayer, gpResult == nil {
                    gpTimerActive = true
                }
                if selectedTab == .higherLower, !hlShowRightValue, !hlIsGameOver {
                    hlTimerActive = true
                }
            case .inactive, .background:
                gpTimerActive = false
                hlTimerActive = false
            @unknown default:
                break
            }
        }
        .onReceive(countdownTimer) { _ in
            tickHigherLowerTimer()
            tickGuessPlayerTimer()
        }
    }

    private func tickHigherLowerTimer() {
        guard selectedTab == .higherLower, hlTimerActive, !hlShowRightValue, !hlIsGameOver else { return }

        if hlTimeRemaining > 0 {
            hlTimeRemaining -= 1
        } else {
            hlTimerActive = false
            hlIsGameOver = true
            hlLastGuessCorrect = false
            hlRevealState = .wrong
            HapticFeedback.error()
            withAnimation(GameMotion.fade) { hlShowRightValue = true }
            withAnimation(.default) { hlShakeTrigger = true }
        }
    }

    private func tickGuessPlayerTimer() {
        guard selectedTab == .guessPlayer, gpTimerActive, gpResult == nil else { return }

        if gpTimeRemaining > 0 {
            gpTimeRemaining -= 1
        } else {
            handleGuessPlayerTimeout()
        }
    }

    private func handleGuessPlayerTimeout() {
        gpTimerActive = false
        gpStreak = 0
        gpShowClubHint = true

        withAnimation(.spring(response: 0.4, dampingFraction: 0.78)) {
            gpResult = .lost
        }
        HapticFeedback.error()
        withAnimation(.default) { gpShakeWrong.toggle() }
    }

    // MARK: - Tab Content

    @ViewBuilder
    private var wordleContent: some View {
        if let target = wordleTarget {
            WordleGameView(
                target: target,
                guesses: wordleGuesses,
                gameResult: wordleResult,
                searchQuery: $wordleSearchQuery,
                suggestions: wordleSuggestions,
                selectedPlayer: wordleSelectedPlayer,
                duplicateGuess: wordleDuplicateGuess,
                onSelectPlayer: selectWordlePlayer,
                onClearSelection: clearWordleSelection,
                onSubmit: submitWordleGuess,
                onPlayAgain: startNewWordleRound
            )
        } else {
            VStack(spacing: 12) {
                Spacer()
                ProgressView().tint(theme.accent)
                Text("Loading players...")
                    .foregroundStyle(theme.textSecondary)
                Spacer()
            }
            .onAppear { startNewWordleRound() }
        }
    }

    private var wordleSuggestions: [WordlePlayer] {
        guard wordleSelectedPlayer == nil else { return [] }
        return store.searchWordlePlayers(wordleSearchQuery)
    }

    @ViewBuilder
    private var guessClubContent: some View {
        if let errorMessage {
            VStack(spacing: 12) {
                Spacer()
                Text(errorMessage).foregroundStyle(theme.textPrimary)
                Button("Try Again", action: startNewRound)
                    .buttonStyle(.borderedProminent)
                Spacer()
            }
        } else if let round {
            GuessClubGameView(
                round: round,
                guess: $guess,
                gameResult: gameResult,
                streak: gcStreak,
                bestStreak: gcBestStreak,
                revealedSlots: $revealedSlots,
                hasUsedHint: hasUsedHint,
                canUseHint: canUseHint(for: round),
                difficulty: $currentDifficulty,
                onNewGame: startNewRound,
                onRevealHint: revealRandomPlayer,
                onSubmit: submitClubGuess,
                onNextRound: advanceClubRound
            )
        }
    }

    @ViewBuilder
    private var guessPlayerContent: some View {
        if let currentRound = gpRound {
            GuessPlayerGameView(
                round: currentRound,
                guess: $gpGuess,
                gameResult: gpResult,
                streak: gpStreak,
                bestStreak: gpBestStreak,
                timeRemaining: gpResult == nil ? gpTimeRemaining : nil,
                totalTime: gpTotalTime,
                showClubHint: gpShowClubHint,
                shakeWrong: gpShakeWrong,
                onRevealClubHint: {
                    withAnimation(.spring(response: 0.42, dampingFraction: 0.75)) {
                        gpShowClubHint = true
                    }
                },
                onSubmit: submitPlayerGuess,
                onNextRound: {
                    if gpResult == .won {
                        advancePlayerRound()
                    } else {
                        startNewPlayerRound()
                    }
                }
            )
        } else {
            VStack(spacing: 12) {
                Spacer()
                ProgressView().tint(theme.accent)
                Text("Loading star players...")
                    .foregroundStyle(theme.textSecondary)
                Spacer()
            }
            .onAppear { startNewPlayerRound() }
        }
    }

    @ViewBuilder
    private var guessNationContent: some View {
        if let gnErrorMessage {
            VStack(spacing: 12) {
                Spacer()
                Text(gnErrorMessage).foregroundStyle(theme.textPrimary)
                Button("Try Again", action: startNewNationRound)
                    .buttonStyle(.borderedProminent)
                Spacer()
            }
        } else if let gnRound {
            GuessNationalTeamGameView(
                round: gnRound,
                guess: $gnGuess,
                gameResult: gnResult,
                streak: gnStreak,
                bestStreak: gnBestStreak,
                revealedSlots: $gnRevealedSlots,
                hasUsedHint: gnHasUsedHint,
                canUseHint: canUseNationHint(for: gnRound),
                difficulty: $gnDifficulty,
                onNewGame: startNewNationRound,
                onRevealHint: revealRandomNationPlayer,
                onSubmit: submitNationGuess,
                onNextRound: advanceNationRound
            )
        }
    }

    private var higherLowerContent: some View {
        HigherOrLowerGameView(
            streak: hlScore,
            bestStreak: hlHighScore,
            timeRemaining: (!hlShowRightValue && !hlIsGameOver) ? hlTimeRemaining : nil,
            left: hlPlayerLeft,
            right: hlPlayerRight,
            revealState: hlRevealState,
            shakeTrigger: hlShakeTrigger,
            showRightValue: hlShowRightValue,
            isGameOver: hlIsGameOver,
            lastGuessCorrect: hlLastGuessCorrect,
            onHigher: { processHLGuess(guessedHigher: true) },
            onLower: { processHLGuess(guessedHigher: false) },
            onContinue: cycleToNextHLRound
        )
    }

    // MARK: - Tab Selection

    private func handleTabSelection(_ tab: GameTab) {
        switch tab {
        case .higherLower where hlPlayerLeft == nil:
            setupInitialHLRound()
        case .guessPlayer where gpRound == nil:
            startNewPlayerRound()
        case .wordle where wordleTarget == nil:
            startNewWordleRound()
        case .guessNation where gnRound == nil:
            startNewNationRound()
        default:
            break
        }
    }

    // MARK: - Wordle Logic

    private func selectWordlePlayer(_ player: WordlePlayer) {
        wordleSelectedPlayer = player
        wordleSearchQuery = player.name
        wordleDuplicateGuess = false
        HapticFeedback.selection()
    }

    private func clearWordleSelection() {
        wordleSelectedPlayer = nil
        wordleSearchQuery = ""
        wordleDuplicateGuess = false
    }

    private func submitWordleGuess() {
        guard wordleResult == nil,
              let target = wordleTarget,
              let player = wordleSelectedPlayer
        else { return }

        if wordleGuesses.contains(where: { $0.player.id == player.id }) {
            wordleDuplicateGuess = true
            HapticFeedback.warning()
            return
        }

        wordleDuplicateGuess = false
        let feedback = WordleEvaluator.evaluate(guess: player, target: target)
        let guess = WordleGuess(id: UUID().uuidString, player: player, feedback: feedback)

        withAnimation(.spring(response: 0.4, dampingFraction: 0.78)) {
            wordleGuesses.append(guess)
        }

        if WordleEvaluator.isWinningGuess(player, target: target) {
            withAnimation(.spring(response: 0.38, dampingFraction: 0.82)) {
                wordleResult = .won
            }
            HapticFeedback.success()
        } else if wordleGuesses.count >= WordleEvaluator.maxGuesses {
            withAnimation(.spring(response: 0.38, dampingFraction: 0.82)) {
                wordleResult = .lost
            }
            HapticFeedback.error()
        }

        wordleSelectedPlayer = nil
        wordleSearchQuery = ""
    }

    private func startNewWordleRound() {
        let previousID = wordleTarget?.id
        wordleGuesses = []
        wordleResult = nil
        wordleSearchQuery = ""
        wordleSelectedPlayer = nil
        wordleDuplicateGuess = false

        withAnimation(.spring(response: 0.42, dampingFraction: 0.82)) {
            wordleTarget = store.randomWordlePlayer(
                excluding: Set([previousID].compactMap { $0 })
            )
        }
    }

    // MARK: - Guess Nation Logic

    private func canUseNationHint(for round: NationalTeamRound) -> Bool {
        guard !gnHasUsedHint, gnResult == nil else { return false }
        return gnRevealedSlots.count < round.formation.flatMap { $0 }.count
    }

    private func submitNationGuess() {
        guard gnResult == nil, let round = gnRound, isSubmittableGuess(gnGuess) else { return }
        let won = NationalTeamGuessValidator.isCorrect(guess: gnGuess, round: round)

        withAnimation(.spring(response: 0.38, dampingFraction: 0.82)) {
            gnResult = won ? .won : .lost
        }

        if won {
            gnStreak += 1
            if gnStreak > gnBestStreak { gnBestStreak = gnStreak }
            HapticFeedback.success()
        } else {
            gnStreak = 0
            HapticFeedback.error()
        }

        for slot in round.formation.flatMap({ $0 }) { gnRevealedSlots.insert(slot.id) }
    }

    private func advanceNationRound() {
        let previousName = gnRound?.nationName
        gnResult = nil
        gnGuess = ""
        gnRevealedSlots.removeAll()
        gnHasUsedHint = false

        var newRound: NationalTeamRound?
        for _ in 0..<12 {
            guard let candidate = store.randomNationalTeamRound(for: gnDifficulty) else { break }
            if candidate.nationName != previousName {
                newRound = candidate
                break
            }
        }

        withAnimation(.spring(response: 0.42, dampingFraction: 0.82)) {
            gnRound = newRound ?? store.randomNationalTeamRound(for: gnDifficulty)
        }
    }

    private func revealRandomNationPlayer() {
        guard let round = gnRound,
              let random = round.formation.flatMap({ $0 }).filter({ !gnRevealedSlots.contains($0.id) }).randomElement()
        else { return }
        withAnimation(GameMotion.fade) { gnRevealedSlots.insert(random.id) }
        HapticFeedback.light()
        gnHasUsedHint = true
    }

    private func startNewNationRound() {
        gnErrorMessage = nil
        gnResult = nil
        gnGuess = ""
        gnRevealedSlots.removeAll()
        gnHasUsedHint = false
        if let newRound = store.randomNationalTeamRound(for: gnDifficulty) {
            gnRound = newRound
        } else {
            gnErrorMessage = "No national teams found for \(gnDifficulty.rawValue) mode."
        }
    }

    // MARK: - Guess Club Logic

    private func canUseHint(for round: GameRound) -> Bool {
        guard !hasUsedHint, gameResult == nil else { return false }
        return revealedSlots.count < round.formation.flatMap { $0 }.count
    }

    private func submitClubGuess() {
        guard gameResult == nil, let round, isSubmittableGuess(guess) else { return }
        let won = ClubGuessValidator.isCorrect(guess: guess, round: round)
        withAnimation(.spring(response: 0.38, dampingFraction: 0.82)) {
            gameResult = won ? .won : .lost
        }

        if won {
            gcStreak += 1
            if gcStreak > gcBestStreak { gcBestStreak = gcStreak }
            HapticFeedback.success()
        } else {
            gcStreak = 0
            HapticFeedback.error()
        }

        for slot in round.formation.flatMap({ $0 }) { revealedSlots.insert(slot.id) }
    }

    private func advanceClubRound() {
        let previousID = round?.clubID
        gameResult = nil
        guess = ""
        revealedSlots.removeAll()
        hasUsedHint = false

        var newRound: GameRound?
        for _ in 0..<12 {
            guard let candidate = store.randomGameRound(for: currentDifficulty) else { break }
            if candidate.clubID != previousID {
                newRound = candidate
                break
            }
        }
        withAnimation(.spring(response: 0.42, dampingFraction: 0.82)) {
            round = newRound ?? store.randomGameRound(for: currentDifficulty)
        }
    }

    private func revealRandomPlayer() {
        guard let round,
              let random = round.formation.flatMap({ $0 }).filter({ !revealedSlots.contains($0.id) }).randomElement()
        else { return }
        withAnimation(GameMotion.fade) { revealedSlots.insert(random.id) }
        HapticFeedback.light()
        hasUsedHint = true
    }

    private func startNewRound() {
        errorMessage = nil
        gameResult = nil
        guess = ""
        revealedSlots.removeAll()
        hasUsedHint = false
        if let newRound = store.randomGameRound(for: currentDifficulty) {
            round = newRound
        } else {
            errorMessage = "No clubs found for \(currentDifficulty.rawValue) mode."
        }
    }

    // MARK: - Guess Player Logic

    private func submitPlayerGuess() {
        guard gpResult == nil, let round = gpRound, isSubmittableGuess(gpGuess) else { return }
        gpTimerActive = false

        let won = PlayerGuessValidator.isCorrect(guess: gpGuess, round: round)

        withAnimation(.spring(response: 0.4, dampingFraction: 0.78)) {
            gpResult = won ? .won : .lost
        }

        if won {
            gpStreak += 1
            if gpStreak > gpBestStreak { gpBestStreak = gpStreak }
            HapticFeedback.success()
        } else {
            gpStreak = 0
            gpShowClubHint = true
            HapticFeedback.error()
            withAnimation(.default) { gpShakeWrong.toggle() }
        }
    }

    private func resetGuessPlayerTimer() {
        gpTimeRemaining = gpTotalTime
        gpTimerActive = true
    }

    private func startNewPlayerRound() {
        gpGuess = ""
        gpResult = nil
        gpShowClubHint = false
        gpShakeWrong = false
        if let newRound = store.randomGuessPlayerRound() {
            gpRound = newRound
            resetGuessPlayerTimer()
        } else {
            gpRound = nil
        }
    }

    private func advancePlayerRound() {
        let previousID = gpRound?.id
        gpGuess = ""
        gpResult = nil
        gpShowClubHint = false
        gpShakeWrong = false

        withAnimation(.spring(response: 0.45, dampingFraction: 0.82)) {
            gpRound = store.randomGuessPlayerRound(
                excluding: Set([previousID].compactMap { $0 })
            )
        }
        resetGuessPlayerTimer()
    }

    // MARK: - Higher or Lower Logic

    private func setupInitialHLRound() {
        let pool = store.fetchHigherOrLowerPool()
        guard pool.count >= 2 else { return }

        let randomized = pool.shuffled()
        hlPlayerLeft = randomized[0]
        hlPlayerRight = pickHLChallenger(excluding: hlPlayerLeft, from: pool) ?? randomized[1]
        resetHLRoundState()
        hlTimeRemaining = 5
        hlTimerActive = true
    }

    private func pickHLChallenger(excluding anchor: HLPlayer?, from pool: [HLPlayer]) -> HLPlayer? {
        guard let anchor else { return pool.randomElement() }

        var candidates = pool.filter { $0.id != anchor.id && $0.marketValue != anchor.marketValue }
        if candidates.isEmpty {
            candidates = pool.filter { $0.id != anchor.id }
        }
        return candidates.randomElement()
    }

    private func processHLGuess(guessedHigher: Bool) {
        guard let left = hlPlayerLeft, let right = hlPlayerRight else { return }
        guard !hlShowRightValue, !hlIsGameOver else { return }

        hlTimerActive = false

        let isCorrect: Bool
        if guessedHigher {
            isCorrect = right.marketValue > left.marketValue
        } else {
            isCorrect = right.marketValue < left.marketValue
        }

        withAnimation(GameMotion.silky) {
            hlShowRightValue = true
            if isCorrect {
                hlIsGameOver = false
                hlRevealState = .correct
                hlLastGuessCorrect = true
            } else {
                hlIsGameOver = true
                hlRevealState = .wrong
                hlLastGuessCorrect = false
            }
        }

        if isCorrect {
            hlScore += 1
            if hlScore > hlHighScore { hlHighScore = hlScore }
            HapticFeedback.success()
        } else {
            HapticFeedback.error()
            withAnimation(GameMotion.silkyQuick) { hlShakeTrigger = true }
        }
    }

    private func cycleToNextHLRound() {
        if hlIsGameOver {
            hlScore = 0
            setupInitialHLRound()
            return
        }

        hlPlayerLeft = hlPlayerRight
        let pool = store.fetchHigherOrLowerPool()
        guard let next = pickHLChallenger(excluding: hlPlayerLeft, from: pool) else {
            setupInitialHLRound()
            return
        }

        hlPlayerRight = next
        resetHLRoundState()
        hlTimeRemaining = 5
        hlTimerActive = true
    }

    private func isSubmittableGuess(_ text: String) -> Bool {
        text.trimmingCharacters(in: .whitespacesAndNewlines).count >= 2
    }

    private func resetHLRoundState() {
        hlShowRightValue = false
        hlIsGameOver = false
        hlShakeTrigger = false
        hlRevealState = .hidden
        hlLastGuessCorrect = nil
    }
}

struct DifficultyPicker: View {
    @Binding var selectedDifficulty: GameDifficulty

    var body: some View {
        GameSegmentedControl(
            items: GameDifficulty.allCases,
            selection: $selectedDifficulty,
            title: \.rawValue
        )
    }
}

struct HLPlayer: Equatable {
    let id: String
    let name: String
    let clubName: String
    let marketValue: Int
}
