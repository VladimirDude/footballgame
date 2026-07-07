import SwiftUI

@main
struct testApp: App {
    // This connects to the same key used in SettingsView
    @AppStorage("isDarkMode") private var isDarkMode = false

    var body: some Scene {
        WindowGroup {
            MainTabView()
                // This forces the entire app to react to your toggle
                .preferredColorScheme(isDarkMode ? .dark : .light)
        }
    }
}
