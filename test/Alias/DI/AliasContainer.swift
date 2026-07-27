import SwiftUI
import Combine

/// Composition root for Football Alias. Owns the card repository and builds game
/// engines. Created once at launch and injected into the environment, mirroring
/// `MonetizationContainer`. Swap the repository here for a mock in DEBUG/tests.
@MainActor
final class AliasContainer: ObservableObject {
    let repository: AliasCardRepository

    init(repository: AliasCardRepository = AliasContainer.defaultRepository()) {
        self.repository = repository
    }

    nonisolated static func defaultRepository() -> AliasCardRepository {
        AliasCardRepositoryImpl()
    }

    /// Builds an engine for a match: draws a gated, shuffled deck for the config.
    func makeEngine(
        config: AliasConfig,
        teams: [AliasTeam],
        isPremiumUnlocked: Bool
    ) -> AliasGameEngine {
        let all = repository.allCards(language: config.language)
        let deck = AliasDeckBuilder.buildDeck(
            from: all, config: config, isPremiumUnlocked: isPremiumUnlocked
        )
        return AliasGameEngine(config: config, deck: deck, teams: teams)
    }

    /// Whether the config yields a playable deck for this user (drives "Kick Off").
    func canStart(config: AliasConfig, isPremiumUnlocked: Bool) -> Bool {
        AliasDeckBuilder.hasPlayableDeck(
            from: repository.allCards(language: config.language),
            config: config,
            isPremiumUnlocked: isPremiumUnlocked
        )
    }

    func cardCount(in category: AliasCategory, language: String) -> Int {
        repository.cardCount(in: category, language: language)
    }
}

extension View {
    /// Injects the Alias container so `@EnvironmentObject` lookups resolve.
    func withAlias(_ container: AliasContainer) -> some View {
        environmentObject(container)
    }
}
