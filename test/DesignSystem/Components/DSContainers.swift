import SwiftUI
import UIKit

/// Canonical card container (the `.dsCard()` modifier as a view, for lists).
struct DSCard<Content: View>: View {
    var radius: CGFloat = DSRadius.lg
    var padding: CGFloat = DSSpacing.md
    var elevation: DSElevation.Shadow = DSElevation.sm
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .frame(maxWidth: .infinity, alignment: .leading)
            .dsCard(radius: radius, padding: padding, elevation: elevation)
    }
}

/// Section header: an optional SF Symbol + title, with an optional trailing action.
struct DSSectionHeader<Trailing: View>: View {
    let title: String
    var icon: String? = nil
    @ViewBuilder var trailing: () -> Trailing

    var body: some View {
        HStack(spacing: DSSpacing.xs) {
            if let icon {
                Image(systemName: icon)
                    .foregroundStyle(DSColor.accent)
                    .accessibilityHidden(true)
            }
            Text(title)
                .dsFont(.headline)
                .foregroundStyle(DSColor.textPrimary)
            Spacer(minLength: 0)
            trailing()
        }
        .accessibilityAddTraits(.isHeader)
    }
}

extension DSSectionHeader where Trailing == EmptyView {
    init(title: String, icon: String? = nil) {
        self.init(title: title, icon: icon, trailing: { EmptyView() })
    }
}

/// Reusable gradient hero header (Search/Club/Settings previously hand-rolled
/// this inline in 4 places with hardcoded white-on-gradient text).
struct DSHero: View {
    let title: String
    var subtitle: String? = nil
    var systemImage: String? = nil
    var gradient: [Color] = [
        DSColor.dyn(light: UIColor(red: 0.10, green: 0.55, blue: 0.20, alpha: 1),
                    dark: UIColor(red: 0.08, green: 0.42, blue: 0.16, alpha: 1)),
        DSColor.dyn(light: UIColor(red: 0.05, green: 0.40, blue: 0.15, alpha: 1),
                    dark: UIColor(red: 0.03, green: 0.28, blue: 0.11, alpha: 1)),
    ]

    var body: some View {
        HStack(alignment: .center, spacing: DSSpacing.md) {
            VStack(alignment: .leading, spacing: DSSpacing.xxs) {
                Text(title)
                    .dsFont(.title2)
                    .foregroundStyle(.white)
                if let subtitle {
                    Text(subtitle)
                        .dsFont(.footnote)
                        .foregroundStyle(.white.opacity(0.85))
                }
            }
            Spacer(minLength: 0)
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.title)
                    .foregroundStyle(.white.opacity(0.9))
                    .accessibilityHidden(true)
            }
        }
        .padding(DSSpacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: DSRadius.xl, style: .continuous)
                .fill(LinearGradient(colors: gradient, startPoint: .topLeading, endPoint: .bottomTrailing))
        )
        .dsElevation(DSElevation.md)
        .accessibilityElement(children: .combine)
    }
}
