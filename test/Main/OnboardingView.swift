import SwiftUI

enum OnboardingStorage {
    static let completedKey = "hasCompletedOnboarding"
}

// MARK: - Page model

private struct OnboardingPage: Identifiable {
    let id: String
    let icon: String
    let tint: Color
    let title: String
    let subtitle: String
    let highlights: [OnboardingHighlight]
    var usesPitchHero: Bool = false
}

private struct OnboardingHighlight: Identifiable {
    let id = UUID()
    let icon: String
    let title: String
    let detail: String
}

// MARK: - Root

struct OnboardingView: View {
    var onComplete: () -> Void

    @Environment(\.appPalette) private var palette
    @Environment(\.colorScheme) private var colorScheme
    @State private var page = 0

    private let pages: [OnboardingPage] = [
        OnboardingPage(
            id: "welcome",
            icon: "soccerball",
            tint: BrowseTheme.accent,
            title: "Welcome to FTMP",
            subtitle: AppBranding.tagline,
            highlights: [
                OnboardingHighlight(
                    icon: "wifi.slash",
                    title: "Works offline",
                    detail: "Browse squads and play quizzes without a connection."
                ),
                OnboardingHighlight(
                    icon: "bolt.fill",
                    title: "Three ways to play",
                    detail: "Search the database, test your knowledge, or simulate a season."
                ),
            ],
            usesPitchHero: true
        ),
        OnboardingPage(
            id: "search",
            icon: "magnifyingglass",
            tint: BrowseTheme.accent,
            title: "Search & Browse",
            subtitle: "Explore players and clubs from the built-in database.",
            highlights: [
                OnboardingHighlight(
                    icon: "person.3.fill",
                    title: "Player search",
                    detail: "Find anyone by name and filter by club, league, position, or nationality."
                ),
                OnboardingHighlight(
                    icon: "shield.lefthalf.filled",
                    title: "Club browser",
                    detail: "Browse every squad with logos, values, and full rosters."
                ),
                OnboardingHighlight(
                    icon: "doc.text.magnifyingglass",
                    title: "Player profiles",
                    detail: "Tap a player for portraits, market value, and squad rank."
                ),
            ]
        ),
        OnboardingPage(
            id: "game",
            icon: "gamecontroller.fill",
            tint: Color(red: 0.55, green: 0.38, blue: 0.98),
            title: "Quiz Modes",
            subtitle: "Five game modes in one tab — switch anytime.",
            highlights: [
                OnboardingHighlight(icon: "shield.lefthalf.filled", title: "Guess the Club", detail: "Formation + flags → name the team."),
                OnboardingHighlight(icon: "flag.fill", title: "Guess the Nation", detail: "Club badges → name the country."),
                OnboardingHighlight(icon: "person.crop.circle.fill", title: "Guess the Player", detail: "Portrait + 10-second timer."),
                OnboardingHighlight(icon: "square.grid.3x3.fill", title: "Wordle", detail: "Six guesses with Nation, League, Club, Pos & Value hints."),
                OnboardingHighlight(icon: "arrow.up.arrow.down.circle.fill", title: "Higher / Lower", detail: "Which player is worth more? Beat your high score."),
            ]
        ),
        OnboardingPage(
            id: "simulate",
            icon: "play.circle.fill",
            tint: Color(red: 0.22, green: 0.78, blue: 0.48),
            title: "Simulate",
            subtitle: "Run Premier League gameweeks and full seasons.",
            highlights: [
                OnboardingHighlight(
                    icon: "sportscourt.fill",
                    title: "Gameweek",
                    detail: "Pick Home / Draw / Away, lock in, and simulate results."
                ),
                OnboardingHighlight(
                    icon: "list.number",
                    title: "Table",
                    detail: "Simulate the full 38-gameweek season and track the standings."
                ),
                OnboardingHighlight(
                    icon: "chart.bar.fill",
                    title: "Stats",
                    detail: "Golden Boot, team leaders, and biggest wins after simulation."
                ),
                OnboardingHighlight(
                    icon: "forward.fill",
                    title: "Simulate Only",
                    detail: "Skip predictions in Settings and just run match simulations."
                ),
            ]
        ),
        OnboardingPage(
            id: "ready",
            icon: "checkmark.circle.fill",
            tint: GameDesign.success,
            title: "You're all set",
            subtitle: "Everything works offline. Customize appearance and haptics in Settings.",
            highlights: [
                OnboardingHighlight(
                    icon: "paintbrush.fill",
                    title: "Appearance",
                    detail: "Choose System, Light, or Dark mode."
                ),
                OnboardingHighlight(
                    icon: "iphone.radiowaves.left.and.right",
                    title: "Haptics",
                    detail: "Feel correct and wrong answers as you play."
                ),
            ]
        ),
    ]

