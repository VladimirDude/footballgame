import XCTest
@testable import test

/// Verifies the gamification → monetization bridge: reaching
/// `ProgressionRewards.proUnlockLevel` grants full Pro for free, with no
/// subscription. `EntitlementService`/`GameProgressStore` are `@MainActor`, so each
/// test hops onto the main actor (see AliasEngineTests for the why).
final class ProgressionEntitlementTests: XCTestCase {

    /// Cumulative XP to reach a level (L→L+1 costs L×100).
    private func xp(forLevel n: Int) -> Int { 100 * (n - 1) * n / 2 }

    @MainActor
    private func makeService(totalXP: Int) -> EntitlementService {
        let defaults = UserDefaults(suiteName: "test.progression.\(UUID().uuidString)")!
        let store = GameProgressStore(defaults: defaults)
        store.awardXP(totalXP)
        let repo = SubscriptionRepository(provider: MockStoreProvider())
        let service = EntitlementService(repository: repo, progressStore: store)
        service.refreshProgression()
        return service
    }

    func testBelowThresholdIsNotPro() async {
        await MainActor.run {
            let service = makeService(totalXP: xp(forLevel: ProgressionRewards.proUnlockLevel) - 1)
            XCTAssertFalse(service.progressionUnlocked)
            XCTAssertFalse(service.isPro)
            XCTAssertFalse(service.canAccess(.hardDifficulty))
            XCTAssertFalse(service.canAccess(.aliasPremiumPacks))
        }
    }

    func testReachingThresholdUnlocksFullProForFree() async {
        await MainActor.run {
            let service = makeService(totalXP: xp(forLevel: ProgressionRewards.proUnlockLevel))
            XCTAssertTrue(service.progressionUnlocked)
            XCTAssertTrue(service.isPro)
            // Full parity: every premium feature is accessible.
            for feature in PremiumFeature.allCases {
                XCTAssertTrue(service.canAccess(feature), "\(feature) should be unlocked via level")
            }
        }
    }

    func testEarnedProIsNotASubscription() async {
        await MainActor.run {
            let service = makeService(totalXP: xp(forLevel: ProgressionRewards.proUnlockLevel))
            XCTAssertTrue(service.isPro)
            XCTAssertFalse(service.isSubscribed, "level unlock must not masquerade as a paid subscription")
        }
    }

    func testProUnlockedAchievementFiresAtThreshold() {
        var below = GameProgress()
        below.totalXP = xp(forLevel: ProgressionRewards.proUnlockLevel) - 1
        XCTAssertFalse(AchievementCatalog.newlyUnlocked(in: below).contains { $0.id == "pro_unlocked" })

        var at = GameProgress()
        at.totalXP = xp(forLevel: ProgressionRewards.proUnlockLevel)
        XCTAssertTrue(AchievementCatalog.newlyUnlocked(in: at).contains { $0.id == "pro_unlocked" })
    }
}
