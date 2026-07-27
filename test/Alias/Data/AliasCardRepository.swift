import Foundation

/// Source of Alias cards. The engine and UI depend on this protocol, not on JSON
/// files or the club database, so tests and previews can inject a mock.
protocol AliasCardRepository {
    /// Curated pack cards + generated entity cards for a language, unfiltered.
    func allCards(language: String) -> [AliasCard]

    /// Count of available cards in a category (for setup / categories UI).
    func cardCount(in category: AliasCategory, language: String) -> Int
}

extension AliasCardRepository {
    func cardCount(in category: AliasCategory, language: String) -> Int {
        allCards(language: language).lazy.filter { $0.category == category }.count
    }
}
