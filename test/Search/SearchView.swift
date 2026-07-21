import SwiftUI

private enum BrowseSection: String, CaseIterable, Identifiable {
    case players = "Players"
    case clubs = "Clubs"

    var id: String { rawValue }
}

struct SearchView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    @State private var section: BrowseSection = .players
    @State private var playerQuery = ""
    @State private var clubQuery = ""
    @State private var players: [Player] = []
    @State private var playerFilters = PlayerSearchFilters()

    private let store = ClubDataStore.shared

    private var clubs: [ClubSummary] {
        store.searchClubs(clubQuery)
    }

    private var canSearchPlayers: Bool {
        playerQuery.trimmingCharacters(in: .whitespacesAndNewlines).count >= 2 || playerFilters.isActive
    }

    private var clubColumns: [GridItem] {
        AdaptiveLayout.gridColumns(for: horizontalSizeClass)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground).ignoresSafeArea()

                VStack(spacing: 12) {
                    Picker("Browse", selection: $section) {
                        ForEach(BrowseSection.allCases) { item in
                            Text(item.rawValue).tag(item)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                    .padding(.top, 8)

                    switch section {
                    case .players:
                        playerBrowseContent
                    case .clubs:
                        clubBrowseContent
                    }
                }
                .adaptiveContentWidth()
            }
            .navigationTitle("Search")
        }
    }

    private var playerBrowseContent: some View {
        VStack(spacing: 12) {
            BrowseSearchField(placeholder: "Search player", text: $playerQuery, onSubmit: searchPlayers)
                .padding(.horizontal)
                .onChange(of: playerQuery) { _, _ in
                    searchPlayers()
                }

            SearchFiltersBar(
                filters: $playerFilters,
                clubs: store.allClubSummaries(),
                leagues: store.allLeagues(),
                nationalities: store.allNationalities()
            )
            .onChange(of: playerFilters) { _, _ in
                searchPlayers()
            }

            Text("\(store.playerCount) players · offline")
                .font(.caption)
                .foregroundStyle(.secondary)

            if !canSearchPlayers {
                ContentUnavailableView(
                    "Search players",
                    systemImage: "person.fill",
                    description: Text("Type at least 2 characters or pick a filter.")
                )
            } else if players.isEmpty {
                ContentUnavailableView(
                    "No Results",
                    systemImage: "magnifyingglass",
                    description: Text("No players match your search or filters.")
                )
            } else if horizontalSizeClass == .regular {
                ScrollView {
                    LazyVGrid(columns: clubColumns, spacing: 12) {
                        ForEach(players) { player in
                            NavigationLink {
                                PlayerProfileView(playerID: player.id)
                            } label: {
                                PlayerResultCard(player: player)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 24)
                }
            } else {
                List(players) { player in
                    NavigationLink {
                        PlayerProfileView(playerID: player.id)
                    } label: {
                        PlayerResultRow(player: player)
                    }
                }
                .listStyle(.plain)
            }
        }
    }

    private var clubBrowseContent: some View {
        ScrollView {
            VStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Club Browser")
                                .font(.title2.bold())
                                .foregroundStyle(.white)
                            Text("\(store.clubCount) clubs · offline database")
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.8))
                        }
                        Spacer()
                        Image(systemName: "shield.lefthalf.filled")
                            .font(.title)
                            .foregroundStyle(.white.opacity(0.9))
                    }
                }
                .padding(18)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(BrowseTheme.pitchGradient)
                )

                TextField("Search club", text: $clubQuery)
                    .textFieldStyle(.plain)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 11)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color(.tertiarySystemGroupedBackground))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Color.primary.opacity(0.06), lineWidth: 1)
                    )
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)

                LazyVGrid(columns: clubColumns, spacing: 10) {
                    ForEach(clubs) { club in
                        NavigationLink {
                            ClubDetailView(clubID: club.id)
                        } label: {
                            ClubRowCard(club: club)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 24)
        }
    }

    private func searchPlayers() {
        players = store.searchPlayers(playerQuery, filters: playerFilters)
    }
}

private struct PlayerResultRow: View {
    let player: Player

    var body: some View {
        HStack(spacing: 14) {
            PlayerPortraitImage(playerID: player.id, style: .compact)

            VStack(alignment: .leading, spacing: 5) {
                Text(player.name)
                    .font(.headline)

                HStack(spacing: 6) {
                    Text(CountryFlags.primaryFlag(from: player.nationalities))
                    Text(player.club)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("· \(player.position)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Text(player.marketValue)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.green)
            }
        }
        .padding(.vertical, 4)
    }
}

private struct PlayerResultCard: View {
    let player: Player

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                PlayerPortraitImage(playerID: player.id, style: .compact)

                VStack(alignment: .leading, spacing: 4) {
                    Text(player.name)
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .lineLimit(2)

                    Text(player.marketValue)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.green)
                }

                Spacer(minLength: 0)
            }

            HStack(spacing: 6) {
                Text(CountryFlags.primaryFlag(from: player.nationalities))
                Text(player.club)
                    .lineLimit(1)
                Text("·")
                Text(player.position)
                    .lineLimit(1)
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.primary.opacity(0.06), lineWidth: 1)
        )
    }
}
