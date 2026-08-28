import Foundation
import Combine

/// The Classic Alias state machine: deck, timer, scoring, team rotation and the
/// end condition. Pure domain — imports only `Foundation`, so it's fully unit
/// testable and free of any UI. The owning view drives `tick()` once per second
/// and calls the intent methods; everything published here feeds the UI.
///
/// Flow per turn:  prepareTurn() → startTurn() → [markCorrect()/skip()]* →
/// tick()→endTurn() → (review edits) → commitTurn() → next team or finish().
@MainActor
final class AliasGameEngine: ObservableObject, Identifiable {
    nonisolated let id = UUID()

    // MARK: Published state
    @Published private(set) var teams: [AliasTeam]
    @Published private(set) var currentTeamIndex = 0
    @Published private(set) var status: AliasGameStatus = .setup
    @Published private(set) var timeRemaining: Int
    @Published private(set) var currentOutcomes: [AliasRoundOutcome] = []
    @Published private(set) var currentCard: AliasCard?

    // MARK: Config & deck
    let config: AliasConfig
    private var deck: [AliasCard]
    private var deckCursor = 0
    private var lastCardID: String?
    private var totalCorrectAllTeams = 0

    // MARK: Hooks (injectable for tests)
    var log: (AnalyticsEvent) -> Void = { AnalyticsService.shared.log($0) }
    var onFinish: ((AliasGameEngine) -> Void)?

    init(config: AliasConfig, deck: [AliasCard], teams: [AliasTeam]) {
        self.config = config
        self.deck = deck
        self.teams = teams
        self.timeRemaining = config.timerSeconds
    }

    // MARK: Derived

    var currentTeam: AliasTeam { teams[currentTeamIndex] }
    var hasDeck: Bool { !deck.isEmpty }

    /// Correct answers in the turn currently being played/reviewed.
    var currentCorrectCount: Int { currentOutcomes.filter { $0.result == .correct }.count }
    var currentSkipCount: Int { currentOutcomes.filter { $0.result == .skipped }.count }

    /// Net points the current turn would award given the live outcomes.
    var currentTurnDelta: Int {
        currentCorrectCount * config.pointsPerCorrect - currentSkipCount * config.skipPenalty
    }

    // MARK: Game lifecycle

    func startGame() {
        log(.aliasGameStarted(teams: teams.count))
        prepareTurn()
    }

    /// Get ready for the current team's turn (the "pass the phone" gate).
    func prepareTurn() {
        currentOutcomes = []
        currentCard = nil
        timeRemaining = config.timerSeconds
        status = .readyForTeam
    }

    /// Begin the timed turn and draw the first card.
    func startTurn() {
        guard hasDeck else { status = .finished; return }
        status = .playing
        drawCard()
    }

    /// Called once per second by the view while `status == .playing`.
    func tick() {
        guard status == .playing else { return }
        if timeRemaining > 0 { timeRemaining -= 1 }
        if timeRemaining <= 0 { endTurn() }
    }

    // MARK: Turn intents

    func markCorrect() {
        guard status == .playing, let card = currentCard else { return }
        currentOutcomes.append(AliasRoundOutcome(card: card, result: .correct))
        totalCorrectAllTeams += 1
        log(.aliasWordGuessed(category: card.category.rawValue))
        drawCard()
    }

    func skip() {
        guard status == .playing, let card = currentCard else { return }
        currentOutcomes.append(AliasRoundOutcome(card: card, result: .skipped))
        log(.aliasWordSkipped(category: card.category.rawValue))
        drawCard()
    }

    /// End the turn (timer expired or the user tapped "Done") → review.
    func endTurn() {
        guard status == .playing else { return }
        status = .roundReview
    }

    // MARK: Review

    /// Flip a card between correct/skipped during review.
    func toggleOutcome(_ id: UUID) {
        guard let idx = currentOutcomes.firstIndex(where: { $0.id == id }) else { return }
        currentOutcomes[idx].result = currentOutcomes[idx].result == .correct ? .skipped : .correct
    }

    /// Commit the reviewed turn: apply the score, then either finish or rotate.
    func commitTurn() {
        guard status == .roundReview else { return }
        let delta = currentTurnDelta
        teams[currentTeamIndex].score += delta
        teams[currentTeamIndex].roundScores.append(delta)

        if teams.contains(where: { $0.score >= config.targetScore }) {
            finish()
        } else {
            currentTeamIndex = (currentTeamIndex + 1) % teams.count
            prepareTurn()
        }
    }

    // MARK: Results

    /// The single winning team, or `nil` on a tie.
    var winner: AliasTeam? {
        let top = teams.map(\.score).max() ?? 0
        let leaders = teams.filter { $0.score == top }
        return leaders.count == 1 ? leaders.first : nil
    }

    var rankedTeams: [AliasTeam] {
        teams.sorted { $0.score > $1.score }
    }

    // MARK: Deck

    /// Draws the next card with anti-repeat: reshuffles when the deck is exhausted
    /// and avoids immediately repeating the last card seen.
    private func drawCard() {
        guard !deck.isEmpty else { currentCard = nil; return }
        if deckCursor >= deck.count {
            deck.shuffle()
            deckCursor = 0
            if deck.count > 1, deck.first?.id == lastCardID {
                deck.swapAt(0, deck.count - 1)
            }
        }
        currentCard = deck[deckCursor]
        lastCardID = currentCard?.id
        deckCursor += 1
    }

    /// Reset scores and reshuffle for a rematch with the same teams/config.
    func resetForRematch() {
        for i in teams.indices {
            teams[i].score = 0
            teams[i].roundScores = []
        }
        currentTeamIndex = 0
        deck.shuffle()
        deckCursor = 0
        lastCardID = nil
        totalCorrectAllTeams = 0
        startGame()
    }

    private func finish() {
        status = .finished
        let winScore = teams.map(\.score).max() ?? 0
        AliasStatsStore.shared.record(winningScore: winScore, correctCount: totalCorrectAllTeams)
        log(.aliasGameFinished(winnerScore: winScore))
        onFinish?(self)
    }
}
