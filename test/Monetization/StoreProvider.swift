import Foundation

/// A purchasable subscription plan, normalized away from any specific billing
/// SDK. The paywall renders these; it never touches a StoreKit `Product`.
struct SubscriptionPlan: Identifiable, Equatable, Sendable {
    enum Period: Equatable, Sendable {
        case monthly
        case yearly
        case lifetime
    }

    let id: String                 // store product identifier
    let period: Period
    let displayName: String
    let localizedPrice: String     // already formatted in the store's locale
    /// Optional pre-formatted "per month" price for yearly plans, for comparison.
    let localizedPricePerMonth: String?
    /// Introductory free-trial length in days, if the plan offers one.
    let trialDays: Int?

    var hasFreeTrial: Bool { (trialDays ?? 0) > 0 }
}

/// Result of attempting a purchase, provider-agnostic.
enum PurchaseOutcome: Sendable {
    case success(Entitlement)
    case userCancelled
    case pending          // e.g. Ask-to-Buy / SCA deferral
    case failed(String)   // localized error description
}

/// The single seam between the app and a billing backend.
///
/// StoreKit lives *behind* this protocol (`StoreKitProvider`); a `MockStoreProvider`
/// implements it for tests, SwiftUI previews, and running without an App Store
/// Connect account. A future `PlayBillingProvider` would conform to the same
/// protocol, so nothing above this line changes when adding Android.
protocol StoreProvider: Sendable {
    /// The product identifiers this app sells (subscription group + any lifetime).
    var productIDs: [String] { get }

    /// Fetches purchasable plans from the store, localized and priced.
    func loadPlans() async throws -> [SubscriptionPlan]

    /// Current entitlement as known to the store right now (verified).
    func currentEntitlement() async -> Entitlement

    /// Starts a purchase for `productID`.
    func purchase(productID: String) async -> PurchaseOutcome

    /// Restores previous purchases (required by App Store guideline 3.1.1).
    func restore() async -> Entitlement

    /// A stream that emits whenever the entitlement changes out-of-band
    /// (renewal, expiration, refund, Ask-to-Buy approval, family sharing).
    var entitlementUpdates: AsyncStream<Entitlement> { get }
}

/// Central place for product identifiers and the subscription group. These must
/// match App Store Connect (and the local `Products.storekit` used for testing).
enum StoreConfig {
    static let subscriptionGroupID = "ftmp_pro"
    static let monthlyID = "com.ftmpapp.app.pro.monthly"
    static let yearlyID = "com.ftmpapp.app.pro.yearly"
    static let lifetimeID = "com.ftmpapp.app.pro.lifetime"

    static let allProductIDs = [monthlyID, yearlyID, lifetimeID]
}
