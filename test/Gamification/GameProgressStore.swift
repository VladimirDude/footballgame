import SwiftUI
import Combine

/// The app-wide source of truth for player progression: per-mode stats, XP/level,
/// achievements, and the daily-challenge streak. Persisted as one JSON blob in
/// UserDefaults. Views read it via `@EnvironmentObject`.
@MainActor
final class GameProgressStore: ObservableObject {
    static let shared = GameProgressStore()

    @Published private(set) var progress: GameProgress
    /// The next achievement to celebrate; a top-level overlay observes this.
    @Published var pendingUnlock: Achievement?

    private var unlockQueue: [Achievement] = []
    private let key = "gameProgressV1"
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: key),
           let decoded = try? JSONDecoder().decode(GameProgress.self, from: data) {
            progress = decoded
        } else {
            progress = GameProgress()
        }
    }

    var level: LevelInfo { XPCurve.level(forXP: progress.totalXP) }

    // MARK: - Recording

    /// Records a finished game round: updates stats + streak, awards XP, evaluates
    /// achievements. Returns any newly-unlocked achievements (also queued for the banner).
    @discardableResult
    func recordResult(mode: GameMode, won: Bool) -> [Achievement] {
        var stats = progress.stats(for: mode)
        stats.gamesPlayed += 1
        if won {
            stats.wins += 1
            stats.currentStreak += 1
            stats.bestStreak = max(stats.bestStreak, stats.currentStreak)
        } else {
            stats.currentStreak = 0
        }
        progress.modeStats[mode.rawValue] = stats
        progress.totalXP += XPCurve.xp(won: won, streak: stats.currentStreak)
        progress.lastPlayed = Date()
        return finish()
    }

    /// Direct XP award (e.g. predictor points). Evaluates achievements + persists.
    @discardableResult
    func awardXP(_ amount: Int) -> [Achievement] {
        guard amount > 0 else { return [] }
        progress.totalXP += amount
        return finish()
    }

    /// Marks today's daily challenge complete, advancing (or resetting) the day
    /// streak and awarding a bonus. No-op if already completed today.
    @discardableResult
    func recordDailyCompleted() -> [Achievement] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        if let last = progress.dailyLastCompleted {
            if cal.isDate(last, inSameDayAs: today) { return [] }   // already done
            let lastDay = cal.startOfDay(for: last)
            let diff = cal.dateComponents([.day], from: lastDay, to: today).day ?? 99
            progress.dailyStreak = (diff == 1) ? progress.dailyStreak + 1 : 1
        } else {
            progress.dailyStreak = 1
        }
        progress.dailyLastCompleted = today
        progress.totalXP += 50
        return finish()
    }

    var dailyCompletedToday: Bool {
        guard let last = progress.dailyLastCompleted else { return false }
        return Calendar.current.isDateInToday(last)
    }

    // MARK: - Unlock queue

    /// Advance to the next queued unlock (call when the banner is dismissed).
    func dismissUnlock() {
        pendingUnlock = unlockQueue.isEmpty ? nil : unlockQueue.removeFirst()
    }

    func reset() {
        progress = GameProgress()
        unlockQueue.removeAll()
        pendingUnlock = nil
        persist()
    }

    // MARK: - Private

    private func finish() -> [Achievement] {
        let newly = AchievementCatalog.newlyUnlocked(in: progress)
        for achievement in newly { progress.unlockedAchievements.insert(achievement.id) }
        if !newly.isEmpty {
            var queue = newly
            if pendingUnlock == nil { pendingUnlock = queue.removeFirst() }
            unlockQueue.append(contentsOf: queue)
        }
        persist()
        return newly
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(progress) {
            defaults.set(data, forKey: key)
        }
    }
}
