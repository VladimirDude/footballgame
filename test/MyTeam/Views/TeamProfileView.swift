import SwiftUI
import UniformTypeIdentifiers

struct TeamProfileView: View {
    @ObservedObject var vm: TeamStore
    @Environment(\.dismiss) private var dismiss
    @State private var showImportPicker = false
    @State private var showExportShare = false
    @State private var showQuickAdd = false
    @State private var alertMessage = ""
    @State private var showAlert = false
    @State private var exportURL: URL?

    var body: some View {
        List {
            Section {
                HStack(spacing: 14) {
                    if let icon = vm.teamIcon {
                        Image(uiImage: icon).resizable().scaledToFill()
                            .frame(width: 56, height: 56).clipShape(Circle())
                    } else {
                        Image(systemName: "sportscourt.fill")
                            .font(.system(size: 24)).foregroundStyle(TeamTheme.blue)
                            .frame(width: 56, height: 56)
                            .background(TeamTheme.blue.opacity(0.15), in: Circle())
                    }
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Cognaize Futsal").font(.system(size: 18, weight: .bold)).foregroundStyle(TeamTheme.textPrimary)
                        Text(vm.isAdmin ? "Admin Mode" : "User Mode")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(vm.isAdmin ? TeamTheme.red : TeamTheme.textSecondary)
                    }
                }
                .listRowBackground(TeamTheme.cardBg)
            }

            Section("Team Summary") {
                summaryRow("Players", "\(vm.playerCount)", "figure.run")
                summaryRow("Goalkeepers", "\(vm.goalkeeperCount)", "hand.raised.fill")
                summaryRow("Coaches", "\(vm.coachCount)", "person.badge.clock.fill")
                summaryRow("Games Played", "\(vm.games.count)", "sportscourt")
                summaryRow("Total Goals", "\(vm.totalGoals)", "soccerball")
            }
            .listRowBackground(TeamTheme.cardBg)

            if vm.isAdmin {
                Section("Quick Add Game") {
                    Button { showQuickAdd = true } label: {
                        Label("Paste Game Text", systemImage: "doc.text.fill")
                            .foregroundStyle(TeamTheme.green)
                    }
                }
                .listRowBackground(TeamTheme.cardBg)

                Section("Data Management") {
                    Button { saveData() } label: {
                        Label("Save to Device", systemImage: "square.and.arrow.down.fill")
                            .foregroundStyle(TeamTheme.blue)
                    }

                    Button { exportData() } label: {
                        Label("Export as File", systemImage: "square.and.arrow.up.fill")
                            .foregroundStyle(TeamTheme.blue)
                    }

                    Button { showImportPicker = true } label: {
                        Label("Import from File", systemImage: "folder.fill")
                            .foregroundStyle(TeamTheme.orange)
                    }

                    Button { loadSaved() } label: {
                        Label("Load Last Save", systemImage: "clock.arrow.circlepath")
                            .foregroundStyle(TeamTheme.purple)
                    }
                }
                .listRowBackground(TeamTheme.cardBg)
            }

            Section("About") {
                HStack {
                    Text("Version").foregroundStyle(TeamTheme.textSecondary)
                    Spacer()
                    Text("1.0").foregroundStyle(TeamTheme.textTertiary)
                }
                HStack {
                    Text("Season").foregroundStyle(TeamTheme.textSecondary)
                    Spacer()
                    Text("2025").foregroundStyle(TeamTheme.textTertiary)
                }
            }
            .listRowBackground(TeamTheme.cardBg)
        }
        .scrollContentBackground(.hidden)
        .background(TeamTheme.bg.ignoresSafeArea())
        .navigationTitle("Profile")
        .navigationBarTitleDisplayMode(.large)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .alert("Data", isPresented: $showAlert) { Button("OK") {} } message: { Text(alertMessage) }
        .sheet(isPresented: $showQuickAdd) { QuickAddGameSheet(vm: vm) }
        .sheet(isPresented: $showImportPicker) {
            DocumentPicker { data in
                guard let result = DataExporter.importData(data) else {
                    alertMessage = "Failed to import. Invalid format."; showAlert = true; return
                }
                vm.players = result.players
                vm.games = result.games
                alertMessage = "Imported \(result.players.count) players, \(result.games.count) games."; showAlert = true
            }
        }
        .sheet(isPresented: $showExportShare) {
            if let url = exportURL {
                ShareSheet(items: [url])
            }
        }
    }

    private func summaryRow(_ label: String, _ value: String, _ icon: String) -> some View {
        HStack {
            Label(label, systemImage: icon).foregroundStyle(TeamTheme.textSecondary)
            Spacer()
            Text(value).font(.system(size: 15, weight: .semibold)).foregroundStyle(TeamTheme.textPrimary)
        }
    }

    private func saveData() {
        if DataExporter.saveToDisk(players: vm.players, games: vm.games) {
            alertMessage = "Saved successfully."; showAlert = true
        } else {
            alertMessage = "Save failed."; showAlert = true
        }
    }

    private func exportData() {
        guard let data = DataExporter.export(players: vm.players, games: vm.games) else { return }
        let url = DataExporter.documentsURL.appendingPathComponent("cognaize_export_\(Int(Date().timeIntervalSince1970)).json")
        try? data.write(to: url)
        exportURL = url
        showExportShare = true
    }

    private func loadSaved() {
        guard let result = DataExporter.loadFromDisk() else {
            alertMessage = "No saved data found."; showAlert = true; return
        }
        vm.players = result.players
        vm.games = result.games
        alertMessage = "Loaded \(result.players.count) players, \(result.games.count) games."; showAlert = true
    }
}

