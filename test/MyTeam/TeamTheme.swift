import SwiftUI
import UIKit

/// Design tokens for the **My Team** tab.
///
/// Ported from the legacy dark-only `Theme`, but every color is now an
/// *adaptive* dynamic color whose light/dark values are aligned to the app's
/// `AppPalette`. This lets the migrated screens follow the FTMP appearance
/// setting (light / dark) without threading `@Environment(\.appPalette)`
/// through every small subview.
enum TeamTheme {

    /// Builds a dynamic `Color` that resolves per `UITraitCollection`.
    private static func dyn(light: UIColor, dark: UIColor) -> Color {
        Color(uiColor: UIColor { $0.userInterfaceStyle == .dark ? dark : light })
    }

    // Backgrounds
    static let bg        = dyn(light: UIColor(red: 0.96, green: 0.95, blue: 0.99, alpha: 1),
                              dark:  UIColor(red: 0.06, green: 0.07, blue: 0.11, alpha: 1))
    static let cardBg    = dyn(light: UIColor(white: 1.0, alpha: 1),
                              dark:  UIColor(red: 0.10, green: 0.11, blue: 0.16, alpha: 1))
    static let cardBgAlt = dyn(light: UIColor(red: 0.93, green: 0.94, blue: 0.97, alpha: 1),
                              dark:  UIColor(red: 0.12, green: 0.13, blue: 0.19, alpha: 1))
    static let surface   = dyn(light: UIColor(white: 0.0, alpha: 0.04),
                              dark:  UIColor(white: 1.0, alpha: 0.05))

    // Text
    static let textPrimary   = dyn(light: UIColor(red: 0.07, green: 0.09, blue: 0.13, alpha: 1),
                                  dark:  UIColor.white)
    static let textSecondary = dyn(light: UIColor(red: 0.30, green: 0.33, blue: 0.39, alpha: 1),
                                  dark:  UIColor(white: 1.0, alpha: 0.55))
    static let textTertiary  = dyn(light: UIColor(red: 0.50, green: 0.53, blue: 0.59, alpha: 1),
                                  dark:  UIColor(white: 1.0, alpha: 0.35))

    // Accents (kept semantic across both schemes; slightly deepened in light for contrast)
    static let blue   = dyn(light: UIColor(red: 0.20, green: 0.45, blue: 0.95, alpha: 1),
                           dark:  UIColor(red: 0.30, green: 0.55, blue: 1.00, alpha: 1))
    static let purple = dyn(light: UIColor(red: 0.48, green: 0.32, blue: 0.92, alpha: 1),
                           dark:  UIColor(red: 0.60, green: 0.40, blue: 1.00, alpha: 1))
    static let orange = Color.orange   // matches BrowseTheme.accent
    static let green  = dyn(light: UIColor(red: 0.18, green: 0.68, blue: 0.38, alpha: 1),
                           dark:  UIColor(red: 0.30, green: 0.85, blue: 0.50, alpha: 1))
    static let red    = dyn(light: UIColor(red: 0.88, green: 0.24, blue: 0.24, alpha: 1),
                           dark:  UIColor(red: 1.00, green: 0.35, blue: 0.35, alpha: 1))
    static let gold   = Color(red: 0.90, green: 0.70, blue: 0.0)
    static let silver = Color(red: 0.62, green: 0.62, blue: 0.66)
    static let bronze = Color(red: 0.72, green: 0.45, blue: 0.20)

    // Gradients
    static let headerGradient = LinearGradient(
        colors: [blue.opacity(0.18), purple.opacity(0.10)],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )
    static let blueGradient = LinearGradient(
        colors: [blue, purple], startPoint: .leading, endPoint: .trailing
    )
    static let cardBorder = dyn(light: UIColor(white: 0.0, alpha: 0.07),
                               dark:  UIColor(white: 1.0, alpha: 0.08))
}
