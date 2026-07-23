import Foundation

/// Sits between the services and the raw `StoreProvider`. Its one added
/// responsibility is an **offline entitlement cache**: the last verified
/// entitlement is written to disk so that if the store is unreachable at launch,
/// a paying user still gets Pro (App Store requires paid features keep working
/// without a live network check). A verified value always supersedes the cache.
actor SubscriptionRepository {
    private let provider: StoreProvider
    private let cacheURL: URL

    init(provider: StoreProvider) {
        self.provider = provider
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        self.cacheURL = dir.appendingPathComponent("entitlement.json")
    }

    var entitlementUpdates: AsyncStream<Entitlement> { provider.entitlementUpdates }

    func loadPlans() async throws -> [SubscriptionPlan] {
        try await provider.loadPlans()
    }

    /// Resolves the entitlement, preferring a live verified value and falling
    /// back to the on-disk cache when the store yields nothing (offline).
    func resolveEntitlement() async -> Entitlement {
        let verified = await provider.currentEntitlement()
        if verified.tier == .pro {
            persist(verified)
            return verified
        }
        // Store says free — but if we're offline it may just not know yet.
        // Honor a cached, still-valid Pro entitlement.
        if let cached = readCache(), cached.isProActive() {
            return Entitlement(tier: .pro, expirationDate: cached.expirationDate,
                               productID: cached.productID, source: .cached)
        }
        persist(verified)
        return verified
    }

    func purchase(productID: String) async -> PurchaseOutcome {
        let outcome = await provider.purchase(productID: productID)
        if case .success(let entitlement) = outcome { persist(entitlement) }
        return outcome
    }

    func restore() async -> Entitlement {
        let entitlement = await provider.restore()
        persist(entitlement)
        return entitlement
    }

    func cache(_ entitlement: Entitlement) { persist(entitlement) }

    // MARK: - Disk cache

    private func persist(_ entitlement: Entitlement) {
        guard let data = try? JSONEncoder().encode(entitlement) else { return }
        try? data.write(to: cacheURL, options: .atomic)
    }

    private func readCache() -> Entitlement? {
        guard let data = try? Data(contentsOf: cacheURL) else { return nil }
        return try? JSONDecoder().decode(Entitlement.self, from: data)
    }
}
