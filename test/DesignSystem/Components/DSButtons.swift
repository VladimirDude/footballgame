import SwiftUI

/// Filled accent CTA. 50pt tall (>44pt target), Dynamic-Type label, optional
/// icon + inline loading, and a VoiceOver label derived from the title.
struct DSPrimaryButton: View {
    let title: String
    var icon: String? = nil
    var isLoading: Bool = false
    var role: ButtonRole? = nil
    let action: () -> Void

    private var fill: Color { role == .destructive ? DSColor.danger : DSColor.accent }

    var body: some View {
        Button(role: role, action: action) {
            HStack(spacing: DSSpacing.xs) {
                if isLoading {
                    ProgressView().tint(DSColor.onAccent)
                } else if let icon {
                    Image(systemName: icon)
                }
                Text(title).dsFont(.headline)
            }
            .frame(maxWidth: .infinity, minHeight: 50)
            .foregroundStyle(DSColor.onAccent)
            .background(
                RoundedRectangle(cornerRadius: DSRadius.md, style: .continuous).fill(fill)
            )
        }
        .buttonStyle(DSPressStyle())
        .disabled(isLoading)
        .accessibilityLabel(title)
    }
}

/// Tonal / bordered secondary action.
struct DSSecondaryButton: View {
    let title: String
    var icon: String? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: DSSpacing.xs) {
                if let icon { Image(systemName: icon) }
                Text(title).dsFont(.headline)
            }
            .frame(maxWidth: .infinity, minHeight: 50)
            .foregroundStyle(DSColor.accent)
            .background(
                RoundedRectangle(cornerRadius: DSRadius.md, style: .continuous)
                    .fill(DSColor.accentSoft)
            )
        }
        .buttonStyle(DSPressStyle())
        .accessibilityLabel(title)
    }
}

/// Small pill/badge for statuses and tags.
struct DSBadge: View {
    let text: String
    var color: Color = DSColor.accent
    var filled: Bool = true

    var body: some View {
        Text(text)
            .dsFont(.caption2)
            .fontWeight(.bold)
            .padding(.horizontal, DSSpacing.xs)
            .padding(.vertical, DSSpacing.xxs)
            .foregroundStyle(filled ? DSColor.onAccent : color)
            .background(
                Capsule().fill(filled ? color : color.opacity(0.15))
            )
    }
}
