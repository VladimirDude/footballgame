import SwiftUI

struct MyTeamView: View {
    @StateObject private var vm = TeamStore()
    @StateObject private var sync = TeamSyncService()
    @EnvironmentObject private var entitlements: EntitlementService
    @State private var showAdminPassphrase = false
    @State private var showAdminPaywall = false
    @State private var showCoachDetail = false
    @State private var showGames = false
    @State private var editingPlayerId: UUID?
    @State private var showAddPlayer = false
    @State private var showAddGame = false
    @State private var editingGame: TeamGame?
    @State private var showTeamIconPicker = false
    @State private var showProfile = false

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                headerSection
                overviewCards
                recentGamesSection
                leaderboardSection
                goalkeeperSection
                statisticsSection
                BonusExplanationView()
                actionButtons
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 32)
            .adaptiveContentWidth(AdaptiveLayout.detailMaxWidth)
        }
        .background(TeamTheme.bg.ignoresSafeArea())
        .searchable(text: $vm.searchText, prompt: "Search player...")
        .navigationTitle("My Team")
        .navigationDestination(isPresented: $showProfile) { TeamProfileView(vm: vm, sync: sync) }
        .navigationDestination(isPresented: $showCoachDetail) { CoachDetailView(coaches: vm.coaches) }
        .navigationDestination(isPresented: $showGames) { TeamGamesView(vm: vm) }
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
                TeamSyncMenu(vm: vm, sync: sync)
            }
            ToolbarItem(placement: .navigationBarTrailing) { adminBadge }
        }
        .sheet(isPresented: $showAdminPassphrase) {
            AdminPassphraseSheet { vm.isAdmin = true }
        }
        .paywallSheet(isPresented: $showAdminPaywall, source: "team_admin")
        .onChange(of: entitlements.isPro) { _, isPro in
            // Losing Pro revokes admin access immediately.
            if !isPro { vm.isAdmin = false }
        }
    }

    // MARK: - Admin Badge

    /// Admin is a Pro feature: free users get the paywall, Pro users must still
    /// enter the secret passphrase. "User" is always available.
    private func requestAdminAccess() {
        guard !vm.isAdmin else { return }
        if entitlements.canAccess(.adminMode) {
            showAdminPassphrase = true
        } else {
            AnalyticsService.shared.log(.featureBlocked(feature: PremiumFeature.adminMode.rawValue))
            showAdminPaywall = true
        }
    }

    private var adminBadge: some View {
        Menu {
            Button {
                vm.isAdmin = false
            } label: {
                Label(AppRole.user.rawValue, systemImage: "lock.fill")
            }
            Button {
                requestAdminAccess()
            } label: {
                Label(AppRole.admin.rawValue, systemImage: entitlements.canAccess(.adminMode) ? "lock.open.fill" : "crown.fill")
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: vm.isAdmin ? "shield.checkered" : "person.fill")
                    .font(.system(size: 12, weight: .bold))
                Text(vm.isAdmin ? AppRole.admin.rawValue : AppRole.user.rawValue)
                    .font(.system(size: 11, weight: .bold))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(vm.isAdmin ? TeamTheme.red.opacity(0.2) : TeamTheme.blue.opacity(0.15), in: Capsule())
            .foregroundStyle(vm.isAdmin ? TeamTheme.red : TeamTheme.blue)
        }
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

                Text("Cognaize Futsal")
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

    private var recentGamesSection: some View {
        let recent = vm.games.sorted { $0.date > $1.date }.prefix(3)
        let wins = vm.games.filter { $0.result == .win }.count
        let record = "\(wins)W \(vm.games.filter { $0.result == .draw }.count)D \(vm.games.filter { $0.result == .loss }.count)L"

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
            SectionHeaderView(icon: "trophy.fill", title: "Leaderboard", trailing: "Top 3")
            VStack(spacing: 8) {
                ForEach(Array(vm.leaderboard.enumerated()), id: \.element.id) { i, p in
                    LeaderboardRow(rank: i + 1, player: p)
                }
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
                if let s = gk.goalkeeperStats {
                    HStack(spacing: 12) {
                        Label("\(s.matchesAttended)", systemImage: "checkmark.circle")
                        Label("\(s.goalsConceded)", systemImage: "xmark.circle").foregroundStyle(TeamTheme.red.opacity(0.8))
                        Label("\(s.cleanSheets)", systemImage: "shield.checkered").foregroundStyle(TeamTheme.green)
                    }.font(.system(size: 11, weight: .medium)).foregroundStyle(TeamTheme.textSecondary)
                }
            }
            Spacer()
            if let s = gk.goalkeeperStats {
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
                    StatRowView(index: i, player: p, highlightBonus: vm.sortOption == .totalWithBonus, isAdmin: vm.isAdmin) {
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
