import SwiftUI

// MARK: - Models

enum HLRevealState: Equatable {
    case hidden
    case correct
    case wrong
}

// MARK: - Tokens

private enum HLStyle {
    static let surface = Color.white.opacity(0.08)
    static let surfaceStroke = Color.white.opacity(0.14)
    static let surfaceGlow = Color(red: 0.45, green: 0.55, blue: 0.75).opacity(0.15)
    static let divider = Color.white.opacity(0.12)
    static let higher = Color(red: 0.95, green: 0.5, blue: 0.08)
    static let lower = Color(red: 0.34, green: 0.54, blue: 0.9)
    static let gold = Color(red: 1.0, green: 0.84, blue: 0.38)
    static let muted = Color.white.opacity(0.45)
}

private enum HLMotion {
    static let enter = Animation.smooth(duration: 0.38)
    static let reveal = Animation.smooth(duration: 0.32)
    static let press = Animation.smooth(duration: 0.18)
    static let swap = Animation.smooth(duration: 0.34)

    static func adaptive(_ a: Animation, reduceMotion: Bool) -> Animation {
        reduceMotion ? .easeOut(duration: 0.12) : a
    }
}

// MARK: - Animatable modifiers

private struct HLSlideModifier: ViewModifier, Animatable {
    var progress: CGFloat

    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    func body(content: Content) -> some View {
        content
            .offset(x: (1 - progress) * 28)
            .opacity(Double(progress))
            .scaleEffect(0.94 + 0.06 * progress)
    }
}

private struct HLPopModifier: ViewModifier, Animatable {
    var progress: CGFloat

    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    func body(content: Content) -> some View {
        content
            .scaleEffect(0.9 + 0.1 * progress)
            .opacity(Double(progress))
    }
}

private struct HLPulseModifier: ViewModifier, Animatable {
    var progress: CGFloat

    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    func body(content: Content) -> some View {
        content
            .scaleEffect(1 + 0.035 * sin(progress * .pi))
    }
}

private extension AnyTransition {
    static var hlControlsSwap: AnyTransition {
        .asymmetric(
            insertion: .opacity.combined(with: .scale(scale: 0.96)),
            removal: .opacity
        )
    }

    static var hlFeedback: AnyTransition {
        .move(edge: .bottom).combined(with: .opacity)
    }
}

// MARK: - Screen

struct HigherOrLowerGameView: View {
    let streak: Int
    let bestStreak: Int
    let timeRemaining: Int?
    let left: HLPlayer?
    let right: HLPlayer?
    let revealState: HLRevealState
    let shakeTrigger: Bool
    let showRightValue: Bool
    let isGameOver: Bool
    let lastGuessCorrect: Bool?
    let onHigher: () -> Void
    let onLower: () -> Void
    let onContinue: () -> Void

    var body: some View {
        GeometryReader { geo in
            let arenaHeight = min(max(geo.size.height * 0.52, 260), 360)

            VStack(spacing: 16) {
                HLScoreBar(score: streak, best: bestStreak, timeRemaining: timeRemaining, total: 5)

                if let left, let right {
                    HLCompareBoard(
                        anchor: left,
                        challenger: right,
                        revealState: revealState,
                        shakeTrigger: shakeTrigger,
                        portraitSize: min(104, arenaHeight * 0.34)
                    )
                    .equatable()
                    .frame(height: arenaHeight)
                    .frame(maxWidth: .infinity)

                    HLControls(
                        showResult: showRightValue,
                        isCorrect: lastGuessCorrect,
                        isGameOver: isGameOver,
                        onHigher: onHigher,
                        onLower: onLower,
                        onContinue: onContinue
                    )
                } else {
                    Spacer()
                    ProgressView().tint(HLStyle.gold)
                    Spacer()
                }
            }
            .frame(width: geo.size.width, height: geo.size.height, alignment: .top)
        }
    }
}

// MARK: - Score bar

private struct HLScoreBar: View {
    let score: Int
    let best: Int
    let timeRemaining: Int?
    let total: Int

    @Environment(\.gameTheme) private var theme

    var body: some View {
        HStack(spacing: 0) {
            scoreCell(icon: "flame.fill", value: "\(score)", label: "Score", tint: HLStyle.higher)
            scoreCell(icon: "trophy.fill", value: "\(best)", label: "Best", tint: HLStyle.gold)
            Spacer(minLength: 12)
            if let timeRemaining {
                HLTimerBadge(remaining: timeRemaining, total: total)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(theme.surfaceFill)
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(theme.panelStroke, lineWidth: 1)
                )
        )
    }

