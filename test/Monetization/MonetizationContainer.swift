import SwiftUI
import Combine

/// Composition root for monetization. Owns the object graph
/// (provider → repository → services) and is created once at app launch, then
/// injected into the environment so any screen can gate features or open the
/// paywall.
///
/// Swap `StoreKitProvider` for `MockStoreProvider` (or a future
/// `PlayBillingProvider`) here — it is the single wiring point.
@MainActor
final class MonetizationContainer: ObservableObject {
    let entitlements: EntitlementService
    let subscriptions: SubscriptionService

    init(useMock: Bool = MonetizationContainer.defaultUseMock) {
        let provider: StoreProvider = useMock ? MockStoreProvider() : StoreKitProvider()
        let repository = SubscriptionRepository(provider: provider)
        let entitlements = EntitlementService(repository: repository)
        self.entitlements = entitlements
        self.subscriptions = SubscriptionService(repository: repository, entitlements: entitlements)
    }

    /// Kicks off entitlement resolution and the transaction listener.
    func start() {
        entitlements.start()
    }

    /// In DEBUG we use the in-memory mock so the full paywall → purchase → unlock
    /// flow works in the simulator with no App Store Connect products. In release
    /// we use real StoreKit. Flip DEBUG to real StoreKit once a
    /// `Products.storekit` config is attached to the scheme (Edit Scheme ▸ Run ▸
    /// Options ▸ StoreKit Configuration) or sandbox products exist.
    nonisolated static var defaultUseMock: Bool {
        #if DEBUG
        return true
        #else
        return false
        #endif
    }
}

extension View {
    /// Injects the monetization services so `@EnvironmentObject` lookups resolve.
    func withMonetization(_ container: MonetizationContainer) -> some View {
        self
            .environmentObject(container)
            .environmentObject(container.entitlements)
            .environmentObject(container.subscriptions)
    }
}
