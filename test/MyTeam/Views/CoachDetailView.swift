import SwiftUI

struct CoachDetailView: View {
    let coaches: [TeamPlayer]
    /// Named so an empty list reads as "this team has no coaches" rather than as a
    /// broken screen — especially now that more than one team can be open.
    var teamName: String?

    var body: some View {
        Group {
            if coaches.isEmpty {
                DSEmptyState(
                    title: "No coaching staff",
                    systemImage: "person.badge.clock",
                    message: teamName.map { "\($0) has no coaches yet. Add a squad member with the Coach role." }
                        ?? "Add a squad member with the Coach role."
                )
            } else {
                ScrollView {
                    VStack(spacing: 20) {
                        ForEach(coaches) { coach in
                            coachCard(coach)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 20)
                    .adaptiveContentWidth(AdaptiveLayout.detailMaxWidth)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(TeamTheme.bg.ignoresSafeArea())
        .navigationTitle("Coaching Staff")
        .navigationBarTitleDisplayMode(.large)
    }

    private func coachCard(_ coach: TeamPlayer) -> some View {
        VStack(spacing: 0) {
            // Header
            ZStack(alignment: .bottomLeading) {
                LinearGradient(
                    colors: [TeamTheme.purple.opacity(0.5), TeamTheme.blue.opacity(0.3)],
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

                let info = coach.coachInfo ?? CoachInfo(specialty: "", tactics: "", experience: "", philosophy: "")
                if isBlank(info) {
                    // Otherwise the card is a name over dead space, which reads as
                    // a half-loaded screen.
                    Text("No details added yet. Edit this coach to add tactics, experience and philosophy.")
                        .font(.system(size: 14))
                        .foregroundStyle(TeamTheme.textSecondary)
                } else {
                    if !info.tactics.isEmpty {
                        infoSection(icon: "sportscourt.fill", title: "Tactics & Formation", content: info.tactics)
                    }
                    if !info.experience.isEmpty {
                        infoSection(icon: "clock.badge.checkmark.fill", title: "Experience", content: info.experience)
                    }

                    if !info.philosophy.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Philosophy", systemImage: "quote.opening")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(TeamTheme.purple)
                            .textCase(.uppercase)
                            .tracking(0.5)

                        Text(info.philosophy)
                            .font(.system(size: 15, weight: .medium))
                            .italic()
                            .foregroundStyle(TeamTheme.textSecondary)
                            .padding(14)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(TeamTheme.purple.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
                    }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
            .background(TeamTheme.cardBg)
            .clipShape(UnevenRoundedRectangle(bottomLeadingRadius: 16, bottomTrailingRadius: 16))
        }
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(TeamTheme.cardBorder, lineWidth: 1)
        )
    }

    private func isBlank(_ info: CoachInfo) -> Bool {
        [info.tactics, info.experience, info.philosophy]
            .allSatisfy { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    private func infoSection(icon: String, title: String, content: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: icon)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(TeamTheme.blue)
                .textCase(.uppercase)
                .tracking(0.5)

            Text(content)
                .font(.system(size: 14))
                .foregroundStyle(TeamTheme.textPrimary.opacity(0.85))
                .lineSpacing(4)
        }
    }
}
