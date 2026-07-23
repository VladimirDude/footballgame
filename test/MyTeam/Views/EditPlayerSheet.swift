import SwiftUI

struct EditPlayerSheet: View {
    @ObservedObject var vm: TeamStore
    let playerId: UUID
    @Environment(\.dismiss) private var dismiss

    @State private var name: String
    @State private var goals: Int
    @State private var assists: Int
    @State private var bonus: Double
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

    init(vm: TeamStore, playerId: UUID) {
        self.vm = vm
        self.playerId = playerId
        let p = vm.players.first { $0.id == playerId }
        _name = State(initialValue: p?.name ?? "")
        _goals = State(initialValue: p?.goals ?? 0)
        _assists = State(initialValue: p?.assists ?? 0)
        _bonus = State(initialValue: p?.bonusPoints ?? 0)
        _gkAttended = State(initialValue: p?.goalkeeperStats?.matchesAttended ?? 0)
        _gkConceded = State(initialValue: p?.goalkeeperStats?.goalsConceded ?? 0)
        _gkCleanSheets = State(initialValue: p?.goalkeeperStats?.cleanSheets ?? 0)
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
                    Section("Statistics") {
                        Stepper("Goals: \(goals)", value: $goals, in: 0...999)
                        Stepper("Assists: \(assists)", value: $assists, in: 0...999)
                        HStack {
                            Text("Bonus")
                            Spacer()
                            TextField("0.0", value: $bonus, format: .number)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 60)
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
        if let i = vm.players.firstIndex(where: { $0.id == playerId }) {
            vm.players[i].name = name
            vm.players[i].goals = goals
            vm.players[i].assists = assists
            vm.players[i].bonusPoints = bonus
            vm.players[i].photo = photo
            if vm.players[i].role == .goalkeeper {
                vm.players[i].goalkeeperStats = GoalkeeperStats(matchesAttended: gkAttended, goalsConceded: gkConceded, cleanSheets: gkCleanSheets)
            }
            if vm.players[i].role == .coach {
                vm.players[i].coachInfo = CoachInfo(specialty: specialty, tactics: tactics, experience: experience, philosophy: philosophy)
            }
        }
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
                    Stepper("Goals For: \(game.goalsFor)", value: $game.goalsFor, in: 0...99)
                    Stepper("Goals Against: \(game.goalsAgainst)", value: $game.goalsAgainst, in: 0...99)
                }

                Section("Scorers") {
                    TextField("e.g. Narek x2, Rob, Aro", text: $scorersText)
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
                        game.scorers = scorersText.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
                        game.highlightImage = highlightImage
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
}
