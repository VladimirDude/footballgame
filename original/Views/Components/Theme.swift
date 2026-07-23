import SwiftUI

/// Centralized dark theme colors for Zeyro3DPreview.
enum Theme {
    // Backgrounds
    static let bg = Color(red: 0.06, green: 0.07, blue: 0.11)
    static let cardBg = Color(red: 0.10, green: 0.11, blue: 0.16)
    static let cardBgAlt = Color(red: 0.12, green: 0.13, blue: 0.19)
    static let surface = Color.white.opacity(0.05)

    // Text
    static let textPrimary = Color.white
    static let textSecondary = Color.white.opacity(0.55)
    static let textTertiary = Color.white.opacity(0.35)

    // Accents
    static let blue = Color(red: 0.30, green: 0.55, blue: 1.0)
    static let purple = Color(red: 0.60, green: 0.40, blue: 1.0)
    static let orange = Color(red: 1.0, green: 0.65, blue: 0.20)
    static let green = Color(red: 0.30, green: 0.85, blue: 0.50)
    static let red = Color(red: 1.0, green: 0.35, blue: 0.35)
    static let gold = Color(red: 1.0, green: 0.84, blue: 0.0)
    static let silver = Color(red: 0.78, green: 0.78, blue: 0.82)
    static let bronze = Color(red: 0.82, green: 0.52, blue: 0.22)

    // Gradients
    static let headerGradient = LinearGradient(
        colors: [blue.opacity(0.15), purple.opacity(0.08)],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )
    static let blueGradient = LinearGradient(
        colors: [blue, purple], startPoint: .leading, endPoint: .trailing
    )
    static let cardBorder = Color.white.opacity(0.08)
}
