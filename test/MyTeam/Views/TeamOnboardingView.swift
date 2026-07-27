import SwiftUI

/// My Team initial state: choose how to use My Team — create a local **User** team
/// (free, editable, on-device), create a live **Admin** team (Pro, cloud-shared via
/// a redeem code), or **join** an admin's team with a code (read-only).
struct TeamOnboardingView: View {
    @ObservedObject var vm: TeamStore
    @ObservedObject var sync: TeamSyncService
    @EnvironmentObject private var entitlements: EntitlementService

    @State private var createMode: TeamMode?     // drives the create sheet
    @State private var showJoin = false
    @State private var showPaywall = false

    var body: some View {
        ScrollView {
            VStack(spacing: DSSpacing.xl) {
                hero
                VStack(spacing: DSSpacing.sm) {
                    roleCard(
                        title: "User",
                        subtitle: "Create and manage your own team on this device. Full editing, offline.",
                        icon: "person.fill", tint: TeamTheme.blue, badge: nil
                    ) { createMode = .user }

                    roleCard(
                        title: "Admin",
                        subtitle: "Create a live team others can follow with a code. Live updates, sharing.",
                        icon: "shield.checkered", tint: TeamTheme.red, badge: "PRO"
                    ) { startAdmin() }
                }

                VStack(spacing: DSSpacing.xs) {
                    Text("Have a code?").font(.footnote).foregroundStyle(TeamTheme.textTertiary)
                    Button { showJoin = true } label: {
                        Label("Join a team with a code", systemImage: "key.fill")
                            .font(.subheadline.weight(.semibold))
                    }
                    .disabled(!sync.isConfigured)
                    .opacity(sync.isConfigured ? 1 : 0.5)
                    if !sync.isConfigured {
                        Text("Joining needs an internet connection.")
                            .font(.caption2).foregroundStyle(TeamTheme.textTertiary)
                    }
                }
                .padding(.top, DSSpacing.sm)
            }
            .padding(DSSpacing.lg)
            .adaptiveContentWidth(AdaptiveLayout.detailMaxWidth)
        }
        .background(TeamTheme.bg.ignoresSafeArea())
        .navigationTitle("My Team")
        .sheet(item: $createMode) { mode in
            CreateTeamSheet(vm: vm, sync: sync, mode: mode)
        }
        .sheet(isPresented: $showJoin) { RedeemCodeSheet(vm: vm, sync: sync) }
        .paywallSheet(isPresented: $showPaywall, source: "team_admin")
    }

    private func startAdmin() {
        if entitlements.canAccess(.adminMode) {
            createMode = .admin
        } else {
            AnalyticsService.shared.log(.featureBlocked(feature: PremiumFeature.adminMode.rawValue))
            showPaywall = true
        }
    }

    private var hero: some View {
        VStack(spacing: DSSpacing.sm) {
            Image(systemName: "person.3.fill")
                .font(.system(size: 44))
                .foregroundStyle(TeamTheme.blue)
            Text("Set up your team")
                .font(.system(size: 22, weight: .heavy, design: .rounded))
                .foregroundStyle(TeamTheme.textPrimary)
            Text("Track your squad, games and stats. Choose how you want to start.")
                .font(.subheadline)
                .foregroundStyle(TeamTheme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DSSpacing.xl)
        .dsCard(radius: DSRadius.xxl)
    }

    private func roleCard(title: String, subtitle: String, icon: String, tint: Color, badge: String?, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: DSSpacing.md) {
                ZStack {
                    Circle().fill(tint.opacity(0.15)).frame(width: 46, height: 46)
                    Image(systemName: icon).font(.title3).foregroundStyle(tint)
                }
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: DSSpacing.xs) {
                        Text(title).font(.headline).foregroundStyle(TeamTheme.textPrimary)
                        if badge != nil { PremiumBadge() }
                    }
                    Text(subtitle).font(.caption).foregroundStyle(TeamTheme.textSecondary)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").font(.caption.weight(.bold)).foregroundStyle(TeamTheme.textTertiary)
            }
            .contentShape(Rectangle())
            .dsCard()
        }
        .buttonStyle(.plain)
    }
}

/// Sheet to name a new team. `.user` stays local; `.admin` (Pro) also creates a
/// live cloud team + redeem code when sync is configured. Editing the roster is
/// available to the owner in both cases.
struct CreateTeamSheet: View {
    @ObservedObject var vm: TeamStore
    @ObservedObject var sync: TeamSyncService
    let mode: TeamMode
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var icon: UIImage?
    @State private var showIconPicker = false

    private var trimmed: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var isAdmin: Bool { mode == .admin }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: 14) {
                        Button { showIconPicker = true } label: {
                            ZStack {
                                if let icon {
                                    Image(uiImage: icon).resizable().scaledToFill()
                                        .frame(width: 56, height: 56).clipShape(Circle())
                                } else {
                                    Image(systemName: "camera.fill")
                                        .foregroundStyle(TeamTheme.blue)
                                        .frame(width: 56, height: 56)
                                        .background(TeamTheme.blue.opacity(0.15), in: Circle())
                                }
                            }
                        }
                        .buttonStyle(.plain)
                        TextField("Team name", text: $name)
                            .font(.system(size: 17, weight: .semibold))
                    }
                } footer: {
                    Text(isAdmin
                         ? "Admin teams get live updates and a code you can share so others can follow (read-only). You can add players and games after creating."
                         : "You can add players, goalkeepers, coaches and games after creating your team.")
                }

                Section {
                    Button {
                        create()
                    } label: {
                        Text(isAdmin ? "Create Live Team" : "Create Team").frame(maxWidth: .infinity)
                    }
                    .disabled(trimmed.isEmpty)
                }
            }
            .navigationTitle(isAdmin ? "New Live Team" : "New Team")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .sheet(isPresented: $showIconPicker) { ImagePicker(image: $icon) }
        }
    }

    private func create() {
        vm.createLocalTeam(name: trimmed, mode: mode, icon: icon)
        // Admin teams publish to the cloud (live + shareable) when configured.
        if isAdmin, sync.isConfigured {
            let teamName = vm.teamName ?? trimmed
            Task { await sync.createTeam(name: teamName, from: vm) }
        }
        dismiss()
    }
}
