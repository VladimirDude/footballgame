import Foundation
import StoreKit

/// StoreKit 2 implementation of `StoreProvider`. This is the *only* file in the
/// app that imports StoreKit. Everything above it deals in `SubscriptionPlan` /
/// `Entitlement` / `PurchaseOutcome`, so swapping billing backends never reaches
/// business logic or UI.
final class StoreKitProvider: StoreProvider, @unchecked Sendable {
    let productIDs: [String]

    private let updatesContinuation: AsyncStream<Entitlement>.Continuation
    let entitlementUpdates: AsyncStream<Entitlement>
    private var updatesTask: Task<Void, Never>?

    init(productIDs: [String] = StoreConfig.allProductIDs) {
        self.productIDs = productIDs
        var continuation: AsyncStream<Entitlement>.Continuation!
        self.entitlementUpdates = AsyncStream { continuation = $0 }
        self.updatesContinuation = continuation
        startListeningForTransactions()
    }

    deinit {
        updatesTask?.cancel()
        updatesContinuation.finish()
    }

    // MARK: - Loading

    func loadPlans() async throws -> [SubscriptionPlan] {
        let products = try await Product.products(for: productIDs)
        return products
            .compactMap(Self.plan(from:))
            .sorted { $0.period.sortOrder < $1.period.sortOrder }
    }

    func currentEntitlement() async -> Entitlement {
        var best = Entitlement.free
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else { continue }
            guard transaction.revocationDate == nil else { continue }
            if let expiry = transaction.expirationDate, expiry <= Date() { continue }
            let candidate = Entitlement(
                tier: .pro,
                expirationDate: transaction.expirationDate,
                productID: transaction.productID,
                source: .verified
            )
            // Prefer the entitlement that lasts longest (lifetime > yearly > monthly).
            if candidate.expirationDate == nil { return candidate }
            if let a = candidate.expirationDate, let b = best.expirationDate {
                if a > b { best = candidate }
            } else if best.tier == .free {
                best = candidate
            }
        }
        return best
    }

    // MARK: - Purchase / Restore

    func purchase(productID: String) async -> PurchaseOutcome {
        do {
            guard let product = try await Product.products(for: [productID]).first else {
                return .failed("This item is not available.")
            }
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                guard case .verified(let transaction) = verification else {
                    return .failed("Could not verify the purchase.")
                }
                await transaction.finish()
                return .success(await currentEntitlement())
            case .userCancelled:
                return .userCancelled
            case .pending:
                return .pending
            @unknown default:
                return .failed("Unknown purchase result.")
            }
        } catch {
            return .failed(error.localizedDescription)
        }
    }

    func restore() async -> Entitlement {
        try? await AppStore.sync()
        return await currentEntitlement()
    }

    // MARK: - Transaction listener

    private func startListeningForTransactions() {
        updatesTask = Task { [weak self] in
            guard let self else { return }
            for await result in Transaction.updates {
                guard case .verified(let transaction) = result else { continue }
                await transaction.finish()
                let entitlement = await self.currentEntitlement()
                self.updatesContinuation.yield(entitlement)
            }
        }
    }

    // MARK: - Mapping

    private static func plan(from product: Product) -> SubscriptionPlan? {
        let period: SubscriptionPlan.Period
        var pricePerMonth: String?
        var trialDays: Int?

        if let subscription = product.subscription {
            switch subscription.subscriptionPeriod.unit {
            case .year:
                period = .yearly
                let monthly = product.price / 12
                pricePerMonth = product.priceFormatStyle.format(monthly)
            case .month:
                period = .monthly
            default:
                period = .monthly
            }
            if let intro = subscription.introductoryOffer, intro.paymentMode == .freeTrial {
                trialDays = Self.days(from: intro.period)
            }
        } else {
            // Non-consumable → lifetime unlock.
            period = .lifetime
        }

        return SubscriptionPlan(
            id: product.id,
            period: period,
            displayName: product.displayName,
            localizedPrice: product.displayPrice,
            localizedPricePerMonth: pricePerMonth,
            trialDays: trialDays
        )
    }

    private static func days(from period: Product.SubscriptionPeriod) -> Int {
        switch period.unit {
        case .day: return period.value
        case .week: return period.value * 7
        case .month: return period.value * 30
        case .year: return period.value * 365
        @unknown default: return period.value
        }
    }
}

private extension SubscriptionPlan.Period {
    var sortOrder: Int {
        switch self {
        case .yearly: 0
        case .lifetime: 1
        case .monthly: 2
        }
    }
}
