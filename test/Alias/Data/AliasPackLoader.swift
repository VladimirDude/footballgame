import Foundation

/// Loads a curated, localized card pack (`aliaspack.<lang>.json`) from a bundle.
/// Returns an empty pack (rather than throwing) when a language file is missing or
/// malformed, so a missing RU/HY pack degrades gracefully to "no curated cards".
struct AliasPackLoader {
    var bundle: Bundle = .main

    func load(language: String) -> AliasCardPack {
        let resource = "aliaspack.\(language)"
        guard let url = bundle.url(forResource: resource, withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let pack = try? JSONDecoder().decode(AliasCardPack.self, from: data) else {
            return AliasCardPack(language: language, version: 0, cards: [])
        }
        return pack
    }
}
