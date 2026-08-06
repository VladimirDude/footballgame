import SwiftUI

struct EditPlayerSheet: View {
    @ObservedObject var vm: TeamStore
    let playerId: UUID
    @Environment(\.dismiss) private var dismiss

    @State private var name: String
    @State private var bonus: Double
    @State private var carryGoals: Int
    @State private var carryAssists: Int
    @State private var gkAttended: Int
    @State private var gkConceded: Int
    @State private var gkCleanSheets: Int
    @State private var photo: UIImage?
    @State private var showImagePicker = false
    @State private var specialty: String
    @State private var tactics: String
    @State private var experience: String
    @State private var philosophy: String

    private var player: TeamPlayer? { vm.players.first { $0.id == playerId } }

    /// Hand-entered figures are written against a specific season, so the sheet
    /// always edits one — the current season when the view is scoped to all time.
    private var editingSeasonID: UUID? {
        if case .season(let id) = vm.seasonScope { return id }
        return vm.currentSeason?.id
    }

    private var derived: PlayerSeasonStats {
        player.map { vm.stats(for: $0) } ?? .empty(playerId)
    }

    private var scopeHeader: String {
        if case .season = vm.seasonScope { return vm.seasonScopeLabel }
        return "All time"
    }

    private var hasCarryOver: Bool { carryGoals > 0 || carryAssists > 0 }

    init(vm: TeamStore, playerId: UUID) {
        self.vm = vm
        self.playerId = playerId
        let p = vm.players.first { $0.id == playerId }
        let seasonID: UUID? = {
            if case .season(let id) = vm.seasonScope { return id }
            return vm.currentSeason?.id
        }()
        let entry = seasonID.flatMap { vm.seasonEntry(for: playerId, seasonID: $0) }
        _name = State(initialValue: p?.name ?? "")
        _bonus = State(initialValue: entry?.bonusPoints ?? 0)
        _carryGoals = State(initialValue: entry?.carryOverGoals ?? 0)
        _carryAssists = State(initialValue: entry?.carryOverAssists ?? 0)
        _gkAttended = State(initialValue: entry?.goalkeeper?.matchesAttended ?? 0)
        _gkConceded = State(initialValue: entry?.goalkeeper?.goalsConceded ?? 0)
        _gkCleanSheets = State(initialValue: entry?.goalkeeper?.cleanSheets ?? 0)
        _photo = State(initialValue: p?.photo)
        _specialty = State(initialValue: p?.coachInfo?.specialty ?? "")
        _tactics = State(initialValue: p?.coachInfo?.tactics ?? "")
        _experience = State(initialValue: p?.coachInfo?.experience ?? "")
        _philosophy = State(initialValue: p?.coachInfo?.philosophy ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Profile") {
                    HStack {
                        PlayerAvatarView(image: photo, name: name, role: player?.role ?? .player, size: 60)
                        Spacer()
                        Button("Change Photo") { showImagePicker = true }
                            .font(.system(size: 14, weight: .medium))
                    }
                    TextField("Name", text: $name)
                    if let role = player?.role {
                        HStack { Text("Role"); Spacer(); Text(role.rawValue).foregroundStyle(.secondary) }
                    }
                }

                if player?.role != .coach {
                    Section {
                        // Read-only: goals and assists are counted from the match
                        // log. An editable stepper here would fight the derivation
                        // and there'd be no way to tell which number was true.
                        LabeledContent("Goals", value: "\(derived.goals)")
                        LabeledContent("Assists", value: "\(derived.assists)")
                        HStack {
                            Text("Bonus")
                            Spacer()
                            TextField("0.0", value: $bonus, format: .number)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 60)
                        }
                    } header: {
                        Text(scopeHeader)
                    } footer: {
                        Text("Goals and assists come from the match log. Add scorers to a match and they'll count here.")
                    }

                    if hasCarryOver {
                        Section {
                            Stepper("Goals: \(carryGoals)", value: $carryGoals, in: 0...999)
                            Stepper("Assists: \(carryAssists)", value: $carryAssists, in: 0...999)
                        } header: {
                            Text("Recorded before match logging")
                        } footer: {
                            Text("These were entered by hand before matches tracked scorers, and are included in the totals above. Set them to zero once the match log is complete.")
                        }
                    }
                }

                if player?.role == .goalkeeper {
                    Section("Goalkeeper Stats") {
                        Stepper("Matches: \(gkAttended)", value: $gkAttended, in: 0...999)
                        Stepper("Conceded: \(gkConceded)", value: $gkConceded, in: 0...999)
                        Stepper("Clean Sheets: \(gkCleanSheets)", value: $gkCleanSheets, in: 0...999)
                    }
                }

