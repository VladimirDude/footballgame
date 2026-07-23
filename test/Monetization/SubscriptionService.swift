import SwiftUI
import Combine

/// Drives the paywall: loads plans, runs purchases and restores, and exposes a
/// simple view-state the UI can bind to. It owns the *actions*; `EntitlementService`
/// owns the *entitlement state*. After any successful purchase/restore it asks
/// the entitlement service to refresh so gates update app-wide.
@MainActor
final class SubscriptionService: ObservableObject {
    enum LoadState: Equatable {
        case idle
        case loading
        case loaded([SubscriptionPlan])
        case failed(String)
    }

    @Published private(set) var loadState: LoadState = .idle
    @Published private(set) var isPurchasing = false
    @Published var lastMessage: String?

    private let repository: SubscriptionRepository
    private let entitlements: EntitlementService
    private let analytics: AnalyticsService

    init(repository: SubscriptionRepository,
         entitlements: EntitlementService,
         analytics: AnalyticsService = AnalyticsService.shared) {
        self.repository = repository
        self.entitlements = entitlements
        self.analytics = analytics
    }

    func loadPlans() async {
        if case .loaded = loadState { return }
        loadState = .loading
        do {
            let plans = try await repository.loadPlans()
            loadState = plans.isEmpty ? .failed("No plans available right now.") : .loaded(plans)
        } catch {
            loadState = .failed(error.localizedDescription)
        }
    }

    /// Returns true if the user is now Pro.
    @discardableResult
    func purchase(_ plan: SubscriptionPlan) async -> Bool {
        guard !isPurchasing else { return false }
        isPurchasing = true
        defer { isPurchasing = false }
        analytics.log(.purchaseStarted(productID: plan.id))

        let outcome = await repository.purchase(productID: plan.id)
        switch outcome {
        case .success:
            await entitlements.refresh()
            analytics.log(.purchaseCompleted(productID: plan.id))
            lastMessage = "You're now on FTMP Pro. Enjoy!"
            return entitlements.isPro
        case .userCancelled:
            analytics.log(.purchaseCancelled(productID: plan.id))
            return false
        case .pending:
            lastMessage = "Your purchase is pending approval."
            return false
        case .failed(let message):
            analytics.log(.purchaseFailed(productID: plan.id, reason: message))
            lastMessage = message
            return false
        }
    }

    /// Returns true if a Pro entitlement was restored.
    @discardableResult
    func restore() async -> Bool {
        analytics.log(.restoreStarted)
        _ = await repository.restore()
        await entitlements.refresh()
        let restored = entitlements.isPro
        lastMessage = restored ? "Your purchases were restored." : "No previous purchases found."
        analytics.log(.restoreCompleted(restored: restored))
        return restored
    }
}
