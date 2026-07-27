import SwiftUI
import Combine

/// The live Classic Alias screen. Owns the per-second timer and switches between
/// the pass-the-phone gate, the timed turn, the round review and the results,
/// driven entirely by `engine.status`.
struct AliasGameView: View {
    @ObservedObject var engine: AliasGameEngine
    var onExit: () -> Void

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            DSColor.groupedBackground.ignoresSafeArea()
            content
                .padding(DSSpacing.lg)
        }
        .onReceive(timer) { _ in engine.tick() }
        .onAppear { if engine.status == .setup { engine.startGame() } }
    }

    @ViewBuilder private var content: some View {
        switch engine.status {
        case .setup, .readyForTeam:
            readyView
        case .playing:
            playingView
        case .roundReview:
            AliasRoundReviewView(engine: engine)
        case .finished:
            AliasResultsView(engine: engine,
                             onRematch: { engine.resetForRematch() },
                             onHome: onExit)
        }
    }

    // MARK: - Ready (pass the phone)

    private var readyView: some View {
        VStack(spacing: DSSpacing.xl) {
            HStack {
                Spacer()
                closeButton
            }
            Spacer()
            Image(systemName: "iphone.gen3.radiowaves.left.and.right")
                .font(.system(size: 44))
                .foregroundStyle(DSColor.accent)
            VStack(spacing: DSSpacing.xs) {
                Text("Pass the phone to")
                    .font(.headline)
                    .foregroundStyle(DSColor.textSecondary)
                Text(engine.currentTeam.name)
                    .font(.system(size: 34, weight: .heavy, design: .rounded))
                    .foregroundStyle(DSColor.textPrimary)
            }
            scoreStrip
            Spacer()
            Text("First to \(engine.config.targetScore) points wins")
                .font(.footnote)
                .foregroundStyle(DSColor.textTertiary)
            Button {
                HapticFeedback.medium()
                withAnimation { engine.startTurn() }
            } label: {
                Text("Start Turn")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, DSSpacing.md)
                    .background(DSColor.accent, in: RoundedRectangle(cornerRadius: DSRadius.lg, style: .continuous))
                    .foregroundStyle(DSColor.onAccent)
            }
        }
    }

    // MARK: - Playing

    private var playingView: some View {
        VStack(spacing: DSSpacing.md) {
            HStack(spacing: DSSpacing.md) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(engine.currentTeam.name)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(DSColor.textPrimary)
                    Text("This turn: \(engine.currentTurnDelta >= 0 ? "+" : "")\(engine.currentTurnDelta)")
                        .font(.caption)
                        .foregroundStyle(DSColor.textSecondary)
                }
                Spacer()
                GameCountdownRing(timeRemaining: engine.timeRemaining, total: engine.config.timerSeconds)
                Button {
                    withAnimation { engine.endTurn() }
                } label: {
                    Image(systemName: "stop.fill")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(DSColor.textSecondary)
                        .padding(8)
                        .background(Circle().fill(DSColor.fill))
                }
            }

            if let card = engine.currentCard {
                AliasWordCard(card: card)
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)))
            }

            HStack(spacing: DSSpacing.md) {
                actionButton(title: "Skip", icon: "arrow.right", tint: DSColor.warning) {
                    HapticFeedback.warning()
                    withAnimation { engine.skip() }
                }
                actionButton(title: "Correct", icon: "checkmark", tint: DSColor.success) {
                    HapticFeedback.success()
                    withAnimation { engine.markCorrect() }
                }
            }
        }
    }

    private func actionButton(title: String, icon: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, DSSpacing.md)
                .background(tint, in: RoundedRectangle(cornerRadius: DSRadius.lg, style: .continuous))
                .foregroundStyle(.white)
        }
    }

    // MARK: - Shared bits

    private var scoreStrip: some View {
        HStack(spacing: DSSpacing.sm) {
            ForEach(engine.teams) { team in
                VStack(spacing: 2) {
                    Text(team.name).font(.caption2.weight(.semibold))
                        .foregroundStyle(DSColor.textSecondary)
                        .lineLimit(1)
                    Text("\(team.score)")
                        .font(.title3.weight(.heavy))
                        .foregroundStyle(team.id == engine.currentTeam.id ? DSColor.accent : DSColor.textPrimary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, DSSpacing.sm)
                .background(RoundedRectangle(cornerRadius: DSRadius.md, style: .continuous).fill(DSColor.surface))
            }
        }
    }

    private var closeButton: some View {
        Button(action: onExit) {
            Image(systemName: "xmark")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(DSColor.textSecondary)
                .padding(8)
                .background(Circle().fill(DSColor.fill))
        }
        .accessibilityLabel("Quit game")
    }
}
