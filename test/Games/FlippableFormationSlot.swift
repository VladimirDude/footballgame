import SwiftUI

struct FlippableFormationSlot: View {

    let slot: FormationSlot
    
    // 1. Pass down the Set of currently revealed player IDs from your GameView
    @Binding var revealedPlayerIds: Set<String>

    // 2. Computed property: true if this specific slot's stable ID has been revealed
    private var isFlipped: Bool {
        revealedPlayerIds.contains(slot.id)
    }

    var body: some View {
        // 🛑 REMOVED Button layout wrapper to completely eliminate manual touch flips
        ZStack {
            frontFace
                .opacity(isFlipped ? 0 : 1)
                .rotation3DEffect(.degrees(isFlipped ? 180 : 0), axis: (x: 0, y: 1, z: 0))

            backFace
                .opacity(isFlipped ? 1 : 0)
                .rotation3DEffect(.degrees(isFlipped ? 0 : -180), axis: (x: 0, y: 1, z: 0))
        }
        .frame(width: 62, height: 62)
        .background(Color.white.opacity(0.18))
        .clipShape(Circle())
        .accessibilityLabel(isFlipped ? slot.playerName : "\(slot.role), \(slot.flag)")
    }

    private var frontFace: some View {
        VStack(spacing: 4) {
            Text(slot.flag)
                .font(.system(size: 28))

            Text(slot.role)
                .font(.caption2.bold())
                .foregroundColor(.white.opacity(0.85))
        }
    }

    private var backFace: some View {
        Text(slot.playerName)
            .font(.system(size: 9, weight: .semibold))
            .foregroundColor(.white)
            .multilineTextAlignment(.center)
            .lineLimit(3)
            .minimumScaleFactor(0.65)
            .padding(.horizontal, 4)
    }
}