// MARK: - Quick Add Game from Text

struct QuickAddGameSheet: View {
    @ObservedObject var vm: TeamStore
    @Environment(\.dismiss) private var dismiss
    @State private var text = ""
    @State private var parsed: TeamGame?

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Text("Paste game data in this format:")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(TeamTheme.textSecondary)

                Text("""
                Opponent.  +GF:GA
                - MM:SS - Scorer/Assist
                - MM:SS - opponent_name
                https://youtube.com/...
                """)
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(TeamTheme.textTertiary)
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(TeamTheme.surface, in: RoundedRectangle(cornerRadius: 10))

                TextEditor(text: $text)
                    .font(.system(size: 14, design: .monospaced))
                    .frame(minHeight: 180)
                    .scrollContentBackground(.hidden)
                    .background(TeamTheme.cardBg)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(TeamTheme.cardBorder))

                if let game = parsed {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Preview:").font(.system(size: 12, weight: .bold)).foregroundStyle(TeamTheme.textSecondary)
                        Text("vs \(game.opponent) — \(game.score)")
                            .font(.system(size: 15, weight: .semibold)).foregroundStyle(TeamTheme.textPrimary)
                        Text("\(game.goalDetails.count) goals parsed")
                            .font(.system(size: 12)).foregroundStyle(TeamTheme.green)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(TeamTheme.green.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
                }

                Spacer()
            }
            .padding(16)
            .background(TeamTheme.bg.ignoresSafeArea())
            .navigationTitle("Quick Add Game")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        if let game = parsed { vm.addGame(game); dismiss() }
                    }
                    .fontWeight(.bold)
                    .disabled(parsed == nil)
                }
            }
            .onChange(of: text) { _ in parsed = GameParser.parse(text) }
        }
    }
}

// MARK: - Document Picker for Import

struct DocumentPicker: UIViewControllerRepresentable {
    let onPick: (Data) -> Void

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [UTType.json])
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}
    func makeCoordinator() -> Coordinator { Coordinator(onPick: onPick) }

    final class Coordinator: NSObject, UIDocumentPickerDelegate {
        let onPick: (Data) -> Void
        init(onPick: @escaping (Data) -> Void) { self.onPick = onPick }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first, url.startAccessingSecurityScopedResource() else { return }
            defer { url.stopAccessingSecurityScopedResource() }
            guard let data = try? Data(contentsOf: url) else { return }
            onPick(data)
        }
    }
}

// MARK: - Share Sheet

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
