import SwiftUI

/// A small lock chip you can drop next to any premium affordance.
struct PremiumBadge: View {
    var body: some View {
        Label("PRO", systemImage: "lock.fill")
            .font(.system(size: 10, weight: .bold))
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(Capsule().fill(Color.yellow.opacity(0.9)))
            .foregroundStyle(.black)
            .accessibilityLabel("Pro feature")
    }
}

/// The overlay shown on top of gated content when the user isn't entitled.
struct PremiumLockOverlay: View {
    let feature: PremiumFeature
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(.ultraThinMaterial)
            VStack(spacing: 6) {
                Image(systemName: "lock.fill").font(.title3.bold())
                Text(feature.displayName).font(.caption.weight(.semibold))
                Text("Tap to unlock with Pro").font(.caption2).foregroundStyle(.secondary)
            }
            .padding(10)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(feature.displayName). Locked. Tap to unlock with Pro.")
    }
}

// MARK: - Section gating

/// Wraps content in a premium gate: if the user is entitled, the content shows
/// normally; otherwise it's blurred, disabled, and tapping opens the paywall.
private struct PremiumGateModifier: ViewModifier {
    let feature: PremiumFeature
    let source: String
    @EnvironmentObject private var entitlements: EntitlementService
    @State private var showPaywall = false

    func body(content: Content) -> some View {
        if entitlements.canAccess(feature) {
            content
        } else {
            content
                .disabled(true)
                .blur(radius: 4)
                .overlay { PremiumLockOverlay(feature: feature) }
                .contentShape(Rectangle())
                .onTapGesture {
                    AnalyticsService.shared.log(.featureBlocked(feature: feature.rawValue))
                    showPaywall = true
                }
                .paywallSheet(isPresented: $showPaywall, source: source)
        }
    }
}

// MARK: - Paywall presentation

/// Attaches the paywall as a sheet driven by a binding. Use this for
/// action-gating: at the call site, `if entitlements.canAccess(.x) { … } else { showPaywall = true }`.
private struct PaywallSheetModifier: ViewModifier {
    @Binding var isPresented: Bool
    let source: String
    func body(content: Content) -> some View {
        content.sheet(isPresented: $isPresented) {
            PaywallView(source: source)
        }
    }
}

extension View {
    /// Gate an entire view/section behind `feature`. Locked → blurred + tap-to-paywall.
    func premiumGate(_ feature: PremiumFeature, source: String) -> some View {
        modifier(PremiumGateModifier(feature: feature, source: source))
    }

    /// Present the paywall when `isPresented` becomes true. For action-gating.
    func paywallSheet(isPresented: Binding<Bool>, source: String) -> some View {
        modifier(PaywallSheetModifier(isPresented: isPresented, source: source))
    }
}

/// Convenience for imperative gating inside button actions:
/// `PremiumGate.run(.higherLowerRevive, entitlements: e, showPaywall: $flag) { revive() }`
enum PremiumGate {
    @MainActor
    static func run(_ feature: PremiumFeature,
                    entitlements: EntitlementService,
                    showPaywall: Binding<Bool>,
                    action: () -> Void) {
        if entitlements.canAccess(feature) {
            action()
        } else {
            AnalyticsService.shared.log(.featureBlocked(feature: feature.rawValue))
            showPaywall.wrappedValue = true
        }
    }
}
