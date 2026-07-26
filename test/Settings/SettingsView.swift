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

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    SubscriptionSettingsSection()
                } header: {
                    Label("FTMP Pro", systemImage: "crown.fill")
                }

                Section("Appearance") {
                    Picker(selection: $appearanceModeRaw) {
                        ForEach(AppearanceMode.allCases) { mode in
                            Text(mode.title).tag(mode.rawValue)
                        }
                    } label: {
                        Label("Theme", systemImage: "circle.lefthalf.filled")
                    }
                    .pickerStyle(.segmented)
                }

                Section {
                    Toggle(isOn: $hapticsEnabled) {
                        Label("Haptic Feedback", systemImage: "iphone.radiowaves.left.and.right")
                    }
                    Toggle(isOn: $predictorSimulateOnly) {
                        Label("Simulate Only", systemImage: "sportscourt.fill")
                    }
                    Toggle(isOn: relaxedBinding) {
                        HStack(spacing: DSSpacing.xs) {
                            Label("Relaxed Mode", systemImage: "timer")
                            if !entitlements.canAccess(.relaxedMode) { PremiumBadge() }
                        }
                    }
                } header: {
                    Text("Gameplay")
                } footer: {
                    Text("Relaxed Mode removes the timers from Guess Player and Higher or Lower.")
                }

                Section("Accent") {
                    ForEach(AppAccent.allCases) { accent in
                        accentRow(accent)
                    }
                }

                Section("Database") {
                    LabeledContent("Clubs", value: "\(store.clubCount)")
                    LabeledContent("Players", value: "\(store.playerCount)")
                    LabeledContent("Mode", value: "Offline")
                }

                Section("Help") {
                    Button {
                        hasCompletedOnboarding = false
                    } label: {
                        Label("Show Tutorial Again", systemImage: "book.pages.fill")
                    }
                }

                Section("Support & Legal") {
                    Button { requestReview() } label: {
                        Label("Rate FTMP", systemImage: "star.fill")
                    }
                    Button { openURL(URL(string: "mailto:support@ftmpapp.com")!) } label: {
                        Label("Contact Support", systemImage: "envelope.fill")
                    }
                    Link(destination: URL(string: "https://ftmpapp.com/privacy")!) {
                        Label("Privacy Policy", systemImage: "lock.fill")
                    }
                    Link(destination: URL(string: "https://ftmpapp.com/terms")!) {
                        Label("Terms of Use", systemImage: "doc.text.fill")
                    }
                    Button(role: .destructive) { showResetConfirm = true } label: {
                        Label("Reset All Data", systemImage: "trash.fill")
                    }
                }

                Section {
                    LabeledContent("Version", value: appVersion)
                } header: {
                    Text("About")
                } footer: {
                    Text(AppBranding.about)
                }
            }
            .navigationTitle("Settings")
            .tint(DSColor.accent)
        }
        .paywallSheet(isPresented: $showPaywall, source: "settings_feature")
        .alert("Reset All Data?", isPresented: $showResetConfirm) {
            Button("Reset", role: .destructive) { resetAllData() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This clears your game scores, predictions, and saved team data. This can't be undone.")
        }
    }

    // MARK: - Accent row

    @ViewBuilder
    private func accentRow(_ accent: AppAccent) -> some View {
        let isSelected = accentRaw == accent.rawValue
        let locked = !accent.isFree && !entitlements.canAccess(.themePacks)
        Button {
            selectAccent(accent)
        } label: {
            HStack(spacing: DSSpacing.sm) {
                Circle()
                    .fill(accent.color)
                    .frame(width: 24, height: 24)
                    .overlay(Circle().stroke(DSColor.separator, lineWidth: 1))
                    .accessibilityHidden(true)
                Text(accent.displayName)
                    .foregroundStyle(DSColor.textPrimary)
                Spacer()
                if locked {
                    PremiumBadge()
                } else if isSelected {
                    Image(systemName: "checkmark")
                        .fontWeight(.bold)
                        .foregroundStyle(DSColor.accent)
                }
            }
            .contentShape(Rectangle())
        }
        .accessibilityLabel(accent.displayName)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    // MARK: - Gating helpers

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

    // MARK: - Data

    private var appVersion: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = info?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }

    private func resetAllData() {
        let defaults = UserDefaults.standard
        for key in ["guessClubBestStreak", "guessNationBestStreak", "guessPlayerBestStreak",
                    "higherOrLowerHighScore", "wordleBestStreak"] {
            defaults.removeObject(forKey: key)
        }
        PredictorStore.shared.resetAllProgress()
        try? FileManager.default.removeItem(at: DataExporter.saveURL)
        HapticFeedback.success()
    }
}
