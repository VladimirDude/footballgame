import SwiftUI

struct PlayerProfileView: View {
    let playerID: String
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    private let store = ClubDataStore.shared

    private var detail: PlayerDetail? {
        store.playerDetail(id: playerID)
    }

    var body: some View {
        Group {
            if let detail {
                ScrollView {
                    VStack(spacing: 16) {
                        heroSection(detail)
                        statsSection(detail)
                        nationalitySection(detail)
                        clubSection(detail)
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 24)
                }
                .adaptiveContentWidth(AdaptiveLayout.detailMaxWidth)
            } else {
                ContentUnavailableView("Player not found", systemImage: "person.slash")
            }
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(detail?.name ?? "Player")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func heroSection(_ detail: PlayerDetail) -> some View {
        VStack(spacing: 14) {
            PlayerPortraitImage(playerID: detail.id, style: .hero)

            VStack(spacing: 6) {
                Text(detail.name)
                    .font(.title.bold())
                    .multilineTextAlignment(.center)

                Text(detail.position)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.9))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(Color.white.opacity(0.18)))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .padding(.horizontal, 16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(BrowseTheme.pitchGradient)
        )
    }

    private func statsSection(_ detail: PlayerDetail) -> some View {
        let columns = horizontalSizeClass == .regular
            ? [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]
            : [GridItem(.flexible()), GridItem(.flexible())]

        return LazyVGrid(columns: columns, spacing: 10) {
            StatTile(
                title: "Market Value",
                value: detail.formattedMarketValue,
                icon: "eurosign.circle.fill",
                tint: .green
            )
            StatTile(
                title: "Squad Rank",
                value: "#\(detail.squadRank) of \(detail.squadSize)",
                icon: "list.number",
                tint: BrowseTheme.accent
            )
            StatTile(
                title: "Position Group",
                value: detail.positionGroup.rawValue,
                icon: detail.positionGroup.icon,
                tint: .blue
            )
            StatTile(
                title: "Photo",
                value: detail.hasPortrait ? "Available" : "Placeholder",
                icon: detail.hasPortrait ? "photo.fill" : "person.fill.questionmark",
                tint: detail.hasPortrait ? .purple : .gray
            )
        }
    }

    private func nationalitySection(_ detail: PlayerDetail) -> some View {
        BrowseCard {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader(title: "Nationality", icon: "flag.fill")

                if detail.nationalities.isEmpty {
                    Text("Unknown")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(detail.nationalities, id: \.self) { country in
                        HStack(spacing: 10) {
                            Text(CountryFlags.flag(for: country))
                                .font(.title2)
                            Text(country)
                                .font(.body)
                        }
                    }
                }
            }
        }
    }

    private func clubSection(_ detail: PlayerDetail) -> some View {
        BrowseCard {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader(title: "Current Club", icon: "shield.fill")

                NavigationLink {
                    ClubDetailView(clubID: detail.clubID)
                } label: {
                    HStack(spacing: 12) {
                        ClubLogoImage(clubID: detail.clubID, clubName: detail.clubName, style: .card)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(detail.clubName)
                                .font(.headline)
                                .foregroundStyle(.primary)
                            Text("View full squad")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.caption.bold())
                            .foregroundStyle(.tertiary)
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }
}
