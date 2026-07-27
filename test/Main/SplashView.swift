import SwiftUI

/// Branded launch/splash screen: the app logo + wordmark animating in over a
/// football-pitch gradient. Shown by `RootView` for a beat on cold start, then
/// fades to reveal the app. Committed dark-green look (not theme-dependent) so it
/// stays premium in both light and dark, and matches the static `LaunchBackground`
/// so there's no flash on launch.
struct SplashView: View {
    @State private var logoIn = false
    @State private var textIn = false
    @State private var glow = false

    // Base color mirrors the `LaunchBackground` asset for a seamless handoff.
    private let base = Color(red: 0.039, green: 0.133, blue: 0.098)
    private let deep = Color(red: 0.016, green: 0.055, blue: 0.043)
    private let pitch = Color(red: 0.20, green: 0.62, blue: 0.36)

    var body: some View {
        ZStack {
            backdrop

            VStack(spacing: DSSpacing.lg) {
                logo
                VStack(spacing: DSSpacing.xs) {
                    Text(AppBranding.name)
                        .font(.system(size: 44, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                        .kerning(2)
                    accentLine
                    Text(AppBranding.tagline)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.white.opacity(0.72))
                }
                .opacity(textIn ? 1 : 0)
                .offset(y: textIn ? 0 : 14)
            }
            .padding(.bottom, 24)
        }
        .ignoresSafeArea()
        .onAppear {
            withAnimation(.spring(response: 0.7, dampingFraction: 0.62)) { logoIn = true }
            withAnimation(.easeOut(duration: 0.5).delay(0.22)) { textIn = true }
            withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true)) { glow = true }
        }
    }

    // MARK: - Pieces

    private var backdrop: some View {
        ZStack {
            LinearGradient(colors: [base, deep], startPoint: .top, endPoint: .bottom)
            RadialGradient(colors: [pitch.opacity(0.35), .clear],
                           center: .center, startRadius: 0, endRadius: 320)
                .opacity(glow ? 0.9 : 0.5)
            // Faint pitch centre-circle for football flavor.
            Circle()
                .stroke(.white.opacity(0.06), lineWidth: 1.5)
                .frame(width: 300, height: 300)
            Circle()
                .stroke(.white.opacity(0.05), lineWidth: 1.5)
                .frame(width: 520, height: 520)
        }
    }

    private var logo: some View {
        Image("Logo")
            .resizable()
            .aspectRatio(contentMode: .fill)
            .frame(width: 116, height: 116)
            .clipShape(RoundedRectangle(cornerRadius: 27, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 27, style: .continuous)
                    .stroke(.white.opacity(0.14), lineWidth: 1)
            )
            .shadow(color: pitch.opacity(glow ? 0.55 : 0.3), radius: glow ? 34 : 20, y: 10)
            .scaleEffect(logoIn ? 1 : 0.72)
            .opacity(logoIn ? 1 : 0)
    }

    private var accentLine: some View {
        Capsule()
            .fill(LinearGradient(colors: [pitch, .white.opacity(0.9)], startPoint: .leading, endPoint: .trailing))
            .frame(width: textIn ? 64 : 0, height: 3)
            .animation(.easeOut(duration: 0.5).delay(0.35), value: textIn)
    }
}

/// Wraps the app content and shows `SplashView` on cold start.
///
/// The "landing page renders broken then adapts" bug is a cold-start layout race:
/// mounting the app content on frame 0 — before the window's size/safe-area are
/// final — makes it lay out at the wrong geometry, then visibly re-flow once the
/// geometry settles (worst on the paged onboarding `TabView` / `sidebarAdaptable`
/// tab bar). Fix: a stable full-bleed base holds the frame from the first frame,
/// and the real `content` is mounted only *after* geometry has settled — so its
/// very first layout pass is already correct (no adapt) and happens hidden under
/// the opaque splash. The splash is an `.overlay`, so its fade/removal can never
/// re-flow the content.
struct RootView<Content: View>: View {
    @ViewBuilder var content: Content
    @State private var contentMounted = false
    @State private var splashOpacity: Double = 1
    @State private var splashMounted = true

    var body: some View {
        ZStack {
            Color("LaunchBackground").ignoresSafeArea()
            if contentMounted { content }
        }
        .overlay {
            if splashMounted {
                SplashView()
                    .opacity(splashOpacity)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
            }
        }
        .task {
            // 1) Let the window geometry settle, then mount content at final size.
            try? await Task.sleep(nanoseconds: 1_100_000_000)
            contentMounted = true
            // 2) Let it complete its (now-correct) first layout under the splash.
            try? await Task.sleep(nanoseconds: 350_000_000)
            // 3) Reveal.
            withAnimation(.easeInOut(duration: 0.45)) { splashOpacity = 0 }
            try? await Task.sleep(nanoseconds: 460_000_000)
            splashMounted = false
        }
    }
}

#Preview { SplashView() }
