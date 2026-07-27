import XCTest
@testable import test

final class AliasDeckBuilderTests: XCTestCase {

    private func card(_ id: String, _ cat: AliasCategory, _ diff: AliasDifficulty) -> AliasCard {
        AliasCard(id: id, word: id, category: cat, difficulty: diff)
    }

    private var mixed: [AliasCard] {
        [
            card("free_easy", .players, .easy),
            card("free_hard", .players, .hard),
            card("prem_easy", .tactics, .easy),
            card("term_med", .terms, .medium)
        ]
    }

    func testFreeUserGating() {
        var cfg = AliasConfig.default
        cfg.categories = [.players, .tactics, .terms]
        cfg.minDifficulty = .easy
        cfg.maxDifficulty = .expert
        let deck = AliasDeckBuilder.buildDeck(from: mixed, config: cfg, isPremiumUnlocked: false)
        let ids = Set(deck.map(\.id))
        XCTAssertEqual(ids, ["free_easy", "term_med"],
                       "free = free-category cards at easy/medium only")
    }

    func testProUserGetsEverything() {
        var cfg = AliasConfig.default
        cfg.categories = [.players, .tactics, .terms]
        cfg.minDifficulty = .easy
        cfg.maxDifficulty = .expert
        let deck = AliasDeckBuilder.buildDeck(from: mixed, config: cfg, isPremiumUnlocked: true)
        XCTAssertEqual(deck.count, 4)
    }

    func testDifficultyRangeFilter() {
        var cfg = AliasConfig.default
        cfg.categories = [.players, .terms]
        cfg.minDifficulty = .medium
        cfg.maxDifficulty = .medium
        let deck = AliasDeckBuilder.buildDeck(from: mixed, config: cfg, isPremiumUnlocked: true)
        XCTAssertEqual(deck.map(\.id), ["term_med"], "only medium cards survive a medium..medium range")
    }

    func testHasPlayableDeck() {
        var cfg = AliasConfig.default
        cfg.categories = [.tactics]   // premium only
        XCTAssertFalse(AliasDeckBuilder.hasPlayableDeck(from: mixed, config: cfg, isPremiumUnlocked: false))
        XCTAssertTrue(AliasDeckBuilder.hasPlayableDeck(from: mixed, config: cfg, isPremiumUnlocked: true))
    }
}
