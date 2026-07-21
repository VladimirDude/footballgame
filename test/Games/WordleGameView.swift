import SwiftUI

struct WordleGameView: View {
    @Environment(\.gameTheme) private var theme

    let target: WordlePlayer
    let guesses: [WordleGuess]
    let gameResult: GameResult?
    @Binding var searchQuery: String
    let suggestions: [WordlePlayer]
    let selectedPlayer: WordlePlayer?
    let duplicateGuess: Bool
    let onSelectPlayer: (WordlePlayer) -> Void
    let onClearSelection: () -> Void
    let onSubmit: () -> Void
    let onPlayAgain: () -> Void

    private let columns = ["Nation", "League", "Club", "Pos", "Value"]

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: GameDesign.spacingMD) {
                header
                boardCard
                inputSection

                if let gameResult {
                    GameAnimatedResultBanner(
                        isSuccess: gameResult == .won,
                        title: gameResult == .won
                            ? "Got it in \(guesses.count)/\(WordleEvaluator.maxGuesses)!"
                            : "Out of guesses"
                    )
                    .transition(.gamePresent)
                }
            }
            .padding(.bottom, GameDesign.spacingXL)
        }
        .scrollBounceBehavior(.basedOnSize)
        .animation(GameMotion.silky, value: guesses.count)
        .animation(GameMotion.silky, value: gameResult == nil)
    }

    private var header: some View {
        VStack(spacing: GameDesign.spacingSM) {
            GameInstructionPill(
                icon: "person.fill.questionmark",
                text: "Guess the mystery player in 6 tries"
            )

            HStack(spacing: 5) {
                ForEach(0..<WordleEvaluator.maxGuesses, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(tileFill(for: index))
                        .frame(height: 6)
                }
            }
        }
        .padding(GameDesign.spacingMD)
        .background(glassBackground)
    }

    private func tileFill(for index: Int) -> Color {
        if index < guesses.count {
            return guesses[index].player.id == target.id ? WordlePalette.correct : WordlePalette.wrong
        }
        return theme.panelStroke.opacity(0.8)
    }

    private var boardCard: some View {
        VStack(spacing: 6) {
            columnHeaderRow

            ForEach(guesses) { guess in
                WordleGuessRow(guess: guess)
            }

            ForEach(0..<remainingRows, id: \.self) { _ in
                WordleEmptyRow()
            }
        }
        .padding(GameDesign.spacingMD)
        .background(glassBackground)
    }

    private var remainingRows: Int {
        max(0, WordleEvaluator.maxGuesses - guesses.count)
    }

    private var columnHeaderRow: some View {
        HStack(spacing: 4) {
            Text("Player")
                .frame(width: WordleLayout.playerColumnWidth, alignment: .leading)

            ForEach(columns, id: \.self) { column in
                Text(column)
                    .frame(width: WordleLayout.attributeColumnWidth)
            }
        }
        .font(.caption2.weight(.bold))
        .foregroundStyle(theme.textSecondary)
        .textCase(.uppercase)
        .padding(.horizontal, 2)
    }

    private var inputSection: some View {
        VStack(spacing: GameDesign.spacingSM) {
            if gameResult == nil {
                searchPanel

                if duplicateGuess {
                    Text("Already guessed — pick someone else")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(theme.amber)
                }

                GamePrimaryButton(
                    title: "Submit Guess",
                    action: onSubmit,
                    isEnabled: selectedPlayer != nil
                )
            } else {
                if gameResult == .lost {
                    revealCard
                        .gameSilkyAppear()
                }

                GameContinueButton(
                    won: gameResult == .won,
                    winTitle: "Play Again",
                    loseTitle: "Try Again",
                    action: onPlayAgain
                )
            }
        }
        .padding(GameDesign.spacingMD)
        .background(glassBackground)
    }

    private var searchPanel: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                if let selectedPlayer {
                    HStack(spacing: 6) {
                        PlayerPortraitImage(playerID: selectedPlayer.id, style: .compact)
                            .scaleEffect(0.5)
                            .frame(width: 28, height: 28)

                        Text(selectedPlayer.name)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(WordlePalette.inputText)
                            .lineLimit(1)

                        Button(action: onClearSelection) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(WordlePalette.inputSecondary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    TextField("Search player...", text: $searchQuery)
                        .textFieldStyle(.plain)
                        .foregroundStyle(WordlePalette.inputText)
                        .tint(WordlePalette.inputAccent)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.words)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(WordlePalette.inputBackground)
            .clipShape(RoundedRectangle(cornerRadius: GameDesign.radiusMD, style: .continuous))

            if !suggestions.isEmpty, selectedPlayer == nil {
                VStack(spacing: 0) {
                    ForEach(suggestions.prefix(5)) { player in
                        Button { onSelectPlayer(player) } label: {
                            HStack(spacing: 10) {
                                PlayerPortraitImage(playerID: player.id, style: .compact)
                                    .scaleEffect(32 / 56)
                                    .frame(width: 32, height: 32)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(player.name)
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(WordlePalette.inputText)
                                    Text("\(player.clubName) · \(player.position)")
                                        .font(.caption)
                                        .foregroundStyle(WordlePalette.inputSecondary)
                                        .lineLimit(1)
                                }
                                Spacer(minLength: 0)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                        }
                        .buttonStyle(.plain)

                        if player.id != suggestions.prefix(5).last?.id {
                            Divider()
                        }
                    }
                }
                .background(WordlePalette.inputBackground)
                .clipShape(RoundedRectangle(cornerRadius: GameDesign.radiusMD, style: .continuous))
                .padding(.top, 4)
            }
        }
        .colorScheme(.light)
    }

    private var revealCard: some View {
        HStack(spacing: 12) {
            PlayerPortraitImage(playerID: target.id, style: .card)
                .frame(width: 52, height: 52)
                .clipShape(RoundedRectangle(cornerRadius: GameDesign.radiusSM, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                Text(target.name)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(theme.textPrimary)
                Text("\(target.clubName) · \(target.position)")
                    .font(.caption)
                    .foregroundStyle(theme.textSecondary)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: GameDesign.radiusMD, style: .continuous)
                .fill(theme.panelFill)
        )
    }

    private var glassBackground: some View {
        GameThemedPanel(cornerRadius: GameDesign.radiusLG)
    }
}

