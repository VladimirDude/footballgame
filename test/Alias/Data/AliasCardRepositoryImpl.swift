import Foundation

/// Production repository: merges the curated language pack with the entity cards
/// generated from the club database. Entity cards are proper nouns (player / club /
/// nation names), so they are language-agnostic and reused across every language.
final class AliasCardRepositoryImpl: AliasCardRepository {
    private let packLoader: AliasPackLoader
    private let entityFactory: AliasEntityCardFactory

    /// Entity generation touches the whole club DB, so compute it once, lazily.
    private lazy var entityCards: [AliasCard] = entityFactory.makeCards()
    private var packCache: [String: [AliasCard]] = [:]

    init(
        packLoader: AliasPackLoader = AliasPackLoader(),
        entityFactory: AliasEntityCardFactory = AliasEntityCardFactory()
    ) {
        self.packLoader = packLoader
        self.entityFactory = entityFactory
    }

    func allCards(language: String) -> [AliasCard] {
        let curated: [AliasCard]
        if let cached = packCache[language] {
            curated = cached
        } else {
            curated = packLoader.load(language: language).cards
            packCache[language] = curated
        }
        return curated + entityCards
    }
}
