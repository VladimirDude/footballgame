import SwiftUI

/// Animated launch screen shown briefly before the main content.
struct SplashView: View {
    let onFinished: () -> Void

    @State private var iconScale: CGFloat = 0.5
    @State private var iconOpacity: Double = 0
    @State private var titleOpacity: Double = 0
    @State private var subtitleOpacity: Double = 0
    @State private var ringRotation: Double = 0
    @State private var ringOpacity: Double = 0

    private let teamBlue = Color(red: 0.18, green: 0.45, blue: 0.95)

    var body: some View {
        ZStack {
            // Background
            LinearGradient(
                colors: [
                    Color(red: 0.05, green: 0.08, blue: 0.18),
                    Color(red: 0.02, green: 0.04, blue: 0.10),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 16) {
                Spacer()

                // Animated icon
                ZStack {
                    // Spinning ring
                    Circle()
                        .stroke(
                            AngularGradient(
                                colors: [teamBlue, teamBlue.opacity(0.1), teamBlue],
                                center: .center
                            ),
                            lineWidth: 3
                        )
                        .frame(width: 120, height: 120)
                        .rotationEffect(.degrees(ringRotation))
                        .opacity(ringOpacity)

                    // Inner glow
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [teamBlue.opacity(0.3), .clear],
                                center: .center,
                                startRadius: 0,
                                endRadius: 50
                            )
                        )
                        .frame(width: 100, height: 100)
                        .opacity(iconOpacity)

                    // Icon
                    Image(systemName: "sportscourt.fill")
                        .font(.system(size: 44, weight: .medium))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.white, teamBlue],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .scaleEffect(iconScale)
                        .opacity(iconOpacity)
                }

                // Title
                Text("COGNAIZE")
                    .font(.system(size: 32, weight: .black, design: .rounded))
                    .tracking(6)
                    .foregroundStyle(.white)
                    .opacity(titleOpacity)

                Text("Futsal Team")
                    .font(.system(size: 15, weight: .medium))
                    .tracking(3)
                    .foregroundStyle(teamBlue.opacity(0.8))
                    .opacity(subtitleOpacity)

                Spacer()

                // Bottom tagline
                Text("Season 2025")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.25))
                    .opacity(subtitleOpacity)
                    .padding(.bottom, 40)
            }
        }
        .onAppear {
            // Icon appears
            withAnimation(.easeOut(duration: 0.6)) {
                iconScale = 1.0
                iconOpacity = 1
            }

            // Ring starts spinning
            withAnimation(.easeIn(duration: 0.4)) {
                ringOpacity = 1
            }
            withAnimation(.linear(duration: 2).repeatForever(autoreverses: false)) {
                ringRotation = 360
            }

            // Title fades in
            withAnimation(.easeIn(duration: 0.5).delay(0.3)) {
                titleOpacity = 1
            }

            // Subtitle fades in
            withAnimation(.easeIn(duration: 0.5).delay(0.5)) {
                subtitleOpacity = 1
            }

            // Dismiss after 2 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                onFinished()
            }
        }
    }
}
