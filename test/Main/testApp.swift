import SwiftUI
#if canImport(FirebaseCore)
import FirebaseCore
#endif

@main
struct testApp: App {
    @UIApplicationDelegateAdaptor(FTMPAppDelegate.self) private var appDelegate
    @AppStorage("appearanceMode") private var appearanceModeRaw = AppearanceMode.system.rawValue
    @AppStorage(OnboardingStorage.completedKey) private var hasCompletedOnboarding = false

    @StateObject private var monetization = MonetizationContainer()
    @StateObject private var progress = GameProgressStore.shared
    @StateObject private var alias = AliasContainer()

    private var appearanceMode: AppearanceMode {
        AppearanceMode(rawValue: appearanceModeRaw) ?? .system
    }

    init() {
        #if canImport(FirebaseCore)
        FirebaseApp.configure()
        #endif
        #if canImport(FirebaseAnalytics)
        AnalyticsService.shared.register(FirebaseAnalyticsBackend())
        #endif
        #if canImport(FirebaseRemoteConfig)
        RemoteConfigService.shared.start()
        #endif
    }

    var body: some Scene {
        WindowGroup {
            RootView {
                Group {
                    if hasCompletedOnboarding {
                        MainTabView()
                    } else {
                        OnboardingView {
                            hasCompletedOnboarding = true
                        }
                    }
                }
            }
            .preferredColorScheme(appearanceMode.colorScheme)
            // Liquid Glass / materials glitch when color scheme animates.
            .animation(nil, value: appearanceModeRaw)
            .withAppPalette()
            .withMonetization(monetization)
            .environmentObject(progress)
            .withAlias(alias)
            .background(DailyReminderSceneObserver())
            .onAppear {
                migrateLegacyAppearanceSetting()
                monetization.start()
                let entitlements = monetization.entitlements
                progress.canUnlockProAchievements = { entitlements.isPro }
                progress.refreshWidget()
                AnalyticsService.shared.log(.appOpened)
                Task.detached(priority: .utility) {
                    await RemoteDataRepository.shared.refreshIfNeeded()
                }
                Task { @MainActor in
                    await Self.refreshDailyReminderSchedule()
                }
            }
            .onOpenURL { url in
                guard FTMPDeepLink.isDaily(url) else { return }
                UserDefaults.standard.set(true, forKey: OnboardingStorage.openDailyAfterOnboardingKey)
            }
        }
    }

    @MainActor
    static func refreshDailyReminderSchedule() async {
        let completed = GameProgressStore.shared.dailyCompletedToday
        await DailyReminderService.shared.refreshAuthorizationStatus()
        await DailyReminderService.shared.reschedule(completedToday: completed)
    }

    private func migrateLegacyAppearanceSetting() {
        guard UserDefaults.standard.object(forKey: "appearanceMode") == nil,
              let isDarkMode = UserDefaults.standard.object(forKey: "isDarkMode") as? Bool else {
            return
        }
        appearanceModeRaw = isDarkMode ? AppearanceMode.dark.rawValue : AppearanceMode.light.rawValue
    }
}

/// Keeps the rolling reminder schedule fresh whenever the app becomes active.
private struct DailyReminderSceneObserver: View {
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        Color.clear
            .frame(width: 0, height: 0)
            .onChange(of: scenePhase) { _, phase in
                guard phase == .active else { return }
                Task { @MainActor in
                    GameProgressStore.shared.reconcileDailyStreak()
                    GameProgressStore.shared.refreshWidget()
                    await testApp.refreshDailyReminderSchedule()
                }
            }
    }
}
