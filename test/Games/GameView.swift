import SwiftUI
import Combine

struct GameView: View {
    private let store = ClubDataStore.shared
    @EnvironmentObject private var entitlements: EntitlementService
    @EnvironmentObject private var progress: GameProgressStore
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.scenePhase) private var scenePhase

    @State private var showGamePaywall = false

    // MARK: - Premium gating

    /// Difficulty binding that blocks Medium/Hard for free users (Easy stays free)
    /// and opens the paywall instead of changing the selection.
    private var gatedClubDifficulty: Binding<GameDifficulty> {
        Binding(
            get: { currentDifficulty },
            set: { newValue in
                if newValue == .easy || entitlements.canAccess(.hardDifficulty) {
                    currentDifficulty = newValue
                } else {
                    AnalyticsService.shared.log(.featureBlocked(feature: PremiumFeature.hardDifficulty.rawValue))
                    showGamePaywall = true
                }
            }
        )
    }

    private var gatedNationDifficulty: Binding<NationalTeamDifficulty> {
        Binding(
            get: { gnDifficulty },
            set: { newValue in
                if newValue == .easy || entitlements.canAccess(.hardDifficulty) {
                    gnDifficulty = newValue
                } else {
                    AnalyticsService.shared.log(.featureBlocked(feature: PremiumFeature.hardDifficulty.rawValue))
                    showGamePaywall = true
                }
            }
        )
    }

    private var theme: GameModeTheme {
        GameModeTheme.theme(for: selectedTab, colorScheme: colorScheme)
    }

    @State private var selectedTab: GameTab = .guessClub

    /// Pro "Relaxed Mode" removes the countdowns from the timed games (set in Settings).
    @AppStorage("gameRelaxedMode") private var relaxedMode = false

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
    @State private var gpTimeRemaining = 15
    @State private var gpTimerActive = false
    @State private var gpDifficulty: GameDifficulty = .easy

    private var gpTotalTime: Int { gpDifficulty.guessPlayerTimeLimit }

    private var gatedPlayerDifficulty: Binding<GameDifficulty> {
        Binding(
            get: { gpDifficulty },
            set: { newValue in
                if newValue == .easy || entitlements.canAccess(.hardDifficulty) {
                    gpDifficulty = newValue
                } else {
                    AnalyticsService.shared.log(.featureBlocked(feature: PremiumFeature.hardDifficulty.rawValue))
                    showGamePaywall = true
                }
            }
        )
    }

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
    @State private var hlTimeRemaining = 15
    @State private var hlTimerActive = false
    /// Loss XP/streak is deferred until Continue (so Pro revive can keep the climb).
    @State private var hlPendingLossRecord = false
    /// Skip restarting rounds when Pro lapse only clamps the difficulty picker.
    @State private var suppressDifficultyRestart = false

    // Wordle
    @State private var wordleTarget: WordlePlayer?
    @State private var wordleGuesses: [WordleGuess] = []
    @State private var wordleResult: GameResult?
    @State private var wordleSearchQuery = ""
    @State private var wordleSelectedPlayer: WordlePlayer?
    @State private var wordleDuplicateGuess = false
    @State private var wordleStreak = 0
    @AppStorage("wordleBestStreak") private var wordleBestStreak = 0

    // Guess the League
    @State private var glRound: GuessLeagueRound?
    @State private var glResult: GameResult?
    @State private var glSelected: String?
    @State private var glStreak = 0
    @AppStorage("guessLeagueBestStreak") private var glBestStreak = 0

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
                    case .guessLeague:
                        guessLeagueContent
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
            if !entitlements.canAccess(.hardDifficulty) {
                clampDifficultiesToFreeTier()
            }
        }
        .onChange(of: currentDifficulty) { _, _ in
            guard !suppressDifficultyRestart else { return }
            gcStreak = 0
            progress.resetModeStreak(.guessClub)
            startNewRound()
        }
        .onChange(of: gnDifficulty) { _, _ in
            guard !suppressDifficultyRestart else { return }
            gnStreak = 0
            progress.resetModeStreak(.guessNation)
            startNewNationRound()
        }
        .onChange(of: gpDifficulty) { _, _ in
            guard !suppressDifficultyRestart else { return }
            gpStreak = 0
            progress.resetModeStreak(.guessPlayer)
            startNewPlayerRound()
        }
        .onChange(of: selectedTab) { _, tab in
            // Returning to Guess Player / HL restarts the countdown from full, instead
            // of resuming a nearly-expired timer (which caused unfair instant losses).
            if tab == .guessPlayer, gpResult == nil, gpRound != nil {
                resetGuessPlayerTimer()
            } else {
                gpTimerActive = tab == .guessPlayer && gpResult == nil && !showGamePaywall
            }
            if tab == .higherLower, !hlShowRightValue, !hlIsGameOver {
                resetHigherLowerTimer()
            } else {
                hlTimerActive = false
            }
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active:
                // Fresh countdown on resume rather than the leftover value.
                if selectedTab == .guessPlayer, gpResult == nil, gpRound != nil, !showGamePaywall {
                    resetGuessPlayerTimer()
                }
                if selectedTab == .higherLower, !hlShowRightValue, !hlIsGameOver, !showGamePaywall {
                    resetHigherLowerTimer()
                }
            case .inactive, .background:
                gpTimerActive = false
                hlTimerActive = false
            @unknown default:
                break
            }
        }
        .onChange(of: showGamePaywall) { _, isPresented in
            if isPresented {
                gpTimerActive = false
                hlTimerActive = false
            } else if selectedTab == .guessPlayer, gpResult == nil, gpRound != nil {
                resetGuessPlayerTimer()
            } else if selectedTab == .higherLower, !hlShowRightValue, !hlIsGameOver {
                resetHigherLowerTimer()
            }
        }
        .onChange(of: entitlements.isPro) { _, isPro in
            guard !isPro else { return }
            clampDifficultiesToFreeTier()
        }
        .onReceive(countdownTimer) { _ in
            tickHigherLowerTimer()
            tickGuessPlayerTimer()
        }
        .paywallSheet(isPresented: $showGamePaywall, source: "game")
    }

    private func clampDifficultiesToFreeTier() {
        // Update pickers only — don't wipe the active round mid-guess.
        suppressDifficultyRestart = true
        if currentDifficulty != .easy { currentDifficulty = .easy }
        if gnDifficulty != .easy { gnDifficulty = .easy }
        if gpDifficulty != .easy { gpDifficulty = .easy }
        suppressDifficultyRestart = false
    }

    private func resetHigherLowerTimer() {
        hlTimeRemaining = 15
        hlTimerActive = true
    }

    private func tickHigherLowerTimer() {
        guard selectedTab == .higherLower, hlTimerActive, !hlShowRightValue, !hlIsGameOver, !relaxedMode, !showGamePaywall else { return }

        if hlTimeRemaining > 0 {
            hlTimeRemaining -= 1
        } else {
            hlTimerActive = false
            hlIsGameOver = true
            hlLastGuessCorrect = false
            hlRevealState = .wrong
            hlPendingLossRecord = true
            HapticFeedback.error()
            withAnimation(GameMotion.fade) { hlShowRightValue = true }
            withAnimation(.default) { hlShakeTrigger = true }
        }
    }

    private func tickGuessPlayerTimer() {
        guard selectedTab == .guessPlayer, gpTimerActive, gpResult == nil, !relaxedMode, !showGamePaywall else { return }

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
        recordGameResult(.guessPlayer, won: false)
        withAnimation(.default) { gpShakeWrong.toggle() }
    }

    // MARK: - Tab Content

    /// Shared "couldn't load" state, mirroring the Guess Club / Nation modes.
    @ViewBuilder
    private func gamePoolError(retry: @escaping () -> Void) -> some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "exclamationmark.triangle")
                .font(.title2)
                .foregroundStyle(theme.textSecondary)
            Text("Couldn't load players. Please try again.")
                .foregroundStyle(theme.textPrimary)
                .multilineTextAlignment(.center)
            Button("Try Again", action: retry)
                .buttonStyle(.borderedProminent)
            Spacer()
        }
        .padding()
    }

    @ViewBuilder
    private func gameLoading(_ message: String, onAppear: @escaping () -> Void) -> some View {
        VStack(spacing: 12) {
            Spacer()
            ProgressView().tint(theme.accent)
            Text(message).foregroundStyle(theme.textSecondary)
            Spacer()
        }
        .onAppear(perform: onAppear)
    }

    @ViewBuilder
    private var wordleContent: some View {
        if let target = wordleTarget {
            WordleGameView(
                target: target,
                guesses: wordleGuesses,
                gameResult: wordleResult,
                streak: wordleStreak,
                bestStreak: wordleBestStreak,
                searchQuery: $wordleSearchQuery,
                suggestions: wordleSuggestions,
                selectedPlayer: wordleSelectedPlayer,
                duplicateGuess: wordleDuplicateGuess,
                onSelectPlayer: selectWordlePlayer,
                onClearSelection: clearWordleSelection,
                onSubmit: submitWordleGuess,
                onPlayAgain: startNewWordleRound
            )
        } else if store.wordlePoolCount == 0 {
            gamePoolError(retry: startNewWordleRound)
        } else {
            gameLoading("Loading players...", onAppear: startNewWordleRound)
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
                difficulty: gatedClubDifficulty,
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
                difficulty: gatedPlayerDifficulty,
                gameResult: gpResult,
                streak: gpStreak,
                bestStreak: gpBestStreak,
                timeRemaining: (gpResult == nil && !relaxedMode) ? gpTimeRemaining : nil,
                totalTime: gpTotalTime,
                showClubHint: gpShowClubHint,
                shakeWrong: gpShakeWrong,
                onRevealClubHint: {
                    guard gpDifficulty.guessPlayerAllowsClubHint else { return }
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
        } else if store.guessPlayerPoolCount(for: gpDifficulty) == 0 {
            gamePoolError(retry: startNewPlayerRound)
        } else {
            gameLoading("Loading star players...", onAppear: startNewPlayerRound)
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
                difficulty: gatedNationDifficulty,
                onNewGame: startNewNationRound,
                onRevealHint: revealRandomNationPlayer,
                onSubmit: submitNationGuess,
                onNextRound: advanceNationRound
            )
        }
    }

    @ViewBuilder
    private var higherLowerContent: some View {
        if store.higherOrLowerPoolCount < 2 {
            gamePoolError(retry: setupInitialHLRound)
        } else {
            HigherOrLowerGameView(
                streak: hlScore,
                bestStreak: hlHighScore,
                timeRemaining: (!hlShowRightValue && !hlIsGameOver && !relaxedMode) ? hlTimeRemaining : nil,
                left: hlPlayerLeft,
                right: hlPlayerRight,
                revealState: hlRevealState,
                shakeTrigger: hlShakeTrigger,
                showRightValue: hlShowRightValue,
                isGameOver: hlIsGameOver,
                lastGuessCorrect: hlLastGuessCorrect,
                onHigher: { processHLGuess(guessedHigher: true) },
                onLower: { processHLGuess(guessedHigher: false) },
                onContinue: cycleToNextHLRound,
                onRevive: reviveHL
            )
        }
    }

    /// Pro: after a game over, keep the streak and get a fresh duel instead of
    /// resetting to zero. Free users get the paywall.
    private func reviveHL() {
        PremiumGate.run(.higherLowerRevive, entitlements: entitlements, showPaywall: $showGamePaywall) {
            hlPendingLossRecord = false
            let pool = store.fetchHigherOrLowerPool()
            hlPlayerLeft = hlPlayerRight
            guard let next = pickHLChallenger(excluding: hlPlayerLeft, from: pool) else {
                setupInitialHLRound()
                return
            }
            hlPlayerRight = next
            resetHLRoundState()
            resetHigherLowerTimer()
        }
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
        case .guessLeague where glRound == nil:
            startNewLeagueRound()
        default:
            break
        }
    }

    // MARK: - Guess the League Logic

    @ViewBuilder
    private var guessLeagueContent: some View {
        if let glRound {
            GuessLeagueGameView(
                round: glRound,
                gameResult: glResult,
                streak: glStreak,
                bestStreak: glBestStreak,
                selected: glSelected,
                onSelect: submitLeagueGuess,
                onNext: advanceLeagueRound
            )
        } else if store.guessLeaguePoolCount == 0 {
            gamePoolError(retry: startNewLeagueRound)
        } else {
            gameLoading("Loading clubs...", onAppear: startNewLeagueRound)
        }
    }

    private func startNewLeagueRound() {
        glResult = nil
        glSelected = nil
        glRound = store.randomGuessLeagueRound()
    }

    private func advanceLeagueRound() {
        let previousID = glRound?.clubID
        let previous = glRound
        glResult = nil
        glSelected = nil
        let next = store.randomGuessLeagueRound(excluding: Set([previousID].compactMap { $0 })) ?? previous
        withAnimation(.spring(response: 0.42, dampingFraction: 0.82)) {
            glRound = next
        }
    }

    private func submitLeagueGuess(_ league: String) {
        guard glResult == nil, let round = glRound else { return }
        glSelected = league
        let won = league == round.correctLeague
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            glResult = won ? .won : .lost
        }
        if won {
            glStreak += 1
            if glStreak > glBestStreak { glBestStreak = glStreak }
            HapticFeedback.success()
        } else {
            glStreak = 0
            HapticFeedback.error()
        }
        recordGameResult(.guessLeague, won: won)
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
            wordleStreak += 1
            if wordleStreak > wordleBestStreak { wordleBestStreak = wordleStreak }
            HapticFeedback.success()
        } else if wordleGuesses.count >= WordleEvaluator.maxGuesses {
            withAnimation(.spring(response: 0.38, dampingFraction: 0.82)) {
                wordleResult = .lost
            }
            wordleStreak = 0
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
        recordGameResult(.guessNation, won: won)

        for slot in round.formation.flatMap({ $0 }) { gnRevealedSlots.insert(slot.id) }
    }

    private func advanceNationRound() {
        let previousName = gnRound?.nationName
        let previous = gnRound
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

        let next = newRound ?? store.randomNationalTeamRound(for: gnDifficulty) ?? previous
        withAnimation(.spring(response: 0.42, dampingFraction: 0.82)) {
            gnRound = next
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
        gnStreak = 0
        progress.resetModeStreak(.guessNation)
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

    /// Records a finished round into the progression store and analytics.
    private func recordGameResult(_ mode: GameMode, won: Bool) {
        progress.recordResult(mode: mode, won: won)
        AnalyticsService.shared.log(.gameFinished(mode: mode.rawValue, score: won ? 1 : 0))
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
        recordGameResult(.guessClub, won: won)

        for slot in round.formation.flatMap({ $0 }) { revealedSlots.insert(slot.id) }
    }

    private func advanceClubRound() {
        let previousID = round?.clubID
        let previous = round
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
        let next = newRound ?? store.randomGameRound(for: currentDifficulty) ?? previous
        withAnimation(.spring(response: 0.42, dampingFraction: 0.82)) {
            round = next
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
        gcStreak = 0
        progress.resetModeStreak(.guessClub)
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
        recordGameResult(.guessPlayer, won: won)
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
        gpStreak = 0
        progress.resetModeStreak(.guessPlayer)
        if let newRound = store.randomGuessPlayerRound(for: gpDifficulty) {
            gpRound = newRound
            resetGuessPlayerTimer()
        } else {
            gpRound = nil
        }
    }

    private func advancePlayerRound() {
        let previousID = gpRound?.id
        let previous = gpRound
        gpGuess = ""
        gpResult = nil
        gpShowClubHint = false
        gpShakeWrong = false

        let next = store.randomGuessPlayerRound(
            for: gpDifficulty,
            excluding: Set([previousID].compactMap { $0 })
        ) ?? previous
        withAnimation(.spring(response: 0.45, dampingFraction: 0.82)) {
            gpRound = next
        }
        if next != nil {
            resetGuessPlayerTimer()
        }
    }

    // MARK: - Higher or Lower Logic

    private func setupInitialHLRound() {
        let pool = store.fetchHigherOrLowerPool()
        guard pool.count >= 2 else { return }

        let randomized = pool.shuffled()
        hlPlayerLeft = randomized[0]
        hlPlayerRight = pickHLChallenger(excluding: hlPlayerLeft, from: pool) ?? randomized[1]
        resetHLRoundState()
        resetHigherLowerTimer()
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
        if right.marketValue == left.marketValue {
            // Equal values can't be guessed higher OR lower — never a loss.
            isCorrect = true
        } else if guessedHigher {
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
                hlPendingLossRecord = true
            }
        }

        if isCorrect {
            recordGameResult(.higherLower, won: true)
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
            if hlPendingLossRecord {
                recordGameResult(.higherLower, won: false)
                hlPendingLossRecord = false
            }
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
        resetHigherLowerTimer()
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
