import SwiftUI

struct SearchView: View {

    @State private var query: String = ""
    @State private var players: [Player] = []

    private let store = ClubDataStore.shared

    var body: some View {
        NavigationStack {

            VStack(spacing: 12) {

                TextField("Search player", text: $query)
                    .textFieldStyle(.roundedBorder)
                    .padding(.horizontal)
                    .onSubmit { searchPlayers() }

                Button(action: searchPlayers) {
                    Text("Search")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                        .padding(.horizontal)
                }

                Text("\(store.playerCount) players · \(store.clubCount) clubs · offline")
                    .font(.caption)
                    .foregroundColor(.gray)

                Text("Results: \(players.count)")
                    .font(.caption)
                    .foregroundColor(.gray)

                List(players) { player in

                    NavigationLink {
                        PlayerProfileView(player: player)
                    } label: {

                        HStack(spacing: 12) {

                            Text(CountryFlags.primaryFlag(from: player.nationalities ?? []))
                                .font(.largeTitle)

                            VStack(alignment: .leading) {
                                Text(player.name)
                                Text("\(player.club) · \(player.position)")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                                Text(player.marketValue)
                                    .font(.caption)
                                    .foregroundColor(.green)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Transfermarkt")
        }
    }

    private func searchPlayers() {
        players = store.searchPlayers(query)
    }
}
