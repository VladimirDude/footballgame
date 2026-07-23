import SwiftUI
#if canImport(FirebaseCore)
import FirebaseCore
#endif

@main
struct testApp: App {
    @AppStorage("appearanceMode") private var appearanceModeRaw = AppearanceMode.system.rawValue
    @AppStorage(OnboardingStorage.completedKey) private var hasCompletedOnboarding = false

    @StateObject private var monetization = MonetizationContainer()

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
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if hasCompletedOnboarding {
                    MainTabView()
                } else {
                    OnboardingView {
                        hasCompletedOnboarding = true
                    }
                }
            }
            .preferredColorScheme(appearanceMode.colorScheme)
            .withAppPalette()
            .withMonetization(monetization)
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
