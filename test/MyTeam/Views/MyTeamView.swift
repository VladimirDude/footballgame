import SwiftUI

/// Owns the team registry and hands the open team to `TeamHomeView`.
///
/// The split exists so the home screen can hold the active `TeamStore` as a real
/// `@ObservedObject` — reading it through a computed property would render once
/// and then never update.
struct MyTeamView: View {
    @StateObject private var teams = TeamsStore()
    @StateObject private var sync = TeamSyncService()

    var body: some View {
        TeamHomeView(vm: teams.active, teams: teams, sync: sync)
            // Rebuilds the subtree when the open team changes, so `vm` is
            // re-bound rather than left pointing at the previous team.
            .id(teams.activeID?.uuidString ?? "pending-\(teams.revision)")
    }
}

struct TeamHomeView: View {
    @ObservedObject var vm: TeamStore
    @ObservedObject var teams: TeamsStore
    @ObservedObject var sync: TeamSyncService
    @EnvironmentObject private var entitlements: EntitlementService
    @State private var showRolePaywall = false
    @State private var showCoachDetail = false
    @State private var showGames = false
    @State private var editingPlayerId: UUID?
    @State private var showAddPlayer = false
    @State private var showAddGame = false
    @State private var editingGame: TeamGame?
    @State private var showTeamIconPicker = false
    @State private var showProfile = false
    @State private var showLeaderboard = false
    @State private var showLinkScorers = false
    @State private var dismissedLinkBanner = false
    @State private var showSecondTeamPaywall = false

    var body: some View {
        Group {
            if vm.loadState.isRecoverable {
                // A save file exists but couldn't be read. Never fall through to
                // onboarding here — that is what used to let the next edit
                // overwrite recoverable data with an empty team.
                TeamDataRecoveryView(vm: vm)
            } else if vm.hasTeam {
                dashboard
            } else {
                TeamOnboardingView(vm: vm, sync: sync)
            }
        }
    }

    private var dashboard: some View {
        List {
            Group {
                headerSection
                seasonBar
                unlinkedScorersBanner
                overviewCards
                recentGamesSection
                leaderboardSection
                goalkeeperSection
                statisticsSection
                BonusExplanationView()
                actionButtons
            }
            .listRowInsets(EdgeInsets(top: DSSpacing.sm, leading: DSSpacing.md, bottom: DSSpacing.sm, trailing: DSSpacing.md))
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(TeamTheme.bg.ignoresSafeArea())
        .adaptiveContentWidth(AdaptiveLayout.detailMaxWidth)
        .searchable(text: $vm.searchText, prompt: "Search player...")
        .navigationTitle(vm.teamName ?? "My Team")
        .toolbarTitleMenu { teamSwitcher }
        .navigationDestination(isPresented: $showProfile) {
            TeamProfileView(vm: vm, sync: sync, onDeleteTeam: leaveTeam)
        }
        .navigationDestination(isPresented: $showCoachDetail) {
            CoachDetailView(coaches: vm.coaches, teamName: vm.teamName)
        }
        .navigationDestination(isPresented: $showGames) { TeamGamesView(vm: vm) }
        .navigationDestination(isPresented: $showLeaderboard) { LeaderboardView(vm: vm) }
        .sheet(isPresented: $showLinkScorers) { LinkScorersView(vm: vm) }
        .sheet(item: $editingPlayerId) { pid in
            EditPlayerSheet(vm: vm, playerId: pid)
        }
        .sheet(isPresented: $showAddPlayer) { AddPlayerSheet(vm: vm) }
        .sheet(isPresented: $showAddGame) { EditGameSheet(vm: vm) }
        .sheet(isPresented: $showTeamIconPicker) { ImagePicker(image: $vm.teamIcon) }
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button { showProfile = true } label: {
                    Image(systemName: "person.crop.circle").foregroundStyle(TeamTheme.textSecondary)
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                TeamSyncMenu(vm: vm, sync: sync, onLeave: leaveTeam)
            }
            ToolbarItem(placement: .navigationBarTrailing) { adminBadge }
        }
        .paywallSheet(isPresented: $showRolePaywall, source: "team_admin")
        .paywallSheet(isPresented: $showSecondTeamPaywall, source: "team_second")
    }

    // MARK: - Team switcher

