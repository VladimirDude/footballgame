import SwiftUI
import UIKit

/// Toolbar menu that surfaces team-sharing actions, shown next to the role badge
/// in `MyTeamView`. Self-contained: it owns its redeem sheet and error alert, so
/// wiring it in is just adding one toolbar item.
struct TeamSyncMenu: View {
    @ObservedObject var vm: TeamStore
    @ObservedObject var sync: TeamSyncService
    @State private var showRedeem = false
    @State private var showShareCode = false

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
                                Button {
                                    showShareCode = true
                                } label: { Label("Share Code", systemImage: "square.and.arrow.up") }
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
                            createAndShare()
                        } label: { Label("Create Shared Team", systemImage: "plus.circle.fill") }
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
        .sheet(isPresented: $showShareCode) {
            if let code = sync.membership?.teamID {
                ShareCodeSheet(code: code)
            }
        }
        .alert("Team Sync", isPresented: errorBinding) {
            Button("OK", role: .cancel) {}
        } message: { Text(sync.lastError ?? "") }
    }

    /// Creates a shared team from the current roster, then reveals the code to
    /// share. If creation fails (e.g. Storage rules not deployed yet) the error
    /// alert shows and no sheet is presented.
    private func createAndShare() {
        Task {
            await sync.createTeam(name: "My Team", from: vm)
            if sync.membership != nil { showShareCode = true }
        }
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

/// Shows a team's redeem code with copy + share affordances. Admins share this
/// so teammates can join.
struct ShareCodeSheet: View {
    let code: String
    @Environment(\.dismiss) private var dismiss
    @State private var copied = false

    private var shareText: String {
        "Join my team on FTMP! Open the app → My Team → the cloud menu → Join with Code, and enter:\n\n\(code)"
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 22) {
                Image(systemName: "person.2.badge.key.fill")
                    .font(.system(size: 46))
                    .foregroundStyle(TeamTheme.blue)
                    .padding(.top, 12)

                Text("Share this code")
                    .font(.title2.bold())
                Text("Anyone with this code can view your team. You keep editing from this device.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                Text(code)
                    .font(.system(.title2, design: .monospaced).weight(.bold))
                    .textSelection(.enabled)
                    .padding(.vertical, 16)
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(TeamTheme.blue.opacity(0.12))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(TeamTheme.blue.opacity(0.4), style: StrokeStyle(lineWidth: 1, dash: [6]))
                    )

                HStack(spacing: 12) {
                    Button {
                        UIPasteboard.general.string = code
                        withAnimation { copied = true }
                    } label: {
                        Label(copied ? "Copied!" : "Copy", systemImage: copied ? "checkmark" : "doc.on.doc")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)

                    ShareLink(item: shareText) {
                        Label("Share", systemImage: "square.and.arrow.up")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding(.top, 4)

                Spacer()
            }
            .padding(20)
            .navigationTitle("Team Code")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
    }
}
