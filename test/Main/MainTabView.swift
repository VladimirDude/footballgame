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
                    .toolbar(.hidden, for: .navigationBar)
            }
            .tabItem {
                Image(systemName: "gamecontroller.fill")
                Text("Game")
            }

            NavigationStack {
                PredictorView()
            }
            .tabItem {
                Image(systemName: "play.circle.fill")
                Text("Simulate")
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
        .tint(BrowseTheme.accent)
    }
}
