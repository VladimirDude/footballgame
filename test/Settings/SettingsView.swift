import SwiftUI
import StoreKit

struct SettingsView: View {
    @EnvironmentObject private var entitlements: EntitlementService
    @EnvironmentObject private var progress: GameProgressStore
    @Environment(\.requestReview) private var requestReview
    @Environment(\.openURL) private var openURL
    @ObservedObject private var reminders = DailyReminderService.shared
    @State private var showResetConfirm = false
    @State private var showNotificationSettingsAlert = false
    @AppStorage("appearanceMode") private var appearanceModeRaw = AppearanceMode.system.rawValue
    @AppStorage(AppAccent.storageKey) private var accentRaw = AppAccent.classic.rawValue
    @AppStorage(OnboardingStorage.completedKey) private var hasCompletedOnboarding = false
    @AppStorage(DailyReminderService.enabledKey) private var dailyReminderEnabled = false
    @State private var showPaywall = false
    @State private var reminderTime = DailyReminderService.shared.reminderTime

    private let store = ClubDataStore.shared

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    SubscriptionSettingsSection()
                } header: {
                    Label("FTMP Pro", systemImage: "crown.fill")
                }

                Section {
                    Toggle(isOn: dailyReminderBinding) {
                        Label("Daily Challenge reminder", systemImage: "bell.badge.fill")
                    }

                    if dailyReminderEnabled {
                        DatePicker(
                            "Remind me at",
                            selection: reminderTimeBinding,
                            displayedComponents: .hourAndMinute
                        )
                    }
                } header: {
                    Text("Notifications")
                } footer: {
                    Text(reminderFooter)
                }

                Section("Appearance") {
                    Picker(selection: appearanceModeBinding) {
                        ForEach(AppearanceMode.allCases) { mode in
                            Text(mode.title).tag(mode.rawValue)
                        }
                    } label: {
                        Label("Theme", systemImage: "circle.lefthalf.filled")
                    }
                    .pickerStyle(.segmented)
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
                    Button { openURL(URL(string: "mailto:support@ftmpapp.app")!) } label: {
                        Label("Contact Support", systemImage: "envelope.fill")
                    }
                    Link(destination: URL(string: "https://ftmpapp.app/privacy")!) {
                        Label("Privacy Policy", systemImage: "lock.fill")
                    }
                    Link(destination: URL(string: "https://ftmpapp.app/terms")!) {
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
            .adaptiveContentWidth(AdaptiveLayout.settingsMaxWidth)
            .task {
                await reminders.refreshAuthorizationStatus()
                reminderTime = reminders.reminderTime
                // Keep AppStorage in sync if permission was revoked in System Settings.
                if dailyReminderEnabled && reminders.needsOpenSettings {
                    dailyReminderEnabled = false
                    await reminders.setEnabled(false, completedToday: progress.dailyCompletedToday)
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
                Task {
                    await reminders.refreshAuthorizationStatus()
                    if dailyReminderEnabled && reminders.needsOpenSettings {
                        dailyReminderEnabled = false
                        await reminders.setEnabled(false, completedToday: progress.dailyCompletedToday)
                    } else if dailyReminderEnabled {
                        await reminders.reschedule(completedToday: progress.dailyCompletedToday)
                    }
                }
            }
        }
        .paywallSheet(isPresented: $showPaywall, source: "settings_feature")
        .alert("Reset All Data?", isPresented: $showResetConfirm) {
            Button("Reset", role: .destructive) { resetAllData() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This clears your game scores, predictions, and saved team data. This can't be undone.")
        }
        .alert("Enable notifications", isPresented: $showNotificationSettingsAlert) {
            Button("Open Settings") { reminders.openSystemSettings() }
            Button("Not now", role: .cancel) {}
        } message: {
            Text("Turn on notifications for FTMP in Settings so we can remind you about the Daily Challenge.")
        }
    }

    // MARK: - Daily reminder

    private var reminderFooter: String {
        if reminders.needsOpenSettings {
            return "Notifications are off for FTMP. Enable them in Settings to get Daily Challenge reminders."
        }
        if let error = reminders.lastScheduleError, dailyReminderEnabled {
            return "Couldn't schedule reminders: \(error)"
        }
        if dailyReminderEnabled {
            return "We'll nudge you if you haven't played today's Daily Challenge yet. No ping after you've completed it."
        }
        return "Get a reminder to play the Daily Challenge and protect your streak."
    }

    private var dailyReminderBinding: Binding<Bool> {
        Binding(
            get: { dailyReminderEnabled },
            set: { newValue in
                Task { await applyReminderEnabled(newValue) }
            }
        )
    }

    private var reminderTimeBinding: Binding<Date> {
        Binding(
            get: { reminderTime },
            set: { newValue in
                reminderTime = newValue
                reminders.setReminderTime(newValue)
                Task {
                    await reminders.reschedule(completedToday: progress.dailyCompletedToday)
                }
            }
        )
    }

    private func applyReminderEnabled(_ enabled: Bool) async {
        if enabled {
            await reminders.refreshAuthorizationStatus()
            if reminders.needsOpenSettings {
                dailyReminderEnabled = false
                showNotificationSettingsAlert = true
                return
            }
            let active = await reminders.setEnabled(true, completedToday: progress.dailyCompletedToday)
            dailyReminderEnabled = active
            if !active, reminders.needsOpenSettings {
                // User dismissed the system permission prompt without granting.
                showNotificationSettingsAlert = true
            }
        } else {
            dailyReminderEnabled = false
            _ = await reminders.setEnabled(false, completedToday: progress.dailyCompletedToday)
        }
    }

    // MARK: - Accent row

    /// Appearance changes must not animate — Liquid Glass chrome (tab bar, nav,
    /// materials) interpolates badly across light/dark and flashes/tears.
    private var appearanceModeBinding: Binding<String> {
        Binding(
            get: { appearanceModeRaw },
            set: { newValue in
                var transaction = Transaction()
                transaction.disablesAnimations = true
                withTransaction(transaction) {
                    appearanceModeRaw = newValue
                }
            }
        )
    }

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
        progress.reset()
        AliasStatsStore.shared.reset()
        PredictorStore.shared.resetAllProgress()
        // Teams now live in `TeamData/` (one folder each, plus images and the
        // index); removing only the legacy file would leave a half-reset app.
        try? FileManager.default.removeItem(at: DataExporter.saveURL)
        try? FileManager.default.removeItem(at: DataExporter.previousSaveURL)
        try? FileManager.default.removeItem(
            at: DataExporter.documentsURL.appendingPathComponent("TeamData", isDirectory: true)
        )
        for key in ["teamSync.teamID", "teamSync.role", "teamSync.memberships.v2"] {
            defaults.removeObject(forKey: key)
        }
        HapticFeedback.success()
    }
}
