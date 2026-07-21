import SwiftUI

struct AppPalette: Equatable {
    let textPrimary: Color
    let textSecondary: Color
    let textMuted: Color
    let panelFill: Color
    let panelStroke: Color
    let surfaceFill: Color
    let chromeFill: Color
    let chromeStroke: Color
    let selectedTabFill: Color
    let backdropTop: Color
    let backdropBottom: Color
    let accentGlow: Color
    let buttonOnAccent: Color
    let toolbarTint: Color
    let groupedBackground: Color

    static func palette(for scheme: ColorScheme) -> AppPalette {
        scheme == .dark ? .dark : .light
    }

    static let light = AppPalette(
        textPrimary: Color(red: 0.07, green: 0.09, blue: 0.13),
        textSecondary: Color(red: 0.24, green: 0.27, blue: 0.33),
        textMuted: Color(red: 0.44, green: 0.47, blue: 0.53),
        panelFill: Color.white.opacity(0.96),
        panelStroke: Color.black.opacity(0.07),
        surfaceFill: Color.black.opacity(0.04),
        chromeFill: Color.black.opacity(0.06),
        chromeStroke: Color.black.opacity(0.08),
        selectedTabFill: Color.white.opacity(0.98),
        backdropTop: Color(red: 0.96, green: 0.95, blue: 0.99),
        backdropBottom: Color(red: 0.88, green: 0.92, blue: 0.97),
        accentGlow: Color(red: 0.55, green: 0.38, blue: 0.98).opacity(0.14),
        buttonOnAccent: Color(red: 0.07, green: 0.09, blue: 0.13),
        toolbarTint: Color(red: 0.07, green: 0.09, blue: 0.13),
        groupedBackground: Color(.systemGroupedBackground)
    )

    static let dark = AppPalette(
        textPrimary: .white,
        textSecondary: Color.white.opacity(0.78),
        textMuted: Color.white.opacity(0.45),
        panelFill: Color.white.opacity(0.08),
        panelStroke: Color.white.opacity(0.1),
        surfaceFill: Color.white.opacity(0.05),
        chromeFill: Color.black.opacity(0.35),
        chromeStroke: Color.white.opacity(0.1),
        selectedTabFill: Color.white.opacity(0.18),
        backdropTop: Color(red: 0.1, green: 0.06, blue: 0.22),
        backdropBottom: Color(red: 0.05, green: 0.08, blue: 0.16),
        accentGlow: Color(red: 0.55, green: 0.38, blue: 0.98).opacity(0.22),
        buttonOnAccent: Color(red: 0.08, green: 0.1, blue: 0.14),
        toolbarTint: .white,
        groupedBackground: Color(.systemGroupedBackground)
    )

    func panel(cornerRadius: CGFloat = 16) -> some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(panelFill)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(panelStroke, lineWidth: 1)
            )
    }
}

private struct AppPaletteKey: EnvironmentKey {
    static let defaultValue = AppPalette.light
}

extension EnvironmentValues {
    var appPalette: AppPalette {
        get { self[AppPaletteKey.self] }
        set { self[AppPaletteKey.self] = newValue }
    }
}

struct AppPaletteModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content.environment(\.appPalette, AppPalette.palette(for: colorScheme))
    }
}

extension View {
    func withAppPalette() -> some View {
        modifier(AppPaletteModifier())
    }
}
