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

    /// Injected from the app root so Pro-only achievements stay locked for free users.
    var canUnlockProAchievements: () -> Bool = { false }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: key),
           let decoded = try? JSONDecoder().decode(GameProgress.self, from: data) {
            progress = decoded
        } else {
            progress = GameProgress()
        }
        reconcileDailyStreak()
        publishStreakWidget()
    }

    /// Clears a dead daily streak after a multi-day gap (repair window is exactly one missed day).
    /// Call on launch and whenever the app becomes active.
    func reconcileDailyStreak() {
        guard progress.dailyStreak > 0, let last = progress.dailyLastCompleted else { return }
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let lastDay = cal.startOfDay(for: last)
        let diff = cal.dateComponents([.day], from: lastDay, to: today).day ?? 99
        // 0 = today, 1 = yesterday (alive), 2 = one miss (repair eligible). 3+ = dead.
        guard diff >= 3 else { return }
        progress.dailyStreak = 0
        persist()
    }

    /// Zeros the persisted win streak for a mode (New Game / difficulty change).
    func resetModeStreak(_ mode: GameMode) {
        var stats = progress.stats(for: mode)
        guard stats.currentStreak != 0 else { return }
        stats.currentStreak = 0
        progress.modeStats[mode.rawValue] = stats
        persist()
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
        let unlocked = finish()
        Task {
            await DailyReminderService.shared.reschedule(completedToday: true)
        }
        return unlocked
    }

    var dailyCompletedToday: Bool {
        guard let last = progress.dailyLastCompleted else { return false }
        return Calendar.current.isDateInToday(last)
    }

    /// Missed exactly one calendar day (last play was two days ago) with a live streak.
    var dailyStreakMissedOneDay: Bool {
        guard progress.dailyStreak > 0, !dailyCompletedToday else { return false }
        guard let last = progress.dailyLastCompleted else { return false }
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let lastDay = cal.startOfDay(for: last)
        return cal.dateComponents([.day], from: lastDay, to: today).day == 2
    }

    /// Pro cooldown: next repair is allowed 2 calendar months after the last one.
    var streakRepairAvailableAt: Date? {
        guard let last = progress.dailyStreakLastRepaired else { return nil }
        return Calendar.current.date(byAdding: .month, value: 2, to: last)
    }

    var streakRepairOnCooldown: Bool {
        guard let available = streakRepairAvailableAt else { return false }
        return Date() < available
    }

    /// Whether the UI should offer repair (gap + cooldown). Pro entitlement is checked separately.
    var canOfferStreakRepair: Bool {
        dailyStreakMissedOneDay && !streakRepairOnCooldown
    }

    /// Bridges a one-day gap so today's completion continues the existing streak.
    /// Caller must enforce Pro. Returns `false` if the repair isn't eligible.
    @discardableResult
    func repairDailyStreak() -> Bool {
        guard canOfferStreakRepair else { return false }
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        guard let yesterday = cal.date(byAdding: .day, value: -1, to: today) else { return false }
        progress.dailyLastCompleted = yesterday
        progress.dailyStreakLastRepaired = Date()
        persist()
        HapticFeedback.success()
        return true
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
        DailyStreakBridge.clear()
    }

    // MARK: - Private

    private func finish() -> [Achievement] {
        let newly = AchievementCatalog.newlyUnlocked(
            in: progress,
            allowPro: canUnlockProAchievements()
        )
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
        publishStreakWidget()
    }

    /// Push current streak state to the Home Screen widget (call on launch / foreground).
    func refreshWidget() {
        publishStreakWidget()
    }

    private func publishStreakWidget() {
        DailyStreakBridge.publish(
            streak: progress.dailyStreak,
            completedToday: dailyCompletedToday,
            lastCompleted: progress.dailyLastCompleted,
            dayLabel: DailyChallenge.label()
        )
    }
}
