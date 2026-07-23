import Foundation

/// In-memory `StoreProvider` for unit tests, SwiftUI previews, and running the
/// app before any App Store Connect products exist. Purchases "succeed"
/// instantly and grant Pro so the full paywall → gate → unlock flow can be
/// exercised end-to-end without the network or a sandbox account.
final class MockStoreProvider: StoreProvider, @unchecked Sendable {
    let productIDs: [String]

    private let updatesContinuation: AsyncStream<Entitlement>.Continuation
    let entitlementUpdates: AsyncStream<Entitlement>

    private let lock = NSLock()
    private var _entitlement: Entitlement
    private let plans: [SubscriptionPlan]

    init(startingEntitlement: Entitlement = .free) {
        self.productIDs = StoreConfig.allProductIDs
        self._entitlement = startingEntitlement
        var continuation: AsyncStream<Entitlement>.Continuation!
        self.entitlementUpdates = AsyncStream { continuation = $0 }
        self.updatesContinuation = continuation
        self.plans = [
            SubscriptionPlan(id: StoreConfig.yearlyID, period: .yearly,
                             displayName: "FTMP Pro (Yearly)", localizedPrice: "$19.99",
                             localizedPricePerMonth: "$1.67", trialDays: 7),
            SubscriptionPlan(id: StoreConfig.monthlyID, period: .monthly,
                             displayName: "FTMP Pro (Monthly)", localizedPrice: "$2.99",
                             localizedPricePerMonth: nil, trialDays: nil),
            SubscriptionPlan(id: StoreConfig.lifetimeID, period: .lifetime,
                             displayName: "FTMP Pro (Lifetime)", localizedPrice: "$49.99",
                             localizedPricePerMonth: nil, trialDays: nil),
        ]
    }

    func loadPlans() async throws -> [SubscriptionPlan] { plans }

    func currentEntitlement() async -> Entitlement {
        lock.lock(); defer { lock.unlock() }
        return _entitlement
    }

    func purchase(productID: String) async -> PurchaseOutcome {
        let isLifetime = productID == StoreConfig.lifetimeID
        let entitlement = Entitlement(
            tier: .pro,
            expirationDate: isLifetime ? nil : Calendar.current.date(byAdding: .month, value: 1, to: Date()),
            productID: productID,
            source: .verified
        )
        lock.lock(); _entitlement = entitlement; lock.unlock()
        updatesContinuation.yield(entitlement)
        return .success(entitlement)
    }

    func restore() async -> Entitlement {
        await currentEntitlement()
    }
}