                if player?.role == .coach {
                    Section("Coach Info") {
                        TextField("Specialty", text: $specialty)
                        TextField("Experience", text: $experience)
                        ZStack(alignment: .topLeading) {
                            if tactics.isEmpty {
                                Text("Tactics").foregroundStyle(.secondary).padding(.top, 8)
                            }
                            TextEditor(text: $tactics).frame(minHeight: 80)
                        }
                        TextField("Philosophy", text: $philosophy)
                    }
                }

                Section {
                    Button("Delete Player", role: .destructive) {
                        vm.removePlayer(id: playerId)
                        dismiss()
                    }
                }
            }
            .navigationTitle("Edit \(name)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save(); dismiss() }.fontWeight(.bold)
                }
            }
            .sheet(isPresented: $showImagePicker) { ImagePicker(image: $photo) }
        }
    }

    private func save() {
        guard let i = vm.players.firstIndex(where: { $0.id == playerId }) else { return }
        let role = vm.players[i].role
        vm.players[i].name = name
        if vm.players[i].photo !== photo {
            vm.updatePlayerPhoto(id: playerId, photo: photo)
        }
        if role == .coach {
            vm.players[i].coachInfo = CoachInfo(specialty: specialty, tactics: tactics,
                                                experience: experience, philosophy: philosophy)
            return
        }
        // Everything numeric is per-season state, not a property of the player.
        guard let seasonID = editingSeasonID else { return }
        vm.updateSeasonEntry(
            playerID: playerId,
            seasonID: seasonID,
            bonusPoints: bonus,
            goalkeeper: role == .goalkeeper
                ? GoalkeeperStats(matchesAttended: gkAttended, goalsConceded: gkConceded, cleanSheets: gkCleanSheets)
                : nil,
            carryOverGoals: carryGoals,
            carryOverAssists: carryAssists
        )
    }
}

// MARK: - Add TeamPlayer Sheet

struct AddPlayerSheet: View {
    @ObservedObject var vm: TeamStore
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var role: PlayerRole = .player
    @State private var photo: UIImage?
    @State private var showImagePicker = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Profile") {
                    HStack {
                        PlayerAvatarView(image: photo, name: name.isEmpty ? "?" : name, role: role, size: 60)
                        Spacer()
                        Button("Add Photo") { showImagePicker = true }
                            .font(.system(size: 14, weight: .medium))
                    }
                    TextField("Name", text: $name)
                    Picker("Role", selection: $role) {
                        ForEach(PlayerRole.allCases) { r in
                            Text(r.rawValue).tag(r)
                        }
                    }
                }
            }
            .navigationTitle("Add Member")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        guard !name.isEmpty else { return }
                        var p = TeamPlayer(name: name, role: role, photo: photo)
                        if role == .goalkeeper { p.goalkeeperStats = GoalkeeperStats(matchesAttended: 0, goalsConceded: 0, cleanSheets: 0) }
                        if role == .coach { p.coachInfo = CoachInfo(specialty: "", tactics: "", experience: "", philosophy: "") }
                        vm.addPlayer(p)
                        dismiss()
                    }
                    .fontWeight(.bold)
                    .disabled(name.isEmpty)
                }
            }
            .sheet(isPresented: $showImagePicker) { ImagePicker(image: $photo) }
        }
    }
}

// MARK: - Edit Game Sheet

struct EditGameSheet: View {
    @ObservedObject var vm: TeamStore
    @State var game: TeamGame
    let isNew: Bool
    @Environment(\.dismiss) private var dismiss

    @State private var scorersText: String
    @State private var highlightImage: UIImage?
    @State private var showImagePicker = false

    init(vm: TeamStore, game: TeamGame? = nil) {
        self.vm = vm
        let g = game ?? TeamGame()
        _game = State(initialValue: g)
        self.isNew = game == nil
        _scorersText = State(initialValue: g.scorers.joined(separator: ", "))
        _highlightImage = State(initialValue: g.highlightImage)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Match Info") {
                    TextField("Opponent", text: $game.opponent)
                    DatePicker("Date", selection: $game.date, displayedComponents: .date)
                    if !vm.seasons.isEmpty {
                        Picker("Season", selection: $game.seasonID) {
                            ForEach(vm.seasons) { season in
                                Text(season.name).tag(Optional(season.id))
                            }
                            if game.seasonID == nil { Text("Unassigned").tag(UUID?.none) }
                        }
                    }
                    Stepper("Goals For: \(game.goalsFor)", value: $game.goalsFor, in: 0...99)
                    Stepper("Goals Against: \(game.goalsAgainst)", value: $game.goalsAgainst, in: 0...99)
                }

