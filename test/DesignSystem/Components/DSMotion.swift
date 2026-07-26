import SwiftUI

/// Shared, Reduce-Motion-aware animation. Lifts the pattern that previously
/// lived only in the Games layer so every module inherits it.
enum DSMotion {
    static let standard = Animation.smooth(duration: 0.3)
    static let quick = Animation.smooth(duration: 0.18)
    static let bouncy = Animation.spring(response: 0.4, dampingFraction: 0.82)
}

private struct DSAnimatedValue<V: Equatable>: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let animation: Animation
    let value: V
    func body(content: Content) -> some View {
        content.animation(reduceMotion ? nil : animation, value: value)
    }
}

/// Press-feedback style that scales down slightly (disabled under Reduce Motion).
struct DSPressStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(reduceMotion ? 1 : (configuration.isPressed ? 0.97 : 1))
            .opacity(configuration.isPressed ? 0.9 : 1)
            .animation(reduceMotion ? nil : DSMotion.quick, value: configuration.isPressed)
    }
}

extension View {
    /// Animate on `value` changes, but honor the Reduce Motion setting.
    func dsAnimation<V: Equatable>(_ animation: Animation = DSMotion.standard, value: V) -> some View {
        modifier(DSAnimatedValue(animation: animation, value: value))
    }
}
