import SwiftUI

enum OnboardingStorage {
    static let completedKey = "hasCompletedOnboarding"
    /// Set when onboarding finishes via "Play Daily" so the You tab opens Daily once.
    static let openDailyAfterOnboardingKey = "openDailyAfterOnboarding"
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
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
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
                    detail: "Age, foot, height, peak value, nationality, and club."
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
            ]
        ),
        OnboardingPage(
            id: "ready",
            icon: "flame.fill",
            tint: Color(red: 1.0, green: 0.55, blue: 0.15),
            title: "Start your streak",
            subtitle: "The Daily Challenge is five quick questions — finish it to earn XP and day one of your streak.",
            highlights: [
                OnboardingHighlight(
                    icon: "calendar",
                    title: "One shared puzzle",
                    detail: "Everyone gets the same questions each day."
                ),
                OnboardingHighlight(
                    icon: "star.fill",
                    title: "+50 XP",
                    detail: "Completing Daily advances your level toward Pro."
                ),
                OnboardingHighlight(
                    icon: "bell.fill",
                    title: "Optional reminder",
                    detail: "Turn on Daily reminders later in Settings."
                ),
            ]
        ),
    ]

    private var isLastPage: Bool { page == pages.count - 1 }
    private var isRegularWidth: Bool { horizontalSizeClass == .regular }

    var body: some View {
        ZStack {
            // Full-bleed backdrop — never constrain this on iPad.
            onboardingBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                topBar
                    .frame(maxWidth: contentMaxWidth)
                    .frame(maxWidth: .infinity)

                TabView(selection: $page) {
                    ForEach(Array(pages.enumerated()), id: \.element.id) { index, pageData in
                        OnboardingPageView(page: pageData, isRegularWidth: isRegularWidth)
                            .tag(index)
                            .frame(maxWidth: contentMaxWidth)
                            .frame(maxWidth: .infinity)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.smooth(duration: 0.35), value: page)

                bottomBar
                    .frame(maxWidth: contentMaxWidth)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private var contentMaxWidth: CGFloat {
        isRegularWidth ? AdaptiveLayout.formMaxWidth : .infinity
    }

    private var onboardingBackground: some View {
        ZStack {
            DSColor.groupedBackground
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
                Button("Skip") { finish(openDaily: false) }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(palette.textMuted)
            }
        }
        .padding(.horizontal, isRegularWidth ? 32 : 20)
        .padding(.top, 12)
        .frame(height: 44)
    }

    private var bottomBar: some View {
        VStack(spacing: 12) {
            pageIndicator

            Button(action: advance) {
                HStack(spacing: 8) {
                    Text(isLastPage ? "Play Daily Challenge" : "Continue")
                        .font(.headline.weight(.bold))
                    Image(systemName: isLastPage ? "flame.fill" : "chevron.right")
                        .font(.subheadline.weight(.bold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .foregroundStyle(palette.buttonOnAccent)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(isLastPage ? Color(red: 1.0, green: 0.55, blue: 0.15) : BrowseTheme.accent)
                )
            }
            .buttonStyle(.plain)

            if isLastPage {
                Button("Maybe later") { finish(openDaily: false) }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(palette.textMuted)
            }
        }
        .padding(.horizontal, isRegularWidth ? 32 : 24)
        .padding(.bottom, isRegularWidth ? 40 : 32)
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
            finish(openDaily: true)
        } else {
            withAnimation { page += 1 }
        }
    }

    private func finish(openDaily: Bool) {
        UserDefaults.standard.set(openDaily, forKey: OnboardingStorage.openDailyAfterOnboardingKey)
        withAnimation(.easeOut(duration: 0.25)) {
            onComplete()
        }
    }
}

// MARK: - Page content

private struct OnboardingPageView: View {
    let page: OnboardingPage
    var isRegularWidth: Bool = false

    @Environment(\.appPalette) private var palette

    private var heroHeight: CGFloat { isRegularWidth ? 180 : (page.usesPitchHero ? 140 : 120) }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: isRegularWidth ? 28 : 24) {
                hero
                textBlock
                highlightsCard
            }
            .padding(.horizontal, isRegularWidth ? 32 : 24)
            .padding(.top, isRegularWidth ? 16 : 8)
            .padding(.bottom, 16)
            .frame(maxWidth: .infinity)
        }
        .scrollBounceBehavior(.basedOnSize)
    }

    private var hero: some View {
        ZStack {
            if page.usesPitchHero {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(BrowseTheme.pitchGradient)
                    .frame(height: heroHeight)
                    .overlay(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .stroke(Color.white.opacity(0.12), lineWidth: 1)
                    )

                VStack(spacing: 10) {
                    Image(systemName: page.icon)
                        .font(.system(size: isRegularWidth ? 44 : 36, weight: .semibold))
                        .foregroundStyle(.white)
                    Text(AppBranding.name)
                        .font(isRegularWidth ? .largeTitle.weight(.heavy) : .title.weight(.heavy))
                        .foregroundStyle(.white)
                }
            } else {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(palette.panelFill)
                    .frame(height: heroHeight)
                    .overlay(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .stroke(palette.panelStroke, lineWidth: 1)
                    )
                    .overlay {
                        ZStack {
                            Circle()
                                .fill(page.tint.opacity(0.14))
                                .frame(width: isRegularWidth ? 88 : 72, height: isRegularWidth ? 88 : 72)
                            Image(systemName: page.icon)
                                .font(.system(size: isRegularWidth ? 38 : 32, weight: .semibold))
                                .foregroundStyle(page.tint)
                        }
                    }
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var textBlock: some View {
        VStack(spacing: 8) {
            Text(page.title)
                .font(isRegularWidth ? .title.weight(.bold) : .title2.weight(.bold))
                .foregroundStyle(palette.textPrimary)
                .multilineTextAlignment(.center)

            Text(page.subtitle)
                .font(isRegularWidth ? .body : .subheadline)
                .foregroundStyle(palette.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
    }

    private var highlightsCard: some View {
        Group {
            if isRegularWidth && page.highlights.count >= 3 {
                LazyVGrid(
                    columns: [
                        GridItem(.flexible(), spacing: 12),
                        GridItem(.flexible(), spacing: 12),
                    ],
                    spacing: 12
                ) {
                    ForEach(page.highlights) { highlight in
                        highlightTile(highlight)
                    }
                }
            } else {
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
                .background(highlightsBackground)
            }
        }
    }

    private func highlightTile(_ highlight: OnboardingHighlight) -> some View {
        HStack(alignment: .top, spacing: 12) {
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
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 96, alignment: .topLeading)
        .background(highlightsBackground)
    }

    private var highlightsBackground: some View {
        RoundedRectangle(cornerRadius: 18, style: .continuous)
            .fill(palette.panelFill)
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(palette.panelStroke, lineWidth: 1)
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
