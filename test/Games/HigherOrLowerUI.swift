import SwiftUI

enum HLCardRole {
    case anchor
    case challenge
}

enum HLRevealState {
    case hidden
    case revealed
    case correct
    case wrong
}

private enum HLTheme {
    static let gold = Color(red: 1.0, green: 0.82, blue: 0.35)
    static let amber = Color(red: 1.0, green: 0.62, blue: 0.18)
    static let glassStroke = Color.white.opacity(0.14)
    static let glassFill = Color.white.opacity(0.08)
}

struct HLTopBar: View {
    let streak: Int
    let bestStreak: Int
    let timeRemaining: Int?
    let total: Int

    var body: some View {
        HStack(spacing: 0) {
            statBlock(icon: "flame.fill", value: "\(streak)", label: "Streak", tint: HLTheme.amber)

            divider

            statBlock(icon: "trophy.fill", value: "\(bestStreak)", label: "Best", tint: HLTheme.gold)

            Spacer(minLength: 12)

            if let timeRemaining {
                HLCircularTimer(timeRemaining: timeRemaining, total: total)
            } else {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title3)
                    .foregroundStyle(.white.opacity(0.35))
                    .frame(width: 48, height: 48)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(glassPanel(cornerRadius: 18))
    }

    private var divider: some View {
        Rectangle()
            .fill(Color.white.opacity(0.12))
            .frame(width: 1, height: 36)
            .padding(.horizontal, 12)
    }

    private func statBlock(icon: String, value: String, label: String, tint: Color) -> some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(tint.opacity(0.18))
                    .frame(width: 34, height: 34)
                Image(systemName: icon)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(tint)
            }

            VStack(alignment: .leading, spacing: 1) {
                Text(value)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.white)
                Text(label)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.white.opacity(0.55))
            }
        }
    }
}

struct HLCircularTimer: View {
    let timeRemaining: Int
    let total: Int

    private var progress: CGFloat {
        CGFloat(timeRemaining) / CGFloat(total)
    }

    private var tint: Color {
        timeRemaining <= 2 ? Color(red: 1, green: 0.35, blue: 0.35) : HLTheme.amber
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.1), lineWidth: 3.5)

            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    tint,
                    style: StrokeStyle(lineWidth: 3.5, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .shadow(color: tint.opacity(0.55), radius: 4)
                .animation(.easeInOut(duration: 0.25), value: timeRemaining)

            Text("\(timeRemaining)")
                .font(.headline.weight(.bold))
                .foregroundStyle(.white)
                .contentTransition(.numericText())
        }
        .frame(width: 48, height: 48)
    }
}

struct HLArena: View {
    let left: HLPlayer
    let right: HLPlayer
    let revealState: HLRevealState
    let slideIn: Bool
    let shakeTrigger: Bool

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.black.opacity(0.28),
                            Color.black.opacity(0.14),
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(HLTheme.glassStroke, lineWidth: 1)
                )

            HStack(spacing: 10) {
                HLPlayerCard(player: left, role: .anchor, revealState: .revealed)

                HLPlayerCard(
                    player: right,
                    role: .challenge,
                    revealState: revealState
                )
                .offset(x: slideIn ? 0 : 90)
                .opacity(slideIn ? 1 : 0)
                .modifier(HLShakeEffect(animatableData: shakeTrigger ? 1 : 0))
            }
            .padding(12)

            HLVersusBadge()
        }
        .shadow(color: .black.opacity(0.22), radius: 16, y: 8)
    }
}

struct HLPlayerCard: View {
    let player: HLPlayer
    let role: HLCardRole
    let revealState: HLRevealState

    private var accentColor: Color {
        switch revealState {
        case .correct: .green
        case .wrong: Color(red: 1, green: 0.38, blue: 0.38)
        case .revealed: HLTheme.gold
        case .hidden: role == .anchor ? HLTheme.gold : .white.opacity(0.5)
        }
    }

    private var showsValue: Bool {
        role == .anchor || revealState != .hidden
    }

