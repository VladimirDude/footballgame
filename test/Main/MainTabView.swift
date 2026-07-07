import SwiftUI

struct MainTabView: View {
    var body: some View {
        TabView {
            SearchView()
                .tabItem {
                    Image(systemName: "magnifyingglass")
                    Text("Search")
                }

            ClubsView()
                .tabItem {
                    Image(systemName: "shield.lefthalf.filled")
                    Text("Clubs")
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
        .accentColor(.orange)
    }
}
