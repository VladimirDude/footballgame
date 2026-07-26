import SwiftUI

/// Sequential runner for the Daily Challenge — a fixed set of multiple-choice
/// questions. Completing it (once per day) advances the day-streak + XP.
struct DailyChallengeView: View {
    @EnvironmentObject private var progress: GameProgressStore
    @Environment(\.dismiss) private var dismiss

    let questions: [DailyQuestion]

    @State private var index = 0
    @State private var correctCount = 0
    @State private var selected: Int?
    @State private var revealed = false
    @State private var finished = false

    var body: some View {
        NavigationStack {
            ZStack {
                DSColor.groupedBackground.ignoresSafeArea()
                if finished || questions.isEmpty {
                    resultsView
                } else {
                    questionView(questions[index])
                }
            }
            .navigationTitle("Daily Challenge")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } }
            }
        }
    }

    private func questionView(_ q: DailyQuestion) -> some View {
        VStack(spacing: DSSpacing.md) {
            HStack {
                Text("Question \(index + 1) of \(questions.count)")
                    .dsFont(.subheadline).foregroundStyle(DSColor.textSecondary)
                Spacer()
                Text("Score \(correctCount)").dsFont(.subheadline).fontWeight(.bold).foregroundStyle(DSColor.accent)
            }
            ProgressView(value: Double(index), total: Double(questions.count)).tint(DSColor.accent)

            if let clubID = q.clubID {
                ClubLogoImage(clubID: clubID, style: .hero)
            } else if let pid = q.portraitID {
                PlayerPortraitImage(playerID: pid, style: .card)
            }

            Text(q.prompt)
                .dsFont(.title3)
                .foregroundStyle(DSColor.textPrimary)
                .multilineTextAlignment(.center)

            VStack(spacing: DSSpacing.xs) {
                ForEach(Array(q.options.enumerated()), id: \.offset) { i, option in
                    optionButton(q, i, option)
                }
            }
            Spacer()
            if revealed {
                DSPrimaryButton(title: index == questions.count - 1 ? "Finish" : "Next") { advance() }
            }
        }
        .padding(DSSpacing.md)
        .animation(.easeInOut(duration: 0.2), value: revealed)
    }

    private func optionButton(_ q: DailyQuestion, _ i: Int, _ option: String) -> some View {
        let isCorrect = i == q.correctIndex
        let isChosen = i == selected
        let fill: Color = revealed ? (isCorrect ? DSColor.success.opacity(0.2)
                                     : (isChosen ? DSColor.danger.opacity(0.2) : DSColor.surface))
                                   : DSColor.surface
        let border: Color = revealed ? (isCorrect ? DSColor.success
                                       : (isChosen ? DSColor.danger : DSColor.separator))
                                     : DSColor.separator
        return Button {
            guard !revealed else { return }
            selected = i
            revealed = true
            if isCorrect { correctCount += 1; HapticFeedback.success() } else { HapticFeedback.error() }
        } label: {
            HStack {
                Text(option).dsFont(.body).foregroundStyle(DSColor.textPrimary)
                Spacer()
                if revealed && isCorrect {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(DSColor.success)
                } else if revealed && isChosen {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(DSColor.danger)
                }
            }
            .padding(DSSpacing.sm)
            .frame(maxWidth: .infinity, minHeight: 44)
            .background(fill, in: RoundedRectangle(cornerRadius: DSRadius.md, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: DSRadius.md, style: .continuous).stroke(border, lineWidth: 1.5))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(revealed)
    }

    private func advance() {
        if index == questions.count - 1 {
            if !finished {
                finished = true
                progress.recordDailyCompleted()   // no-op if already completed today
            }
        } else {
            index += 1
            selected = nil
            revealed = false
        }
    }

    private var resultsView: some View {
        VStack(spacing: DSSpacing.sm) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 56))
                .foregroundStyle(DSColor.gold)
            Text("Daily Complete!").dsFont(.title)
            Text("You scored \(correctCount) / \(max(questions.count, 1))")
                .dsFont(.headline).foregroundStyle(DSColor.textSecondary)
            Text("\(progress.progress.dailyStreak)-day streak")
                .dsFont(.subheadline).fontWeight(.bold).foregroundStyle(DSColor.accent)
            DSPrimaryButton(title: "Done") { dismiss() }
                .padding(.horizontal, DSSpacing.xl)
                .padding(.top, DSSpacing.sm)
        }
        .padding(DSSpacing.xl)
    }
}
