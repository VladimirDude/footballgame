import SwiftUI
import Combine

/// The app-wide source of truth for "what can this user do." Views read this
/// (via `@EnvironmentObject`) to decide whether to show content or a lock.
///
/// It deliberately exposes a *capability* API — `canAccess(_:)` — rather than a
/// raw `isSubscribed` boolean, so gating rules live in `FeatureCatalog`, not at
/// call sites. Flip a feature free, or A/B a new gate, without touching any view.
@MainActor
final class EntitlementService: ObservableObject {
    @Published private(set) var entitlement: Entitlement = .free

    private let repository: SubscriptionRepository
    private var updatesTask: Task<Void, Never>?

    init(repository: SubscriptionRepository) {
        self.repository = repository
    }

    /// Call once at launch. Loads the (possibly cached) entitlement and starts
    /// listening for out-of-band changes (renewals, expirations, refunds).
    func start() {
        Task { await refresh() }
        updatesTask = Task { [weak self] in
            guard let self else { return }
            for await updated in await repository.entitlementUpdates {
                self.entitlement = updated
            }
        }
    }

    func refresh() async {
        entitlement = await repository.resolveEntitlement()
    }

    // MARK: - Gating API

    var isPro: Bool { entitlement.isProActive() }

    /// Whether the user may use a given feature. Free features always return
    /// true; premium features require an active Pro entitlement.
    func canAccess(_ feature: PremiumFeature) -> Bool {
        guard FeatureCatalog.requiresPro(feature) else { return true }
        return isPro
    }
}
