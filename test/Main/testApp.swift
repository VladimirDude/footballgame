import SwiftUI

@main
struct testApp: App {
    @AppStorage("appearanceMode") private var appearanceModeRaw = AppearanceMode.system.rawValue
    @AppStorage(OnboardingStorage.completedKey) private var hasCompletedOnboarding = false

    private var appearanceMode: AppearanceMode {
        AppearanceMode(rawValue: appearanceModeRaw) ?? .system
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
            .onAppear(perform: migrateLegacyAppearanceSetting)
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
