import SwiftUI

struct TeamGamesView: View {
    @ObservedObject var vm: TeamStore
    @State private var editingGame: TeamGame?
    @State private var showAddGame = false

    private let dateFmt: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "MMM d, yyyy"; return f
    }()

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                recordSummary
                ForEach(vm.games.sorted(by: { $0.date > $1.date })) { game in
                    gameCard(game)
                }
            }
            .padding(.horizontal, 16).padding(.vertical, 16)
        }
        .background(TeamTheme.bg.ignoresSafeArea())
        .navigationTitle("Match History")
        .navigationBarTitleDisplayMode(.large)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar {
            if vm.isAdmin {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { showAddGame = true } label: {
                        Image(systemName: "plus.circle.fill").foregroundStyle(TeamTheme.green)
                    }
                }
            }
        }
        .sheet(item: $editingGame) { game in EditGameSheet(vm: vm, game: game) }
        .sheet(isPresented: $showAddGame) { EditGameSheet(vm: vm) }
    }

    private var recordSummary: some View {
        let g = vm.games
        let wins = g.filter { $0.result == .win }.count
        let draws = g.filter { $0.result == .draw }.count
        let losses = g.filter { $0.result == .loss }.count
        let gf = g.reduce(0) { $0 + $1.goalsFor }
        let ga = g.reduce(0) { $0 + $1.goalsAgainst }

        return HStack(spacing: 0) {
            pill("\(wins)", "W", TeamTheme.green)
            pill("\(draws)", "D", TeamTheme.orange)
            pill("\(losses)", "L", TeamTheme.red)
            Divider().overlay(TeamTheme.cardBorder).frame(height: 30).padding(.horizontal, 12)
            VStack(spacing: 2) {
                Text("\(gf):\(ga)").font(.system(size: 18, weight: .bold, design: .rounded)).foregroundStyle(TeamTheme.textPrimary)
                Text("GF:GA").font(.system(size: 9, weight: .bold)).foregroundStyle(TeamTheme.textTertiary).textCase(.uppercase)
            }.frame(maxWidth: .infinity)
        }
        .padding(.vertical, 14)
        .background(TeamTheme.cardBg, in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(TeamTheme.cardBorder, lineWidth: 1))
    }

    private func pill(_ value: String, _ label: String, _ color: Color) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.system(size: 20, weight: .bold, design: .rounded)).foregroundStyle(color)
            Text(label).font(.system(size: 9, weight: .bold)).foregroundStyle(TeamTheme.textTertiary).textCase(.uppercase)
        }.frame(maxWidth: .infinity)
    }

    private func gameCard(_ game: TeamGame) -> some View {
        VStack(spacing: 0) {
            HStack {
                resultBadge(game.result)
                VStack(alignment: .leading, spacing: 2) {
                    Text("vs \(game.opponent)").font(.system(size: 16, weight: .bold)).foregroundStyle(TeamTheme.textPrimary)
                    Text(dateFmt.string(from: game.date)).font(.system(size: 12, weight: .medium)).foregroundStyle(TeamTheme.textTertiary)
                }
                Spacer()

                if let img = game.highlightImage {
                    Image(uiImage: img).resizable().scaledToFill()
                        .frame(width: 50, height: 32).clipShape(RoundedRectangle(cornerRadius: 6))
                }

                Text(game.score).font(.system(size: 28, weight: .black, design: .rounded)).foregroundStyle(color(game.result))
            }
            .padding(.horizontal, 16).padding(.vertical, 14)

            Divider().overlay(TeamTheme.cardBorder).padding(.horizontal, 16)

            if !game.goalDetails.isEmpty {
                VStack(spacing: 0) {
                    ForEach(game.goalDetails) { goal in
                        HStack(spacing: 8) {
                            Text(goal.time)
                                .font(.system(size: 11, weight: .medium, design: .monospaced))
                                .foregroundStyle(TeamTheme.textTertiary)
                                .frame(width: 42, alignment: .trailing)
                            Image(systemName: goal.isOpponent ? "xmark.circle.fill" : "soccerball")
                                .font(.system(size: 10))
                                .foregroundStyle(goal.isOpponent ? TeamTheme.red.opacity(0.7) : TeamTheme.green)
                            Text(goal.isOpponent ? goal.scorer : goal.scorer)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(goal.isOpponent ? TeamTheme.red.opacity(0.7) : TeamTheme.textPrimary)
                            if !goal.assist.isEmpty {
                                Text("(\(goal.assist))")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(TeamTheme.textTertiary)
                            }
                            Spacer()
                        }
                        .padding(.vertical, 3)
                    }
                }
                .padding(.horizontal, 16).padding(.vertical, 8)
            } else if !game.scorers.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "soccerball").font(.system(size: 11)).foregroundStyle(TeamTheme.textTertiary)
                    Text(game.scorers.joined(separator: ", ")).font(.system(size: 13, weight: .medium)).foregroundStyle(TeamTheme.textSecondary).lineLimit(2)
                    Spacer()
                }.padding(.horizontal, 16).padding(.vertical, 10)
            }

            if !game.mediaLinks.isEmpty {
                Divider().overlay(TeamTheme.cardBorder).padding(.horizontal, 16)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(game.mediaLinks) { link in
                            if let url = link.url {
                                Link(destination: url) { linkPill(link) }
                            } else {
                                linkPill(link)
                            }
                        }
                    }.padding(.horizontal, 16).padding(.vertical, 10)
                }
            }

            if vm.isAdmin {
                Divider().overlay(TeamTheme.cardBorder).padding(.horizontal, 16)
                Button { editingGame = game } label: {
                    Label("Edit Game", systemImage: "pencil")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(TeamTheme.blue)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                }.buttonStyle(.plain)
            }
        }
        .background(TeamTheme.cardBg, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(color(game.result).opacity(0.15), lineWidth: 1))
    }

    private func linkPill(_ link: MediaLink) -> some View {
        HStack(spacing: 5) {
            Image(systemName: link.type.icon).font(.system(size: 11))
            Text(link.title).font(.system(size: 12, weight: .semibold))
        }
        .padding(.horizontal, 12).padding(.vertical, 7)
        .foregroundStyle(TeamTheme.blue)
        .background(TeamTheme.blue.opacity(0.1), in: Capsule())
        .overlay(Capsule().stroke(TeamTheme.blue.opacity(0.2), lineWidth: 1))
    }

    private func resultBadge(_ r: TeamGameResult) -> some View {
        Text(r.rawValue).font(.system(size: 13, weight: .black, design: .rounded)).foregroundStyle(.white)
            .frame(width: 32, height: 32).background(color(r), in: RoundedRectangle(cornerRadius: 8))
    }

    private func color(_ r: TeamGameResult) -> Color {
        switch r { case .win: return TeamTheme.green; case .draw: return TeamTheme.orange; case .loss: return TeamTheme.red }
    }
}