    /// Lives in the title menu: native, discoverable via the title chevron, and no
    /// layout risk on a screen that's already dense.
    @ViewBuilder
    private var teamSwitcher: some View {
        ForEach(teams.teams, id: \.id) { entry in
            Button {
                teams.setActive(entry.id)
            } label: {
                Label(entry.store.teamName ?? "Team",
                      systemImage: entry.id == teams.activeID ? "checkmark" : "person.3")
            }
        }
        Divider()
        // Never hidden — a cap the user can't see reads as a bug.
        Button {
            addTeam()
        } label: {
            Label(addTeamTitle, systemImage: "plus")
        }
        .disabled(teams.isAtCap)
    }

    private var addTeamTitle: String {
        if teams.isAtCap { return "Team limit reached (\(TeamsStore.maxTeams))" }
        return entitlements.canAccess(.multipleTeams) || teams.count == 0 ? "Add Team" : "Add Team (PRO)"
    }

    private func addTeam() {
        guard teams.canCreateTeam(isPro: entitlements.canAccess(.multipleTeams)) else {
            AnalyticsService.shared.log(.featureBlocked(feature: PremiumFeature.multipleTeams.rawValue))
            showSecondTeamPaywall = true
            return
        }
        // Routes back into the existing create/join flow: `beginNewTeam` clears the
        // active team, which is the condition onboarding already keys off.
        teams.beginNewTeam()
    }

    // MARK: - Role Badge

    private var roleStyle: (title: String, icon: String, tint: Color) {
        switch vm.mode {
        case .admin:  return ("Admin", "shield.checkered", TeamTheme.red)
        case .viewer: return ("Viewer", "eye.fill", TeamTheme.textSecondary)
        default:      return ("User", "person.fill", TeamTheme.blue)
        }
    }

    /// The current role plus the ways to switch or exit it. The role is set at team
    /// creation (User / Admin·Pro) or Viewer when joining; this menu is the way out.
    private var adminBadge: some View {
        Menu {
            Section(roleStyle.title + " mode") {
                switch vm.mode {
                case .user:
                    Button { switchToAdmin() } label: {
                        Label("Switch to Admin (Live)", systemImage: "shield.checkered")
                    }
                case .admin:
                    Button { switchToUser() } label: {
                        Label("Switch to User (Local)", systemImage: "person.fill")
                    }
                case .viewer, .none:
                    EmptyView()
                }
                Button(role: .destructive) { leaveTeam() } label: {
                    Label(sync.isJoined ? "Leave Team" : "Delete Team", systemImage: "rectangle.portrait.and.arrow.right")
                }
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: roleStyle.icon).font(.system(size: 12, weight: .bold))
                Text(roleStyle.title).font(.system(size: 11, weight: .bold))
                Image(systemName: "chevron.down").font(.system(size: 8, weight: .bold))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(roleStyle.tint.opacity(0.18), in: Capsule())
            .foregroundStyle(roleStyle.tint)
        }
    }

    /// User → Admin: keep the roster, go live (Pro; publishes to the cloud when a
    /// backend is configured).
    private func switchToAdmin() {
        guard entitlements.canAccess(.adminMode) else {
            AnalyticsService.shared.log(.featureBlocked(feature: PremiumFeature.adminMode.rawValue))
            showRolePaywall = true
            return
        }
        vm.mode = .admin
        if sync.isConfigured {
            Task { await sync.createTeam(name: vm.teamName ?? "My Team", from: vm) }
        }
    }

    /// Admin → User: keep the roster, stop live sync and go local-only.
    private func switchToUser() {
        sync.detachMembership()
        vm.mode = .user
    }

    /// Exit the current team back to the Create / Join screen.
    private func leaveTeam() {
        if sync.isJoined { sync.detachMembership() }
        // Goes through the registry so the index, the folder and the legacy mirror
        // are cleaned up, and another team (if any) becomes active.
        teams.deleteActiveTeam()
    }

    // MARK: - Header (gradient hero — the legacy `board` image asset is absent,
    // so we render a pitch-style gradient that adapts to light/dark instead)

