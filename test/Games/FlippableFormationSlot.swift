import SwiftUI

struct FlippableFormationSlot: View {

    @Environment(\.gameTheme) private var theme

    let slot: FormationSlot
    @Binding var revealedPlayerIds: Set<String>

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var isFlipped: Bool {
        revealedPlayerIds.contains(slot.id)
    }

    var body: some View {
        ZStack {
            frontFace
                .opacity(isFlipped ? 0 : 1)

            backFace
                .opacity(isFlipped ? 1 : 0)
        }
        .frame(width: 58, height: 58)
        .background(
            Circle()
                .fill(Color.white.opacity(0.12))
                .overlay(Circle().stroke(theme.panelStroke, lineWidth: 1))
        )
        .animation(GameMotion.adaptive(GameMotion.silkyQuick, reduceMotion: reduceMotion), value: isFlipped)
        .accessibilityLabel(isFlipped ? slot.playerName : "\(slot.role), \(slot.flag)")
    }

    private var frontFace: some View {
        VStack(spacing: slot.showsClub ? 2 : 3) {
            if slot.showsClub {
                Text(slot.flag)
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(theme.textPrimary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.65)
                    .frame(height: 20)
            } else {
                Text(slot.flag)
                    .font(.system(size: 24))
            }

            Text(slot.role)
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(theme.textSecondary)
        }
        .padding(.horizontal, slot.showsClub ? 2 : 0)
    }

    private var backFace: some View {
        Text(slot.playerName)
            .font(.system(size: 8, weight: .semibold))
            .foregroundStyle(theme.textPrimary)
            .multilineTextAlignment(.center)
            .lineLimit(3)
            .minimumScaleFactor(0.65)
            .padding(.horizontal, 4)
    }
}
