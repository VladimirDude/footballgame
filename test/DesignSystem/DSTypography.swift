import SwiftUI

/// The semantic type ramp. Every role maps to a built-in text style so text
/// **scales with Dynamic Type** — the fix for the 115 hardcoded `.system(size:)`
/// fonts that ignored the user's text-size setting.
///
/// Usage: `.font(DSFont.headline)` or the sugar `.dsFont(.headline)`.
enum DSFont {
    static let largeTitle = Font.largeTitle.weight(.bold)
    static let title      = Font.title.weight(.bold)
    static let title2     = Font.title2.weight(.bold)
    static let title3     = Font.title3.weight(.semibold)
    static let headline   = Font.headline
    static let body       = Font.body
    static let callout    = Font.callout
    static let subheadline = Font.subheadline
    static let footnote   = Font.footnote
    static let caption    = Font.caption
    static let caption2   = Font.caption2

    /// Emphasized numeric/stat display (rounded, still Dynamic-Type-scaled).
    static let statValue  = Font.system(.title2, design: .rounded).weight(.bold)
    static let statLabel  = Font.caption.weight(.medium)
    /// Monospaced (codes, tabular figures).
    static let mono       = Font.system(.body, design: .monospaced).weight(.semibold)
}

enum DSTextRole {
    case largeTitle, title, title2, title3, headline, body, callout
    case subheadline, footnote, caption, caption2, statValue, statLabel, mono

    var font: Font {
        switch self {
        case .largeTitle: DSFont.largeTitle
        case .title: DSFont.title
        case .title2: DSFont.title2
        case .title3: DSFont.title3
        case .headline: DSFont.headline
        case .body: DSFont.body
        case .callout: DSFont.callout
        case .subheadline: DSFont.subheadline
        case .footnote: DSFont.footnote
        case .caption: DSFont.caption
        case .caption2: DSFont.caption2
        case .statValue: DSFont.statValue
        case .statLabel: DSFont.statLabel
        case .mono: DSFont.mono
        }
    }
}

extension View {
    func dsFont(_ role: DSTextRole) -> some View { font(role.font) }
}