    private func scoreCell(icon: String, value: String, label: String, tint: Color) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.body.weight(.semibold))
                .foregroundStyle(tint)
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 1) {
                Text(value)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(theme.textPrimary)
                    .contentTransition(.numericText())
                    .animation(HLMotion.reveal, value: value)
                Text(label)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(theme.textMuted)
            }
        }
        .padding(.trailing, 20)
    }
}

private struct HLTimerBadge: View, Equatable {
    let remaining: Int
    let total: Int

    @Environment(\.gameTheme) private var theme

    static func == (lhs: HLTimerBadge, rhs: HLTimerBadge) -> Bool {
        lhs.remaining == rhs.remaining && lhs.total == rhs.total
    }

    private var urgent: Bool { remaining <= 2 }
    private var progress: CGFloat { CGFloat(remaining) / CGFloat(total) }

    var body: some View {
        ZStack {
            Circle().stroke(theme.panelStroke, lineWidth: 3)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(urgent ? Color.red : HLStyle.higher, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.smooth(duration: 0.28), value: remaining)
            Text("\(remaining)")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(theme.textPrimary)
                .contentTransition(.numericText())
                .animation(nil, value: remaining)
        }
        .frame(width: 44, height: 44)
    }
}

// MARK: - Compare board

struct HLDuelStage: View, Equatable {
    let anchor: HLPlayer
    let challenger: HLPlayer
    let revealState: HLRevealState
    let shakeTrigger: Bool

    static func == (lhs: HLDuelStage, rhs: HLDuelStage) -> Bool {
        lhs.anchor == rhs.anchor
            && lhs.challenger == rhs.challenger
            && lhs.revealState == rhs.revealState
            && lhs.shakeTrigger == rhs.shakeTrigger
    }

    var body: some View {
        HLCompareBoard(
            anchor: anchor,
            challenger: challenger,
            revealState: revealState,
            shakeTrigger: shakeTrigger,
            portraitSize: 100
        )
        .frame(height: 300)
    }
}

private struct HLCompareBoard: View, Equatable {
    let anchor: HLPlayer
    let challenger: HLPlayer
    let revealState: HLRevealState
    let shakeTrigger: Bool
    let portraitSize: CGFloat

    @Environment(\.gameTheme) private var theme

    static func == (lhs: HLCompareBoard, rhs: HLCompareBoard) -> Bool {
        lhs.anchor == rhs.anchor
            && lhs.challenger == rhs.challenger
            && lhs.revealState == rhs.revealState
            && lhs.shakeTrigger == rhs.shakeTrigger
            && lhs.portraitSize == rhs.portraitSize
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [theme.surfaceFill, theme.panelFill.opacity(0.5)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(theme.panelStroke, lineWidth: 1)
                )
                .shadow(color: HLStyle.surfaceGlow, radius: 24, y: 8)

            // Ambient glow
            RadialGradient(
                colors: [HLStyle.gold.opacity(0.08), Color.clear],
                center: .center,
                startRadius: 10,
                endRadius: 200
            )
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))

            HStack(spacing: 0) {
                halfBackground(tint: HLStyle.higher.opacity(0.06))
                    .clipShape(UnevenRoundedRectangle(
                        topLeadingRadius: 22, bottomLeadingRadius: 22,
                        bottomTrailingRadius: 0, topTrailingRadius: 0, style: .continuous
                    ))

                halfBackground(tint: HLStyle.lower.opacity(0.06))
                    .clipShape(UnevenRoundedRectangle(
                        topLeadingRadius: 0, bottomLeadingRadius: 0,
                        bottomTrailingRadius: 22, topTrailingRadius: 22, style: .continuous
                    ))
            }

            HStack(spacing: 0) {
                HLPlayerPane(
                    player: anchor,
                    value: .shown(anchor.marketValue),
                    tag: "Known",
                    portraitSize: portraitSize
                )

                Rectangle()
                    .fill(theme.panelStroke.opacity(0.6))
                    .frame(width: 1)
                    .padding(.vertical, 24)

                HLChallengerPane(
                    player: challenger,
                    revealState: revealState,
                    shakeTrigger: shakeTrigger,
                    portraitSize: portraitSize
                )
            }
            .padding(.horizontal, 12)

            // VS badge
            HLVSBadge(challengerID: challenger.id)
        }
        .animation(HLMotion.reveal, value: revealState)
    }

    private func halfBackground(tint: Color) -> some View {
        Rectangle().fill(tint)
    }
}

