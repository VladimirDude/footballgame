import SwiftUI

struct ClubsView: View {
    @State private var query = ""
    private let store = ClubDataStore.shared

    private var clubs: [ClubSummary] {
        store.searchClubs(query)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground).ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 16) {
                        header

                        LazyVStack(spacing: 10) {
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
            .navigationTitle("Clubs")
            .searchable(text: $query, prompt: "Search clubs")
        }
    }

    private var header: some View {
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
    }
}

private struct ClubRowCard: View {
    let club: ClubSummary

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(BrowseTheme.pitchGradient)
                Text(club.name.prefix(1).uppercased())
                    .font(.title2.bold())
                    .foregroundStyle(.white)
            }
            .frame(width: 48, height: 48)

            VStack(alignment: .leading, spacing: 4) {
                Text(club.name)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                if let official = club.officialName, official != club.name {
                    Text(official)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                HStack(spacing: 10) {
                    Label("\(club.playerCount)", systemImage: "person.3.fill")
                    Label(club.formattedSquadValue, systemImage: "eurosign.circle.fill")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)

            Image(systemName: "chevron.right")
                .font(.caption.bold())
                .foregroundStyle(.tertiary)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.primary.opacity(0.05), lineWidth: 1)
        )
    }
}
