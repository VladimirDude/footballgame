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
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .onSubmit { searchPlayers() }
                    .onChange(of: query) { _, newValue in
                        let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                        if trimmed.count >= 2 {
                            searchPlayers()
                        } else if trimmed.isEmpty {
                            players = []
                        }
                    }

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

                if query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    ContentUnavailableView(
                        "Search players",
                        systemImage: "magnifyingglass",
                        description: Text("Type at least 2 characters to search.")
                    )
                } else if players.isEmpty {
                    ContentUnavailableView.search(text: query)
                } else {
                    List(players) { player in
                        NavigationLink {
                            PlayerProfileView(player: player)
                        } label: {
                            HStack(spacing: 14) {
                                PlayerPortraitImage(
                                    playerID: player.id,
                                    imageValue: player.image,
                                    style: .compact
                                )

                                VStack(alignment: .leading, spacing: 5) {
                                    Text(player.name)
                                        .font(.headline)

                                    HStack(spacing: 6) {
                                        Text(CountryFlags.primaryFlag(from: player.nationalities ?? []))
                                        Text("\(player.club) · \(player.position)")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }

                                    Text(player.marketValue)
                                        .font(.caption.weight(.semibold))
                                        .foregroundColor(.green)
                                }

                                Spacer(minLength: 0)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Search Players")
        }
    }

    private func searchPlayers() {
        players = store.searchPlayers(query)
    }
}
