import SwiftUI

/// Standard loading state (replaces ~8 bare `ProgressView()` sites).
struct DSLoadingState: View {
    var message: String? = nil

    var body: some View {
        VStack(spacing: DSSpacing.sm) {
            ProgressView().tint(DSColor.accent)
            if let message {
                Text(message)
                    .dsFont(.subheadline)
                    .foregroundStyle(DSColor.textSecondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(DSSpacing.xl)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(message ?? "Loading")
    }
}

/// Standard empty state (thin wrapper over the native `ContentUnavailableView`).
struct DSEmptyState: View {
    let title: String
    var systemImage: String = "tray"
    var message: String? = nil

    var body: some View {
        ContentUnavailableView {
            Label(title, systemImage: systemImage)
        } description: {
            if let message { Text(message) }
        }
    }
}

/// Standard error state with a retry affordance (this pattern was missing app-wide).
struct DSErrorState: View {
    var title: String = "Something went wrong"
    var message: String? = nil
    var systemImage: String = "exclamationmark.triangle"
    var retryTitle: String = "Try Again"
    var onRetry: (() -> Void)?

    var body: some View {
        VStack(spacing: DSSpacing.sm) {
            Image(systemName: systemImage)
                .font(.largeTitle)
                .foregroundStyle(DSColor.danger)
                .accessibilityHidden(true)
            Text(title)
                .dsFont(.headline)
                .foregroundStyle(DSColor.textPrimary)
                .multilineTextAlignment(.center)
            if let message {
                Text(message)
                    .dsFont(.subheadline)
                    .foregroundStyle(DSColor.textSecondary)
                    .multilineTextAlignment(.center)
            }
            if let onRetry {
                Button(retryTitle, action: onRetry)
                    .buttonStyle(.borderedProminent)
                    .tint(DSColor.accent)
                    .padding(.top, DSSpacing.xxs)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(DSSpacing.xl)
    }
}
