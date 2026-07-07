import Foundation

enum NationalTeamDifficulty: String, CaseIterable, Identifiable {
    case easy = "Easy"
    case medium = "Medium"
    case hard = "Hard"

    var id: String { rawValue }

    /// Top 40 football nations, split into three difficulty tiers.
    var associatedNations: Set<String> {
        switch self {
        case .easy:
            return [
                "Argentina", "Belgium", "Brazil", "Croatia", "England",
                "France", "Germany", "Italy", "Morocco", "Netherlands",
                "Portugal", "Spain",
            ]
        case .medium:
            return [
                "Colombia", "Cote d'Ivoire", "Denmark", "Japan", "Nigeria",
                "Norway", "Poland", "Senegal", "Serbia", "Sweden",
                "Switzerland", "Türkiye", "United States", "Uruguay",
            ]
        case .hard:
            return [
                "Algeria", "Austria", "Bosnia-Herzegovina", "Cameroon", "Canada",
                "Czech Republic", "Ecuador", "Ghana", "Greece", "Ireland",
                "Mexico", "Paraguay", "Scotland", "Ukraine",
            ]
        }
    }

    static var allTopNations: Set<String> {
        Set(NationalTeamDifficulty.allCases.flatMap { $0.associatedNations })
    }
}
