import SwiftUI
import Combine

/// The app-wide source of truth for "what can this user do." Views read this
/// (via `@EnvironmentObject`) to decide whether to show content or a lock.
///
/// It deliberately exposes a *capability* API — `canAccess(_:)` — rather than a
/// raw `isSubscribed` boolean, so gating rules live in `FeatureCatalog`, not at
/// call sites. Flip a feature free, or A/B a new gate, without touching any view.
///
/// Pro can be held two ways, OR'd together: a paid subscription (`entitlement`) or
/// an *earned* unlock from progression (`progressionUnlocked`) — reaching
/// `ProgressionRewards.proUnlockLevel` grants full Pro for free.
@MainActor
final class EntitlementService: ObservableObject {
    @Published private(set) var entitlement: Entitlement = .free
    /// True once the player has reached the level that unlocks Pro for free.
    @Published private(set) var progressionUnlocked = false

    private let repository: SubscriptionRepository
    private let progressStore: GameProgressStore
    private var updatesTask: Task<Void, Never>?
    private var progressionCancellable: AnyCancellable?

    /// Persisted so the "earned Pro" analytics event fires at most once, ever.
    private let unlockLoggedKey = "proProgressionUnlockLogged"

    init(repository: SubscriptionRepository, progressStore: GameProgressStore = .shared) {
        self.repository = repository
        self.progressStore = progressStore
    }

    /// Call once at launch. Loads the (possibly cached) entitlement, starts
    /// listening for out-of-band changes (renewals, expirations, refunds), and
    /// watches progression so a level-up can unlock Pro live.
    func start() {
        Task {
            // Seed from disk so paid users aren't briefly gated as free at launch.
            if let cached = await repository.peekCache(), cached.isProActive() {
                entitlement = cached
            }
            await refresh()
        }
        updatesTask = Task { [weak self] in
            guard let self else { return }
            for await updated in await repository.entitlementUpdates {
                self.entitlement = updated
                await repository.cache(updated)
            }
        }
        progressionCancellable = progressStore.$progress
            .sink { [weak self] progress in
                self?.applyProgression(level: XPCurve.level(forXP: progress.totalXP).level)
            }
        refreshProgression()
    }

    func refresh() async {
        entitlement = await repository.resolveEntitlement()
    }

    /// Recompute the progression unlock from the current stored level. Exposed for
    /// tests and to seed the initial value in `start()`.
    func refreshProgression() {
        applyProgression(level: progressStore.level.level)
    }

    private func applyProgression(level: Int) {
        let unlocked = level >= ProgressionRewards.proUnlockLevel
        guard unlocked != progressionUnlocked else { return }
        progressionUnlocked = unlocked
        if unlocked, !UserDefaults.standard.bool(forKey: unlockLoggedKey) {
            UserDefaults.standard.set(true, forKey: unlockLoggedKey)
            AnalyticsService.shared.log(.featureUnlocked(feature: "pro_progression"))
        }
    }

    // MARK: - Gating API

    /// Pro from *either* a paid subscription or an earned progression unlock.
    var isPro: Bool { entitlement.isProActive() || progressionUnlocked }

    /// Pro specifically from a paid subscription — used where the UI must
    /// distinguish a subscriber (manage/cancel) from an earned unlock.
    var isSubscribed: Bool { entitlement.isProActive() }

    /// Whether the user may use a given feature. Free features always return
    /// true; premium features require active Pro (subscription or earned).
    func canAccess(_ feature: PremiumFeature) -> Bool {
        guard FeatureCatalog.requiresPro(feature) else { return true }
        return isPro
    }
}
