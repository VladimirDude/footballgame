import XCTest
@testable import test

final class AliasDataTests: XCTestCase {

    // MARK: Pack loader

    func testMissingPackDegradesToEmpty() {
        let loader = AliasPackLoader(bundle: .main)
        let pack = loader.load(language: "zz") // no such language file
        XCTAssertTrue(pack.cards.isEmpty)
        XCTAssertEqual(pack.language, "zz")
    }

    func testEmptyScaffoldPackLoads() {
        // ru/hy ship as empty scaffolds — should decode cleanly to zero cards.
        let loader = AliasPackLoader(bundle: .main)
        let pack = loader.load(language: "ru")
        XCTAssertEqual(pack.cards.count, 0)
    }

    // MARK: Entity factory

    private func player(_ id: String, _ name: String, value: Int, position: String, nations: [String]) -> ClubSquadPlayer {
        ClubSquadPlayer(id: id, name: name, image: nil, position: position, marketValue: value, nationality: nations)
    }

    func testPlayerForbiddenDerivation() {
        let club = BundledClub(
            id: "1", name: "Barcelona", officialName: "FC Barcelona", aliases: [],
            players: [player("p1", "Lamine Yamal", value: 100_000_000, position: "Right Winger", nations: ["Spain"])])
        let factory = AliasEntityCardFactory(clubs: [club], leagueByClubID: ["1": "LaLiga"])
        let cards = factory.makePlayerCards()
        XCTAssertEqual(cards.count, 1)
        let c = cards[0]
        XCTAssertEqual(c.word, "Lamine Yamal")
        XCTAssertEqual(c.difficulty, .easy, "100M value => easy")
        XCTAssertTrue(c.forbiddenWords.contains("Barcelona"))
        XCTAssertTrue(c.forbiddenWords.contains("LaLiga"))
        XCTAssertTrue(c.forbiddenWords.contains("Spain"))
        XCTAssertTrue(c.forbiddenWords.contains("winger"), "position synonym derived")
        XCTAssertFalse(c.forbiddenWords.contains { $0.lowercased() == "lamine yamal" }, "never leaks its own word")
    }

    func testLowValuePlayersExcluded() {
        let club = BundledClub(
            id: "1", name: "Test FC", officialName: nil, aliases: [],
            players: [player("p1", "Nobody", value: 100_000, position: "Goalkeeper", nations: ["Nowhere"])])
        let factory = AliasEntityCardFactory(clubs: [club], leagueByClubID: [:])
        XCTAssertTrue(factory.makePlayerCards().isEmpty, "players under the value floor are dropped")
    }

    func testNationCardNeedsEnoughPlayers() {
        // 11 players of one nation qualifies; fewer does not.
        let manyPlayers = (0..<11).map { player("p\($0)", "Player \($0)", value: 2_000_000, position: "Midfield", nations: ["Testland"]) }
        let club = BundledClub(id: "1", name: "Test FC", officialName: nil, aliases: [], players: manyPlayers)
        let factory = AliasEntityCardFactory(clubs: [club], leagueByClubID: [:])
        let nations = factory.makeNationCards()
        XCTAssertTrue(nations.contains { $0.word == "Testland" })
    }
}
