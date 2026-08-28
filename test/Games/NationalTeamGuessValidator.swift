import Foundation

enum NationalTeamAbbreviations {
    /// Keys must be `FuzzyMatcher.normalize`d so diacritics like "Türkiye" resolve.
    static let map: [String: [String]] = {
        let raw: [String: [String]] = [
            "brazil": ["brasil"],
            "england": ["eng"],
            "united states": ["usa", "us", "america", "united states of america"],
            "turkiye": ["turkey", "turkiye"],
            "cote divoire": ["ivory coast", "cote d'ivoire"],
            "south korea": ["korea", "korea republic", "republic of korea", "korea, south"],
            "netherlands": ["holland", "ned"],
            "germany": ["deutschland", "ger"],
            "spain": ["espana", "españa"],
            "france": ["fra"],
            "portugal": ["por"],
            "argentina": ["arg"],
            "italy": ["ita"],
            "mexico": ["mex"],
            "belgium": ["bel"],
            "croatia": ["cro"],
            "uruguay": ["uru"],
            "colombia": ["col"],
            "morocco": ["mar"],
            "japan": ["jpn"],
            "nigeria": ["nga"],
            "senegal": ["sen"],
            "scotland": ["sco"],
            "wales": ["wal"],
            "ireland": ["republic of ireland", "roi"],
            "bosnia herzegovina": ["bosnia", "bosnia-herzegovina"],
            "czech republic": ["czechia", "cze"],
            "cameroon": ["cmr"],
            "ecuador": ["ecu"],
            "paraguay": ["par"],
            "ghana": ["gha"],
            "algeria": ["alg"],
            "austria": ["aut"],
            "canada": ["can"],
            "greece": ["gre"],
            "norway": ["nor"],
            "sweden": ["swe"],
            "denmark": ["den"],
            "poland": ["pol"],
            "serbia": ["srb"],
            "switzerland": ["sui", "swiss"],
            "ukraine": ["ukr"],
        ]
        var normalized: [String: [String]] = [:]
        for (key, aliases) in raw {
            normalized[FuzzyMatcher.normalize(key)] = aliases
        }
        return normalized
    }()
}

enum NationalTeamGuessValidator {

    static func isCorrect(guess: String, round: NationalTeamRound) -> Bool {
        var candidates = [round.nationName, round.flag] + round.aliases

        let key = FuzzyMatcher.normalize(round.nationName)
        if let abbrevs = NationalTeamAbbreviations.map[key] {
            candidates.append(contentsOf: abbrevs)
        }

        return FuzzyMatcher.matches(guess: guess, candidates: candidates)
    }
}