private struct HLVSBadge: View {
    let challengerID: String

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pop: CGFloat = 1

    var body: some View {
        Text("VS")
            .font(.system(size: 10, weight: .black))
            .foregroundStyle(.white)
            .padding(.horizontal, 9)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(HLStyle.higher)
                    .shadow(color: HLStyle.higher.opacity(0.4), radius: 6, y: 2)
            )
            .overlay(Capsule().stroke(Color.white.opacity(0.25), lineWidth: 1))
            .modifier(HLPopModifier(progress: pop))
            .onAppear { bounce() }
            .onChange(of: challengerID) { _, _ in bounce() }
    }

    private func bounce() {
        pop = 0
        withAnimation(HLMotion.adaptive(HLMotion.enter, reduceMotion: reduceMotion)) {
            pop = 1
        }
    }
}

// MARK: - Player panes

private enum HLValueDisplay: Equatable {
    case shown(Int)
    case hidden
    case revealed(Int, HLRevealState)
}

private struct HLPlayerPane: View {
    let player: HLPlayer
    let value: HLValueDisplay
    var tag: String?
    let portraitSize: CGFloat

    @Environment(\.gameTheme) private var theme

    var body: some View {
        VStack(spacing: 0) {
            if let tag {
                Text(tag.uppercased())
                    .font(.system(size: 9, weight: .bold))
                    .tracking(0.8)
                    .foregroundStyle(theme.textMuted)
                    .padding(.bottom, 10)
            }

            Spacer(minLength: 0)

            PlayerPortraitImage(playerID: player.id, style: .hl)
                .scaleEffect(portraitSize / 76)
                .frame(width: portraitSize, height: portraitSize)

            Spacer(minLength: 8)

            HLValueLabel(display: value)

            Spacer(minLength: 10)

            VStack(spacing: 4) {
                Text(player.name)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(theme.textPrimary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)

                Text(player.clubName)
                    .font(.caption)
                    .foregroundStyle(theme.textMuted)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, 16)
    }
}

private struct HLChallengerPane: View {
    let player: HLPlayer
    let revealState: HLRevealState
    let shakeTrigger: Bool
    let portraitSize: CGFloat

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var enter: CGFloat = 1
    @State private var pulse: CGFloat = 0

    private var value: HLValueDisplay {
        switch revealState {
        case .hidden: .hidden
        case .correct: .revealed(player.marketValue, .correct)
        case .wrong: .revealed(player.marketValue, .wrong)
        }
    }

    var body: some View {
        HLPlayerPane(player: player, value: value, tag: "Guess", portraitSize: portraitSize)
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(outcomeColor, lineWidth: revealState == .hidden ? 0 : 2.5)
                    .padding(4)
            )
            .modifier(HLSlideModifier(progress: enter))
            .modifier(HLPulseModifier(progress: pulse))
            .gameShake(trigger: shakeTrigger)
            .onAppear { animateIn() }
            .onChange(of: player.id) { _, _ in animateIn() }
            .onChange(of: revealState) { _, state in
                guard state == .correct else { return }
                pulse = 0
                withAnimation(HLMotion.adaptive(HLMotion.reveal, reduceMotion: reduceMotion)) {
                    pulse = 1
                }
            }
    }

    private var outcomeColor: Color {
        switch revealState {
        case .correct: GameDesign.success
        case .wrong: GameDesign.danger
        case .hidden: .clear
        }
    }

    private func animateIn() {
        enter = 0
        withAnimation(HLMotion.adaptive(HLMotion.enter, reduceMotion: reduceMotion)) {
            enter = 1
        }
    }
}

private struct HLValueLabel: View {
    let display: HLValueDisplay

    @Environment(\.gameTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pop: CGFloat = 1

    var body: some View {
        Text(text)
            .font(.system(size: 24, weight: .heavy, design: .rounded))
            .foregroundStyle(color)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(Color.black.opacity(0.35))
                    .overlay(Capsule().stroke(color.opacity(0.35), lineWidth: 1))
            )
            .modifier(HLPopModifier(progress: pop))
            .onAppear { pop = 1 }
            .onChange(of: key) { _, _ in
                pop = 0
                withAnimation(HLMotion.adaptive(HLMotion.reveal, reduceMotion: reduceMotion)) {
                    pop = 1
                }
            }
    }

