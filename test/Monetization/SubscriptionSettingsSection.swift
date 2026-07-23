import SwiftUI
import UIKit

/// The Pro block shown in Settings. Reflects entitlement status and provides the
/// three App-Store-required affordances: upgrade (paywall), restore purchases,
/// and manage subscription. Additive — it changes no existing setting.
struct SubscriptionSettingsSection: View {
    @EnvironmentObject private var entitlements: EntitlementService
    @EnvironmentObject private var subscriptions: SubscriptionService
    @State private var showPaywall = false
    @State private var isRestoring = false

    private let manageURL = URL(string: "https://apps.apple.com/account/subscriptions")!

    var body: some View {
        VStack(spacing: 0) {
            statusRow
            Divider().padding(.leading, 52)

            if entitlements.isPro {
                linkRow(title: "Manage Subscription",
                        subtitle: "Change or cancel your plan",
                        icon: "gearshape.fill", tint: .blue) {
                    UIApplication.shared.open(manageURL)
                }
            } else {
                actionRow(title: "Upgrade to Pro",
                          subtitle: "Unlock everything with a free trial",
                          icon: "crown.fill", tint: .yellow) {
                    showPaywall = true
                }
            }

            Divider().padding(.leading, 52)

            actionRow(title: "Restore Purchases",
                      subtitle: "Already subscribed? Restore access",
                      icon: "arrow.clockwise", tint: .green,
                      showsSpinner: isRestoring) {
                Task {
                    isRestoring = true
                    await subscriptions.restore()
                    isRestoring = false
                }
            }
        }
        .paywallSheet(isPresented: $showPaywall, source: "settings")
        .alert("FTMP Pro", isPresented: messageBinding) {
            Button("OK", role: .cancel) {}
        } message: { Text(subscriptions.lastMessage ?? "") }
    }

    private var statusRow: some View {
        HStack(spacing: 14) {
            iconTile(entitlements.isPro ? "checkmark.seal.fill" : "sparkles",
                     tint: entitlements.isPro ? .green : .yellow)
            VStack(alignment: .leading, spacing: 2) {
                Text(entitlements.isPro ? "FTMP Pro" : "Free Plan")
                    .font(.body.weight(.semibold))
                Text(entitlements.isPro ? "All features unlocked" : "Upgrade to unlock everything")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            if entitlements.isPro { PremiumBadge() }
        }
        .padding(.vertical, 6)
    }

    private func actionRow(title: String, subtitle: String, icon: String, tint: Color,
                           showsSpinner: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            rowContent(title: title, subtitle: subtitle, icon: icon, tint: tint,
                       accessory: showsSpinner ? .spinner : .chevron)
        }
        .buttonStyle(.plain)
    }

    private func linkRow(title: String, subtitle: String, icon: String, tint: Color,
                         action: @escaping () -> Void) -> some View {
        actionRow(title: title, subtitle: subtitle, icon: icon, tint: tint, action: action)
    }

    private enum Accessory { case chevron, spinner }

    private func rowContent(title: String, subtitle: String, icon: String, tint: Color,
                            accessory: Accessory) -> some View {
        HStack(spacing: 14) {
            iconTile(icon, tint: tint)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.body.weight(.semibold)).foregroundStyle(.primary)
                Text(subtitle).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            switch accessory {
            case .chevron:
                Image(systemName: "chevron.right").font(.caption.weight(.semibold)).foregroundStyle(.tertiary)
            case .spinner:
                ProgressView()
            }
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
    }

    private func iconTile(_ icon: String, tint: Color) -> some View {
        ZStack {
            Circle().fill(tint.opacity(0.15)).frame(width: 40, height: 40)
            Image(systemName: icon).foregroundStyle(tint)
        }
    }

    private var messageBinding: Binding<Bool> {
        Binding(get: { subscriptions.lastMessage != nil },
                set: { if !$0 { subscriptions.lastMessage = nil } })
    }
}
