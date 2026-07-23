import Foundation

/// The user's subscription tier. Intentionally provider-agnostic — nothing here
/// knows about StoreKit, so the same model works if billing later moves to
/// Google Play, a web checkout, or a server-issued entitlement.
enum SubscriptionTier: String, Codable, Sendable {
    case free
    case pro
}

/// Where the current entitlement came from. Useful for analytics and for
/// deciding how much to trust a value (e.g. a cached value while offline).
enum EntitlementSource: String, Codable, Sendable {
    /// Verified this session against the store (StoreKit `Transaction`).
    case verified
    /// Loaded from the on-device cache while the store was unreachable.
    case cached
    /// No entitlement information available yet.
    case unknown
}

/// The app-wide answer to "what is this user allowed to do right now."
///
/// This is the single value the rest of the app reads. It is `Codable` so it can
/// be cached to disk and honored offline (App Store guidelines require that a
/// paid entitlement keeps working without a live network round-trip).
struct Entitlement: Codable, Equatable, Sendable {
    var tier: SubscriptionTier
    /// When the paid entitlement lapses. `nil` for free or non-expiring (lifetime).
    var expirationDate: Date?
    /// Product identifier that granted the entitlement, if any.
    var productID: String?
    var source: EntitlementSource

    static let free = Entitlement(tier: .free, expirationDate: nil, productID: nil, source: .unknown)

    /// Pro is active if the tier is pro and it hasn't expired. A `nil`
    /// expiration means lifetime / non-expiring.
    func isProActive(asOf now: Date = Date()) -> Bool {
        guard tier == .pro else { return false }
        if let expirationDate { return expirationDate > now }
        return true
    }
}

/// Every capability that can be gated behind Pro. Adding a case here — and one
/// line in `FeatureCatalog` — is all it takes to gate a new feature; no call
/// site hard-codes `if isSubscribed`.
enum PremiumFeature: String, CaseIterable, Codable, Sendable {
    case hardDifficulty          // Medium/Hard quiz difficulty tiers
    case higherLowerRevive       // Second chance after a wrong Higher-or-Lower guess
    case unlimitedSimulations    // Full-season / unlimited match simulations
    case advancedMatchReport     // Full xG / shot-map / timeline match reports
    case advancedSeasonStats     // Golden boot, clean sheets, biggest win, etc.
    case advancedSearchFilters   // Multi-select + market-value range filters
    case unlimitedSearchResults  // Removes the free-tier result cap
    case extraLeagues            // Leagues beyond the free Premier League
    case themePacks              // Cosmetic theme skins
    case adminMode               // My Team admin: create/edit/publish shared teams

    /// Short, user-facing name for paywall / lock copy.
    var displayName: String {
        switch self {
        case .hardDifficulty: "Harder Difficulties"
        case .higherLowerRevive: "Second Chances"
        case .unlimitedSimulations: "Unlimited Simulations"
        case .advancedMatchReport: "Full Match Reports"
        case .advancedSeasonStats: "Advanced Season Stats"
        case .advancedSearchFilters: "Advanced Filters"
        case .unlimitedSearchResults: "Unlimited Results"
        case .extraLeagues: "All Leagues"
        case .themePacks: "Theme Packs"
        case .adminMode: "Team Admin"
        }
    }
}

/// Declares which features are gated. This is deliberately *data*, not scattered
/// `if` checks — flip a feature to free (or gate a new one) in one place, and it
/// could later be driven by Remote Config for A/B testing without a code change.
enum FeatureCatalog {
    /// Features that require Pro. Anything not listed is free for everyone.
    static let premiumFeatures: Set<PremiumFeature> = Set(PremiumFeature.allCases)

    static func requiresPro(_ feature: PremiumFeature) -> Bool {
        premiumFeatures.contains(feature)
    }
}
