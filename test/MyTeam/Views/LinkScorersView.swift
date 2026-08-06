import SwiftUI

/// Repairs scorer names in the match log that don't resolve to a squad member.
///
/// Migration deliberately never guesses: it links only unambiguous names, because
/// it also runs on viewer devices with no roster and no right to edit. Whatever it
/// couldn't resolve lands here, where the person who knows the answer can decide.
struct LinkScorersView: View {
    @ObservedObject var vm: TeamStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if vm.unlinkedScorerNames.isEmpty {
                    DSEmptyState(
                        title: "Everything's linked",
                        systemImage: "checkmark.circle",
                        message: "Every goal in the match log is credited to a player."
                    )
                } else {
                    List {
                        Section {
                            ForEach(vm.unlinkedScorerNames, id: \.name) { item in
                                row(name: item.name, goals: item.goals)
                            }
                        } footer: {
                            Text("Unlinked goals still count towards team totals — they just aren't credited to anyone in the rankings.")
                        }
                    }
                }
            }
            .navigationTitle("Unlinked Names")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func row(name: String, goals: Int) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(name).font(.system(size: 16, weight: .semibold))
                Spacer()
                Text("\(goals) goal\(goals == 1 ? "" : "s")")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(TeamTheme.textSecondary)
            }

            HStack(spacing: 8) {
                Menu {
                    ForEach(candidates) { player in
                        Button {
                            vm.linkScorerName(name, to: player.id)
                        } label: {
                            // The near-miss the matcher found but refused to apply
                            // automatically is surfaced as a hint, never preselected.
                            Text(suggestion(for: name) == player.id ? "\(player.name)  ·  likely" : player.name)
                        }
                    }
                } label: {
                    Label("Match to player", systemImage: "person.crop.circle.badge.checkmark")
                        .font(.system(size: 13, weight: .semibold))
                }
                .disabled(candidates.isEmpty)

                Spacer()

                Button {
                    vm.createPlayerForScorerName(name)
                } label: {
                    Label("Add", systemImage: "plus.circle")
                        .font(.system(size: 13, weight: .semibold))
                }

                Button(role: .destructive) {
                    vm.ignoreScorerName(name)
                } label: {
                    Label("Ignore", systemImage: "xmark.circle")
                        .font(.system(size: 13, weight: .semibold))
                }
            }
            .buttonStyle(.borderless)
        }
        .padding(.vertical, 6)
    }

    private var candidates: [TeamPlayer] {
        vm.players.filter { $0.role != .coach }
    }

    /// The fuzzy match, if any — shown as a hint only.
    private func suggestion(for name: String) -> UUID? {
        PlayerLinker.match(name, in: candidates)?.playerID
    }
}
