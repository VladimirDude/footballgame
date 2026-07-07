import Foundation

struct NationalTeamSquadPlayer {
    let id: String
    let name: String
    let position: String
    let marketValue: Int
    let clubName: String
    let nationalities: [String]
}

struct NationalTeamRound {
    let nationName: String
    let flag: String
    let aliases: [String]
    let formation: [[FormationSlot]]
}

enum ClubNameShortener {
    static func label(for clubName: String) -> String {
        var name = clubName
        for suffix in [" FC", " CF", " SC", " AFC", " OSC", " BV", " AC", " SFC", " 1909", " 1913"] {
            if name.hasSuffix(suffix) {
                name = String(name.dropLast(suffix.count)).trimmingCharacters(in: .whitespaces)
            }
        }

        let replacements: [String: String] = [
            "Manchester United": "Man Utd",
            "Manchester City": "Man City",
            "Tottenham Hotspur": "Spurs",
            "Bayern Munich": "Bayern",
            "Borussia Dortmund": "Dortmund",
            "Paris Saint-Germain": "PSG",
            "Atlético de Madrid": "Atlético",
            "Inter Milan": "Inter",
            "AC Milan": "Milan",
            "Juventus FC": "Juventus",
            "Juventus": "Juve",
            "Real Madrid": "Real",
            "FC Barcelona": "Barça",
            "Newcastle United": "Newcastle",
            "Nottingham Forest": "Forest",
            "Brighton & Hove Albion": "Brighton",
            "Wolverhampton Wanderers": "Wolves",
            "Bayer 04 Leverkusen": "Leverkusen",
            "Eintracht Frankfurt": "Frankfurt",
            "Borussia Mönchengladbach": "Gladbach",
        ]

        if let short = replacements[clubName] ?? replacements[name] {
            return short
        }

        if name.count <= 11 {
            return name
        }

        return String(name.prefix(10)) + "…"
    }
}
