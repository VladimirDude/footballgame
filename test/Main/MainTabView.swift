import SwiftUI

struct MainTabView: View {
    var body: some View {
        TabView {
            SearchView()
                .tabItem {
                    Image(systemName: "magnifyingglass")
                    Text("Search")
                }

            NavigationStack {
                GameView()
            }
            .tabItem {
                Image(systemName: "gamecontroller.fill")
                Text("Game")
            }

            SettingsView()
                .tabItem {
                    Image(systemName: "gearshape.fill")
                    Text("Settings")
                }
        }
        .tabViewStyle(.sidebarAdaptable)
        .tint(BrowseTheme.accent)
    }
}
