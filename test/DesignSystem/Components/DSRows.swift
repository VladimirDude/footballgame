import SwiftUI

/// Icon + value + label stat tile (replaces the 3 divergent stat tiles).
/// `@ScaledMetric` keeps the icon proportional to the user's text size.
struct DSStatTile: View {
    let value: String
    let label: String
    var icon: String? = nil
    var tint: Color = DSColor.accent

    @ScaledMetric(relativeTo: .title2) private var iconSize: CGFloat = 18

    var body: some View {
        VStack(alignment: .leading, spacing: DSSpacing.xxs) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: iconSize, weight: .semibold))
                    .foregroundStyle(tint)
                    .accessibilityHidden(true)
            }
            Text(value)
                .font(DSFont.statValue)
                .foregroundStyle(DSColor.textPrimary)
            Text(label)
                .font(DSFont.statLabel)
                .foregroundStyle(DSColor.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(value)")
    }
}

/// Leading icon-tile + title/subtitle + trailing accessory. 44pt min height.
/// Replaces the 5 different row treatments across the app.
struct DSRow<Trailing: View>: View {
    let title: String
    var subtitle: String? = nil
    var icon: String? = nil
    var tint: Color = DSColor.accent
    @ViewBuilder var trailing: () -> Trailing

    var body: some View {
        HStack(spacing: DSSpacing.sm) {
            if let icon {
                ZStack {
                    Circle().fill(tint.opacity(0.15)).frame(width: 34, height: 34)
                    Image(systemName: icon).foregroundStyle(tint)
                }
                .accessibilityHidden(true)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .dsFont(.body)
                    .fontWeight(.semibold)
                    .foregroundStyle(DSColor.textPrimary)
                if let subtitle {
                    Text(subtitle)
                        .dsFont(.caption)
                        .foregroundStyle(DSColor.textSecondary)
                }
            }
            Spacer(minLength: 0)
            trailing()
        }
        .frame(minHeight: 44)
        .contentShape(Rectangle())
    }
}

/// Standard trailing chevron for navigation rows.
struct DSChevron: View {
    var body: some View {
        Image(systemName: "chevron.right")
            .font(.caption.weight(.semibold))
            .foregroundStyle(DSColor.textTertiary)
            .accessibilityHidden(true)
    }
}

extension DSRow where Trailing == DSChevron {
    /// Navigation-style row with a chevron.
    init(title: String, subtitle: String? = nil, icon: String? = nil, tint: Color = DSColor.accent) {
        self.init(title: title, subtitle: subtitle, icon: icon, tint: tint) { DSChevron() }
    }
}
