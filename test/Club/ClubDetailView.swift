import SwiftUI

struct ClubDetailView: View {
    let clubID: String
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    private let store = ClubDataStore.shared

    private var club: BundledClub? { store.club(id: clubID) }

    private var squadValue: Int {
        club?.players.reduce(0) { $0 + ($1.marketValue ?? 0) } ?? 0
    }

    private var averageValue: Int {
        guard let club, !club.players.isEmpty else { return 0 }
        return squadValue / club.players.count
    }

    var body: some View {
        Group {
            if let club {
                ScrollView {
                    VStack(spacing: 16) {
                        clubHeader(club)
                        statsGrid(playerCount: club.players.count)

                        ForEach(store.groupedPlayers(for: clubID), id: \.0) { group, players in
                            VStack(spacing: 8) {
                                SectionHeader(title: group.rawValue, icon: group.icon)

                                BrowseCard {
                                    VStack(spacing: 0) {
                                        ForEach(Array(players.enumerated()), id: \.element.id) { index, player in
                                            NavigationLink {
                                                PlayerProfileView(playerID: player.id)
                                            } label: {
                                                SquadPlayerRow(
                                                    player: player,
                                                    rank: index + 1,
                                                    showDivider: index < players.count - 1
                                                )
                                            }
                                            .buttonStyle(.plain)
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 24)
                }
                .adaptiveContentWidth(AdaptiveLayout.detailMaxWidth)
            } else {
                ContentUnavailableView("Club not found", systemImage: "shield.slash")
            }
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(club?.name ?? "Club")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func clubHeader(_ club: BundledClub) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.18))
                        .frame(width: 56, height: 56)
                    Text(club.name.prefix(1).uppercased())
                        .font(.title.bold())
                        .foregroundStyle(.white)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(club.name)
                        .font(.title2.bold())
                        .foregroundStyle(.white)

                    if let official = club.officialName {
                        Text(official)
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.8))
                            .lineLimit(2)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(BrowseTheme.pitchGradient)
        )
    }

    private func statsGrid(playerCount: Int) -> some View {
        let columns = horizontalSizeClass == .regular
            ? [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]
            : [GridItem(.flexible()), GridItem(.flexible())]

        return LazyVGrid(columns: columns, spacing: 10) {
            StatTile(title: "Squad Size", value: "\(playerCount)", icon: "person.3.fill")
            StatTile(title: "Squad Value", value: MarketValueFormatter.format(squadValue), icon: "eurosign.circle.fill")
            StatTile(title: "Average Value", value: MarketValueFormatter.format(averageValue), icon: "chart.bar.fill", tint: .green)
            StatTile(title: "Groups", value: "\(store.groupedPlayers(for: clubID).count)", icon: "square.grid.2x2.fill", tint: .blue)
        }
    }
}

private struct SquadPlayerRow: View {
    let player: ClubSquadPlayer
    let rank: Int
    let showDivider: Bool

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Text("#\(rank)")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                    .frame(width: 28, alignment: .leading)

                PlayerPortraitImage(playerID: player.id, style: .compact)

                VStack(alignment: .leading, spacing: 3) {
                    Text(player.name)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    HStack(spacing: 6) {
                        Text(CountryFlags.primaryFlag(from: player.nationality))
                        Text(player.position)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer(minLength: 0)

                Text(MarketValueFormatter.format(player.marketValue ?? 0))
                    .font(.caption.bold())
                    .foregroundStyle(.green)
            }
            .padding(.vertical, 10)

            if showDivider {
                Divider()
            }
        }
    }
}
