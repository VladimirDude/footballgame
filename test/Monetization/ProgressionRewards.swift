import Foundation

/// Progression-based rewards config. Kept as data (like `FeatureCatalog`) so the
/// threshold can later be driven by Remote Config for A/B testing without touching
/// the entitlement logic.
enum ProgressionRewards {
    /// Reaching this level unlocks full Pro access for free — the gamification →
    /// monetization bridge (see `EntitlementService.progressionUnlocked`).
    static let proUnlockLevel = 20
}
