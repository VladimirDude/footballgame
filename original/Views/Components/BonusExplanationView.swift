import SwiftUI

struct BonusExplanationView: View {

    private let items: [(points: String, label: String, icon: String)] = [
        ("+2.0", "Attending match", "checkmark.circle.fill"),
        ("+0.5", "Nice goal", "soccerball"),
        ("+0.5", "MVP of the match", "star.fill"),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeaderView(icon: "star.circle.fill", title: "Bonus Points")

            VStack(spacing: 0) {
                ForEach(Array(items.enumerated()), id: \.element.label) { i, item in
                    HStack(spacing: 12) {
                        Image(systemName: item.icon)
                            .font(.system(size: 14))
                            .foregroundStyle(Theme.orange)
                            .frame(width: 24)

                        Text(item.points)
                            .font(.system(size: 14, weight: .bold, design: .monospaced))
                            .foregroundStyle(Theme.orange)
                            .frame(width: 44, alignment: .trailing)

                        Text(item.label)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(Theme.textSecondary)

                        Spacer()
                    }
                    .padding(.vertical, 10)
                    .padding(.horizontal, 14)

                    if i < items.count - 1 {
                        Divider().overlay(Theme.cardBorder).padding(.leading, 50)
                    }
                }
            }
            .background(Theme.cardBg, in: RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Theme.orange.opacity(0.12), lineWidth: 1)
            )
        }
    }
}
