import SwiftUI

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let tint: Color

    var body: some View {
        VStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(tint.opacity(0.15))
                    .frame(width: 44, height: 44)
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(tint)
            }

            Text(value)
                .font(.system(size: 26, weight: .bold, design: .rounded))
                .foregroundStyle(TeamTheme.textPrimary)

            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(TeamTheme.textSecondary)
                .textCase(.uppercase)
                .tracking(0.5)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
        .background(TeamTheme.cardBg, in: RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(tint.opacity(0.15), lineWidth: 1)
        )
    }
}
