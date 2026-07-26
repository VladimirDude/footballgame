import SwiftUI

struct MainTabView: View {
    @AppStorage(AppAccent.storageKey) private var accentRaw = AppAccent.classic.rawValue

    var body: some View {
        TabView {
            ProfileView()
                .tabItem {
                    Image(systemName: "person.fill")
                    Text("You")
                }

            NavigationStack {
                MyTeamView()
            }
            .tabItem {
                Image(systemName: "person.3.fill")
                Text("My Team")
            }

            SettingsView()
                .tabItem {
                    Image(systemName: "gearshape.fill")
                    Text("Settings")
                }
        }
        .tabViewStyle(.sidebarAdaptable)
        .tint(AppAccent.from(accentRaw).color)
        .overlay(alignment: .top) { AchievementBannerHost() }
    }
}
