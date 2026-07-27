import SwiftUI
import Combine

/// Backs the team/round setup screen. Holds the editable choices and turns them
/// into an `AliasConfig` + teams for the container to build an engine.
@MainActor
final class AliasSetupViewModel: ObservableObject {
    @Published var teamCount: Int
    @Published var teamNames: [String]
    @Published var timerSeconds: Int
    @Published var selectedCategories: Set<AliasCategory>
    @Published var minDifficulty: AliasDifficulty
    @Published var maxDifficulty: AliasDifficulty
    @Published var targetScore: Int
    @Published var skipPenalty: Int

    let language: String

    static let defaultTeamNames = ["Red Team", "Blue Team", "Green Team", "Yellow Team"]
    static let maxTeams = 4
    static let minTeams = 2

    init(language: String = "en", base: AliasConfig = .default) {
        self.language = language
        self.teamCount = 2
        self.teamNames = AliasSetupViewModel.defaultTeamNames
        self.timerSeconds = base.timerSeconds
        self.selectedCategories = base.categories
        self.minDifficulty = base.minDifficulty
        self.maxDifficulty = base.maxDifficulty
        self.targetScore = base.targetScore
        self.skipPenalty = base.skipPenalty
    }

    func setTeamCount(_ n: Int) {
        teamCount = min(max(n, Self.minTeams), Self.maxTeams)
    }

    func toggleCategory(_ category: AliasCategory) {
        if selectedCategories.contains(category) {
            // Keep at least one category selected.
            if selectedCategories.count > 1 { selectedCategories.remove(category) }
        } else {
            selectedCategories.insert(category)
            AnalyticsService.shared.log(.aliasCategorySelected(category: category.rawValue))
        }
    }

    func makeConfig() -> AliasConfig {
        AliasConfig(
            timerSeconds: timerSeconds,
            categories: selectedCategories,
            minDifficulty: min(minDifficulty, maxDifficulty),
            maxDifficulty: max(minDifficulty, maxDifficulty),
            skipPenalty: skipPenalty,
            pointsPerCorrect: 1,
            targetScore: targetScore,
            language: language
        )
    }

    func makeTeams() -> [AliasTeam] {
        (0..<teamCount).map { i in
            let fallback = "Team \(i + 1)"
            let name = i < teamNames.count && !teamNames[i].trimmingCharacters(in: .whitespaces).isEmpty
                ? teamNames[i]
                : fallback
            return AliasTeam(id: i, name: name)
        }
    }
}
