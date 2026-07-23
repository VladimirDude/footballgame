import Foundation

/// Gate for unlocking My Team **Admin mode**.
///
/// Admin is a two-key gate:
///   1. The user must have **Pro** (`PremiumFeature.adminMode`) — enforced in the UI.
///   2. They must enter the correct **secret passphrase** (below).
///
/// So a free user can never reach admin, and even a Pro user needs the shared
/// secret your organization hands out.
///
/// The passphrase is **Remote-Config-driven**: `RemoteConfigService` fetches the
/// `admin_passphrase` key from Firebase and sets `remotePassphrase`, so you can
/// rotate it from the console without shipping an app update. Until (or unless)
/// a remote value arrives, `fallbackPassphrase` is used.
enum AdminAccess {
    /// Firebase Remote Config key that holds the passphrase.
    static let remoteConfigKey = "admin_passphrase"

    /// Used before Remote Config responds, or if the SDK/network is unavailable.
    /// Change this to your own secret.
    static let fallbackPassphrase = "cognaize-admin"

    /// Set by `RemoteConfigService` once a remote value is fetched. `nil` = use fallback.
    static var remotePassphrase: String?

    /// The passphrase currently in effect.
    static var passphrase: String { remotePassphrase ?? fallbackPassphrase }

    static func isValid(_ input: String) -> Bool {
        input.trimmingCharacters(in: .whitespacesAndNewlines)
            .caseInsensitiveCompare(passphrase) == .orderedSame
    }
}
