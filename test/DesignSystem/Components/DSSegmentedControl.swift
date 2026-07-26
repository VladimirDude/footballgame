import SwiftUI

/// A pill segmented control that consumes DS tokens and labels each segment for
/// VoiceOver. Replaces the 3 divergent segmented controls (`GameSegmentedControl`,
/// Predictor's hand-rolled `sectionPicker`, ad-hoc pickers). For plain grouped
/// settings, prefer a native `Picker`; use this where a bold pill row is wanted.
struct DSSegmentedControl<Item: Hashable>: View {
    let items: [Item]
    @Binding var selection: Item
    let title: (Item) -> String
    var icon: ((Item) -> String)? = nil

    @Namespace private var namespace

    var body: some View {
        HStack(spacing: 4) {
            ForEach(items, id: \.self) { item in
                let isSelected = item == selection
                Button {
                    selection = item
                } label: {
                    HStack(spacing: DSSpacing.xxs) {
                        if let icon { Image(systemName: icon(item)).font(.caption) }
                        Text(title(item)).dsFont(.subheadline).fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity, minHeight: 36)
                    .foregroundStyle(isSelected ? DSColor.onAccent : DSColor.textSecondary)
                    .background {
                        if isSelected {
                            Capsule().fill(DSColor.accent)
                                .matchedGeometryEffect(id: "seg", in: namespace)
                        }
                    }
                    .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(title(item))
                .accessibilityAddTraits(isSelected ? [.isSelected] : [])
            }
        }
        .padding(4)
        .background(Capsule().fill(DSColor.fill))
        .dsAnimation(DSMotion.quick, value: selection)
    }
}
