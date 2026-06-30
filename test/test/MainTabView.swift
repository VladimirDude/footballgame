import SwiftUI

struct MainTabView: View {
    var body: some View {
        TabView {

            SearchView()
                .tabItem {
                    Image(systemName: "magnifyingglass")
                    Text("Search")
                }

            GameView()
                .tabItem {
                    Image(systemName: "gamecontroller.fill")
                    Text("Game")
                }
        }
    }
}
