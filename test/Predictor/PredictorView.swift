import SwiftUI

private enum SimulateSection: String, CaseIterable, Identifiable {
    case gameweek
    case table
    case stats

    var id: String { rawValue }

    var title: String {
        switch self {
        case .gameweek: "Gameweek"
        case .table: "Table"
        case .stats: "Stats"
        }
    }

    var icon: String {
        switch self {
        case .gameweek: "sportscourt.fill"
        case .table: "list.number"
        case .stats: "chart.bar.fill"
        }
    }
}

struct PredictorView: View {
    @StateObject private var store = PredictorStore.shared
    @AppStorage(PredictorStore.simulateOnlyKey) private var simulateOnly = false
    @Environment(\.appPalette) private var palette
    @State private var section: SimulateSection = .gameweek
    @State private var detailMatch: PLMatch?
    @State private var detailSimulation: PLMatchSimulation?

    var body: some View {
        ZStack {
            PredictorBackdrop()

            if store.database != nil {
                VStack(spacing: 12) {
                    sectionPicker
                        .padding(.horizontal)

                    ScrollView {
                        VStack(spacing: 16) {
                            switch section {
                            case .gameweek:
                                if let gameweek = store.gameweek(store.selectedGameweek) {
                                    header(for: gameweek)
                                    matchesSection(for: gameweek)
                                }
                            case .table:
                                PLStandingsSection(store: store)
                            case .stats:
                                PLSeasonStatsSection(store: store)
                            }
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 24)
                        .adaptiveContentWidth(AdaptiveLayout.gameMaxWidth)
                    }
                }
                .padding(.top, 8)
            } else {
                ContentUnavailableView(
                    "No Fixtures",
                    systemImage: "sportscourt",
                    description: Text("Pull to refresh or check your connection.")
                )
                .foregroundStyle(palette.textPrimary)
            }
        }
        .navigationTitle("Simulate")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Task { await store.refreshFromWeb(resetProgress: true) }
                } label: {
                    if store.isRefreshing {
                        ProgressView().tint(palette.toolbarTint)
                    } else {
                        Image(systemName: "arrow.clockwise")
                    }
                }
                .disabled(store.isRefreshing)
            }
        }
        .task {
            if store.database == nil {
                await store.refreshFromWeb()
            }
        }
        .sheet(item: $detailMatch) { match in
            if let simulation = detailSimulation ?? store.simulation(for: match.id) {
                PLMatchDetailView(match: match, simulation: simulation)
                    .withAppPalette()
            } else {
                ContentUnavailableView("No Report", systemImage: "chart.bar.doc.horizontal")
                    .withAppPalette()
            }
        }
    }

    private var sectionPicker: some View {
        HStack(spacing: 4) {
            ForEach(SimulateSection.allCases) { item in
                Button {
                    withAnimation(.smooth(duration: 0.25)) {
                        section = item
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: item.icon)
                            .font(.caption.weight(.semibold))
                        Text(item.title)
                            .font(.subheadline.weight(.bold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .foregroundStyle(section == item ? palette.textPrimary : palette.textMuted)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(section == item ? palette.selectedTabFill : Color.clear)
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(palette.chromeFill)
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(palette.chromeStroke, lineWidth: 1)
                )
        )
        .adaptiveContentWidth(AdaptiveLayout.gameMaxWidth)
    }

    // MARK: - Header

    private func header(for gameweek: PLGameweek) -> some View {
        let prediction = store.prediction(for: gameweek.number)
        let locked = store.isPredictionLocked(for: gameweek.number)
        let simulated = store.isGameweekSimulated(gameweek.number)
        let score = simulateOnly ? nil : store.score(for: gameweek)

        return VStack(spacing: 14) {
            HStack {
                gameweekStepper(for: gameweek)
                Spacer()
                seasonBadge
            }

            if simulateOnly {
                Text("Simulation mode — no predictions required")
                    .font(.caption)
                    .foregroundStyle(palette.textMuted)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            HStack(spacing: 12) {
                if simulateOnly {
                    statCard(
                        title: "Mode",
                        value: "Sim",
                        subtitle: simulated ? "GW\(gameweek.number) played" : "Ready to run",
                        tint: PredictorStyle.purple
                    )
                } else {
                    statCard(title: "Season", value: "\(store.seasonPoints())", subtitle: "pts", tint: PredictorStyle.purple)
                }
                statCard(
                    title: "GW\(gameweek.number)",
                    value: score.map { "\($0.points)" } ?? (simulated ? "Done" : "—"),
                    subtitle: score?.summary ?? statusText(
                        gameweek: gameweek,
                        prediction: prediction,
                        simulated: simulated
                    ),
                    tint: PredictorStyle.green
                )
            }

            if let error = store.lastRefreshError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(PredictorStyle.danger)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            actionBar(
                for: gameweek,
                prediction: prediction,
                locked: locked,
                simulated: simulated,
                score: score
            )
        }
        .padding(16)
        .background(palette.panel())
    }

    private var seasonBadge: some View {
        Text(store.season)
            .font(.caption.weight(.bold))
            .foregroundStyle(palette.textSecondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Capsule().fill(palette.surfaceFill))
    }

    private func gameweekStepper(for gameweek: PLGameweek) -> some View {
        HStack(spacing: 8) {
            Button {
                store.selectedGameweek = max(1, gameweek.number - 1)
            } label: {
                Image(systemName: "chevron.left")
                    .font(.body.weight(.semibold))
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(palette.surfaceFill))
            }
            .disabled(gameweek.number <= 1)

            VStack(alignment: .leading, spacing: 2) {
                Text("Gameweek \(gameweek.number)")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(palette.textPrimary)
                if let date = gameweek.kickoffDate {
                    Text(PLPredictorFormat.dayFormatter.string(from: date))
                        .font(.caption)
                        .foregroundStyle(palette.textMuted)
                }
            }

            Button {
                store.selectedGameweek = min(store.gameweeks.count, gameweek.number + 1)
            } label: {
                Image(systemName: "chevron.right")
                    .font(.body.weight(.semibold))
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(palette.surfaceFill))
            }
            .disabled(gameweek.number >= store.gameweeks.count)
        }
        .foregroundStyle(palette.textPrimary)
        .buttonStyle(.plain)
    }

    private func statCard(title: String, value: String, subtitle: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased())
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(palette.textMuted)
            Text(value)
                .font(.title2.weight(.bold))
                .foregroundStyle(palette.textPrimary)
            Text(subtitle)
                .font(.caption)
                .foregroundStyle(tint)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(palette.surfaceFill)
        )
    }

    private func statusText(
        gameweek: PLGameweek,
        prediction: PLGameweekPrediction,
        simulated: Bool
    ) -> String {
        if simulated { return "Simulated" }
        if simulateOnly { return "Tap simulate below" }
        let picked = prediction.picks.count
        let total = gameweek.matches.count
        return "\(picked)/\(total) picked"
    }

    @ViewBuilder
    private func actionBar(
        for gameweek: PLGameweek,
        prediction: PLGameweekPrediction,
        locked: Bool,
        simulated: Bool,
        score: PLGameweekScore?
    ) -> some View {
        if simulateOnly {
            VStack(spacing: 8) {
                primaryActionButton(
                    title: simulated ? "Re-simulate Gameweek" : "Simulate Gameweek",
                    enabled: true
                ) {
                    store.simulateOnlyGameweek(gameweek.number, reroll: simulated)
                    HapticFeedback.success()
                }

                if simulated {
                    secondaryActionButton(title: "Clear Results", icon: "arrow.counterclockwise") {
                        store.resetGameweek(gameweek.number)
                        HapticFeedback.light()
                    }
                }

                secondaryActionButton(title: "Simulate Entire Season", icon: "forward.end.fill") {
                    store.simulateFullSeason(reroll: false)
                    HapticFeedback.success()
                }
            }
        } else if locked {
            VStack(spacing: 8) {
                if let score, simulated {
                    resultBanner(score: score, gameweek: gameweek)
                } else if !simulated {
                    Text("Simulation didn't complete — try re-simulating.")
                        .font(.caption)
                        .foregroundStyle(PredictorStyle.danger)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                HStack(spacing: 8) {
                    secondaryActionButton(title: "Edit Picks", icon: "pencil") {
                        store.resetGameweek(gameweek.number)
                        HapticFeedback.light()
                    }
                    secondaryActionButton(title: "Re-simulate", icon: "arrow.clockwise") {
                        store.simulateGameweek(gameweek.number, reroll: true)
                        HapticFeedback.success()
                    }
                }
                secondaryActionButton(title: "Simulate Entire Season", icon: "forward.end.fill") {
                    store.simulateFullSeason(reroll: false)
                    HapticFeedback.success()
                }
            }
        } else {
            VStack(spacing: 8) {
                submitBar(for: gameweek, prediction: prediction)
                secondaryActionButton(title: "Simulate Entire Season", icon: "forward.end.fill") {
                    store.simulateFullSeason(reroll: false)
                    HapticFeedback.success()
                }
            }
        }
    }

    private func primaryActionButton(title: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.headline.weight(.bold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .foregroundStyle(enabled ? palette.buttonOnAccent : palette.textMuted)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(enabled ? palette.selectedTabFill : palette.surfaceFill)
                )
        }
        .disabled(!enabled)
        .buttonStyle(.plain)
    }

    private func secondaryActionButton(title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 11)
                .foregroundStyle(palette.textSecondary)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(palette.surfaceFill)
                )
        }
        .buttonStyle(.plain)
    }

    private func submitBar(for gameweek: PLGameweek, prediction: PLGameweekPrediction) -> some View {
        let complete = prediction.isComplete(for: gameweek)
        return Button {
            store.lockPrediction(for: gameweek.number)
            HapticFeedback.success()
        } label: {
            Text(complete ? "Lock & Simulate" : "Pick all \(gameweek.matches.count) matches")
                .font(.headline.weight(.bold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .foregroundStyle(complete ? palette.buttonOnAccent : palette.textMuted)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(complete ? palette.selectedTabFill : palette.surfaceFill)
                )
        }
        .disabled(!complete)
        .buttonStyle(.plain)
    }

    private func resultBanner(score: PLGameweekScore, gameweek: PLGameweek) -> some View {
        HStack {
            Image(systemName: "checkmark.seal.fill")
            Text("Locked · \(score.summary)")
                .font(.subheadline.weight(.semibold))
            Spacer()
            if gameweek.isComplete {
                ShareLink(item: shareText(score: score, gameweek: gameweek)) {
                    Image(systemName: "square.and.arrow.up")
                }
            }
        }
        .foregroundStyle(palette.textPrimary)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(PredictorStyle.green.opacity(0.25))
        )
    }

    private func shareText(score: PLGameweekScore, gameweek: PLGameweek) -> String {
        "Premier League Predictor \(store.season) · GW\(gameweek.number)\n\(score.points)/\(score.maxPoints) pts · \(score.correct)/\(score.total) correct"
    }

    // MARK: - Matches

    private func matchesSection(for gameweek: PLGameweek) -> some View {
        let prediction = store.prediction(for: gameweek.number)
        let locked = store.isPredictionLocked(for: gameweek.number)
        let showPicks = !simulateOnly && !locked

        return VStack(spacing: 12) {
            ForEach(gameweek.matches) { match in
                let simulation = store.simulation(for: match.id)
                PLMatchCard(
                    match: match,
                    result: store.result(for: match),
                    simulation: simulation,
                    pick: simulateOnly ? nil : prediction.pick(for: match),
                    showPicks: showPicks,
                    locked: locked,
                    odds: store.cachedOdds[match.id],
                    onPick: { pick in
                        store.setPick(pick, for: match)
                        HapticFeedback.light()
                    },
                    onShowDetail: {
                        detailSimulation = simulation
                        detailMatch = match
                    }
                )
            }
        }
    }
}

