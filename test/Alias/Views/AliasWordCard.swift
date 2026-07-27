import SwiftUI

/// The big card shown to the explainer: the word to describe plus the forbidden
/// words they may not say. A hint can be revealed on demand.
struct AliasWordCard: View {
    let card: AliasCard
    @State private var showHint = false

    var body: some View {
        VStack(spacing: DSSpacing.lg) {
            HStack {
                Label(card.category.displayName, systemImage: card.category.icon)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(DSColor.textSecondary)
                Spacer()
                Text(card.difficulty.displayName.uppercased())
                    .font(.system(size: 10, weight: .bold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(difficultyColor.opacity(0.16)))
                    .foregroundStyle(difficultyColor)
            }

            Spacer(minLength: 0)

            Text(card.word)
                .font(.system(size: 40, weight: .heavy, design: .rounded))
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.5)
                .foregroundStyle(DSColor.textPrimary)

            if !card.forbiddenWords.isEmpty {
                VStack(spacing: DSSpacing.xs) {
                    Text("DON'T SAY")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(DSColor.danger)
                    forbiddenChips
                }
            }

            Spacer(minLength: 0)

            if !card.hints.isEmpty {
                if showHint {
                    Text(card.hints.joined(separator: " · "))
                        .font(.footnote)
                        .foregroundStyle(DSColor.textSecondary)
                        .multilineTextAlignment(.center)
                        .transition(.opacity)
                } else {
                    Button {
                        withAnimation { showHint = true }
                    } label: {
                        Label("Reveal hint", systemImage: "lightbulb.fill")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(DSColor.accent)
                    }
                }
            }
        }
        .padding(DSSpacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: DSRadius.xxl, style: .continuous)
                .fill(DSColor.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DSRadius.xxl, style: .continuous)
                .stroke(DSColor.separator, lineWidth: 0.5)
        )
        .dsElevation(DSElevation.md)
        .id(card.id) // fresh transition each new card
    }

    private var forbiddenChips: some View {
        FlowLayout(spacing: DSSpacing.xs) {
            ForEach(card.forbiddenWords, id: \.self) { word in
                Text(word)
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(DSColor.danger.opacity(0.12)))
                    .foregroundStyle(DSColor.danger)
            }
        }
    }

    private var difficultyColor: Color {
        switch card.difficulty {
        case .easy: DSColor.success
        case .medium: DSColor.warning
        case .hard: DSColor.danger
        case .expert: DSColor.accent
        }
    }
}

/// A minimal wrapping layout for the forbidden-word chips (no third-party deps).
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var rows: [[LayoutSubviews.Element]] = [[]]
        var x: CGFloat = 0
        var totalHeight: CGFloat = 0
        var rowHeight: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, !rows[rows.count - 1].isEmpty {
                rows.append([])
                totalHeight += rowHeight + spacing
                x = 0
                rowHeight = 0
            }
            rows[rows.count - 1].append(view)
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        totalHeight += rowHeight
        return CGSize(width: maxWidth == .infinity ? x : maxWidth, height: totalHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            view.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
