import SwiftUI
import StoreKit

struct SettingsView: View {
    @EnvironmentObject private var entitlements: EntitlementService
    @Environment(\.requestReview) private var requestReview
    @Environment(\.openURL) private var openURL
    @State private var showResetConfirm = false
    @AppStorage("appearanceMode") private var appearanceModeRaw = AppearanceMode.system.rawValue
    @AppStorage("hapticsEnabled") private var hapticsEnabled = true
    @AppStorage(PredictorStore.simulateOnlyKey) private var predictorSimulateOnly = false
    @AppStorage("gameRelaxedMode") private var relaxedMode = false
    @AppStorage(AppAccent.storageKey) private var accentRaw = AppAccent.classic.rawValue
    @AppStorage(OnboardingStorage.completedKey) private var hasCompletedOnboarding = false
    @State private var showPaywall = false

    private let store = ClubDataStore.shared

    private var appearanceSelection: AppearanceMode {
        AppearanceMode(rawValue: appearanceModeRaw) ?? .system
    }

    /// Relaxed Mode is Pro — free users get the paywall instead of enabling it.
    private var relaxedBinding: Binding<Bool> {
        Binding(
            get: { relaxedMode },
            set: { newValue in
                if !newValue {
                    relaxedMode = false
                } else if entitlements.canAccess(.relaxedMode) {
                    relaxedMode = true
                } else {
                    AnalyticsService.shared.log(.featureBlocked(feature: PremiumFeature.relaxedMode.rawValue))
                    showPaywall = true
                }
            }
        )
    }

    private func selectAccent(_ accent: AppAccent) {
        if accent.isFree || entitlements.canAccess(.themePacks) {
            accentRaw = accent.rawValue
        } else {
            AnalyticsService.shared.log(.featureBlocked(feature: PremiumFeature.themePacks.rawValue))
            showPaywall = true
        }
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

                        Divider().padding(.leading, 52)

                        Toggle(isOn: relaxedBinding) {
                            HStack(spacing: 8) {
                                SettingsRowLabel(
                                    title: "Relaxed Mode",
                                    subtitle: "No timers on Guess Player & Higher or Lower",
                                    icon: "timer",
                                    tint: .blue
                                )
                                if !entitlements.canAccess(.relaxedMode) { PremiumBadge() }
                            }
                        }
                        .tint(BrowseTheme.accent)
                    }

                    settingsSection(title: "Theme", icon: "paintpalette.fill") {
                        VStack(spacing: 10) {
                            ForEach(AppAccent.allCases) { accent in
                                accentRow(accent)
                            }
                        }
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

                    settingsSection(title: "Support & Legal", icon: "hand.raised.fill") {
                        VStack(spacing: 0) {
                            linkRow(title: "Rate FTMP", icon: "star.fill", tint: .yellow) {
                                requestReview()
                            }
                            Divider().padding(.leading, 52)
                            linkRow(title: "Contact Support", icon: "envelope.fill", tint: .blue) {
                                openURL(URL(string: "mailto:support@ftmpapp.com")!)
                            }
                            Divider().padding(.leading, 52)
                            linkRow(title: "Privacy Policy", icon: "lock.fill", tint: .gray) {
                                openURL(URL(string: "https://ftmpapp.com/privacy")!)
                            }
                            Divider().padding(.leading, 52)
                            linkRow(title: "Terms of Use", icon: "doc.text.fill", tint: .gray) {
                                openURL(URL(string: "https://ftmpapp.com/terms")!)
                            }
                            Divider().padding(.leading, 52)
                            linkRow(title: "Reset All Data", icon: "trash.fill", tint: .red) {
                                showResetConfirm = true
                            }
                        }
                    }

                    settingsSection(title: "About", icon: "info.circle.fill") {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(AppBranding.name)
                                .font(.headline)
                            Text(AppBranding.about)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                            Divider().padding(.vertical, 4)
                            HStack {
                                Text("Version").foregroundStyle(.secondary)
                                Spacer()
                                Text(appVersion).foregroundStyle(.tertiary)
                            }
                            .font(.subheadline)
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
        .paywallSheet(isPresented: $showPaywall, source: "settings_feature")
        .alert("Reset All Data?", isPresented: $showResetConfirm) {
            Button("Reset", role: .destructive) { resetAllData() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This clears your game scores, predictions, and saved team data. This can't be undone.")
        }
    }

    private var appVersion: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = info?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }

    private func resetAllData() {
        let defaults = UserDefaults.standard
        // Game scores
        for key in ["guessClubBestStreak", "guessNationBestStreak", "guessPlayerBestStreak",
                    "higherOrLowerHighScore", "wordleBestStreak"] {
            defaults.removeObject(forKey: key)
        }
        // Predictor progress
        PredictorStore.shared.resetAllProgress()
        // Saved team data
        try? FileManager.default.removeItem(at: DataExporter.saveURL)
        HapticFeedback.success()
    }

    private func linkRow(title: String, icon: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                ZStack {
                    Circle().fill(tint.opacity(0.15)).frame(width: 40, height: 40)
                    Image(systemName: icon).foregroundStyle(tint)
                }
                Text(title)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(tint == .red ? Color.red : .primary)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func accentRow(_ accent: AppAccent) -> some View {
        let isSelected = accentRaw == accent.rawValue
        let locked = !accent.isFree && !entitlements.canAccess(.themePacks)
        return Button {
            selectAccent(accent)
        } label: {
            HStack(spacing: 14) {
                Circle()
                    .fill(accent.color)
                    .frame(width: 28, height: 28)
                    .overlay(Circle().stroke(Color.primary.opacity(0.1), lineWidth: 1))
                Text(accent.displayName)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.primary)
                Spacer()
                if locked {
                    PremiumBadge()
                } else if isSelected {
                    Image(systemName: "checkmark")
                        .foregroundStyle(accent.color)
                        .fontWeight(.bold)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
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
