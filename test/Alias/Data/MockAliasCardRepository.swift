import Foundation

/// In-memory repository for SwiftUI previews and unit tests — a small, deterministic
/// deck that needs neither the JSON pack nor the club database.
struct MockAliasCardRepository: AliasCardRepository {
    var cards: [AliasCard]

    init(cards: [AliasCard] = MockAliasCardRepository.sampleCards) {
        self.cards = cards
    }

    func allCards(language: String) -> [AliasCard] { cards }

    static let sampleCards: [AliasCard] = [
        AliasCard(id: "p1", word: "Messi", category: .players, difficulty: .easy,
                  forbiddenWords: ["Argentina", "Barcelona", "Inter Miami", "forward"],
                  hints: ["Left foot", "Won multiple Ballon d'Or"]),
        AliasCard(id: "p2", word: "Haaland", category: .players, difficulty: .easy,
                  forbiddenWords: ["Norway", "Manchester City", "striker"],
                  hints: ["Tall number 9"]),
        AliasCard(id: "c1", word: "Real Madrid", category: .clubs, difficulty: .easy,
                  forbiddenWords: ["Spain", "LaLiga", "white", "Bernabeu"],
                  hints: ["Most Champions League titles"]),
        AliasCard(id: "n1", word: "Brazil", category: .nationalTeams, difficulty: .easy,
                  forbiddenWords: ["Samba", "yellow", "five", "Pele"],
                  hints: ["Five World Cups"]),
        AliasCard(id: "t1", word: "Offside", category: .terms, difficulty: .easy,
                  forbiddenWords: ["line", "defender", "flag"],
                  hints: ["A positioning rule"]),
        AliasCard(id: "t2", word: "Hat-trick", category: .terms, difficulty: .medium,
                  forbiddenWords: ["three", "goals", "match"],
                  hints: ["A count of goals"]),
        AliasCard(id: "ta1", word: "Tiki-taka", category: .tactics, difficulty: .hard,
                  forbiddenWords: ["Barcelona", "possession", "Spain", "passing"],
                  hints: []),
        AliasCard(id: "co1", word: "Champions League", category: .competitions, difficulty: .easy,
                  forbiddenWords: ["Europe", "UEFA", "anthem", "club"],
                  hints: ["Top European club competition"])
    ]
}
