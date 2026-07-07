import SwiftUI

enum GameTab: String, CaseIterable, Identifiable {
    case guessClub
    case guessNation
    case guessPlayer
    case higherLower

    var id: String { rawValue }

    var title: String {
        switch self {
        case .guessClub: "Club"
        case .guessNation: "Nation"
        case .guessPlayer: "Player"
        case .higherLower: "Higher/Lower"
        }
    }

    var subtitle: String {
        switch self {
        case .guessClub: "Flags & positions"
        case .guessNation: "Clubs & positions"
        case .guessPlayer: "Star players"
        case .higherLower: "Market value"
        }
    }

    var icon: String {
        switch self {
        case .guessClub: "shield.lefthalf.filled"
        case .guessNation: "flag.fill"
        case .guessPlayer: "person.crop.circle.fill"
        case .higherLower: "arrow.up.arrow.down.circle.fill"
        }
    }
}

enum GameResult {
    case won, lost
}

struct GamePitchBackground: View {
    var body: some View {
        LinearGradient(
            colors: [
                Color(red: 0.1, green: 0.55, blue: 0.2),
                Color(red: 0.05, green: 0.4, blue: 0.15),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
}

struct GameModeSwitcher: View {
    @Binding var selection: GameTab
    var onSelect: (GameTab) -> Void

    @Namespace private var indicator

    var body: some View {
        HStack(spacing: 8) {
            ForEach(GameTab.allCases) { tab in
                Button {
                    guard selection != tab else { return }
                    withAnimation(.spring(response: 0.38, dampingFraction: 0.82)) {
                        selection = tab
                    }
                    onSelect(tab)
                } label: {
                    VStack(spacing: 5) {
                        Image(systemName: tab.icon)
                            .font(.body.weight(.semibold))
                            .symbolEffect(.bounce, value: selection == tab)

                        Text(tab.title)
                            .font(.caption.weight(.bold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
                    .foregroundStyle(selection == tab ? .white : .white.opacity(0.65))
                    .background {
                        if selection == tab {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Color.white.opacity(0.18))
                                .matchedGeometryEffect(id: "game-tab-indicator", in: indicator)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(6)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.black.opacity(0.22))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
        )
        .padding(.top, 8)
    }
}

struct GPShakeEffect: GeometryEffect {
    var animatableData: CGFloat

    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(
            CGAffineTransform(translationX: 12 * sin(animatableData * .pi * 4), y: 0)
        )
    }
}

struct GameStreakBar: View {
    let streak: Int
    let bestStreak: Int

    var body: some View {
        HStack(spacing: 10) {
            miniStat(icon: "flame.fill", label: "Streak", value: "\(streak)", tint: .orange)
            miniStat(icon: "trophy.fill", label: "Best", value: "\(bestStreak)", tint: .yellow)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(glassCapsule)
    }

    private var glassCapsule: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(.ultraThinMaterial)
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
            )
    }

    private func miniStat(icon: String, label: String, value: String, tint: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(tint)

            VStack(alignment: .leading, spacing: 0) {
                Text(label)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.6))
                    .textCase(.uppercase)
                Text(value)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.white)
                    .contentTransition(.numericText())
            }
        }
    }
}

struct GPPlayerTopBar: View {
    let streak: Int
    let bestStreak: Int
    let timeRemaining: Int?
    let total: Int

    private var progress: CGFloat {
        guard let timeRemaining else { return 0 }
        return CGFloat(timeRemaining) / CGFloat(total)
    }

    private var urgencyTint: Color {
        guard let timeRemaining else { return .white.opacity(0.3) }
        if timeRemaining <= 3 { return Color(red: 1, green: 0.32, blue: 0.32) }
        if timeRemaining <= 6 { return .orange }
        return Color(red: 0.45, green: 0.95, blue: 0.55)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                statBlock(icon: "flame.fill", value: "\(streak)", label: "Streak", tint: .orange)

                divider

                statBlock(icon: "trophy.fill", value: "\(bestStreak)", label: "Best", tint: .yellow)

                Spacer(minLength: 10)

                if let timeRemaining {
                    GameCountdownRing(
                        timeRemaining: timeRemaining,
                        total: total,
                        tint: urgencyTint
                    )
                } else {
                    Image(systemName: "clock.badge.checkmark.fill")
                        .font(.title3)
                        .foregroundStyle(.white.opacity(0.35))
                        .frame(width: 52, height: 52)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)

            if timeRemaining != nil {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.white.opacity(0.1))

                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [urgencyTint.opacity(0.7), urgencyTint],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: max(8, geo.size.width * progress))
                            .shadow(color: urgencyTint.opacity(0.45), radius: 4)
                    }
                }
                .frame(height: 4)
                .padding(.horizontal, 14)
                .padding(.bottom, 10)
                .animation(.easeInOut(duration: 0.3), value: timeRemaining)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )
        )
    }

    private var divider: some View {
        Rectangle()
            .fill(Color.white.opacity(0.12))
            .frame(width: 1, height: 34)
            .padding(.horizontal, 12)
    }

    private func statBlock(icon: String, value: String, label: String, tint: Color) -> some View {
        HStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(tint.opacity(0.18))
                    .frame(width: 32, height: 32)
                Image(systemName: icon)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(tint)
            }

            VStack(alignment: .leading, spacing: 1) {
                Text(value)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.white)
                    .contentTransition(.numericText())
                Text(label)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.white.opacity(0.55))
            }
        }
    }
}

struct GameCountdownRing: View {
    let timeRemaining: Int
    let total: Int
    var tint: Color = .orange

    private var progress: CGFloat {
        CGFloat(timeRemaining) / CGFloat(total)
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.1), lineWidth: 4)

            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    tint,
                    style: StrokeStyle(lineWidth: 4, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .shadow(color: tint.opacity(0.5), radius: 5)
                .animation(.easeInOut(duration: 0.3), value: timeRemaining)

            VStack(spacing: 0) {
                Text("\(timeRemaining)")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.white)
                    .contentTransition(.numericText())
                Text("sec")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.55))
            }
        }
        .frame(width: 52, height: 52)
    }
}
