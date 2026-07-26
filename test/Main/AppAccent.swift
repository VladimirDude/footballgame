import SwiftUI

/// Selectable app accent color. "Classic" is free; the rest are a Pro theme pack
/// (`PremiumFeature.themePacks`). The selection drives the app-wide `.tint` in
/// `MainTabView`, so switching it visibly re-tints the tab bar and default controls.
enum AppAccent: String, CaseIterable, Identifiable {
    case classic
    case blue
    case purple
    case green
    case crimson

    var id: String { rawValue }

    static let storageKey = "appAccentTheme"

    var displayName: String {
        switch self {
        case .classic: "Classic"
        case .blue: "Ocean"
        case .purple: "Grape"
        case .green: "Pitch"
        case .crimson: "Crimson"
        }
    }

    var isFree: Bool { self == .classic }

    var color: Color {
        switch self {
        case .classic: BrowseTheme.accent
        case .blue: Color(red: 0.20, green: 0.55, blue: 0.95)
        case .purple: Color(red: 0.55, green: 0.38, blue: 0.98)
        case .green: Color(red: 0.20, green: 0.70, blue: 0.45)
        case .crimson: Color(red: 0.90, green: 0.24, blue: 0.32)
        }
    }

    static func from(_ raw: String) -> AppAccent {
        AppAccent(rawValue: raw) ?? .classic
    }
}
