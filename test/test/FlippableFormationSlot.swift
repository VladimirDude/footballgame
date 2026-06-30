import SwiftUI

struct FlippableFormationSlot: View {

    let slot: FormationSlot

    @State private var isFlipped = false

    var body: some View {
        Button {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.78)) {
                isFlipped.toggle()
            }
        } label: {
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
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isFlipped ? slot.playerName : "\(slot.role), \(slot.flag)")
        .accessibilityHint("Double tap to reveal or hide player name")
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