    var body: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .topTrailing) {
                VStack(spacing: 10) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.black.opacity(0.35),
                                        Color.black.opacity(0.18),
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .frame(width: 88, height: 88)

                        PlayerPortraitImage(playerID: player.id, style: .game)
                    }

                    VStack(spacing: 3) {
                        Text(player.name)
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                            .minimumScaleFactor(0.82)

                        Text(player.clubName)
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(.white.opacity(0.55))
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)
                    }
                    .frame(minHeight: 38)
                }
                .padding(.top, 12)
                .padding(.horizontal, 8)

                roleBadge
                    .padding(8)
            }

            valueFooter
        }
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(HLTheme.glassFill)
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(accentColor.opacity(0.45), lineWidth: 1.5)
                )
        )
    }

    private var roleBadge: some View {
        Text(role == .anchor ? "BASE" : "?")
            .font(.system(size: 9, weight: .heavy))
            .foregroundStyle(role == .anchor ? HLTheme.gold : .white.opacity(0.8))
            .padding(.horizontal, 7)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(Color.black.opacity(0.45))
                    .overlay(
                        Capsule()
                            .stroke(accentColor.opacity(0.5), lineWidth: 1)
                    )
            )
    }

    @ViewBuilder
    private var valueFooter: some View {
        Group {
            if showsValue {
                Text(formatCurrency(player.marketValue))
                    .font(.system(size: 14, weight: .heavy, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [HLTheme.gold, HLTheme.amber],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
            } else {
                HStack(spacing: 4) {
                    Image(systemName: "eye.slash.fill")
                        .font(.caption2)
                    Text("Hidden")
                        .font(.caption.weight(.bold))
                }
                .foregroundStyle(.white.opacity(0.38))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 9)
        .background(
            UnevenRoundedRectangle(
                topLeadingRadius: 0,
                bottomLeadingRadius: 18,
                bottomTrailingRadius: 18,
                topTrailingRadius: 0,
                style: .continuous
            )
            .fill(Color.black.opacity(0.32))
        )
        .transition(.opacity.combined(with: .scale(scale: 0.95)))
    }

    private func formatCurrency(_ val: Int) -> String {
        MarketValueFormatter.format(val)
    }
}

struct HLVersusBadge: View {
    var body: some View {
        Text("VS")
            .font(.caption.weight(.black))
            .tracking(1)
            .foregroundStyle(.white)
            .frame(width: 40, height: 40)
            .background(
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [HLTheme.amber, Color(red: 0.95, green: 0.35, blue: 0.2)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.35), lineWidth: 2)
                    )
            )
            .shadow(color: HLTheme.amber.opacity(0.5), radius: 10, y: 3)
            .overlay(
                Circle()
                    .stroke(Color.black.opacity(0.25), lineWidth: 4)
                    .blur(radius: 2)
                    .offset(y: 1)
                    .mask(Circle())
            )
    }
}

struct HLActionDock: View {
    let onHigher: () -> Void
    let onLower: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            Button(action: onHigher) {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title3)
                    Text("Higher")
                        .font(.headline.weight(.bold))
                    Spacer()
                    Text("Worth more")
                        .font(.caption.weight(.medium))
                        .opacity(0.75)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .foregroundStyle(.white)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.98, green: 0.55, blue: 0.12),
                                    Color(red: 0.88, green: 0.28, blue: 0.1),
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(Color.white.opacity(0.2), lineWidth: 1)
                        )
                )
                .shadow(color: HLTheme.amber.opacity(0.35), radius: 10, y: 5)
            }

            Button(action: onLower) {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.down.circle.fill")
                        .font(.title3)
                    Text("Lower")
                        .font(.headline.weight(.bold))
                    Spacer()
                    Text("Worth less")
                        .font(.caption.weight(.medium))
                        .opacity(0.75)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .foregroundStyle(.white)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.22, green: 0.48, blue: 0.95),
                                    Color(red: 0.14, green: 0.28, blue: 0.72),
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(Color.white.opacity(0.2), lineWidth: 1)
                        )
                )
                .shadow(color: Color.blue.opacity(0.28), radius: 10, y: 5)
            }
        }
        .padding(12)
        .background(glassPanel(cornerRadius: 20))
    }
}

struct HLContinueButton: View {
    let isGameOver: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: isGameOver ? "arrow.counterclockwise.circle.fill" : "arrow.right.circle.fill")
                    .font(.title3)
                Text(isGameOver ? "Play Again" : "Next Round")
                    .font(.headline.weight(.bold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .foregroundStyle(isGameOver ? .white : Color(red: 0.05, green: 0.38, blue: 0.14))
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(isGameOver
                          ? LinearGradient(colors: [Color(red: 0.95, green: 0.3, blue: 0.28), Color(red: 0.75, green: 0.15, blue: 0.18)], startPoint: .topLeading, endPoint: .bottomTrailing)
                          : LinearGradient(colors: [.white, Color(white: 0.92)], startPoint: .top, endPoint: .bottom))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(Color.white.opacity(isGameOver ? 0.15 : 0.5), lineWidth: 1)
                    )
            )
            .shadow(color: .black.opacity(0.18), radius: 8, y: 4)
        }
        .padding(12)
        .background(glassPanel(cornerRadius: 20))
    }
}

struct HLShakeEffect: GeometryEffect {
    var animatableData: CGFloat

    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(CGAffineTransform(translationX: 10 * sin(animatableData * .pi * 4), y: 0))
    }
}

struct HLResultBanner: View {
    let isCorrect: Bool

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: isCorrect ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.body.weight(.semibold))
            Text(isCorrect ? "Correct — keep going!" : "Wrong — streak ended")
                .font(.subheadline.weight(.semibold))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(
                    isCorrect
                    ? Color.green.opacity(0.82)
                    : Color(red: 0.9, green: 0.25, blue: 0.25).opacity(0.85)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
        )
        .transition(.scale(scale: 0.95).combined(with: .opacity))
    }
}

private func glassPanel(cornerRadius: CGFloat) -> some View {
    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        .fill(.ultraThinMaterial)
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(HLTheme.glassStroke, lineWidth: 1)
        )
}
