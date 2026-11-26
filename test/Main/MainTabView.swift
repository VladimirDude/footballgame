import SwiftUI

struct MainTabView: View {
    /// Hides the "My Team" tab without removing the feature's code.
    static let showsMyTeamTab = false

    @AppStorage(AppAccent.storageKey) private var accentRaw = AppAccent.classic.rawValue
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        TabView {
            ProfileView()
                .tabItem {
                    Image(systemName: "person.fill")
                    Text("You")
                }

            // "My Team" tab hidden for now. Flip `showsMyTeamTab` to bring it back.
            if Self.showsMyTeamTab {
                NavigationStack {
                    MyTeamView()
                }
                .tabItem {
                    Image(systemName: "person.3.fill")
                    Text("My Team")
                }
            }

            SettingsView()
                .tabItem {
                    Image(systemName: "gearshape.fill")
                    Text("Settings")
                }
        }
        .sidebarAdaptableTabStyle()
        .tint(AppAccent.from(accentRaw).color)
        // Force Liquid Glass tab chrome to rebuild on scheme change without
        // animating through a broken intermediate material state.
        .animation(nil, value: colorScheme)
        .overlay(alignment: .top) { AchievementBannerHost() }
    }
}

private extension View {
    /// `.sidebarAdaptable` is iOS 18+; fall back to the default tab style below that.
    @ViewBuilder
    func sidebarAdaptableTabStyle() -> some View {
        if #available(iOS 18.0, *) {
            tabViewStyle(.sidebarAdaptable)
        } else {
            self
        }
    }
}
