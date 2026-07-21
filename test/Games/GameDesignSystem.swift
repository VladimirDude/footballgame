import SwiftUI

// MARK: - Design Tokens (spacing & shared semantics)

enum GameDesign {
    static let spacingXS: CGFloat = 6
    static let spacingSM: CGFloat = 10
    static let spacingMD: CGFloat = 14
    static let spacingLG: CGFloat = 18
    static let spacingXL: CGFloat = 24

    static let radiusSM: CGFloat = 10
    static let radiusMD: CGFloat = 14
    static let radiusLG: CGFloat = 18
    static let radiusXL: CGFloat = 22

    static let success = Color(red: 0.33, green: 0.67, blue: 0.39)
    static let danger = Color(red: 0.95, green: 0.3, blue: 0.28)
}

// MARK: - Screen Chrome

struct GameScreenToolbar: View {
    @Environment(\.gameTheme) private var theme

    let title: String
    let icon: String
    var newGameTitle: String = "New"
    let onNewGame: () -> Void

    var body: some View {
        HStack(spacing: GameDesign.spacingSM) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(theme.gold)
                Text(title)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(theme.textPrimary)
            }

            Spacer(minLength: 0)

            Button(action: onNewGame) {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.clockwise")
                        .font(.caption.weight(.bold))
                    Text(newGameTitle)
                        .font(.caption.weight(.bold))
                }
                .foregroundStyle(theme.textPrimary)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(
                    Capsule()
                        .fill(theme.surfaceFill)
                        .overlay(Capsule().stroke(theme.panelStroke, lineWidth: 1))
                )
            }
            .buttonStyle(GamePressButtonStyle())
        }
    }
}

struct GameInstructionPill: View {
    @Environment(\.gameTheme) private var theme

    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption2.weight(.bold))
                .foregroundStyle(theme.gold)
            Text(text)
                .font(.caption.weight(.semibold))
                .foregroundStyle(theme.textSecondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(
            Capsule()
                .fill(theme.panelFill)
                .overlay(Capsule().stroke(theme.panelStroke, lineWidth: 1))
        )
    }
}

// MARK: - Stats Bar

struct GameStatsBar: View {
    @Environment(\.gameTheme) private var theme

    let streak: Int
    let bestStreak: Int
    var timeRemaining: Int?
    var totalTime: Int = 10
    var showProgressBar: Bool = false

    private var progress: CGFloat {
        guard let timeRemaining else { return 0 }
        return CGFloat(timeRemaining) / CGFloat(totalTime)
    }

    private var urgencyTint: Color {
        guard let timeRemaining else { return theme.textMuted }
        if timeRemaining <= 3 { return GameDesign.danger }
        if timeRemaining <= 6 { return theme.amber }
        return GameDesign.success
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                statBlock(icon: "flame.fill", value: "\(streak)", label: "Streak", tint: theme.amber)
                divider
                statBlock(icon: "trophy.fill", value: "\(bestStreak)", label: "Best", tint: theme.gold)
                Spacer(minLength: 10)

                if let timeRemaining {
                    GameCountdownRing(timeRemaining: timeRemaining, total: totalTime, tint: urgencyTint)
                }
            }
            .padding(.horizontal, GameDesign.spacingMD)
            .padding(.vertical, 10)

            if showProgressBar, timeRemaining != nil {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(theme.surfaceFill)
                        Capsule()
                            .fill(urgencyTint)
                            .frame(width: max(8, geo.size.width * progress))
                    }
                }
                .frame(height: 3)
                .padding(.horizontal, GameDesign.spacingMD)
                .padding(.bottom, 10)
            }
        }
        .gameThemedPanel()
    }

    private var divider: some View {
        Rectangle()
            .fill(theme.panelStroke)
            .frame(width: 1, height: 32)
            .padding(.horizontal, 12)
    }

    private func statBlock(icon: String, value: String, label: String, tint: Color) -> some View {
        HStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(tint.opacity(0.18))
                    .frame(width: 30, height: 30)
                Image(systemName: icon)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(tint)
            }

            VStack(alignment: .leading, spacing: 1) {
                Text(value)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(theme.textPrimary)
                    .contentTransition(.numericText())
                Text(label)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(theme.textMuted)
            }
        }
    }
}