// MARK: - Match card

private struct PLMatchCard: View {
    let match: PLMatch
    let result: PLMatchResult?
    let simulation: PLMatchSimulation?
    let pick: PLPick?
    let showPicks: Bool
    let locked: Bool
    let odds: PLModelOdds?
    let onPick: (PLPick) -> Void
    let onShowDetail: () -> Void

    @Environment(\.appPalette) private var palette

    private var isPlayed: Bool { result != nil }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            headerRow

            if isPlayed, let simulation {
                playedScoreboard(simulation)
                if let halftimeLabel = simulation.halftimeLabel {
                    Text("HT \(halftimeLabel)")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(palette.textMuted)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
                playedStatsRow(simulation)
                goalsList(simulation)
                reportButton
            } else {
                teamsRow
                if let odds {
                    modelStrip(odds: odds)
                }
                if showPicks {
                    pickRow
                }
            }
        }
        .padding(14)
        .background(palette.panel())
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(borderColor, lineWidth: 1.5)
        )
    }

    private var headerRow: some View {
        HStack {
            Text(match.displayKickoff)
                .font(.caption.weight(.medium))
                .foregroundStyle(palette.textMuted)
            Spacer()
            if isPlayed {
                Text("FT")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(palette.textMuted)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(palette.surfaceFill))
            }
        }
    }

    private var teamsRow: some View {
        HStack(alignment: .top, spacing: 12) {
            teamColumn(name: match.homeTeam, clubID: match.homeClubID, alignment: .leading)
            Text("vs")
                .font(.caption.weight(.bold))
                .foregroundStyle(palette.textMuted)
                .padding(.top, 10)
            teamColumn(name: match.awayTeam, clubID: match.awayClubID, alignment: .trailing)
        }
    }

    private func playedScoreboard(_ simulation: PLMatchSimulation) -> some View {
        HStack(alignment: .top, spacing: 10) {
            teamScoreColumn(
                name: match.homeTeam,
                clubID: match.homeClubID,
                goals: simulation.homeGoals,
                xG: simulation.homeStats.formattedXG,
                alignment: .leading
            )

            VStack(spacing: 4) {
                Text("\(simulation.homeGoals) – \(simulation.awayGoals)")
                    .font(.title2.weight(.heavy))
                    .foregroundStyle(palette.textPrimary)
                    .monospacedDigit()
                Text("FT")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(palette.textMuted)
            }
            .padding(.top, 6)

            teamScoreColumn(
                name: match.awayTeam,
                clubID: match.awayClubID,
                goals: simulation.awayGoals,
                xG: simulation.awayStats.formattedXG,
                alignment: .trailing
            )
        }
    }

    private func teamScoreColumn(
        name: String,
        clubID: String?,
        goals: Int,
        xG: String,
        alignment: HorizontalAlignment
    ) -> some View {
        VStack(spacing: 6) {
            ClubLogoImage(clubID: clubID, clubName: name, style: .row)
            Text(name)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(palette.textPrimary)
                .multilineTextAlignment(alignment == .leading ? .leading : .trailing)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: alignment == .leading ? .leading : .trailing)
            Text("\(goals) goal\(goals == 1 ? "" : "s") · \(xG) xG")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(PredictorStyle.accent)
                .frame(maxWidth: .infinity, alignment: alignment == .leading ? .leading : .trailing)
        }
        .frame(maxWidth: .infinity, alignment: alignment == .leading ? .leading : .trailing)
    }

    private func playedStatsRow(_ simulation: PLMatchSimulation) -> some View {
        HStack(spacing: 6) {
            playedStatPill(
                label: "Shots",
                value: "\(simulation.homeStats.shots)–\(simulation.awayStats.shots)"
            )
            playedStatPill(
                label: "On target",
                value: "\(simulation.homeStats.shotsOnTarget)–\(simulation.awayStats.shotsOnTarget)"
            )
            playedStatPill(
                label: "Possession",
                value: "\(simulation.homeStats.possession)–\(simulation.awayStats.possession)%"
            )
        }
    }

    private func playedStatPill(label: String, value: String) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.caption.weight(.bold))
                .foregroundStyle(palette.textPrimary)
                .monospacedDigit()
            Text(label)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(palette.textMuted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(palette.surfaceFill)
        )
    }

    private func goalsList(_ simulation: PLMatchSimulation) -> some View {
        Group {
            if simulation.goals.isEmpty {
                Text("No goals")
                    .font(.caption)
                    .foregroundStyle(palette.textMuted)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                VStack(spacing: 6) {
                    ForEach(simulation.goals) { goal in
                        HStack(spacing: 8) {
                            Text(goal.minuteLabel)
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(palette.textPrimary)
                                .frame(width: 30)
                                .padding(.vertical, 3)
                                .background(
                                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                                        .fill(goal.isHome ? PredictorStyle.purple.opacity(0.35) : PredictorStyle.green.opacity(0.35))
                                )

                            Text(goal.scorerName)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(palette.textPrimary)
                                .lineLimit(1)

                            Spacer(minLength: 0)

                            Text(goal.typeLabel)
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(goal.isPenalty ? PredictorStyle.penalty : PredictorStyle.goal)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(
                                    Capsule()
                                        .fill((goal.isPenalty ? PredictorStyle.penalty : PredictorStyle.goal).opacity(0.15))
                                )
                        }
                    }
                }
            }
        }
    }

    private var reportButton: some View {
        Button(action: onShowDetail) {
            Label("Full match report", systemImage: "chart.bar.doc.horizontal")
                .font(.caption.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 9)
                .foregroundStyle(palette.textSecondary)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(palette.surfaceFill)
                )
        }
        .buttonStyle(.plain)
    }

    private var borderColor: Color {
        guard let pick, let result else {
            return palette.panelStroke
        }
        return pick.matches(result: result) ? PredictorStyle.green.opacity(0.6) : PredictorStyle.danger.opacity(0.5)
    }

    private func teamColumn(name: String, clubID: String?, alignment: HorizontalAlignment) -> some View {
        VStack(spacing: 6) {
            ClubLogoImage(clubID: clubID, clubName: name, style: .row)
            Text(name)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(palette.textPrimary)
                .multilineTextAlignment(alignment == .leading ? .leading : .trailing)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: alignment == .leading ? .leading : .trailing)
        }
        .frame(maxWidth: .infinity, alignment: alignment == .leading ? .leading : .trailing)
    }

    private func modelStrip(odds: PLModelOdds) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "chart.bar.fill")
                .font(.caption2)
            Text("Squad model")
                .font(.caption2.weight(.semibold))
            Spacer()
            modelChip("H", value: odds.home, pick: .home, odds: odds)
            modelChip("D", value: odds.draw, pick: .draw, odds: odds)
            modelChip("A", value: odds.away, pick: .away, odds: odds)
        }
        .foregroundStyle(palette.textMuted)
    }

    private func modelChip(_ label: String, value: Double, pick: PLPick, odds: PLModelOdds) -> some View {
        Text("\(label) \(SquadStrengthModel.formattedProbability(value))")
            .font(.system(size: 10, weight: .bold))
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
            .background(
                Capsule().fill(odds.favorite == pick ? PredictorStyle.purple.opacity(0.35) : palette.surfaceFill)
            )
    }

    private var pickRow: some View {
        HStack(spacing: 8) {
            ForEach(PLPick.allCases) { option in
                pickButton(option)
            }
        }
    }

    private func pickButton(_ option: PLPick) -> some View {
        let selected = pick == option
        let correct: Bool? = {
            guard let pick, let result else { return nil }
            return pick == option && option.matches(result: result)
        }()

        return Button {
            guard showPicks, !locked, !isPlayed else { return }
            onPick(option)
        } label: {
            Text(option.label)
                .font(.subheadline.weight(.bold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .foregroundStyle(foreground(for: option, selected: selected, correct: correct))
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(background(for: option, selected: selected, correct: correct))
                )
        }
        .buttonStyle(.plain)
        .disabled(!showPicks || locked || isPlayed)
    }

    private func foreground(for option: PLPick, selected: Bool, correct: Bool?) -> Color {
        if let correct, selected {
            return palette.textPrimary
        }
        return selected ? palette.buttonOnAccent : palette.textSecondary
    }

    private func background(for option: PLPick, selected: Bool, correct: Bool?) -> Color {
        if let correct, selected {
            return correct ? PredictorStyle.green : PredictorStyle.danger
        }
        return selected ? palette.selectedTabFill : palette.surfaceFill
    }
}

// MARK: - Style

private enum PredictorStyle {
    static let purple = Color(red: 0.55, green: 0.38, blue: 0.98)
    static let green = Color(red: 0.22, green: 0.78, blue: 0.48)
    static let danger = Color(red: 0.92, green: 0.28, blue: 0.32)
    static let accent = Color(red: 0.72, green: 0.84, blue: 1.0)
    static let goal = Color(red: 0.55, green: 0.9, blue: 0.62)
    static let penalty = Color(red: 1.0, green: 0.72, blue: 0.28)
}

private struct PredictorBackdrop: View {
    @Environment(\.appPalette) private var palette

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [palette.backdropTop, palette.backdropBottom],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            RadialGradient(
                colors: [palette.accentGlow, .clear],
                center: .topTrailing,
                startRadius: 20,
                endRadius: 320
            )
        }
        .ignoresSafeArea()
    }
}

#Preview {
    NavigationStack {
        PredictorView()
            .withAppPalette()
    }
}