                // Structured rows rather than a comma-separated string: this is
                // what makes `goalDetails` authoritative for new data, so the
                // rankings never need the repair flow for matches added here.
                Section {
                    ForEach($game.goalDetails) { $goal in
                        goalRow($goal)
                    }
                    .onDelete { game.goalDetails.remove(atOffsets: $0) }

                    Button {
                        game.goalDetails.append(GoalDetail(time: "", scorer: ""))
                    } label: {
                        Label("Add Goal", systemImage: "plus.circle")
                    }
                } header: {
                    HStack {
                        Text("Goals")
                        Spacer()
                        Text("\(ourGoalCount) of \(game.goalsFor) credited")
                            .foregroundStyle(ourGoalCount == game.goalsFor ? TeamTheme.textTertiary : TeamTheme.orange)
                    }
                } footer: {
                    Text("Pick the scorer from your squad so the goal counts towards their season stats.")
                }

                Section("Highlight Image") {
                    HStack {
                        if let img = highlightImage {
                            Image(uiImage: img)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 80, height: 50)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        Spacer()
                        Button(highlightImage == nil ? "Add Image" : "Change") { showImagePicker = true }
                            .font(.system(size: 14, weight: .medium))
                    }
                }

                Section("Media Links") {
                    ForEach($game.mediaLinks) { $link in
                        VStack(spacing: 6) {
                            TextField("Title", text: $link.title)
                            TextField("URL", text: $link.urlString)
                                .keyboardType(.URL)
                                .autocapitalization(.none)
                            Picker("Type", selection: $link.type) {
                                ForEach(MediaType.allCases) { t in Text(t.rawValue).tag(t) }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .onDelete { game.mediaLinks.remove(atOffsets: $0) }

                    Button("Add Link") {
                        game.mediaLinks.append(MediaLink())
                    }
                }

                if !isNew {
                    Section {
                        Button("Delete Game", role: .destructive) {
                            vm.removeGame(id: game.id)
                            dismiss()
                        }
                    }
                }
            }
            .navigationTitle(isNew ? "New Game" : "Edit Game")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        game.highlightImage = highlightImage
                        // `scorers` is regenerated from the goal list by the store,
                        // so it can't drift from what's actually recorded.
                        if isNew { vm.addGame(game) } else { vm.updateGame(game) }
                        dismiss()
                    }
                    .fontWeight(.bold)
                    .disabled(game.opponent.isEmpty)
                }
            }
            .sheet(isPresented: $showImagePicker) { ImagePicker(image: $highlightImage) }
        }
    }

    // MARK: - Goal row

    private func goalRow(_ goal: Binding<GoalDetail>) -> some View {
        VStack(spacing: 8) {
            HStack {
                TextField("12:30", text: goal.time)
                    .frame(width: 70)
                    .font(.system(size: 14, design: .monospaced))
                Toggle("Opponent", isOn: goal.isOpponent)
                    .labelsHidden()
                Text(goal.wrappedValue.isOpponent ? "Opponent goal" : "Our goal")
                    .font(.system(size: 12))
                    .foregroundStyle(TeamTheme.textSecondary)
                Spacer()
            }

            if goal.wrappedValue.isOpponent {
                TextField("Scorer (optional)", text: goal.scorer)
            } else {
                Picker("Scorer", selection: scorerBinding(goal)) {
                    Text("Unassigned").tag(UUID?.none)
                    ForEach(squad) { p in Text(p.name).tag(Optional(p.id)) }
                }
                Picker("Assist", selection: assistBinding(goal)) {
                    Text("None").tag(UUID?.none)
                    ForEach(squad) { p in Text(p.name).tag(Optional(p.id)) }
                }
            }
        }
        .padding(.vertical, 4)
    }

    private var squad: [TeamPlayer] { vm.players.filter { $0.role != .coach } }

    private var ourGoalCount: Int { game.goalDetails.filter { !$0.isOpponent }.count }

    /// Keeps the id and the display name in step — the name is still what a v1
    /// client reads, and what shows if the player is later removed.
    private func scorerBinding(_ goal: Binding<GoalDetail>) -> Binding<UUID?> {
        Binding(
            get: { goal.wrappedValue.scorerID },
            set: { id in
                goal.wrappedValue.scorerID = id
                goal.wrappedValue.scorer = squad.first { $0.id == id }?.name ?? goal.wrappedValue.scorer
            }
        )
    }

    private func assistBinding(_ goal: Binding<GoalDetail>) -> Binding<UUID?> {
        Binding(
            get: { goal.wrappedValue.assistID },
            set: { id in
                goal.wrappedValue.assistID = id
                goal.wrappedValue.assist = squad.first { $0.id == id }?.name ?? ""
            }
        )
    }
}
