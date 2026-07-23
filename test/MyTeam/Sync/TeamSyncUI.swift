import SwiftUI

/// Toolbar menu that surfaces team-sharing actions, shown next to the role badge
/// in `MyTeamView`. Self-contained: it owns its redeem sheet and error alert, so
/// wiring it in is just adding one toolbar item.
struct TeamSyncMenu: View {
    @ObservedObject var vm: TeamStore
    @ObservedObject var sync: TeamSyncService
    @State private var showRedeem = false

    var body: some View {
        Group {
            if sync.isConfigured {
                Menu {
                    if let membership = sync.membership {
                        Section("Shared team · \(membership.role.rawValue.capitalized)") {
                            if sync.canEdit {
                                Button {
                                    Task { await sync.publish(from: vm) }
                                } label: { Label("Publish Changes", systemImage: "icloud.and.arrow.up") }
                            }
                            Button {
                                Task { await sync.pull(into: vm) }
                            } label: { Label("Refresh from Cloud", systemImage: "arrow.clockwise") }
                            Button(role: .destructive) {
                                sync.leaveTeam(vm)
                            } label: { Label("Leave Team", systemImage: "rectangle.portrait.and.arrow.right") }
                        }
                    } else {
                        Button {
                            showRedeem = true
                        } label: { Label("Join with Code", systemImage: "key.fill") }
                    }
                } label: {
                    Image(systemName: sync.isJoined ? "icloud.fill" : "icloud")
                        .foregroundStyle(TeamTheme.blue)
                }
                .overlay(alignment: .center) {
                    if sync.isBusy { ProgressView().scaleEffect(0.7) }
                }
            }
        }
        .sheet(isPresented: $showRedeem) {
            RedeemCodeSheet(vm: vm, sync: sync)
        }
        .alert("Team Sync", isPresented: errorBinding) {
            Button("OK", role: .cancel) {}
        } message: { Text(sync.lastError ?? "") }
    }

    private var errorBinding: Binding<Bool> {
        Binding(get: { sync.lastError != nil }, set: { if !$0 { sync.lastError = nil } })
    }
}

/// Sheet where a user enters a redeem code to join a shared team.
struct RedeemCodeSheet: View {
    @ObservedObject var vm: TeamStore
    @ObservedObject var sync: TeamSyncService
    @Environment(\.dismiss) private var dismiss
    @State private var code = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("e.g. FTMP-8XK2Q-P4M9", text: $code)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                        .font(.system(.body, design: .monospaced))
                } header: {
                    Text("Redeem Code")
                } footer: {
                    Text("Enter the code your team admin shared with you to view — and, if granted, edit — the team.")
                }

                Section {
                    Button {
                        Task { await sync.redeem(code: code, into: vm) }
                    } label: {
                        HStack {
                            if sync.isBusy { ProgressView() }
                            Text("Join Team").frame(maxWidth: .infinity)
                        }
                    }
                    .disabled(code.trimmingCharacters(in: .whitespaces).isEmpty || sync.isBusy)
                }

                if let error = sync.lastError {
                    Section { Text(error).foregroundStyle(.red).font(.footnote) }
                }
            }
            .navigationTitle("Join a Team")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onChange(of: sync.isJoined) { _, joined in
                if joined { dismiss() }
            }
        }
    }
}
