import SwiftUI

/// Shown when a saved team exists on disk but could not be read.
///
/// This screen exists so a bad file is never mistaken for a new user. Until the
/// user picks one of these outcomes the store has no autosave subscription, so
/// nothing they do can overwrite the file we failed to read.
struct TeamDataRecoveryView: View {
    @ObservedObject var vm: TeamStore

    @State private var showStartFreshConfirm = false
    @State private var typedConfirmation = ""

    var body: some View {
        ScrollView {
            VStack(spacing: DSSpacing.lg) {
                header
                explanation
                actions
            }
            .padding(DSSpacing.lg)
            .adaptiveContentWidth(AdaptiveLayout.detailMaxWidth)
        }
        .background(TeamTheme.bg.ignoresSafeArea())
        .navigationTitle("My Team")
        .sheet(isPresented: $showStartFreshConfirm) { startFreshSheet }
    }

    // MARK: - Sections

    private var header: some View {
        VStack(spacing: DSSpacing.sm) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 44))
                .foregroundStyle(DSColor.warning)
            Text(isTooNew ? "Team saved by a newer version" : "Couldn't open your team")
                .dsFont(.title2)
                .multilineTextAlignment(.center)
            Text(message)
                .dsFont(.subheadline)
                .foregroundStyle(TeamTheme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DSSpacing.lg)
        .dsCard(radius: DSRadius.xxl)
    }

    private var explanation: some View {
        VStack(alignment: .leading, spacing: DSSpacing.sm) {
            Label("Your file has not been changed or deleted.", systemImage: "lock.fill")
            if quarantineURL != nil {
                Label("A copy has been set aside so you can export it.", systemImage: "doc.on.doc.fill")
            }
            Label("Nothing will be saved over it until you choose below.", systemImage: "hand.raised.fill")
        }
        .dsFont(.footnote)
        .foregroundStyle(TeamTheme.textSecondary)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DSSpacing.md)
        .dsCard()
    }

    private var actions: some View {
        VStack(spacing: DSSpacing.sm) {
            DSPrimaryButton(title: "Try Again", icon: "arrow.clockwise") { vm.retryLoad() }

            if vm.canRestorePreviousSave {
                DSSecondaryButton(title: "Restore Previous Save", icon: "clock.arrow.circlepath") {
                    vm.restorePreviousSave()
                }
            }

            if let url = quarantineURL {
                ShareLink(item: url) {
                    Label("Export Unreadable File", systemImage: "square.and.arrow.up")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.bordered)
            }

            Button(role: .destructive) {
                typedConfirmation = ""
                showStartFreshConfirm = true
            } label: {
                Text("Start Fresh").frame(maxWidth: .infinity).padding(.vertical, 14)
            }
            .buttonStyle(.bordered)
            .tint(DSColor.danger)

            if let error = vm.lastSaveError {
                Text(error)
                    .dsFont(.caption)
                    .foregroundStyle(DSColor.danger)
                    .multilineTextAlignment(.center)
            }
        }
    }

    // MARK: - Start Fresh

    private var startFreshSheet: some View {
        NavigationStack {
            Form {
                Section {
                    Text("This permanently deletes the team saved on this device, including every player and match.")
                    Text("If you shared this team with a code, you can rejoin it afterwards and pull the cloud copy.")
                        .dsFont(.footnote)
                        .foregroundStyle(TeamTheme.textSecondary)
                }
                Section("Type DELETE to confirm") {
                    TextField("DELETE", text: $typedConfirmation)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                }
                Section {
                    Button(role: .destructive) {
                        vm.startFresh()
                        showStartFreshConfirm = false
                    } label: {
                        Text("Delete and Start Fresh")
                    }
                    .disabled(typedConfirmation.trimmingCharacters(in: .whitespaces).uppercased() != "DELETE")
                }
            }
            .navigationTitle("Start Fresh")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showStartFreshConfirm = false }
                }
            }
        }
        .presentationDetents([.medium])
    }

    // MARK: - Helpers

    private var isTooNew: Bool {
        if case .tooNew = vm.loadState { return true }
        return false
    }

    private var message: String {
        switch vm.loadState {
        case .failed(let message, _): return message
        case .tooNew(let message): return message
        default: return ""
        }
    }

    private var quarantineURL: URL? {
        if case .failed(_, let url) = vm.loadState { return url }
        return nil
    }
}