enum WordlePalette {
    static let correct = GameDesign.success
    static let wrong = Color(red: 0.47, green: 0.47, blue: 0.45)
    static let valueHint = Color(red: 0.35, green: 0.55, blue: 0.85)
    static let inputBackground = Color.white
    static let inputText = Color(red: 0.08, green: 0.1, blue: 0.12)
    static let inputSecondary = Color(red: 0.38, green: 0.4, blue: 0.45)
    static let inputAccent = Color(red: 0.33, green: 0.67, blue: 0.39)
}

enum WordleLayout {
    static let playerColumnWidth: CGFloat = 88
    static let attributeColumnWidth: CGFloat = 52
}

struct WordleGuessRow: View {
    let guess: WordleGuess

    @State private var progress: CGFloat = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.gameTheme) private var theme

    var body: some View {
        HStack(spacing: 4) {
            playerCell
            WordleTile(state: guess.feedback.nation, label: guess.player.nationFlag)
            WordleTile(state: guess.feedback.league, label: shortLeague(guess.player.league))
            WordleTile(state: guess.feedback.club, label: shortClub(guess.player.clubName))
            WordleTile(state: guess.feedback.position, label: shortPosition(guess.player.position))
            WordleTile(state: guess.feedback.value, label: guess.player.formattedMarketValue)
        }
        .silkyProgress(progress, lift: 4)
        .onAppear {
            progress = 0
            withAnimation(GameMotion.adaptive(GameMotion.silky, reduceMotion: reduceMotion)) {
                progress = 1
            }
            HapticFeedback.light()
        }
    }

    private var playerCell: some View {
        HStack(spacing: 4) {
            PlayerPortraitImage(playerID: guess.player.id, style: .compact)
                .scaleEffect(24 / 56)
                .frame(width: 24, height: 24)

            Text(shortName(guess.player.name))
                .font(.system(size: 10, weight: .bold))
                .lineLimit(2)
                .minimumScaleFactor(0.7)
        }
        .frame(width: WordleLayout.playerColumnWidth, alignment: .leading)
        .padding(.horizontal, 4)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(theme.surfaceFill)
        )
        .foregroundStyle(theme.textPrimary)
    }

    private func shortName(_ name: String) -> String {
        name.split(separator: " ").last.map(String.init) ?? name
    }

    private func shortClub(_ club: String) -> String {
        if club.count <= 8 { return club }
        return String(club.prefix(7)) + "…"
    }

    private func shortLeague(_ league: String) -> String {
        if league.count <= 8 { return league }
        return String(league.prefix(7)) + "…"
    }

    private func shortPosition(_ position: String) -> String {
        let lower = position.lowercased()
        if lower.contains("goalkeeper") { return "GK" }
        if lower.contains("centre-back") || lower.contains("center-back") { return "CB" }
        if lower.contains("left-back") { return "LB" }
        if lower.contains("right-back") { return "RB" }
        if lower.contains("defensive midfield") { return "CDM" }
        if lower.contains("central midfield") { return "CM" }
        if lower.contains("attacking midfield") { return "CAM" }
        if lower.contains("left midfield") || lower.contains("left winger") { return "LW" }
        if lower.contains("right midfield") || lower.contains("right winger") { return "RW" }
        if lower.contains("centre-forward") || lower.contains("center-forward") { return "CF" }
        if lower.contains("second striker") { return "SS" }
        if position.count <= 6 { return position }
        return String(position.prefix(5)) + "…"
    }
}

struct WordleEmptyRow: View {
    @Environment(\.gameTheme) private var theme

    var body: some View {
        HStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .stroke(theme.panelStroke, lineWidth: 1)
                .frame(width: WordleLayout.playerColumnWidth, height: 34)

            ForEach(0..<5, id: \.self) { _ in
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .stroke(theme.panelStroke, lineWidth: 1)
                    .frame(width: WordleLayout.attributeColumnWidth, height: 34)
            }
        }
    }
}

struct WordleTile: View {
    let state: WordleTileState
    let label: String

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(backgroundColor)

            if state == .higher {
                VStack(spacing: 0) {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 9, weight: .black))
                    Text(label)
                        .font(.system(size: 8, weight: .bold))
                        .lineLimit(2)
                        .minimumScaleFactor(0.6)
                }
            } else if state == .lower {
                VStack(spacing: 0) {
                    Image(systemName: "arrow.down")
                        .font(.system(size: 9, weight: .black))
                    Text(label)
                        .font(.system(size: 8, weight: .bold))
                        .lineLimit(2)
                        .minimumScaleFactor(0.6)
                }
            } else {
                Text(label)
                    .font(.system(size: 9, weight: .bold))
                    .lineLimit(2)
                    .minimumScaleFactor(0.6)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(width: WordleLayout.attributeColumnWidth, height: 34)
        .foregroundStyle(Color.white)
    }

    private var backgroundColor: Color {
        switch state {
        case .correct: WordlePalette.correct
        case .wrong: WordlePalette.wrong
        case .higher, .lower: WordlePalette.valueHint
        }
    }
}
