import SwiftUI

/// Branded launch/splash screen: the app logo + wordmark animating in over a
/// layered football-pitch backdrop. Shown by `RootView` for a beat on cold start,
/// then fades to reveal the app. Committed dark-emerald look (not theme-dependent)
/// so it stays premium in both light and dark, and its base tone matches the static
/// `LaunchBackground` asset for a seamless, flash-free handoff.
struct SplashView: View {
    @State private var appear = false
    @State private var glow = false
    @State private var shimmer = false

    // `base` mirrors the `LaunchBackground` asset for a seamless static → splash handoff.
    private let base  = Color(red: 0.039, green: 0.133, blue: 0.098)
    private let top   = Color(red: 0.067, green: 0.204, blue: 0.145)
    private let deep  = Color(red: 0.010, green: 0.043, blue: 0.031)
    private let pitch = Color(red: 0.22,  green: 0.66,  blue: 0.40)

    var body: some View {
        ZStack {
            backdrop
            VStack(spacing: 28) {
                logo
                wordmark
            }
            .padding(.bottom, 16)
        }
        .ignoresSafeArea()
        .onAppear {
            withAnimation(.spring(response: 0.85, dampingFraction: 0.72)) { appear = true }
            withAnimation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true)) { glow = true }
            withAnimation(.easeOut(duration: 1.15).delay(0.5)) { shimmer = true }
        }
    }

    // MARK: - Backdrop

    private var backdrop: some View {
        ZStack {
            LinearGradient(colors: [top, base, deep], startPoint: .top, endPoint: .bottom)

            // Soft glow blooming from behind the logo.
            RadialGradient(colors: [pitch.opacity(0.30), .clear],
                           center: UnitPoint(x: 0.5, y: 0.42), startRadius: 0, endRadius: 300)
                .opacity(glow ? 1 : 0.65)

            // Subtle pitch arcs.
            Circle().stroke(.white.opacity(0.05), lineWidth: 1).frame(width: 360, height: 360).offset(y: -34)
            Circle().stroke(.white.opacity(0.035), lineWidth: 1).frame(width: 640, height: 640).offset(y: -34)

            // Vignette for depth.
            RadialGradient(colors: [.clear, .black.opacity(0.38)],
                           center: .center, startRadius: 220, endRadius: 640)
        }
    }

    // MARK: - Logo

    private var logo: some View {
        ZStack {
            Circle()
                .fill(pitch.opacity(0.20))
                .frame(width: 176, height: 176)
                .blur(radius: 30)
                .opacity(glow ? 1 : 0.6)

            Image("Logo")
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 112, height: 112)
                .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
                .overlay(topGloss)
                .overlay(shimmerSweep)
                .overlay(
                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .stroke(.white.opacity(0.16), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.35), radius: 24, y: 14)
                .shadow(color: pitch.opacity(glow ? 0.5 : 0.28), radius: glow ? 30 : 18, y: 6)
        }
        .scaleEffect(appear ? 1 : 0.82)
        .opacity(appear ? 1 : 0)
    }

    private var topGloss: some View {
        LinearGradient(colors: [.white.opacity(0.22), .clear], startPoint: .top, endPoint: .center)
            .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
    }

    private var shimmerSweep: some View {
        LinearGradient(colors: [.clear, .white.opacity(0.45), .clear],
                       startPoint: .topLeading, endPoint: .bottomTrailing)
            .frame(width: 58)
            .rotationEffect(.degrees(20))
            .offset(x: shimmer ? 135 : -135)
            .mask(RoundedRectangle(cornerRadius: 26, style: .continuous))
    }

    // MARK: - Wordmark

    private var wordmark: some View {
        VStack(spacing: 14) {
            Text(AppBranding.name)
                .font(.system(size: 46, weight: .heavy, design: .rounded))
                .kerning(3)
                .foregroundStyle(
                    LinearGradient(colors: [.white, .white.opacity(0.74)],
                                   startPoint: .top, endPoint: .bottom)
                )

            Capsule()
                .fill(
                    LinearGradient(colors: [pitch.opacity(0), pitch, .white.opacity(0.9), pitch, pitch.opacity(0)],
                                   startPoint: .leading, endPoint: .trailing)
                )
                .frame(width: appear ? 78 : 0, height: 3)
                .animation(.easeOut(duration: 0.6).delay(0.32), value: appear)

            Text(AppBranding.tagline.uppercased())
                .font(.system(size: 12, weight: .semibold))
                .kerning(2.6)
                .foregroundStyle(.white.opacity(0.62))
        }
        .opacity(appear ? 1 : 0)
        .offset(y: appear ? 0 : 12)
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
