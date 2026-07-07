import SwiftUI

struct ClubDetailView: View {
    let clubName: String
    let transfers = ["Victor Osimhen (Out)", "Romelu Lukaku (In)", "Scott McTominay (In)"]

    var body: some View {
        List {
            Section(header: Text("Recent Transfers")) {
                ForEach(transfers, id: \.self) { transfer in
                    Text(transfer)
                }
            }
        }
        .navigationTitle(clubName)
        .navigationBarTitleDisplayMode(.inline)
    }
}
