import SwiftUI

/// A celebratory banner shown when an achievement unlocks. Mounted once at the
/// app root; it observes `GameProgressStore.pendingUnlock` and auto-dismisses.
struct AchievementBannerHost: View {
    @EnvironmentObject private var progress: GameProgressStore

    var body: some View {
        VStack {
            if let achievement = progress.pendingUnlock {
                AchievementBanner(achievement: achievement)
                    .id(achievement.id)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .task(id: achievement.id) {
                        HapticFeedback.success()
                        try? await Task.sleep(nanoseconds: 2_800_000_000)
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) {
                            progress.dismissUnlock()
                        }
                    }
                    .onTapGesture {
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) {
                            progress.dismissUnlock()
                        }
                    }
            }
            Spacer(minLength: 0)
        }
        .animation(.spring(response: 0.5, dampingFraction: 0.85), value: progress.pendingUnlock)
        .allowsHitTesting(progress.pendingUnlock != nil)
    }
}

struct AchievementBanner: View {
    let achievement: Achievement

    private var tierColor: Color {
        switch achievement.tier {
        case .bronze: DSColor.bronze
        case .silver: DSColor.silver
        case .gold: DSColor.gold
        }
    }

    var body: some View {
        HStack(spacing: DSSpacing.sm) {
            ZStack {
                Circle().fill(tierColor.opacity(0.22)).frame(width: 44, height: 44)
                Image(systemName: achievement.icon)
                    .font(.title3)
                    .foregroundStyle(tierColor)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("Achievement Unlocked")
                    .dsFont(.caption2)
                    .fontWeight(.bold)
                    .textCase(.uppercase)
                    .foregroundStyle(tierColor)
                Text(achievement.title)
                    .dsFont(.headline)
                    .foregroundStyle(DSColor.textPrimary)
            }
            Spacer(minLength: 0)
            Image(systemName: "checkmark.seal.fill")
                .foregroundStyle(tierColor)
        }
        .padding(DSSpacing.sm)
        .background(
            RoundedRectangle(cornerRadius: DSRadius.lg, style: .continuous)
                .fill(DSColor.surfaceElevated)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DSRadius.lg, style: .continuous)
                .stroke(tierColor.opacity(0.45), lineWidth: 1)
        )
        .dsElevation(DSElevation.lg)
        .padding(.horizontal, DSSpacing.md)
        .padding(.top, DSSpacing.xs)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Achievement unlocked: \(achievement.title)")
    }
}
