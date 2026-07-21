import SwiftUI

/// Silky motion — kept light; HL and timer UIs avoid heavy modifiers.
enum GameMotion {
    static var silky: Animation { .smooth(duration: 0.35) }
    static var silkyQuick: Animation { .smooth(duration: 0.2) }
    static var silkySlow: Animation { .smooth(duration: 0.45) }
    static var dissolve: Animation { .easeInOut(duration: 0.25) }

    static func adaptive(_ animation: Animation, reduceMotion: Bool) -> Animation {
        reduceMotion ? .easeOut(duration: 0.12) : animation
    }
}

// MARK: - Animatable modifiers

private struct SilkyProgressModifier: ViewModifier, Animatable {
    var progress: CGFloat
    let lift: CGFloat
    let scaleFrom: CGFloat

    init(progress: CGFloat, lift: CGFloat = 8, scaleFrom: CGFloat = 0.988) {
        self.progress = progress
        self.lift = lift
        self.scaleFrom = scaleFrom
    }

    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    func body(content: Content) -> some View {
        content
            .opacity(Double(progress))
            .offset(y: (1 - progress) * lift)
            .scaleEffect(scaleFrom + (1 - scaleFrom) * progress)
    }
}

extension View {
    func silkyProgress(_ progress: CGFloat, lift: CGFloat = 8, scaleFrom: CGFloat = 0.988) -> some View {
        modifier(SilkyProgressModifier(progress: progress, lift: lift, scaleFrom: scaleFrom))
    }
}

extension AnyTransition {
    static var gamePresent: AnyTransition {
        .opacity.combined(with: .scale(scale: 0.98))
    }

    static var gameDismiss: AnyTransition {
        .opacity
    }
}

// MARK: - Effects

struct GameShakeEffect: GeometryEffect {
    var amount: CGFloat = 5
    var shakes: CGFloat = 2
    var animatableData: CGFloat

    func effectValue(size: CGSize) -> ProjectionTransform {
        let decay = 1 - animatableData
        return ProjectionTransform(
            CGAffineTransform(
                translationX: amount * decay * sin(animatableData * .pi * shakes),
                y: 0
            )
        )
    }
}

struct GamePressButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.88 : 1)
    }
}

struct GameShakeModifier: ViewModifier {
    let trigger: Bool

    @State private var phase: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .modifier(GameShakeEffect(amount: 6, shakes: 2.5, animatableData: phase))
            .onChange(of: trigger) { _, active in
                guard active else { return }
                phase = 0
                withAnimation(.smooth(duration: 0.32)) { phase = 1 }
            }
    }
}

struct GameSilkyAppearModifier: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var visible = false

    func body(content: Content) -> some View {
        content
            .opacity(visible ? 1 : 0)
            .onAppear {
                guard !visible else { return }
                if reduceMotion {
                    visible = true
                } else {
                    withAnimation(GameMotion.dissolve) { visible = true }
                }
            }
    }
}

struct GameFormationEntranceModifier: ViewModifier {
    let token: String
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var visible = false

    func body(content: Content) -> some View {
        content
            .opacity(visible ? 1 : 0)
            .onAppear { animateIn() }
            .onChange(of: token) { _, _ in animateIn() }
    }

    private func animateIn() {
        visible = false
        if reduceMotion {
            visible = true
        } else {
            withAnimation(GameMotion.dissolve) { visible = true }
        }
    }
}

struct GameAnimatedResultBanner: View {
    let isSuccess: Bool
    let title: String
    var icon: String?

    private var resolvedIcon: String {
        icon ?? (isSuccess ? "checkmark.seal.fill" : "xmark.seal.fill")
    }

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: resolvedIcon)
            Text(title)
                .font(.subheadline.weight(.bold))
                .multilineTextAlignment(.leading)
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(isSuccess ? Color.green.opacity(0.88) : Color.red.opacity(0.88))
        )
    }
}

extension View {
    func gameShake(trigger: Bool) -> some View {
        modifier(GameShakeModifier(trigger: trigger))
    }

    func gameSilkyAppear() -> some View {
        modifier(GameSilkyAppearModifier())
    }

    func gameFormationEntrance(token: String) -> some View {
        modifier(GameFormationEntranceModifier(token: token))
    }
}

typealias GPShakeEffect = GameShakeEffect
typealias HLShakeEffect = GameShakeEffect

extension GameMotion {
    static var present: Animation { silky }
    static var quick: Animation { silkyQuick }
    static var fade: Animation { dissolve }
}
