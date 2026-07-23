import SwiftUI

struct CoachDetailView: View {
    let coaches: [Player]

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                ForEach(coaches) { coach in
                    coachCard(coach)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 20)
        }
        .background(Theme.bg.ignoresSafeArea())
        .navigationTitle("Coaching Staff")
        .navigationBarTitleDisplayMode(.large)
        .toolbarColorScheme(.dark, for: .navigationBar)
    }

    private func coachCard(_ coach: Player) -> some View {
        VStack(spacing: 0) {
            // Header
            ZStack(alignment: .bottomLeading) {
                LinearGradient(
                    colors: [Theme.purple.opacity(0.5), Theme.blue.opacity(0.3)],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
                .frame(height: 120)

                HStack(alignment: .bottom, spacing: 14) {
                    PlayerAvatarView(image: coach.photo, name: coach.name, role: .coach, size: 72)
                        .offset(y: 36)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(coach.name)
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(.white)
                        Text(coach.coachInfo?.specialty ?? "Coach")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.white.opacity(0.7))
                    }
                    .padding(.bottom, 12)

                    Spacer()
                }
                .padding(.horizontal, 20)
            }
            .clipShape(UnevenRoundedRectangle(topLeadingRadius: 16, topTrailingRadius: 16))

            VStack(alignment: .leading, spacing: 16) {
                Spacer().frame(height: 24)

                if let info = coach.coachInfo {
                    infoSection(icon: "sportscourt.fill", title: "Tactics & Formation", content: info.tactics)
                    infoSection(icon: "clock.badge.checkmark.fill", title: "Experience", content: info.experience)

                    VStack(alignment: .leading, spacing: 8) {
                        Label("Philosophy", systemImage: "quote.opening")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(Theme.purple)
                            .textCase(.uppercase)
                            .tracking(0.5)

                        Text(info.philosophy)
                            .font(.system(size: 15, weight: .medium))
                            .italic()
                            .foregroundStyle(Theme.textSecondary)
                            .padding(14)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Theme.purple.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
            .background(Theme.cardBg)
            .clipShape(UnevenRoundedRectangle(bottomLeadingRadius: 16, bottomTrailingRadius: 16))
        }
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Theme.cardBorder, lineWidth: 1)
        )
    }

    private func infoSection(icon: String, title: String, content: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: icon)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Theme.blue)
                .textCase(.uppercase)
                .tracking(0.5)

            Text(content)
                .font(.system(size: 14))
                .foregroundStyle(Theme.textPrimary.opacity(0.85))
                .lineSpacing(4)
        }
    }
}
