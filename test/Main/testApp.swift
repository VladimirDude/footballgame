import SwiftUI
#if canImport(FirebaseCore)
import FirebaseCore
#endif

@main
struct testApp: App {
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
            .onAppear {
                migrateLegacyAppearanceSetting()
                monetization.start()
                AnalyticsService.shared.log(.appOpened)
                Task.detached(priority: .utility) {
                    await RemoteDataRepository.shared.refreshIfNeeded()
                }
            }
        }
    }

    private func migrateLegacyAppearanceSetting() {
        guard UserDefaults.standard.object(forKey: "appearanceMode") == nil,
              let isDarkMode = UserDefaults.standard.object(forKey: "isDarkMode") as? Bool else {
            return
        }
        appearanceModeRaw = isDarkMode ? AppearanceMode.dark.rawValue : AppearanceMode.light.rawValue
    }
}
