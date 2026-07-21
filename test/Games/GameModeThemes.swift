import SwiftUI

// MARK: - Per-mode visual theme (grass only on formation games)

struct GameModeTheme: Equatable {
    let id: String
    let textPrimary: Color
    let textSecondary: Color
    let textMuted: Color
    let accent: Color
    let gold: Color
    let amber: Color
    let panelFill: Color
    let panelStroke: Color
    let surfaceFill: Color
    let formationFill: Color
    let buttonLabelOnLight: Color

    static func theme(for tab: GameTab) -> GameModeTheme {
        switch tab {
        case .guessClub: .club
        case .guessNation: .nation
        case .guessPlayer: .player
        case .wordle: .wordle
        case .higherLower: .higherLower
        }
    }

    // Formation — warm pitch
    static let club = GameModeTheme(
        id: "club",
        textPrimary: .white,
        textSecondary: Color.white.opacity(0.78),
        textMuted: Color.white.opacity(0.5),
        accent: BrowseTheme.accent,
        gold: Color(red: 1.0, green: 0.82, blue: 0.35),
        amber: Color(red: 1.0, green: 0.62, blue: 0.18),
        panelFill: Color.black.opacity(0.26),
        panelStroke: Color.white.opacity(0.14),
        surfaceFill: Color.white.opacity(0.08),
        formationFill: Color.white.opacity(0.07),
        buttonLabelOnLight: BrowseTheme.pitchBottom
    )

    // Formation — cooler international pitch
    static let nation = GameModeTheme(
        id: "nation",
        textPrimary: .white,
        textSecondary: Color.white.opacity(0.78),
        textMuted: Color.white.opacity(0.5),
        accent: Color(red: 0.2, green: 0.72, blue: 0.95),
        gold: Color(red: 1.0, green: 0.82, blue: 0.35),
        amber: Color(red: 1.0, green: 0.62, blue: 0.18),
        panelFill: Color.black.opacity(0.26),
        panelStroke: Color.white.opacity(0.14),
        surfaceFill: Color.white.opacity(0.08),
        formationFill: Color.white.opacity(0.07),
        buttonLabelOnLight: Color(red: 0.04, green: 0.32, blue: 0.22)
    )

    // Spotlight studio — dark teal-black
    static let player = GameModeTheme(
        id: "player",
        textPrimary: .white,
        textSecondary: Color.white.opacity(0.74),
        textMuted: Color.white.opacity(0.46),
        accent: Color(red: 1.0, green: 0.82, blue: 0.35),
        gold: Color(red: 1.0, green: 0.82, blue: 0.35),
        amber: Color(red: 1.0, green: 0.62, blue: 0.18),
        panelFill: Color.white.opacity(0.07),
        panelStroke: Color.white.opacity(0.12),
        surfaceFill: Color.white.opacity(0.05),
        formationFill: Color.clear,
        buttonLabelOnLight: Color(red: 0.06, green: 0.14, blue: 0.16)
    )

    // Analytical board — dark gray
    static let wordle = GameModeTheme(
        id: "wordle",
        textPrimary: .white,
        textSecondary: Color.white.opacity(0.72),
        textMuted: Color.white.opacity(0.44),
        accent: Color(red: 0.33, green: 0.67, blue: 0.39),
        gold: Color(red: 0.85, green: 0.88, blue: 0.92),
        amber: Color(red: 1.0, green: 0.62, blue: 0.18),
        panelFill: Color.white.opacity(0.06),
        panelStroke: Color.white.opacity(0.1),
        surfaceFill: Color.white.opacity(0.04),
        formationFill: Color.clear,
        buttonLabelOnLight: Color(red: 0.08, green: 0.1, blue: 0.12)
    )

    // Trading stage — deep navy charcoal
    static let higherLower = GameModeTheme(
        id: "higherLower",
        textPrimary: .white,
        textSecondary: Color.white.opacity(0.72),
        textMuted: Color.white.opacity(0.44),
        accent: Color(red: 1.0, green: 0.62, blue: 0.18),
        gold: Color(red: 1.0, green: 0.82, blue: 0.35),
        amber: Color(red: 1.0, green: 0.62, blue: 0.18),
        panelFill: Color.white.opacity(0.08),
        panelStroke: Color.white.opacity(0.12),
        surfaceFill: Color.white.opacity(0.06),
        formationFill: Color.clear,
        buttonLabelOnLight: Color(red: 0.1, green: 0.12, blue: 0.16)
    )
}

// MARK: - Environment

private struct GameModeThemeKey: EnvironmentKey {
    static let defaultValue = GameModeTheme.club
}

extension EnvironmentValues {
    var gameTheme: GameModeTheme {
        get { self[GameModeThemeKey.self] }
        set { self[GameModeThemeKey.self] = newValue }
    }
}

// MARK: - Backgrounds

struct GameModeBackdrop: View {
    let tab: GameTab

    var body: some View {
        Group {
            switch tab {
            case .guessClub:
                ClubPitchBackground()
            case .guessNation:
                NationPitchBackground()
            case .guessPlayer:
                PlayerStudioBackground()
            case .wordle:
                WordleBoardBackground()
            case .higherLower:
                HLStageBackground()
            }
        }
        .ignoresSafeArea()
    }
}

struct ClubPitchBackground: View {
    var body: some View {
        BrowseTheme.pitchGradient
    }
}

struct NationPitchBackground: View {
    var body: some View {
        LinearGradient(
            colors: [
                Color(red: 0.08, green: 0.5, blue: 0.34),
                Color(red: 0.04, green: 0.3, blue: 0.24),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

struct PlayerStudioBackground: View {
    var body: some View {
        LinearGradient(
            colors: [
                Color(red: 0.05, green: 0.12, blue: 0.14),
                Color(red: 0.02, green: 0.06, blue: 0.08),
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}

struct WordleBoardBackground: View {
    var body: some View {
        LinearGradient(
            colors: [
                Color(red: 0.11, green: 0.12, blue: 0.14),
                Color(red: 0.07, green: 0.08, blue: 0.1),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

struct HLStageBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.07, green: 0.09, blue: 0.13),
                    Color(red: 0.12, green: 0.14, blue: 0.2),
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            RadialGradient(
                colors: [
                    Color(red: 0.2, green: 0.24, blue: 0.34).opacity(0.35),
                    Color.clear,
                ],
                center: .center,
                startRadius: 20,
                endRadius: 380
            )
        }
    }
}

// Legacy alias
typealias GamePitchBackground = ClubPitchBackground

// MARK: - Themed panel helper

struct GameThemedPanel: View {
    @Environment(\.gameTheme) private var theme
    var cornerRadius: CGFloat = GameDesign.radiusLG

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(theme.panelFill)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(theme.panelStroke, lineWidth: 1)
            )
    }
}

extension View {
    func gameThemedPanel(cornerRadius: CGFloat = GameDesign.radiusLG) -> some View {
        background(GameThemedPanel(cornerRadius: cornerRadius))
    }
}
