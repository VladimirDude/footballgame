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
                        aboutSection(detail)
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

                if let age = detail.age {
                    Text("Age \(age)")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.75))
                }
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
            if let peak = detail.formattedPeakValue {
                StatTile(
                    title: "Peak Value",
                    value: peak,
                    icon: "chart.line.uptrend.xyaxis",
                    tint: .orange
                )
            }
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
        }
    }

    @ViewBuilder
    private func aboutSection(_ detail: PlayerDetail) -> some View {
        let rows: [(String, String, String)] = [
            detail.age.map { ("Age", "\($0)", "calendar") },
            detail.formattedFoot.map { ("Preferred foot", $0, "figure.walk") },
            detail.formattedHeight.map { ("Height", $0, "ruler") },
            detail.countryOfBirth.map { ("Born in", $0, "mappin.and.ellipse") },
            detail.dateOfBirth.map { ("Date of birth", Self.displayDOB($0), "calendar") },
        ].compactMap { $0 }

        if !rows.isEmpty {
            BrowseCard {
                VStack(alignment: .leading, spacing: 12) {
                    SectionHeader(title: "About", icon: "person.text.rectangle.fill")
                    ForEach(rows, id: \.0) { title, value, icon in
                        HStack(spacing: 12) {
                            Image(systemName: icon)
                                .font(.body.weight(.semibold))
                                .foregroundStyle(BrowseTheme.accent)
                                .frame(width: 22)
                            Text(title)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(value)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.primary)
                                .multilineTextAlignment(.trailing)
                        }
                    }
                }
            }
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
                            if let league = detail.league {
                                Text(league)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            } else {
                                Text("View full squad")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
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

    private static func displayDOB(_ iso: String) -> String {
        let raw = String(iso.prefix(10))
        let inFormatter = DateFormatter()
        inFormatter.calendar = Calendar(identifier: .gregorian)
        inFormatter.locale = Locale(identifier: "en_US_POSIX")
        inFormatter.timeZone = TimeZone(secondsFromGMT: 0)
        inFormatter.dateFormat = "yyyy-MM-dd"
        guard let date = inFormatter.date(from: raw) else { return raw }
        let out = DateFormatter()
        out.dateStyle = .medium
        out.timeStyle = .none
        return out.string(from: date)
    }
}
