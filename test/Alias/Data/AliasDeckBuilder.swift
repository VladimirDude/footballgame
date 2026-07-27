import Foundation

/// Turns the full card pool into a filtered, shuffled deck for one match.
///
/// This is also the single **free/premium gate** for Alias content: non-Pro users
/// are limited to `AliasCategory.freeCategories` and Easy/Medium difficulty,
/// regardless of what they selected in setup.
enum AliasDeckBuilder {
    static func buildDeck(
        from cards: [AliasCard],
        config: AliasConfig,
        isPremiumUnlocked: Bool
    ) -> [AliasCard] {
        let allowedCategories = config.categories.filter { isPremiumUnlocked || $0.isFree }
        let range = config.difficultyRange

        var deck = cards.filter {
            allowedCategories.contains($0.category) && range.contains($0.difficulty)
        }

        if !isPremiumUnlocked {
            deck = deck.filter { $0.difficulty <= .medium }
        }

        return deck.shuffled()
    }

    /// Whether a given config would yield a non-empty deck for this user — used by
    /// the setup screen to enable/disable "Kick Off".
    static func hasPlayableDeck(
        from cards: [AliasCard],
        config: AliasConfig,
        isPremiumUnlocked: Bool
    ) -> Bool {
        !buildDeck(from: cards, config: config, isPremiumUnlocked: isPremiumUnlocked).isEmpty
    }
}
