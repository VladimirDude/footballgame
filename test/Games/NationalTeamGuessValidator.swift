import Foundation

enum NationalTeamAbbreviations {
    static let map: [String: [String]] = [
        "brazil": ["brasil"],
        "england": ["eng"],
        "united states": ["usa", "us", "america", "united states of america"],
        "türkiye": ["turkey", "turkiye"],
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
}

enum NationalTeamGuessValidator {

    static func isCorrect(guess: String, round: NationalTeamRound) -> Bool {
        var candidates = [round.nationName, round.flag] + round.aliases

        let key = FuzzyMatcher.normalize(round.nationName)
        for (canonical, abbrevs) in NationalTeamAbbreviations.map {
            if key == canonical || key.contains(canonical) || canonical.contains(key) {
                candidates.append(canonical)
                candidates.append(contentsOf: abbrevs)
            }
        }

        return FuzzyMatcher.matches(guess: guess, candidates: candidates)
    }
}