    private var headerSection: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.10, green: 0.45, blue: 0.22),
                            Color(red: 0.05, green: 0.30, blue: 0.14)
                        ],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                )
                .frame(height: 200)
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(
                            LinearGradient(colors: [Color.black.opacity(0.05), Color.black.opacity(0.35)],
                                           startPoint: .top, endPoint: .bottom)
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )

            VStack(spacing: 8) {
                // Team icon
                ZStack {
                    if let icon = vm.teamIcon {
                        Image(uiImage: icon)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 56, height: 56)
                            .clipShape(Circle())
                    } else {
                        Image(systemName: "sportscourt.fill")
                            .font(.system(size: 28, weight: .semibold))
                            .foregroundStyle(TeamTheme.blueGradient)
                            .frame(width: 56, height: 56)
                    }

                    if vm.isAdmin {
                        Button { showTeamIconPicker = true } label: {
                            Image(systemName: "camera.circle.fill")
                                .font(.system(size: 18))
                                .foregroundStyle(.white)
                                .background(Circle().fill(TeamTheme.blue).frame(width: 22, height: 22))
                        }
                        .offset(x: 20, y: 20)
                    }
                }

                Text(vm.teamName ?? "My Team")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                Text("Match Statistics")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white.opacity(0.6))

                HStack(spacing: 20) {
                    statPill(icon: "soccerball", value: "\(vm.totalGoals)", label: "Goals")
                    statPill(icon: "arrow.triangle.branch", value: "\(vm.totalAssists)", label: "Assists")
                    statPill(icon: "person.3.fill", value: "\(vm.players.count)", label: "Squad")
                }
                .padding(.top, 4)
            }
        }
        .frame(height: 200)
    }

    private func statPill(icon: String, value: String, label: String) -> some View {
        VStack(spacing: 2) {
            Image(systemName: icon).font(.system(size: 11)).foregroundStyle(.white.opacity(0.5))
            Text(value).font(.system(size: 15, weight: .bold, design: .rounded)).foregroundStyle(.white)
            Text(label).font(.system(size: 9, weight: .medium)).foregroundStyle(.white.opacity(0.45))
        }
    }

    // MARK: - Overview

    private var overviewCards: some View {
        VStack(spacing: 10) {
            HStack {
                SectionHeaderView(icon: "person.3.fill", title: "Team Overview")
                if vm.isAdmin {
                    Spacer()
                    Button { showAddPlayer = true } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(TeamTheme.blue)
                    }
                }
            }

            HStack(spacing: 10) {
                StatCard(title: "Players", value: "\(vm.playerCount)", icon: "figure.run", tint: TeamTheme.blue)
                StatCard(title: "Goalkeepers", value: "\(vm.goalkeeperCount)", icon: "hand.raised.fill", tint: TeamTheme.orange)
                Button { showCoachDetail = true } label: {
                    StatCard(title: "Coaches", value: "\(vm.coachCount)", icon: "person.badge.clock.fill", tint: TeamTheme.purple)
                }.buttonStyle(.plain)
            }
        }
    }

    // MARK: - Recent Games

    /// Season selector plus a reminder of what the numbers below are scoped to.
    private var seasonBar: some View {
        HStack(spacing: 8) {
            SeasonPickerButton(vm: vm)
            teamsChip
            Spacer()
            if vm.seasonScope == .allTime, vm.seasons.count > 1 {
                Text("\(vm.seasons.count) seasons")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(TeamTheme.textTertiary)
            }
        }
    }

    /// The visible entry point for switching and adding teams.
    ///
    /// `toolbarTitleMenu` alone isn't enough: with a large navigation title iOS
    /// draws no chevron, so the menu is invisible and "Add Team" would be as
    /// unreachable as the feature it lives next to.
    private var teamsChip: some View {
        Menu {
            teamSwitcher
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "person.3.fill").font(.system(size: 11, weight: .semibold))
                Text(teams.count > 1 ? "\(teams.count) teams" : "Teams")
                    .font(.system(size: 13, weight: .semibold))
                Image(systemName: "chevron.down").font(.system(size: 10, weight: .bold))
            }
            .foregroundStyle(TeamTheme.purple)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(TeamTheme.purple.opacity(0.12), in: Capsule())
        }
        .accessibilityLabel("Teams. Currently \(vm.teamName ?? "none")")
    }

    private var recentGamesSection: some View {
        let scoped = vm.gamesInScope
        let recent = scoped.prefix(3)
        let wins = scoped.filter { $0.result == .win }.count
        let record = "\(wins)W \(scoped.filter { $0.result == .draw }.count)D \(scoped.filter { $0.result == .loss }.count)L"

        return VStack(spacing: 10) {
            HStack {
                SectionHeaderView(icon: "calendar.badge.clock", title: "Recent Matches", trailing: record)
                if vm.isAdmin {
                    Spacer()
                    Button { showAddGame = true } label: {
                        Image(systemName: "plus.circle.fill").font(.system(size: 20)).foregroundStyle(TeamTheme.green)
                    }
                }
            }

            VStack(spacing: 6) {
                ForEach(Array(recent)) { game in recentGameRow(game) }
            }

            Button { showGames = true } label: {
                Text("View All Matches")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(TeamTheme.blue)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(TeamTheme.blue.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
            }.buttonStyle(.plain)
        }
    }

    private func recentGameRow(_ game: TeamGame) -> some View {
        HStack(spacing: 12) {
            Text(game.result.rawValue)
                .font(.system(size: 12, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .frame(width: 28, height: 28)
                .background(gameColor(game.result), in: RoundedRectangle(cornerRadius: 6))

            VStack(alignment: .leading, spacing: 2) {
                Text("vs \(game.opponent)").font(.system(size: 14, weight: .semibold)).foregroundStyle(TeamTheme.textPrimary).lineLimit(1)
                Text(game.scorers.prefix(3).joined(separator: ", ")).font(.system(size: 11, weight: .medium)).foregroundStyle(TeamTheme.textTertiary).lineLimit(1)
            }

            Spacer()

            Text(game.score).font(.system(size: 18, weight: .bold, design: .rounded)).foregroundStyle(gameColor(game.result))
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
        .background(TeamTheme.cardBg, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(gameColor(game.result).opacity(0.12), lineWidth: 1))
    }

    private func gameColor(_ r: TeamGameResult) -> Color {
        switch r { case .win: return TeamTheme.green; case .draw: return TeamTheme.orange; case .loss: return TeamTheme.red }
    }

    // MARK: - Leaderboard

    private var leaderboardSection: some View {
        VStack(spacing: 10) {
            HStack {
                SectionHeaderView(icon: "trophy.fill", title: "Leaderboard",
                                  trailing: vm.leaderboardMetric.fullName)
                Spacer()
                Button { showLeaderboard = true } label: {
                    Text("See all").font(.system(size: 13, weight: .semibold)).foregroundStyle(TeamTheme.blue)
                }
            }
            VStack(spacing: 8) {
                ForEach(vm.leaderboard) { entry in
                    LeaderboardRow(rank: entry.rank, player: entry.player,
                                   stats: entry.stats, metric: vm.leaderboardMetric)
                }
            }
        }
    }

    /// Prompt shown to editors when goals in the log aren't credited to anyone.
    @ViewBuilder
    private var unlinkedScorersBanner: some View {
        let unlinked = vm.unlinkedScorerNames
        if vm.isAdmin, !unlinked.isEmpty, !dismissedLinkBanner {
            let goals = unlinked.reduce(0) { $0 + $1.goals }
            Button { showLinkScorers = true } label: {
                HStack(spacing: 12) {
                    Image(systemName: "person.fill.questionmark")
                        .font(.system(size: 18))
                        .foregroundStyle(TeamTheme.orange)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(unlinked.count) name\(unlinked.count == 1 ? "" : "s") not linked to a player")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(TeamTheme.textPrimary)
                        Text(goals == 1 ? "1 goal isn't counted in the rankings."
                                        : "\(goals) goals aren't counted in the rankings.")
                            .font(.system(size: 12))
                            .foregroundStyle(TeamTheme.textSecondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right").font(.system(size: 12, weight: .bold))
                        .foregroundStyle(TeamTheme.textTertiary)
                }
                .padding(14)
                .background(TeamTheme.orange.opacity(0.10), in: RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
            .contextMenu {
                Button("Dismiss") { dismissedLinkBanner = true }
            }
        }
    }

    // MARK: - Goalkeepers

    private var goalkeeperSection: some View {
        VStack(spacing: 10) {
            SectionHeaderView(icon: "hand.raised.fill", title: "Goalkeepers")
            VStack(spacing: 8) { ForEach(vm.goalkeepers) { gk in goalkeeperCard(gk) } }
        }
    }

    private func goalkeeperCard(_ gk: TeamPlayer) -> some View {
        HStack(spacing: 14) {
            PlayerAvatarView(image: gk.photo, name: gk.name, role: .goalkeeper, size: 44)

            VStack(alignment: .leading, spacing: 3) {
                Text(gk.name).font(.system(size: 16, weight: .bold)).foregroundStyle(TeamTheme.textPrimary)
                if let s = vm.stats(for: gk).goalkeeper {
                    HStack(spacing: 12) {
                        Label("\(s.matchesAttended)", systemImage: "checkmark.circle")
                        Label("\(s.goalsConceded)", systemImage: "xmark.circle").foregroundStyle(TeamTheme.red.opacity(0.8))
                        Label("\(s.cleanSheets)", systemImage: "shield.checkered").foregroundStyle(TeamTheme.green)
                    }.font(.system(size: 11, weight: .medium)).foregroundStyle(TeamTheme.textSecondary)
                }
            }
            Spacer()
            if let s = vm.stats(for: gk).goalkeeper {
                VStack(alignment: .trailing, spacing: 2) {
                    Text(String(format: "%.1f", s.rating)).font(.system(size: 20, weight: .bold, design: .rounded)).foregroundStyle(TeamTheme.orange)
                    Text("rating").font(.system(size: 9, weight: .semibold)).foregroundStyle(TeamTheme.textTertiary).textCase(.uppercase)
                }
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
        .background(TeamTheme.cardBg, in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(TeamTheme.orange.opacity(0.15), lineWidth: 1))
    }

    // MARK: - Statistics

    private var statisticsSection: some View {
        VStack(spacing: 10) {
            SectionHeaderView(icon: "chart.bar.fill", title: "Full Statistics", trailing: "\(vm.filteredPlayers.count) shown")

            VStack(spacing: 8) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(FilterOption.allCases) { o in
                            chipButton(label: o.rawValue, isSelected: vm.filterOption == o, tint: TeamTheme.blue) { vm.filterOption = o }
                        }
                    }
                }
                HStack(spacing: 8) {
                    Text("Sort:").font(.system(size: 12, weight: .medium)).foregroundStyle(TeamTheme.textTertiary)
                    ForEach(SortOption.allCases) { o in
                        chipButton(label: o.rawValue, isSelected: vm.sortOption == o, tint: TeamTheme.purple) { vm.sortOption = o }
                    }
                    Spacer()
                }
            }

            tableHeader

            VStack(spacing: 0) {
                ForEach(Array(vm.filteredPlayers.enumerated()), id: \.element.id) { i, p in
                    StatRowView(index: i, player: p, stats: vm.stats(for: p),
                                highlightBonus: vm.sortOption == .totalWithBonus, isAdmin: vm.isAdmin) {
                        editingPlayerId = p.id
                    }
                    if i < vm.filteredPlayers.count - 1 { Divider().overlay(TeamTheme.cardBorder).padding(.horizontal, 12) }
                }
            }
            .background(TeamTheme.cardBg, in: RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(TeamTheme.cardBorder, lineWidth: 1))
        }
        .animation(.easeInOut(duration: 0.3), value: vm.sortOption)
        .animation(.easeInOut(duration: 0.3), value: vm.filterOption)
    }

    private var tableHeader: some View {
        HStack(spacing: 0) {
            Text("#").frame(width: 28, alignment: .center)
            Text("Name").frame(maxWidth: .infinity, alignment: .leading)
            Text("G").frame(width: 32, alignment: .trailing)
            Text("A").frame(width: 32, alignment: .trailing)
            Text("T").frame(width: 32, alignment: .trailing)
            Text("T+B").frame(width: 50, alignment: .trailing)
            if vm.isAdmin { Spacer().frame(width: 30) }
        }
        .font(.system(size: 10, weight: .bold)).foregroundStyle(TeamTheme.textTertiary).textCase(.uppercase).tracking(0.3)
        .padding(.horizontal, 12).padding(.vertical, 6)
    }

    // MARK: - Actions

    private var actionButtons: some View {
        VStack(spacing: 10) {
            Button { showCoachDetail = true } label: {
                HStack(spacing: 10) {
                    Image(systemName: "person.badge.clock.fill").font(.system(size: 18))
                    Text("View Coaching Staff").font(.system(size: 16, weight: .bold))
                }
                .frame(maxWidth: .infinity).padding(.vertical, 15)
                .foregroundStyle(TeamTheme.purple)
                .background(TeamTheme.purple.opacity(0.12), in: RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(TeamTheme.purple.opacity(0.2), lineWidth: 1))
            }
        }
    }

    private func chipButton(label: String, isSelected: Bool, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 13, weight: .semibold))
                .padding(.horizontal, 14).padding(.vertical, 7)
                .foregroundStyle(isSelected ? .white : TeamTheme.textSecondary)
                .background(isSelected ? AnyShapeStyle(tint.gradient) : AnyShapeStyle(TeamTheme.surface), in: Capsule())
                .overlay(Capsule().stroke(isSelected ? Color.clear : TeamTheme.cardBorder, lineWidth: 1))
        }.buttonStyle(.plain)
    }
}

// MARK: - UUID Identifiable for sheet(item:)
extension UUID: @retroactive Identifiable {
    public var id: UUID { self }
}
