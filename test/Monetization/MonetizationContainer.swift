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

    /// DEBUG uses the in-memory mock so buy/restore works in Simulator with no
    /// Apple Account. Release uses real StoreKit (needs App Store Connect products
    /// or a Sandbox Apple ID). Attach `Products.storekit` to the scheme only when
    /// you explicitly want to test the StoreKit path with `useMock: false`.
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
