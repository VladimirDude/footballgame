import SwiftUI

struct PlayerProfileView: View {

    let player: Player

    var body: some View {
        ScrollView {

            VStack(spacing: 16) {

                Text(CountryFlags.primaryFlag(from: player.nationalities ?? []))
                    .font(.system(size: 80))

                Text(player.name)
                    .font(.title)
                    .bold()

                Text(player.club)
                    .font(.headline)
                    .foregroundColor(.secondary)

                Text(player.position)
                    .foregroundColor(.gray)

                Text(player.marketValue)
                    .foregroundColor(.green)
                    .font(.headline)

                Divider()

                VStack(alignment: .leading, spacing: 10) {

                    if let nationalities = player.nationalities, !nationalities.isEmpty {
                        Text("Nationality: \(nationalities.joined(separator: ", "))")
                    }

                    Text("Data from bundled squad list")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
            }
            .padding()
        }
        .navigationTitle("Player")
    }
}
