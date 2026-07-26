import SwiftUI
import UIKit

/// The single source of truth for color in FTMP.
///
/// Every token is an **adaptive dynamic color** (resolves per light/dark trait
/// via `UITraitCollection`) so any view can use it directly — no
/// `@Environment` threading. This replaces the previously-fragmented set of
/// palettes (`AppPalette`, `BrowseTheme`, `TeamTheme`, `GameModeTheme`,
/// `PredictorStyle`/`SimulateStyle`/`DetailStyle`, `HLStyle`, `WordlePalette`),
/// which defined 15+ accents, 6 greens, 5 reds, etc. Those facades now alias
/// these roles (see Phase 3), collapsing the duplication.
enum DSColor {

    /// Adaptive color from explicit light/dark `UIColor`s.
    static func dyn(light: UIColor, dark: UIColor) -> Color {
        Color(uiColor: UIColor { $0.userInterfaceStyle == .dark ? dark : light })
    }

    private static func rgb(_ r: Double, _ g: Double, _ b: Double, _ a: Double = 1) -> UIColor {
        UIColor(red: r, green: g, blue: b, alpha: a)
    }

    // MARK: - Surfaces (layered depth)

    /// App backdrop — the lowest layer.
    static let background = dyn(light: rgb(0.95, 0.96, 0.98), dark: rgb(0.05, 0.06, 0.08))
    /// Grouped list / scroll background (one step down from cards).
    static let groupedBackground = dyn(light: rgb(0.92, 0.93, 0.96), dark: rgb(0.03, 0.04, 0.06))
    /// Card / panel surface. White in light (with real elevation) → premium.
    static let surface = dyn(light: rgb(1.0, 1.0, 1.0), dark: rgb(0.11, 0.12, 0.15))
    /// Raised surface for sheets / popovers / highlighted rows.
    static let surfaceElevated = dyn(light: rgb(1.0, 1.0, 1.0), dark: rgb(0.15, 0.16, 0.20))
    /// A subtly filled inset (search fields, inputs, secondary chips).
    static let fill = dyn(light: rgb(0.0, 0.0, 0.0, 0.04), dark: rgb(1.0, 1.0, 1.0, 0.06))
    /// Hairline separators / borders.
    static let separator = dyn(light: rgb(0.0, 0.0, 0.0, 0.08), dark: rgb(1.0, 1.0, 1.0, 0.12))

    // MARK: - Text

    static let textPrimary = dyn(light: rgb(0.07, 0.09, 0.13), dark: rgb(1.0, 1.0, 1.0))
    static let textSecondary = dyn(light: rgb(0.34, 0.37, 0.43), dark: rgb(1.0, 1.0, 1.0, 0.72))
    static let textTertiary = dyn(light: rgb(0.55, 0.58, 0.64), dark: rgb(1.0, 1.0, 1.0, 0.45))

    // MARK: - Accent (unified, user-selectable)

    /// The one brand/accent color, driven by the user's `AppAccent` choice so the
    /// whole app (tab bar, buttons, chips, checks) finally agrees. Reading the
    /// stored value keeps it in sync with the Settings picker.
    static var accent: Color {
        let raw = UserDefaults.standard.string(forKey: AppAccent.storageKey) ?? AppAccent.classic.rawValue
        return AppAccent.from(raw).color
    }
    /// Foreground for content sitting on top of the accent fill.
    static let onAccent = Color.white
    /// Soft accent tint for glows / selected backgrounds.
    static var accentSoft: Color { accent.opacity(0.14) }

    // MARK: - Semantic

    static let success = dyn(light: rgb(0.16, 0.66, 0.40), dark: rgb(0.24, 0.78, 0.48))
    static let warning = dyn(light: rgb(0.90, 0.58, 0.10), dark: rgb(1.0, 0.68, 0.22))
    static let danger  = dyn(light: rgb(0.86, 0.22, 0.26), dark: rgb(1.0, 0.36, 0.38))

    // Podium (unique, kept from TeamTheme)
    static let gold   = dyn(light: rgb(0.82, 0.58, 0.08), dark: rgb(1.0, 0.82, 0.35))
    static let silver = dyn(light: rgb(0.55, 0.57, 0.62), dark: rgb(0.78, 0.80, 0.85))
    static let bronze = dyn(light: rgb(0.62, 0.42, 0.24), dark: rgb(0.85, 0.60, 0.36))
}