    private var isLastPage: Bool { page == pages.count - 1 }

    var body: some View {
        ZStack {
            onboardingBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                topBar

                TabView(selection: $page) {
                    ForEach(Array(pages.enumerated()), id: \.element.id) { index, pageData in
                        OnboardingPageView(page: pageData)
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.smooth(duration: 0.35), value: page)

                bottomBar
            }
        }
        .adaptiveContentWidth(AdaptiveLayout.settingsMaxWidth)
    }

    private var onboardingBackground: some View {
        ZStack {
            Color(.systemGroupedBackground)
            if colorScheme == .dark {
                RadialGradient(
                    colors: [palette.accentGlow, .clear],
                    center: .topTrailing,
                    startRadius: 20,
                    endRadius: 420
                )
            }
        }
    }

    private var topBar: some View {
        HStack {
            Spacer()
            if !isLastPage {
                Button("Skip") { finish() }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(palette.textMuted)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .frame(height: 44)
    }

    private var bottomBar: some View {
        VStack(spacing: 20) {
            pageIndicator

            Button(action: advance) {
                HStack(spacing: 8) {
                    Text(isLastPage ? "Get Started" : "Continue")
                        .font(.headline.weight(.bold))
                    Image(systemName: isLastPage ? "arrow.right" : "chevron.right")
                        .font(.subheadline.weight(.bold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .foregroundStyle(palette.buttonOnAccent)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(isLastPage ? GameDesign.success : BrowseTheme.accent)
                )
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 32)
        .padding(.top, 8)
    }

    private var pageIndicator: some View {
        HStack(spacing: 8) {
            ForEach(0..<pages.count, id: \.self) { index in
                Capsule()
                    .fill(index == page ? BrowseTheme.accent : palette.chromeStroke)
                    .frame(width: index == page ? 22 : 7, height: 7)
                    .animation(.smooth(duration: 0.25), value: page)
            }
        }
    }

    private func advance() {
        if isLastPage {
            finish()
        } else {
            withAnimation { page += 1 }
        }
    }

    private func finish() {
        withAnimation(.easeOut(duration: 0.25)) {
            onComplete()
        }
    }
}

// MARK: - Page content

private struct OnboardingPageView: View {
    let page: OnboardingPage

    @Environment(\.appPalette) private var palette

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 24) {
                hero
                textBlock
                highlightsCard
            }
            .padding(.horizontal, 24)
            .padding(.top, 8)
            .padding(.bottom, 16)
        }
        .scrollBounceBehavior(.basedOnSize)
    }

    private var hero: some View {
        ZStack {
            if page.usesPitchHero {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(BrowseTheme.pitchGradient)
                    .frame(height: 140)
                    .overlay(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .stroke(Color.white.opacity(0.12), lineWidth: 1)
                    )

                VStack(spacing: 10) {
                    Image(systemName: page.icon)
                        .font(.system(size: 36, weight: .semibold))
                        .foregroundStyle(.white)
                    Text(AppBranding.name)
                        .font(.title.weight(.heavy))
                        .foregroundStyle(.white)
                }
            } else {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(palette.panelFill)
                    .frame(height: 120)
                    .overlay(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .stroke(palette.panelStroke, lineWidth: 1)
                    )
                    .overlay {
                        ZStack {
                            Circle()
                                .fill(page.tint.opacity(0.14))
                                .frame(width: 72, height: 72)
                            Image(systemName: page.icon)
                                .font(.system(size: 32, weight: .semibold))
                                .foregroundStyle(page.tint)
                        }
                    }
            }
        }
    }

    private var textBlock: some View {
        VStack(spacing: 8) {
            Text(page.title)
                .font(.title2.weight(.bold))
                .foregroundStyle(palette.textPrimary)
                .multilineTextAlignment(.center)

            Text(page.subtitle)
                .font(.subheadline)
                .foregroundStyle(palette.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
    }

    private var highlightsCard: some View {
        VStack(spacing: 0) {
            ForEach(Array(page.highlights.enumerated()), id: \.element.id) { index, highlight in
                if index > 0 {
                    Divider()
                        .overlay(palette.panelStroke.opacity(0.6))
                        .padding(.leading, 52)
                }
                highlightRow(highlight)
            }
        }
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(palette.panelFill)
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(palette.panelStroke, lineWidth: 1)
                )
        )
    }

    private func highlightRow(_ highlight: OnboardingHighlight) -> some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                Circle()
                    .fill(page.tint.opacity(0.12))
                    .frame(width: 38, height: 38)
                Image(systemName: highlight.icon)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(page.tint)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(highlight.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(palette.textPrimary)
                Text(highlight.detail)
                    .font(.caption)
                    .foregroundStyle(palette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

#Preview {
    OnboardingView(onComplete: {})
        .withAppPalette()
}
