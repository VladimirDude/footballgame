import SwiftUI

/// Detail sheet for a single achievement — works for locked and unlocked.
struct AchievementDetailSheet: View {
    let achievement: Achievement
    let progress: GameProgress
    let isPro: Bool

    @Environment(\.dismiss) private var dismiss

    private var unlocked: Bool { progress.unlockedAchievements.contains(achievement.id) }
    private var proLocked: Bool { achievement.isPro && !isPro && !unlocked }
    private var metric: AchievementProgress { achievement.progress(progress) }

    private var tierColor: Color {
        switch achievement.tier {
        case .bronze: DSColor.bronze
        case .silver: DSColor.silver
        case .gold: DSColor.gold
        }
    }

    private var accent: Color {
        unlocked ? tierColor : DSColor.textTertiary
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: DSSpacing.lg) {
                    hero
                    meaningCard
                    if unlocked {
                        unlockedCard
                    } else {
                        progressCard
                    }
                }
                .padding(DSSpacing.md)
                .adaptiveContentWidth(AdaptiveLayout.settingsMaxWidth)
            }
            .background(DSColor.groupedBackground.ignoresSafeArea())
            .navigationTitle("Achievement")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private var hero: some View {
        VStack(spacing: DSSpacing.sm) {
            ZStack {
                Circle()
                    .fill(accent.opacity(unlocked ? 0.22 : 0.12))
                    .frame(width: 88, height: 88)
                Image(systemName: proLocked ? "lock.fill" : achievement.icon)
                    .font(.system(size: 36, weight: .semibold))
                    .foregroundStyle(accent)
                    .opacity(unlocked || !proLocked ? 1 : 0.7)
            }

            Text(achievement.title)
                .dsFont(.title2)
                .foregroundStyle(DSColor.textPrimary)
                .multilineTextAlignment(.center)

            HStack(spacing: DSSpacing.xs) {
                Text(achievement.tier.rawValue.capitalized)
                    .dsFont(.caption)
                    .fontWeight(.bold)
                    .foregroundStyle(tierColor)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(tierColor.opacity(0.16)))

                Text(statusLabel)
                    .dsFont(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(statusForeground)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(statusBackground))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, DSSpacing.xs)
    }

    private var statusLabel: String {
        if unlocked { return "Unlocked" }
        if proLocked { return "Pro" }
        return "In progress"
    }

    private var statusForeground: Color {
        if unlocked { return DSColor.success }
        if proLocked { return DSColor.warning }
        return DSColor.textSecondary
    }

    private var statusBackground: Color {
        if unlocked { return DSColor.success.opacity(0.14) }
        if proLocked { return DSColor.warning.opacity(0.14) }
        return DSColor.fill
    }

    private var meaningCard: some View {
        VStack(alignment: .leading, spacing: DSSpacing.xs) {
            Text("How to unlock")
                .dsFont(.caption)
                .fontWeight(.bold)
                .foregroundStyle(DSColor.textTertiary)
                .textCase(.uppercase)
            Text(achievement.detail)
                .dsFont(.body)
                .foregroundStyle(DSColor.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            if achievement.isPro {
                Text("Pro achievement — visible to everyone, unlocks for Pro players.")
                    .dsFont(.footnote)
                    .foregroundStyle(DSColor.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .dsCard()
    }

    private var progressCard: some View {
        VStack(alignment: .leading, spacing: DSSpacing.sm) {
            HStack {
                Text("Progress")
                    .dsFont(.headline)
                    .foregroundStyle(DSColor.textPrimary)
                Spacer()
                Text(metric.label)
                    .dsFont(.subheadline)
                    .fontWeight(.bold)
                    .foregroundStyle(proLocked ? DSColor.textTertiary : DSColor.accent)
                    .monospacedDigit()
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(DSColor.fill)
                    Capsule()
                        .fill(proLocked ? DSColor.textTertiary.opacity(0.45) : DSColor.accent)
                        .frame(width: max(6, geo.size.width * metric.fraction))
                }
            }
            .frame(height: 10)

            Text(progressCaption)
                .dsFont(.footnote)
                .foregroundStyle(DSColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .dsCard()
    }

    private var progressCaption: String {
        if proLocked {
            return "You're at \(metric.label). Unlock FTMP Pro to claim this badge when you hit the goal."
        }
        let left = max(0, metric.target - metric.clampedCurrent)
        if left == 0 {
            return "Goal reached — it'll unlock on your next progress sync."
        }
        return left == 1
            ? "1 more to go."
            : "\(left) more to go."
    }

    private var unlockedCard: some View {
        HStack(spacing: DSSpacing.sm) {
            Image(systemName: "checkmark.seal.fill")
                .font(.title2)
                .foregroundStyle(tierColor)
            VStack(alignment: .leading, spacing: 2) {
                Text("Completed")
                    .dsFont(.headline)
                    .foregroundStyle(DSColor.textPrimary)
                Text("Final progress \(metric.label)")
                    .dsFont(.footnote)
                    .foregroundStyle(DSColor.textSecondary)
            }
            Spacer(minLength: 0)
        }
        .dsCard()
    }
}