// MARK: - Segmented Control

struct GameSegmentedControl<Item: Hashable & Identifiable>: View {
    @Environment(\.gameTheme) private var theme

    let items: [Item]
    @Binding var selection: Item
    let title: (Item) -> String

    var body: some View {
        HStack(spacing: 4) {
            ForEach(items) { item in
                Button {
                    withAnimation(GameMotion.silkyQuick) { selection = item }
                } label: {
                    Text(title(item))
                        .font(.caption.weight(.bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .foregroundStyle(selection == item ? theme.textPrimary : theme.textMuted)
                        .background(
                            RoundedRectangle(cornerRadius: GameDesign.radiusSM, style: .continuous)
                                .fill(selection == item ? theme.accent : Color.clear)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .gameThemedPanel(cornerRadius: GameDesign.radiusMD)
    }
}

// MARK: - Input & Buttons

struct GameInputField: View {
    @Environment(\.gameTheme) private var theme

    let placeholder: String
    @Binding var text: String
    var icon: String = "magnifyingglass"
    var onSubmit: () -> Void = {}
    var isDisabled: Bool = false

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.body.weight(.semibold))
                .foregroundStyle(theme.textMuted)

            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .font(.body.weight(.medium))
                .foregroundStyle(theme.textPrimary)
                .tint(theme.gold)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.words)
                .onSubmit(onSubmit)
                .disabled(isDisabled)
        }
        .padding(.horizontal, GameDesign.spacingMD)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: GameDesign.radiusMD, style: .continuous)
                .fill(theme.panelFill)
                .overlay(
                    RoundedRectangle(cornerRadius: GameDesign.radiusMD, style: .continuous)
                        .stroke(theme.panelStroke, lineWidth: 1)
                )
        )
    }
}

struct GamePrimaryButton: View {
    @Environment(\.gameTheme) private var theme

    let title: String
    var icon: String? = "checkmark.circle.fill"
    let action: () -> Void
    var isEnabled: Bool = true

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let icon {
                    Image(systemName: icon)
                }
                Text(title)
                    .font(.subheadline.weight(.bold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 13)
            .foregroundStyle(isEnabled ? theme.buttonLabelOnLight : theme.textMuted)
            .background(
                RoundedRectangle(cornerRadius: GameDesign.radiusMD, style: .continuous)
                    .fill(isEnabled ? Color.white : theme.surfaceFill)
            )
        }
        .buttonStyle(GamePressButtonStyle())
        .disabled(!isEnabled)
    }
}

struct GameContinueButton: View {
    @Environment(\.gameTheme) private var theme

    let won: Bool
    let winTitle: String
    let loseTitle: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: won ? "arrow.right.circle.fill" : "arrow.counterclockwise.circle.fill")
                Text(won ? winTitle : loseTitle)
                    .font(.subheadline.weight(.bold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 13)
            .foregroundStyle(won ? theme.buttonLabelOnLight : theme.textPrimary)
            .background(
                RoundedRectangle(cornerRadius: GameDesign.radiusMD, style: .continuous)
                    .fill(won
                          ? AnyShapeStyle(Color.white)
                          : AnyShapeStyle(LinearGradient(
                              colors: [GameDesign.danger, Color(red: 0.78, green: 0.18, blue: 0.2)],
                              startPoint: .topLeading,
                              endPoint: .bottomTrailing
                          )))
            )
        }
        .buttonStyle(GamePressButtonStyle())
    }
}

struct GameHintButton: View {
    @Environment(\.gameTheme) private var theme

