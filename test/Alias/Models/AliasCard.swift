import Foundation

/// A single Alias card: the word to explain plus the words the explainer may not
/// say. `hints` are optional prompts to help the explainer get started.
struct AliasCard: Identifiable, Codable, Hashable {
    let id: String
    let word: String
    let category: AliasCategory
    let difficulty: AliasDifficulty
    let forbiddenWords: [String]
    let hints: [String]

    init(
        id: String,
        word: String,
        category: AliasCategory,
        difficulty: AliasDifficulty,
        forbiddenWords: [String] = [],
        hints: [String] = []
    ) {
        self.id = id
        self.word = word
        self.category = category
        self.difficulty = difficulty
        self.forbiddenWords = forbiddenWords
        self.hints = hints
    }
}

/// A localized, curated pack decoded from `aliaspack.<lang>.json`.
struct AliasCardPack: Codable {
    let language: String
    let version: Int
    let cards: [AliasCard]
}
