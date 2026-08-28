import XCTest
@testable import test

/// Regression coverage for the Aug 2026 bug-fix batch (matcher, nations, widget bridge, Pro level).
final class GameLogicRegressionTests: XCTestCase {

    // MARK: - Club matcher (no bare shared words)

    func testClubGuessRejectsBareSharedWords() {
        let round = GameRound(
            clubID: "13",
            clubName: "Atletico de Madrid",
            officialName: "Club Atlético de Madrid",
            aliases: ["atletico", "atletico madrid", "atleti"],
            formation: []
        )
        XCTAssertFalse(ClubGuessValidator.isCorrect(guess: "madrid", round: round))
        XCTAssertFalse(ClubGuessValidator.isCorrect(guess: "united", round: round))
        XCTAssertTrue(ClubGuessValidator.isCorrect(guess: "atletico", round: round))
        XCTAssertTrue(ClubGuessValidator.isCorrect(guess: "Atletico de Madrid", round: round))
    }

    func testInterAliasesDoNotCrossMatchViaSharedWord() {
        let inter = GameRound(
            clubID: "46",
            clubName: "Inter Milan",
            officialName: "FC Internazionale Milano",
            aliases: ["inter", "internazionale"],
            formation: []
        )
        let miami = GameRound(
            clubID: "ACCT-000025",
            clubName: "Inter Miami CF",
            officialName: "Club Internacional de Fútbol Miami",
            aliases: ["inter miami", "miami"],
            formation: []
        )
        // Explicit alias still works for Inter Milan.
        XCTAssertTrue(ClubGuessValidator.isCorrect(guess: "inter", round: inter))
        // "inter" alone must not win Inter Miami (alias is "inter miami").
        XCTAssertFalse(ClubGuessValidator.isCorrect(guess: "inter", round: miami))
        XCTAssertTrue(ClubGuessValidator.isCorrect(guess: "miami", round: miami))
    }

    // MARK: - Türkiye aliases

    func testTurkeyAcceptedForTurkiye() {
        let round = NationalTeamRound(
            nationName: "Türkiye",
            flag: "🇹🇷",
            aliases: [],
            formation: []
        )
        XCTAssertTrue(NationalTeamGuessValidator.isCorrect(guess: "Turkey", round: round))
        XCTAssertTrue(NationalTeamGuessValidator.isCorrect(guess: "turkiye", round: round))
        XCTAssertTrue(NationalTeamGuessValidator.isCorrect(guess: "Türkiye", round: round))
    }

    // MARK: - Widget App Group clear on reset

    @MainActor
    func testStreakBridgeClearRemovesDoneForToday() {
        let suiteName = "group.com.ftmpapp.app.test.\(UUID().uuidString)"
        // Exercise production keys via publish/clear on the real suite is risky
        // in parallel tests — instead verify clear() wipes the known keys after publish.
        DailyStreakBridge.publish(
            streak: 5,
            completedToday: true,
            lastCompleted: Date(),
            dayLabel: "Test"
        )
        var snap = DailyStreakBridge.load()
        XCTAssertEqual(snap.streak, 5)
        XCTAssertTrue(snap.completedToday)

        DailyStreakBridge.clear()
        snap = DailyStreakBridge.load()
        XCTAssertEqual(snap.streak, 0)
        XCTAssertFalse(snap.completedToday)

        // Silence unused warning if suiteName needed later.
        _ = suiteName
    }

    // MARK: - Pro unlock level

    func testProUnlockIsLevel20() {
        XCTAssertEqual(ProgressionRewards.proUnlockLevel, 20)
        let xpFor20 = 100 * 19 * 20 / 2
        XCTAssertEqual(xpFor20, 19_000)
        let info = XPCurve.level(forXP: xpFor20)
        XCTAssertEqual(info.level, 20)
        let justBelow = XPCurve.level(forXP: xpFor20 - 1)
        XCTAssertEqual(justBelow.level, 19)
    }

    // MARK: - Mode streak reset

    @MainActor
    func testResetModeStreakZerosPersistedStreak() {
        let defaults = UserDefaults(suiteName: "test.modeStreak.\(UUID().uuidString)")!
        let store = GameProgressStore(defaults: defaults)
        _ = store.recordResult(mode: .guessClub, won: true)
        _ = store.recordResult(mode: .guessClub, won: true)
        XCTAssertEqual(store.progress.stats(for: .guessClub).currentStreak, 2)

        store.resetModeStreak(.guessClub)
        XCTAssertEqual(store.progress.stats(for: .guessClub).currentStreak, 0)
    }
}