    let title: String
    let usedTitle: String
    let isUsed: Bool
    let isEnabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: isUsed ? "lightbulb.slash.fill" : "lightbulb.max.fill")
                    .foregroundStyle(isEnabled ? theme.gold : theme.textMuted)
                Text(isUsed ? usedTitle : title)
                    .font(.subheadline.weight(.semibold))
                Spacer()
                if isEnabled, !isUsed {
                    Image(systemName: "chevron.right")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(theme.textMuted)
                }
            }
            .foregroundStyle(isEnabled ? theme.textPrimary : theme.textMuted)
            .padding(.horizontal, GameDesign.spacingMD)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: GameDesign.radiusMD, style: .continuous)
                    .fill(isEnabled ? theme.surfaceFill : theme.panelFill)
                    .overlay(
                        RoundedRectangle(cornerRadius: GameDesign.radiusMD, style: .continuous)
                            .stroke(isEnabled ? theme.gold.opacity(0.35) : Color.clear, lineWidth: 1)
                    )
            )
        }
        .buttonStyle(GamePressButtonStyle())
        .disabled(!isEnabled)
    }
}

// MARK: - Formation Board

struct GameFormationBoard<Content: View>: View {
    @Environment(\.gameTheme) private var theme

    let entranceToken: String
  @ViewBuilder let content: Content

    var body: some View {
        content
            .padding(GameDesign.spacingLG)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: GameDesign.radiusLG, style: .continuous)
                    .fill(theme.formationFill)
                    .overlay(
                        RoundedRectangle(cornerRadius: GameDesign.radiusLG, style: .continuous)
                            .stroke(theme.panelStroke, lineWidth: 1)
                    )
            )
            .gameFormationEntrance(token: entranceToken)
    }
}

// MARK: - Hint Chip

struct GameHintChip: View {
    @Environment(\.gameTheme) private var theme

    let title: String
    let displayValue: String
    var symbol: String?
    var emoji: String?
    let tint: Color
    var progress: CGFloat = 1

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .fill(tint.opacity(0.2))
                    .frame(width: 34, height: 34)

                if let emoji {
                    Text(emoji).font(.body)
                } else if let symbol {
                    Image(systemName: symbol)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(tint)
                }
            }

            VStack(spacing: 2) {
                Text(title.uppercased())
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(theme.textMuted)
                    .tracking(0.4)

                Text(displayValue)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(theme.textPrimary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.75)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .padding(.horizontal, 4)
        .background(
            RoundedRectangle(cornerRadius: GameDesign.radiusMD, style: .continuous)
                .fill(theme.surfaceFill)
                .overlay(
                    RoundedRectangle(cornerRadius: GameDesign.radiusMD, style: .continuous)
                        .stroke(theme.panelStroke, lineWidth: 1)
                )
        )
        .silkyProgress(progress, lift: 3, scaleFrom: 0.99)
    }
}

// MARK: - Guess Panel

struct GameGuessPanel: View {
    @Environment(\.gameTheme) private var theme

    @Binding var guess: String
    let placeholder: String
    var inputIcon: String = "text.magnifyingglass"
    let gameResult: GameResult?
    let onSubmit: () -> Void
    let onContinue: () -> Void
    var winContinueTitle: String = "Next Round"
    var loseContinueTitle: String = "Try Again"

    var body: some View {
        VStack(spacing: GameDesign.spacingSM) {
            GameInputField(
                placeholder: placeholder,
                text: $guess,
                icon: inputIcon,
                onSubmit: onSubmit,
                isDisabled: gameResult != nil
            )

            if gameResult == nil {
                GamePrimaryButton(title: "Submit Guess", action: onSubmit)
                    .transition(.gamePresent)
            } else {
                GameContinueButton(
                    won: gameResult == .won,
                    winTitle: winContinueTitle,
                    loseTitle: loseContinueTitle,
                    action: onContinue
                )
                .transition(.gamePresent)
            }
        }
        .padding(GameDesign.spacingMD)
        .gameThemedPanel(cornerRadius: GameDesign.radiusXL)
        .animation(GameMotion.dissolve, value: gameResult == nil)
    }
}

// MARK: - Glass Card

struct GameGlassCard<Content: View>: View {
    var cornerRadius: CGFloat = GameDesign.radiusXL
  @ViewBuilder let content: Content

    var body: some View {
        content
            .gameThemedPanel(cornerRadius: cornerRadius)
    }
}
