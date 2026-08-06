import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct TeamProfileView: View {
    @ObservedObject var vm: TeamStore
    @ObservedObject var sync: TeamSyncService
    @Environment(\.dismiss) private var dismiss
    @State private var showImportPicker = false
    @State private var showExportShare = false
    @State private var showQuickAdd = false
    @State private var alertMessage = ""
    @State private var showAlert = false
    @State private var exportURL: URL?
    @State private var codeCopied = false

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
                        Text(vm.teamName ?? "My Team").font(.system(size: 18, weight: .bold)).foregroundStyle(TeamTheme.textPrimary)
                        Text(roleLabel)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(roleTint)
                    }
                }
                .listRowBackground(TeamTheme.cardBg)
            }

            Section("Team Summary") {
                summaryRow("Players", "\(vm.playerCount)", "figure.run")
                summaryRow("Goalkeepers", "\(vm.goalkeeperCount)", "hand.raised.fill")
                summaryRow("Coaches", "\(vm.coachCount)", "person.badge.clock.fill")
                summaryRow("Games Played", "\(vm.gamesInScope.count)", "sportscourt")
                summaryRow("Total Goals", "\(vm.totalGoals)", "soccerball")
                NavigationLink { SeasonsView(vm: vm) } label: {
                    HStack {
                        Label("Seasons", systemImage: "calendar").foregroundStyle(TeamTheme.textSecondary)
                        Spacer()
                        Text("\(vm.seasons.count)").foregroundStyle(TeamTheme.textTertiary)
                    }
                }
            }
            .listRowBackground(TeamTheme.cardBg)

            if vm.isLive {
                Section("Shared Team") {
                    if let code = sync.membership?.teamID, sync.canEdit {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Your team code")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(TeamTheme.textSecondary)
                            Text(code)
                                .font(.system(.title3, design: .monospaced).weight(.bold))
                                .foregroundStyle(TeamTheme.textPrimary)
                                .textSelection(.enabled)
                            Text("Share it so teammates can view your team. Only this device can edit.")
                                .font(.system(size: 12))
                                .foregroundStyle(TeamTheme.textTertiary)
                            HStack(spacing: 12) {
                                Button {
                                    UIPasteboard.general.string = code
                                    withAnimation { codeCopied = true }
                                } label: {
                                    Label(codeCopied ? "Copied!" : "Copy", systemImage: codeCopied ? "checkmark" : "doc.on.doc")
                                        .font(.system(size: 14, weight: .semibold))
                                }
                                ShareLink(item: shareText(code)) {
                                    Label("Share", systemImage: "square.and.arrow.up")
                                        .font(.system(size: 14, weight: .semibold))
                                }
                            }
                            .foregroundStyle(TeamTheme.blue)
                        }
                        .padding(.vertical, 4)
                    } else {
                        Text("No shared team yet. Create one from the cloud menu on the team screen.")
                            .font(.system(size: 13))
                            .foregroundStyle(TeamTheme.textSecondary)
                    }
                }
                .listRowBackground(TeamTheme.cardBg)
            }

            if vm.canEdit {
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

            Section {
                Button(role: .destructive) {
                    if sync.isJoined { sync.leaveTeam(vm) }
                    vm.deleteTeam()
                    dismiss()
                } label: {
                    Label(sync.isJoined ? "Leave Team" : "Delete Team", systemImage: "trash.fill")
                }
            } footer: {
                Text(sync.isJoined
                     ? "Leaves the shared team on this device and returns to the start screen."
                     : "Removes this team from this device and returns to the start screen.")
            }
            .listRowBackground(TeamTheme.cardBg)

            Section("About") {
                HStack {
                    Text("Version").foregroundStyle(TeamTheme.textSecondary)
                    Spacer()
                    Text("1.0").foregroundStyle(TeamTheme.textTertiary)
                }
                HStack {
                    Text("Current season").foregroundStyle(TeamTheme.textSecondary)
                    Spacer()
                    Text(vm.currentSeason?.name ?? "—").foregroundStyle(TeamTheme.textTertiary)
                }
            }
            .listRowBackground(TeamTheme.cardBg)
        }
        .scrollContentBackground(.hidden)
        .background(TeamTheme.bg.ignoresSafeArea())
        .navigationTitle("Profile")
        .navigationBarTitleDisplayMode(.large)
        .alert("Data", isPresented: $showAlert) { Button("OK") {} } message: { Text(alertMessage) }
        .sheet(isPresented: $showQuickAdd) { QuickAddGameSheet(vm: vm) }
        .sheet(isPresented: $showImportPicker) {
            DocumentPicker { data in
                do {
                    guard let incoming = try DataExporter.decode(data) else {
                        alertMessage = "That file doesn't contain a team."; showAlert = true; return
                    }
                    vm.replaceDocument(incoming)
                    alertMessage = "Imported \(incoming.players.count) players, \(incoming.games.count) games."
                    showAlert = true
                } catch {
                    alertMessage = error.localizedDescription; showAlert = true
                }
            }
        }
        .sheet(isPresented: $showExportShare) {
            if let url = exportURL {
                ShareSheet(items: [url])
            }
        }
    }

    private var roleLabel: String {
        switch vm.mode {
        case .admin:  return "Admin · Live"
        case .viewer: return "Viewer · Read-only"
        default:      return "User · Local"
        }
    }

    private var roleTint: Color {
        switch vm.mode {
        case .admin:  return TeamTheme.red
        case .viewer: return TeamTheme.textSecondary
        default:      return TeamTheme.blue
        }
    }

    private func shareText(_ code: String) -> String {
        "Join my team on FTMP! Open the app → My Team → the cloud menu → Join with Code, and enter:\n\n\(code)"
    }

    private func summaryRow(_ label: String, _ value: String, _ icon: String) -> some View {
        HStack {
            Label(label, systemImage: icon).foregroundStyle(TeamTheme.textSecondary)
            Spacer()
            Text(value).font(.system(size: 15, weight: .semibold)).foregroundStyle(TeamTheme.textPrimary)
        }
    }

    private func saveData() {
        guard let doc = vm.doc else {
            alertMessage = "There's no team to save."; showAlert = true; return
        }
        do {
            try DataExporter.saveToDisk(doc)
            alertMessage = "Saved successfully."; showAlert = true
        } catch {
            alertMessage = "Save failed. \(error.localizedDescription)"; showAlert = true
        }
    }

    private func exportData() {
        guard let doc = vm.doc, let data = DataExporter.encode(doc) else { return }
        let url = DataExporter.documentsURL.appendingPathComponent("team_export_\(Int(Date().timeIntervalSince1970)).json")
        try? data.write(to: url)
        exportURL = url
        showExportShare = true
    }

    private func loadSaved() {
        do {
            guard let loaded = try DataExporter.loadFromDisk() else {
                alertMessage = "No saved data found."; showAlert = true; return
            }
            vm.replaceDocument(loaded)
            alertMessage = "Loaded \(loaded.players.count) players, \(loaded.games.count) games."
            showAlert = true
        } catch {
            alertMessage = error.localizedDescription; showAlert = true
        }
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
