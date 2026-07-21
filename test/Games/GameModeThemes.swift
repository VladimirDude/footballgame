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

    static func theme(for tab: GameTab, colorScheme: ColorScheme) -> GameModeTheme {
        let isDark = colorScheme == .dark
        switch tab {
        case .guessClub: return isDark ? .club : .clubLight
        case .guessNation: return isDark ? .nation : .nationLight
        case .guessPlayer: return isDark ? .player : .playerLight
        case .wordle: return isDark ? .wordle : .wordleLight
        case .higherLower: return isDark ? .higherLower : .higherLowerLight
        }
    }

    static func theme(for tab: GameTab) -> GameModeTheme {
        theme(for: tab, colorScheme: .dark)
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

    static let clubLight = GameModeTheme(
        id: "club",
        textPrimary: Color(red: 0.07, green: 0.11, blue: 0.09),
        textSecondary: Color(red: 0.2, green: 0.28, blue: 0.24),
        textMuted: Color(red: 0.36, green: 0.43, blue: 0.39),
        accent: BrowseTheme.accent,
        gold: Color(red: 0.82, green: 0.58, blue: 0.08),
        amber: Color(red: 0.92, green: 0.48, blue: 0.08),
        panelFill: Color.white.opacity(0.94),
        panelStroke: Color.black.opacity(0.07),
        surfaceFill: Color.black.opacity(0.04),
        formationFill: Color.white.opacity(0.42),
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

    static let nationLight = GameModeTheme(
        id: "nation",
        textPrimary: Color(red: 0.06, green: 0.12, blue: 0.11),
        textSecondary: Color(red: 0.18, green: 0.28, blue: 0.27),
        textMuted: Color(red: 0.34, green: 0.42, blue: 0.41),
        accent: Color(red: 0.08, green: 0.52, blue: 0.72),
        gold: Color(red: 0.82, green: 0.58, blue: 0.08),
        amber: Color(red: 0.92, green: 0.48, blue: 0.08),
        panelFill: Color.white.opacity(0.94),
        panelStroke: Color.black.opacity(0.07),
        surfaceFill: Color.black.opacity(0.04),
        formationFill: Color.white.opacity(0.42),
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

    static let playerLight = GameModeTheme(
        id: "player",
        textPrimary: Color(red: 0.07, green: 0.1, blue: 0.12),
        textSecondary: Color(red: 0.22, green: 0.27, blue: 0.32),
        textMuted: Color(red: 0.4, green: 0.44, blue: 0.48),
        accent: Color(red: 0.82, green: 0.58, blue: 0.08),
        gold: Color(red: 0.82, green: 0.58, blue: 0.08),
        amber: Color(red: 0.92, green: 0.48, blue: 0.08),
        panelFill: Color.white.opacity(0.94),
        panelStroke: Color.black.opacity(0.07),
        surfaceFill: Color.black.opacity(0.04),
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

    static let wordleLight = GameModeTheme(
        id: "wordle",
        textPrimary: Color(red: 0.08, green: 0.1, blue: 0.12),
        textSecondary: Color(red: 0.24, green: 0.28, blue: 0.32),
        textMuted: Color(red: 0.42, green: 0.45, blue: 0.48),
        accent: Color(red: 0.18, green: 0.52, blue: 0.28),
        gold: Color(red: 0.45, green: 0.5, blue: 0.56),
        amber: Color(red: 0.92, green: 0.48, blue: 0.08),
        panelFill: Color.white.opacity(0.94),
        panelStroke: Color.black.opacity(0.07),
        surfaceFill: Color.black.opacity(0.04),
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

    static let higherLowerLight = GameModeTheme(
        id: "higherLower",
        textPrimary: Color(red: 0.08, green: 0.1, blue: 0.14),
        textSecondary: Color(red: 0.24, green: 0.28, blue: 0.34),
        textMuted: Color(red: 0.42, green: 0.45, blue: 0.5),
        accent: Color(red: 0.92, green: 0.48, blue: 0.08),
        gold: Color(red: 0.82, green: 0.58, blue: 0.08),
        amber: Color(red: 0.92, green: 0.48, blue: 0.08),
        panelFill: Color.white.opacity(0.94),
        panelStroke: Color.black.opacity(0.07),
        surfaceFill: Color.black.opacity(0.04),
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
    @Environment(\.colorScheme) private var colorScheme
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
        .animation(.easeInOut(duration: 0.25), value: colorScheme)
        .ignoresSafeArea()
    }
}

struct ClubPitchBackground: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Group {
            if colorScheme == .dark {
                BrowseTheme.pitchGradient
            } else {
                LinearGradient(
                    colors: [
                        Color(red: 0.78, green: 0.92, blue: 0.82),
                        Color(red: 0.58, green: 0.78, blue: 0.64),
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        }
    }
}

struct NationPitchBackground: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Group {
            if colorScheme == .dark {
                LinearGradient(
                    colors: [
                        Color(red: 0.08, green: 0.5, blue: 0.34),
                        Color(red: 0.04, green: 0.3, blue: 0.24),
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            } else {
                LinearGradient(
                    colors: [
                        Color(red: 0.72, green: 0.9, blue: 0.84),
                        Color(red: 0.52, green: 0.76, blue: 0.68),
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        }
    }
}

struct PlayerStudioBackground: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Group {
            if colorScheme == .dark {
                LinearGradient(
                    colors: [
                        Color(red: 0.05, green: 0.12, blue: 0.14),
                        Color(red: 0.02, green: 0.06, blue: 0.08),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            } else {
                LinearGradient(
                    colors: [
                        Color(red: 0.94, green: 0.96, blue: 0.98),
                        Color(red: 0.86, green: 0.9, blue: 0.94),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
        }
    }
}

struct WordleBoardBackground: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Group {
            if colorScheme == .dark {
                LinearGradient(
                    colors: [
                        Color(red: 0.11, green: 0.12, blue: 0.14),
                        Color(red: 0.07, green: 0.08, blue: 0.1),
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            } else {
                LinearGradient(
                    colors: [
                        Color(red: 0.95, green: 0.97, blue: 0.95),
                        Color(red: 0.88, green: 0.92, blue: 0.89),
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        }
    }
}

struct HLStageBackground: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            Group {
                if colorScheme == .dark {
                    LinearGradient(
                        colors: [
                            Color(red: 0.07, green: 0.09, blue: 0.13),
                            Color(red: 0.12, green: 0.14, blue: 0.2),
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                } else {
                    LinearGradient(
                        colors: [
                            Color(red: 0.93, green: 0.95, blue: 0.98),
                            Color(red: 0.86, green: 0.89, blue: 0.94),
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                }
            }

            if colorScheme == .dark {
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
