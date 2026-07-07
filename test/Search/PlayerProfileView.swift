import SwiftUI

struct PlayerProfileView: View {

    let player: Player

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                PlayerPortraitImage(
                    playerID: player.id,
                    imageValue: player.image,
                    style: .hero
                )
                .padding(.top, 8)

                VStack(spacing: 8) {
                    Text(player.name)
                        .font(.title.bold())
                        .multilineTextAlignment(.center)

                    HStack(spacing: 8) {
                        Text(CountryFlags.primaryFlag(from: player.nationalities ?? []))
                            .font(.title2)
                        Text(player.club)
                            .font(.headline)
                            .foregroundColor(.secondary)
                    }

                    Text(player.position)
                        .font(.subheadline)
                        .foregroundColor(.gray)

                    Text(player.marketValue)
                        .font(.title3.bold())
                        .foregroundColor(.green)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            Capsule()
                                .fill(Color.green.opacity(0.12))
                        )
                }

                Divider()
                    .padding(.horizontal)

                VStack(alignment: .leading, spacing: 10) {
                    if let nationalities = player.nationalities, !nationalities.isEmpty {
                        Label {
                            Text(nationalities.joined(separator: ", "))
                        } icon: {
                            Image(systemName: "flag.fill")
                                .foregroundColor(.secondary)
                        }
                    }

                    Text("Data from bundled squad list")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
            }
            .padding()
        }
        .navigationTitle("Player")
        .navigationBarTitleDisplayMode(.inline)
    }
}