    private var text: String {
        switch display {
        case .shown(let v), .revealed(let v, _): MarketValueFormatter.format(v)
        case .hidden: "???"
        }
    }

    private var key: String {
        switch display {
        case .shown: "shown"
        case .hidden: "hidden"
        case .revealed(_, let o): "revealed-\(o)"
        }
    }

    private var color: Color {
        switch display {
        case .shown: HLStyle.gold
        case .hidden: theme.textMuted
        case .revealed(_, .correct): GameDesign.success
        case .revealed(_, .wrong): GameDesign.danger
        case .revealed: HLStyle.gold
        }
    }
}

// MARK: - Controls

private struct HLControls: View, Equatable {
    let showResult: Bool
    let isCorrect: Bool?
    let isGameOver: Bool
    let onHigher: () -> Void
    let onLower: () -> Void
    let onContinue: () -> Void

    @Environment(\.gameTheme) private var theme

    static func == (lhs: HLControls, rhs: HLControls) -> Bool {
        lhs.showResult == rhs.showResult
            && lhs.isCorrect == rhs.isCorrect
            && lhs.isGameOver == rhs.isGameOver
    }

    var body: some View {
        VStack(spacing: 12) {
            if showResult, let isCorrect {
                HLFeedbackChip(isCorrect: isCorrect)
                    .transition(.hlFeedback)
            }

            if showResult {
                HLContinueCTA(isGameOver: isGameOver, action: onContinue)
                    .transition(.hlControlsSwap)
            } else {
                HLSplitChoice(
                    isEnabled: !showResult,
                    onHigher: onHigher,
                    onLower: onLower
                )
                    .transition(.hlControlsSwap)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(theme.surfaceFill)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(theme.panelStroke, lineWidth: 1)
                )
        )
        .animation(HLMotion.swap, value: showResult)
    }
}

private struct HLSplitChoice: View, Equatable {
    var isEnabled: Bool = true
    let onHigher: () -> Void
    let onLower: () -> Void

    static func == (lhs: HLSplitChoice, rhs: HLSplitChoice) -> Bool {
        lhs.isEnabled == rhs.isEnabled
    }

    var body: some View {
        HStack(spacing: 10) {
            choiceButton(title: "Higher", icon: "arrow.up", color: HLStyle.higher, action: onHigher)
            choiceButton(title: "Lower", icon: "arrow.down", color: HLStyle.lower, action: onLower)
        }
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.55)
    }

    private func choiceButton(title: String, icon: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: "\(icon).circle.fill")
                    .font(.title2)
                Text(title)
                    .font(.headline.weight(.bold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .foregroundStyle(.white)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(color)
            )
        }
        .buttonStyle(HLPressStyle())
    }
}

private struct HLContinueCTA: View {
    let isGameOver: Bool
    let action: () -> Void

    @Environment(\.gameTheme) private var theme

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: isGameOver ? "arrow.counterclockwise.circle.fill" : "arrow.right.circle.fill")
                Text(isGameOver ? "Play Again" : "Next Round")
                    .font(.headline.weight(.bold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .foregroundStyle(isGameOver ? .white : theme.buttonLabelOnLight)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(isGameOver
                          ? AnyShapeStyle(GameDesign.danger)
                          : AnyShapeStyle(Color.white))
            )
        }
        .buttonStyle(HLPressStyle())
    }
}

private struct HLFeedbackChip: View {
    let isCorrect: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appear: CGFloat = 0

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: isCorrect ? "checkmark.circle.fill" : "xmark.circle.fill")
            Text(isCorrect ? "Correct — keep going!" : "Wrong — game over")
                .font(.subheadline.weight(.semibold))
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(isCorrect ? GameDesign.success : GameDesign.danger)
        )
        .modifier(HLPopModifier(progress: appear))
        .onAppear {
            appear = 0
            withAnimation(HLMotion.adaptive(HLMotion.reveal, reduceMotion: reduceMotion)) {
                appear = 1
            }
        }
    }
}

private struct HLPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .brightness(configuration.isPressed ? -0.04 : 0)
            .animation(HLMotion.press, value: configuration.isPressed)
    }
}
