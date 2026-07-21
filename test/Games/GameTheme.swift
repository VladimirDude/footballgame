import SwiftUI

enum GameTab: String, CaseIterable, Identifiable {
    case guessClub
    case guessNation
    case guessPlayer
    case wordle
    case higherLower

    var id: String { rawValue }

    var title: String {
        switch self {
        case .guessClub: "Club"
        case .guessNation: "Nation"
        case .guessPlayer: "Player"
        case .wordle: "Wordle"
        case .higherLower: "H/L"
        }
    }

    var icon: String {
        switch self {
        case .guessClub: "shield.lefthalf.filled"
        case .guessNation: "flag.fill"
        case .guessPlayer: "person.crop.circle.fill"
        case .wordle: "square.grid.3x3.fill"
        case .higherLower: "arrow.up.arrow.down.circle.fill"
        }
    }
}

enum GameResult {
    case won, lost
}

/// Neutral switcher — works on every mode background.
struct GameModeSwitcher: View {
    @Binding var selection: GameTab
    var onSelect: (GameTab) -> Void

    @Namespace private var indicator

    var body: some View {
        HStack(spacing: 4) {
            ForEach(GameTab.allCases) { tab in
                Button {
                    guard selection != tab else { return }
                    selection = tab
                    onSelect(tab)
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: tab.icon)
                            .font(.caption.weight(.semibold))
                        Text(tab.title)
                            .font(.system(size: 10, weight: .bold))
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 9)
                    .foregroundStyle(selection == tab ? .white : .white.opacity(0.5))
                    .background {
                        if selection == tab {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(Color.white.opacity(0.2))
                                .matchedGeometryEffect(id: "tab", in: indicator)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.black.opacity(0.45))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
        )
        .animation(GameMotion.silkyQuick, value: selection)
    }
}

struct GameCountdownRing: View, Equatable {
    let timeRemaining: Int
    let total: Int
    var tint: Color = Color(red: 1.0, green: 0.62, blue: 0.18)

    private var progress: CGFloat {
        CGFloat(timeRemaining) / CGFloat(total)
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.12), lineWidth: 3)

            Circle()
                .trim(from: 0, to: progress)
                .stroke(tint, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .rotationEffect(.degrees(-90))

            Text("\(timeRemaining)")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.white)
                .contentTransition(.numericText())
                .animation(nil, value: timeRemaining)
        }
        .frame(width: 42, height: 42)
    }
}

typealias GameStreakBar = GameStatsBar
typealias GPPlayerTopBar = GameStatsBar

extension GameStatsBar {
    init(streak: Int, bestStreak: Int) {
        self.init(streak: streak, bestStreak: bestStreak, timeRemaining: nil)
    }

    init(streak: Int, bestStreak: Int, timeRemaining: Int?, total: Int) {
        self.init(
            streak: streak,
            bestStreak: bestStreak,
            timeRemaining: timeRemaining,
            totalTime: total,
            showProgressBar: timeRemaining != nil
        )
    }
}
