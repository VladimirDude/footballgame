import Foundation

/// A single analytics event. Defining events as an enum (rather than scattering
/// stringly-typed `log("some_event")` calls across the app) keeps the taxonomy
/// in one place, makes renames safe, and gives every call site autocomplete.
enum AnalyticsEvent {
    // Lifecycle
    case appOpened
    case screenViewed(name: String)
    case onboardingStarted
    case onboardingCompleted

    // Games
    case gameStarted(mode: String)
    case gameFinished(mode: String, score: Int)

    // Monetization funnel
    case paywallShown(source: String)
    case paywallDismissed(source: String)
    case featureBlocked(feature: String)
    case featureUnlocked(feature: String)
    case purchaseStarted(productID: String)
    case purchaseCompleted(productID: String)
    case purchaseCancelled(productID: String)
    case purchaseFailed(productID: String, reason: String)
    case restoreStarted
    case restoreCompleted(restored: Bool)

    /// Snake-case name sent to the backend (Firebase-friendly).
    var name: String {
        switch self {
        case .appOpened: "app_opened"
        case .screenViewed: "screen_viewed"
        case .onboardingStarted: "onboarding_started"
        case .onboardingCompleted: "onboarding_completed"
        case .gameStarted: "game_started"
        case .gameFinished: "game_finished"
        case .paywallShown: "paywall_shown"
        case .paywallDismissed: "paywall_dismissed"
        case .featureBlocked: "feature_blocked"
        case .featureUnlocked: "feature_unlocked"
        case .purchaseStarted: "purchase_started"
        case .purchaseCompleted: "purchase_completed"
        case .purchaseCancelled: "purchase_cancelled"
        case .purchaseFailed: "purchase_failed"
        case .restoreStarted: "restore_started"
        case .restoreCompleted: "restore_completed"
        }
    }

    var parameters: [String: Any] {
        switch self {
        case .appOpened, .onboardingStarted, .onboardingCompleted, .restoreStarted:
            return [:]
        case .screenViewed(let name): return ["screen": name]
        case .gameStarted(let mode): return ["mode": mode]
        case .gameFinished(let mode, let score): return ["mode": mode, "score": score]
        case .paywallShown(let source), .paywallDismissed(let source): return ["source": source]
        case .featureBlocked(let feature), .featureUnlocked(let feature): return ["feature": feature]
        case .purchaseStarted(let id), .purchaseCompleted(let id), .purchaseCancelled(let id):
            return ["product_id": id]
        case .purchaseFailed(let id, let reason): return ["product_id": id, "reason": reason]
        case .restoreCompleted(let restored): return ["restored": restored]
        }
    }
}

/// A destination for analytics events. Firebase, Amplitude, a test spy, or a
/// console logger each conform to this. `AnalyticsService` fans out to all
/// registered backends, so adding Firebase later is one `register(...)` call and
/// a new conformer — no call site changes.
protocol AnalyticsBackend: AnyObject {
    func log(name: String, parameters: [String: Any])
    func setUserProperty(_ value: String?, for key: String)
}

/// Prints events in DEBUG builds. Handy until a real backend is wired in.
final class ConsoleAnalyticsBackend: AnalyticsBackend {
    func log(name: String, parameters: [String: Any]) {
        #if DEBUG
        let params = parameters.isEmpty ? "" : " \(parameters)"
        print("📊 analytics: \(name)\(params)")
        #endif
    }
    func setUserProperty(_ value: String?, for key: String) {}
}

/// Centralized analytics entry point. The app logs through `AnalyticsService.shared`;
/// where those events actually go is decided by the registered backends.
///
/// To add Firebase: create `FirebaseAnalyticsBackend: AnalyticsBackend` wrapping
/// `Analytics.logEvent`, then `AnalyticsService.shared.register(FirebaseAnalyticsBackend())`
/// at launch. Nothing else changes.
final class AnalyticsService: @unchecked Sendable {
    static let shared = AnalyticsService()

    private let lock = NSLock()
    private var backends: [AnalyticsBackend] = []

    private init() {
        #if DEBUG
        backends = [ConsoleAnalyticsBackend()]
        #endif
    }

    func register(_ backend: AnalyticsBackend) {
        lock.lock(); backends.append(backend); lock.unlock()
    }

    func log(_ event: AnalyticsEvent) {
        lock.lock(); let backends = self.backends; lock.unlock()
        for backend in backends {
            backend.log(name: event.name, parameters: event.parameters)
        }
    }

    func setUserProperty(_ value: String?, for key: String) {
        lock.lock(); let backends = self.backends; lock.unlock()
        for backend in backends { backend.setUserProperty(value, for: key) }
    }
}
