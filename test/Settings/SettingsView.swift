import SwiftUI

struct SettingsView: View {
    @AppStorage("appearanceMode") private var appearanceModeRaw = AppearanceMode.system.rawValue
    @AppStorage("hapticsEnabled") private var hapticsEnabled = true
    @AppStorage(PredictorStore.simulateOnlyKey) private var predictorSimulateOnly = false
    @AppStorage(OnboardingStorage.completedKey) private var hasCompletedOnboarding = false

    private let store = ClubDataStore.shared

    private var appearanceSelection: AppearanceMode {
        AppearanceMode(rawValue: appearanceModeRaw) ?? .system
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    headerCard

                    settingsSection(title: "FTMP Pro", icon: "crown.fill") {
                        SubscriptionSettingsSection()
                    }

                    settingsSection(title: "Appearance", icon: "paintbrush.fill") {
                        VStack(spacing: 10) {
                            ForEach(AppearanceMode.allCases) { mode in
                                appearanceRow(mode)
                            }
                        }
                    }

                    settingsSection(title: "Gameplay", icon: "gamecontroller.fill") {
                        Toggle(isOn: $hapticsEnabled) {
                            SettingsRowLabel(
                                title: "Haptic Feedback",
                                subtitle: "Vibrate on correct and wrong answers",
                                icon: "iphone.radiowaves.left.and.right",
                                tint: .purple
                            )
                        }
                        .tint(BrowseTheme.accent)

                        Divider().padding(.leading, 52)

                        Toggle(isOn: $predictorSimulateOnly) {
                            SettingsRowLabel(
                                title: "Simulate Only",
                                subtitle: "Skip predictions and just run match simulations",
                                icon: "sportscourt.fill",
                                tint: .green
                            )
                        }
                        .tint(BrowseTheme.accent)
                    }

                    settingsSection(title: "Database", icon: "externaldrive.fill") {
                        VStack(spacing: 0) {
                            infoRow(title: "Clubs", value: "\(store.clubCount)", icon: "shield.fill")
                            Divider().padding(.leading, 52)
                            infoRow(title: "Players", value: "\(store.playerCount)", icon: "person.3.fill")
                            Divider().padding(.leading, 52)
                            infoRow(title: "Mode", value: "Offline", icon: "wifi.slash")
                        }
                    }

                    settingsSection(title: "Help", icon: "questionmark.circle.fill") {
                        Button {
                            withAnimation(.easeInOut(duration: 0.25)) {
                                hasCompletedOnboarding = false
                            }
                        } label: {
                            HStack(spacing: 14) {
                                ZStack {
                                    Circle()
                                        .fill(BrowseTheme.accent.opacity(0.15))
                                        .frame(width: 40, height: 40)
                                    Image(systemName: "book.pages.fill")
                                        .foregroundStyle(BrowseTheme.accent)
                                }

                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Show Tutorial Again")
                                        .font(.body.weight(.semibold))
                                        .foregroundStyle(.primary)
                                    Text("Replay the app walkthrough")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()

                                Image(systemName: "chevron.right")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.tertiary)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }

                    settingsSection(title: "About", icon: "info.circle.fill") {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(AppBranding.name)
                                .font(.headline)
                            Text(AppBranding.about)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 28)
                .adaptiveContentWidth(AdaptiveLayout.settingsMaxWidth)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Settings")
        }
    }

    private var headerCard: some View {
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(BrowseTheme.pitchGradient)
                    .frame(width: 64, height: 64)
                Text(AppBranding.name)
                    .font(.headline.bold())
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(AppBranding.name)
                    .font(.title2.bold())
                Text(AppBranding.tagline)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
        .padding(18)
        .background(settingsCardBackground)
    }

    private func settingsSection<Rows: View>(
        title: String,
        icon: String,
        @ViewBuilder rows: () -> Rows
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: icon)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 4)

            rows()
                .padding(16)
                .background(settingsCardBackground)
        }
    }

    private var settingsCardBackground: some View {
        RoundedRectangle(cornerRadius: 18, style: .continuous)
            .fill(Color(.secondarySystemGroupedBackground))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.primary.opacity(0.06), lineWidth: 1)
            )
    }

    private func appearanceRow(_ mode: AppearanceMode) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                appearanceModeRaw = mode.rawValue
            }
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(BrowseTheme.accent.opacity(appearanceSelection == mode ? 0.2 : 0.1))
                        .frame(width: 40, height: 40)
                    Image(systemName: mode.icon)
                        .foregroundStyle(appearanceSelection == mode ? BrowseTheme.accent : .secondary)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(mode.title)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.primary)
                    Text(mode.subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if appearanceSelection == mode {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(BrowseTheme.accent)
                }
            }
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func infoRow(title: String, value: String, icon: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.body)
                .foregroundStyle(BrowseTheme.accent)
                .frame(width: 28)

            Text(title)
                .font(.body)

            Spacer()

            Text(value)
                .font(.body.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 10)
    }
}

private struct SettingsRowLabel: View {
    let title: String
    let subtitle: String
    let icon: String
    let tint: Color

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(tint.opacity(0.15))
                    .frame(width: 40, height: 40)
                Image(systemName: icon)
                    .foregroundStyle(tint)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body.weight(.semibold))
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
