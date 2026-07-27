import XCTest
@testable import test

/// The engine is `@MainActor`. Each test is `async` and hops onto the main actor
/// with `await MainActor.run { … }` — XCTest may invoke the method off the main
/// thread, and driving the engine's `@Published` state off-main corrupts Combine's
/// publisher, so we make the isolation explicit here.
final class AliasEngineTests: XCTestCase {

    private func card(_ id: String, _ cat: AliasCategory = .terms, _ diff: AliasDifficulty = .easy) -> AliasCard {
        AliasCard(id: id, word: id, category: cat, difficulty: diff)
    }

    @MainActor
    private func makeEngine(deckSize: Int = 30,
                            teams: Int = 2,
                            skipPenalty: Int = 1,
                            target: Int = 999) -> AliasGameEngine {
        let deck = (0..<deckSize).map { card("d\($0)") }
        var cfg = AliasConfig.default
        cfg.skipPenalty = skipPenalty
        cfg.targetScore = target
        let teamList = (0..<teams).map { AliasTeam(id: $0, name: "T\($0)") }
        let e = AliasGameEngine(config: cfg, deck: deck, teams: teamList)
        e.log = { _ in }
        return e
    }

    func testScoringWithSkipPenalty() async {
        await MainActor.run {
            let e = makeEngine()
            e.startGame(); e.startTurn()
            e.markCorrect(); e.markCorrect(); e.markCorrect(); e.skip()
            XCTAssertEqual(e.currentTurnDelta, 2, "3 correct - 1 skip (penalty 1) = 2")
            e.endTurn(); e.commitTurn()
            XCTAssertEqual(e.teams[0].score, 2)
        }
    }

    func testSkipPenaltyOff() async {
        await MainActor.run {
            let e = makeEngine(skipPenalty: 0)
            e.startGame(); e.startTurn()
            e.markCorrect(); e.skip(); e.skip()
            XCTAssertEqual(e.currentTurnDelta, 1)
        }
    }

    func testTeamRotation() async {
        await MainActor.run {
            let e = makeEngine(teams: 3)
            e.startGame()
            XCTAssertEqual(e.currentTeamIndex, 0)
            e.startTurn(); e.endTurn(); e.commitTurn()
            XCTAssertEqual(e.currentTeamIndex, 1)
            e.startTurn(); e.endTurn(); e.commitTurn()
            XCTAssertEqual(e.currentTeamIndex, 2)
            e.startTurn(); e.endTurn(); e.commitTurn()
            XCTAssertEqual(e.currentTeamIndex, 0, "wraps back to first team")
        }
    }

    func testReviewToggleChangesScore() async {
        await MainActor.run {
            let e = makeEngine()
            e.startGame(); e.startTurn()
            e.markCorrect(); e.skip()
            let skipped = e.currentOutcomes.first { $0.result == .skipped }!
            e.endTurn()
            e.toggleOutcome(skipped.id)
            XCTAssertEqual(e.currentTurnDelta, 2, "flipping skip->correct: 2 correct = +2")
        }
    }

    func testTargetScoreEndsGameAndSetsWinner() async {
        await MainActor.run {
            let e = makeEngine(skipPenalty: 0, target: 3)
            e.startGame(); e.startTurn()
            e.markCorrect(); e.markCorrect(); e.markCorrect()
            e.endTurn(); e.commitTurn()
            XCTAssertEqual(e.status, .finished)
            XCTAssertEqual(e.winner?.id, 0)
        }
    }

    func testTieHasNoWinner() async {
        await MainActor.run {
            let deck = (0..<30).map { card("d\($0)") }
            var cfg = AliasConfig.default; cfg.skipPenalty = 0; cfg.targetScore = 100
            let e = AliasGameEngine(config: cfg, deck: deck,
                                    teams: [AliasTeam(id: 0, name: "A", score: 5),
                                            AliasTeam(id: 1, name: "B", score: 5)])
            e.log = { _ in }
            XCTAssertNil(e.winner, "equal scores => no single winner")
        }
    }

    func testAntiRepeatAcrossReshuffle() async {
        await MainActor.run {
            let deck = ["x", "y", "z"].map { card($0) }
            var cfg = AliasConfig.default; cfg.targetScore = 999
            let e = AliasGameEngine(config: cfg, deck: deck,
                                    teams: [AliasTeam(id: 0, name: "A"), AliasTeam(id: 1, name: "B")])
            e.log = { _ in }
            e.startGame(); e.startTurn()
            var prev = e.currentCard?.id
            for _ in 0..<60 {
                e.markCorrect()
                let cur = e.currentCard?.id
                XCTAssertNotEqual(cur, prev, "no back-to-back duplicate card")
                prev = cur
            }
        }
    }

    func testTimerTimeoutEndsTurn() async {
        await MainActor.run {
            let e = makeEngine()
            e.startGame(); e.startTurn()
            XCTAssertEqual(e.status, .playing)
            for _ in 0..<(e.config.timerSeconds + 1) { e.tick() }
            XCTAssertEqual(e.status, .roundReview, "timer expiry moves to review")
        }
    }
}
