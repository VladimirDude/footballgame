import SwiftUI

/// Create, rename and retire seasons.
struct SeasonsView: View {
    @ObservedObject var vm: TeamStore

    @State private var newSeasonName = ""
    @State private var renaming: Season?
    @State private var renameText = ""
    @State private var deleting: Season?
    @State private var reassignTarget: UUID?

    var body: some View {
        List {
            Section {
                ForEach(vm.seasons) { season in
                    row(season)
                }
            } header: {
                Text("Seasons")
            } footer: {
                Text("New matches are added to the current season. Changing the current season doesn't move existing matches.")
            }

            if vm.canEdit {
                Section("Add a season") {
                    HStack {
                        TextField("e.g. 2027/28", text: $newSeasonName)
                        Button("Add") {
                            vm.addSeason(name: newSeasonName)
                            newSeasonName = ""
                        }
                        .disabled(newSeasonName.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }
            }

            if vm.hasUnassignedGames {
                Section {
                    Label("Some matches have no season", systemImage: "questionmark.folder")
                        .foregroundStyle(TeamTheme.orange)
                } footer: {
                    Text("These came from a device running an older version. Open a match and pick a season to file it.")
                }
            }
        }
        .navigationTitle("Seasons")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Rename season", isPresented: renameBinding) {
            TextField("Name", text: $renameText)
            Button("Cancel", role: .cancel) { renaming = nil }
            Button("Save") {
                if let renaming { vm.renameSeason(renaming.id, to: renameText) }
                renaming = nil
            }
        }
        .sheet(item: $deleting) { season in
            deleteSheet(season)
        }
    }

    // MARK: - Rows

    private func row(_ season: Season) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(season.name).font(.system(size: 16, weight: .semibold))
                Text("\(matchCount(season)) match\(matchCount(season) == 1 ? "" : "es")")
                    .font(.system(size: 12))
                    .foregroundStyle(TeamTheme.textSecondary)
            }
            Spacer()
            if season.id == vm.currentSeason?.id {
                Text("Current")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(TeamTheme.green)
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(TeamTheme.green.opacity(0.15), in: Capsule())
            }
        }
        .contentShape(Rectangle())
        .swipeActions(edge: .trailing) {
            if vm.canEdit, vm.seasons.count > 1 {
                Button(role: .destructive) {
                    reassignTarget = vm.seasons.first { $0.id != season.id }?.id
                    deleting = season
                } label: { Label("Delete", systemImage: "trash") }
            }
        }
        .contextMenu {
            if vm.canEdit {
                Button { vm.setCurrentSeason(season.id) } label: {
                    Label("Make current", systemImage: "checkmark.circle")
                }
                Button {
                    renameText = season.name
                    renaming = season
                } label: { Label("Rename", systemImage: "pencil") }
            }
        }
    }

    /// Deleting a season must never take its matches with it — a mis-tap that
    /// erases a year of results is not a recoverable mistake, so the matches are
    /// always moved somewhere the user picks.
    private func deleteSheet(_ season: Season) -> some View {
        NavigationStack {
            Form {
                Section {
                    Text("\(matchCount(season)) match\(matchCount(season) == 1 ? "" : "es") are filed under \(season.name). Matches are never deleted with a season — choose where they go.")
                }
                Section("Move matches to") {
                    Picker("Season", selection: $reassignTarget) {
                        ForEach(vm.seasons.filter { $0.id != season.id }) { other in
                            Text(other.name).tag(Optional(other.id))
                        }
                        Text("Leave unassigned").tag(UUID?.none)
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                }
                Section {
                    Button(role: .destructive) {
                        vm.deleteSeason(season.id, reassignTo: reassignTarget)
                        deleting = nil
                    } label: {
                        Text("Delete \(season.name)")
                    }
                }
            }
            .navigationTitle("Delete Season")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { deleting = nil }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func matchCount(_ season: Season) -> Int {
        vm.games.filter { $0.seasonID == season.id }.count
    }

    private var renameBinding: Binding<Bool> {
        Binding(get: { renaming != nil }, set: { if !$0 { renaming = nil } })
    }
}
