import SwiftUI

/// Team & round setup. Produces an `AliasConfig` + teams, then presents the live
/// game full-screen. Premium categories/difficulties show a Pro badge and are
/// gated by the deck builder for non-subscribers.
struct AliasSetupView: View {
    @EnvironmentObject private var alias: AliasContainer
    @EnvironmentObject private var entitlements: EntitlementService
    @StateObject private var vm = AliasSetupViewModel()

    @State private var engine: AliasGameEngine?
    @State private var showPaywall = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DSSpacing.xl) {
                teamsSection
                categoriesSection
                difficultySection
                roundSection
            }
            .padding(DSSpacing.lg)
        }
        .background(DSColor.groupedBackground.ignoresSafeArea())
        .navigationTitle("New Match")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) { kickOffBar }
        .paywallSheet(isPresented: $showPaywall, source: "alias_setup")
        .fullScreenCover(item: $engine) { engine in
            AliasGameView(engine: engine) { self.engine = nil }
        }
    }

    // MARK: Teams

    private var teamsSection: some View {
        section(title: "Teams") {
            Stepper("Number of teams: \(vm.teamCount)",
                    value: Binding(get: { vm.teamCount }, set: { vm.setTeamCount($0) }),
                    in: AliasSetupViewModel.minTeams...AliasSetupViewModel.maxTeams)
                .font(.subheadline)
            ForEach(0..<vm.teamCount, id: \.self) { i in
                TextField("Team \(i + 1)", text: binding(forTeam: i))
                    .textFieldStyle(.roundedBorder)
            }
        }
    }

    // MARK: Categories

    private var categoriesSection: some View {
        section(title: "Categories") {
            ForEach(AliasCategory.allCases) { category in
                let locked = !category.isFree && !entitlements.isPro
                Button {
                    if locked { showPaywall = true }
                    else { vm.toggleCategory(category) }
                } label: {
                    HStack(spacing: DSSpacing.sm) {
                        Image(systemName: category.icon)
                            .foregroundStyle(DSColor.accent)
                            .frame(width: 24)
                        Text(category.displayName)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(DSColor.textPrimary)
                        Spacer()
                        if locked {
                            PremiumBadge()
                        } else if vm.selectedCategories.contains(category) {
                            Image(systemName: "checkmark.circle.fill").foregroundStyle(DSColor.success)
                        } else {
                            Image(systemName: "circle").foregroundStyle(DSColor.textTertiary)
                        }
                    }
                    .padding(.vertical, DSSpacing.xs)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: Difficulty

    private var difficultySection: some View {
        section(title: "Difficulty") {
            difficultyPicker(title: "From", selection: $vm.minDifficulty)
            difficultyPicker(title: "To", selection: $vm.maxDifficulty)
            if !entitlements.isPro {
                Text("Free play is limited to Easy and Medium cards.")
                    .font(.caption)
                    .foregroundStyle(DSColor.textTertiary)
            }
        }
    }

    private func difficultyPicker(title: String, selection: Binding<AliasDifficulty>) -> some View {
        HStack {
            Text(title).font(.subheadline).foregroundStyle(DSColor.textSecondary)
            Spacer()
            Picker(title, selection: selection) {
                ForEach(AliasDifficulty.allCases) { Text($0.displayName).tag($0) }
            }
            .pickerStyle(.menu)
        }
    }

    // MARK: Round

    private var roundSection: some View {
        section(title: "Round") {
            HStack {
                Text("Turn length").font(.subheadline).foregroundStyle(DSColor.textSecondary)
                Spacer()
                Picker("Turn length", selection: $vm.timerSeconds) {
                    ForEach(AliasConfig.timerOptions, id: \.self) { Text("\($0)s").tag($0) }
                }.pickerStyle(.menu)
            }
            HStack {
                Text("Winning score").font(.subheadline).foregroundStyle(DSColor.textSecondary)
                Spacer()
                Picker("Winning score", selection: $vm.targetScore) {
                    ForEach(AliasConfig.targetScoreOptions, id: \.self) { Text("\($0)").tag($0) }
                }.pickerStyle(.menu)
            }
            Toggle("Penalize skips (−1)", isOn: Binding(
                get: { vm.skipPenalty > 0 },
                set: { vm.skipPenalty = $0 ? 1 : 0 }))
                .font(.subheadline)
        }
    }

    // MARK: Kick off

    private var kickOffBar: some View {
        let canStart = alias.canStart(config: vm.makeConfig(), isPremiumUnlocked: entitlements.isPro)
        return Button {
            HapticFeedback.medium()
            engine = alias.makeEngine(config: vm.makeConfig(),
                                      teams: vm.makeTeams(),
                                      isPremiumUnlocked: entitlements.isPro)
        } label: {
            Text(canStart ? "Kick Off" : "Pick a category with cards")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, DSSpacing.md)
                .background(canStart ? DSColor.accent : DSColor.fill,
                            in: RoundedRectangle(cornerRadius: DSRadius.lg, style: .continuous))
                .foregroundStyle(canStart ? DSColor.onAccent : DSColor.textTertiary)
        }
        .disabled(!canStart)
        .padding(DSSpacing.md)
        .background(DSColor.surface)
    }

    // MARK: Helpers

    private func binding(forTeam i: Int) -> Binding<String> {
        Binding(
            get: { i < vm.teamNames.count ? vm.teamNames[i] : "" },
            set: { newValue in
                while vm.teamNames.count <= i { vm.teamNames.append("") }
                vm.teamNames[i] = newValue
            })
    }

    private func section<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: DSSpacing.sm) {
            Text(title.uppercased())
                .font(.caption.weight(.bold))
                .foregroundStyle(DSColor.textTertiary)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DSSpacing.md)
        .background(RoundedRectangle(cornerRadius: DSRadius.lg, style: .continuous).fill(DSColor.surface))
    }
}
