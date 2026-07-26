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

    // Backgrounds — now aliased to the unified DesignSystem tokens (retires the
    // flat pure-white card surface for the layered DS surfaces + elevation).
    static var bg: Color        { DSColor.background }
    static var cardBg: Color    { DSColor.surface }
    static var cardBgAlt: Color { DSColor.groupedBackground }
    static var surface: Color   { DSColor.fill }

    // Text
    static var textPrimary: Color   { DSColor.textPrimary }
    static var textSecondary: Color { DSColor.textSecondary }
    static var textTertiary: Color  { DSColor.textTertiary }

    // Section accents kept (My Team's colorful identity), semantics aliased to DS.
    static let blue   = dyn(light: UIColor(red: 0.20, green: 0.45, blue: 0.95, alpha: 1),
                           dark:  UIColor(red: 0.30, green: 0.55, blue: 1.00, alpha: 1))
    static let purple = dyn(light: UIColor(red: 0.48, green: 0.32, blue: 0.92, alpha: 1),
                           dark:  UIColor(red: 0.60, green: 0.40, blue: 1.00, alpha: 1))
    static var orange: Color { DSColor.accent }
    static var green: Color  { DSColor.success }
    static var red: Color    { DSColor.danger }
    static var gold: Color   { DSColor.gold }
    static var silver: Color { DSColor.silver }
    static var bronze: Color { DSColor.bronze }

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
