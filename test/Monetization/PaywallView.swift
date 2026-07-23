import SwiftUI

/// The paywall. Presentation-only: it reads plans and drives purchase/restore
/// through `SubscriptionService`, and reflects entitlement via `EntitlementService`.
/// No StoreKit, no business rules here.
struct PaywallView: View {
    /// Where the paywall was opened from (for the conversion funnel).
    let source: String

    @EnvironmentObject private var subscriptions: SubscriptionService
    @EnvironmentObject private var entitlements: EntitlementService
    @Environment(\.dismiss) private var dismiss
    @State private var selectedPlanID: String?

    private let benefits: [(icon: String, title: String, subtitle: String)] = [
        ("infinity", "Unlimited simulations", "Run full seasons as often as you like"),
        ("chart.bar.fill", "Advanced stats & reports", "xG, shot maps, golden boot & more"),
        ("slider.horizontal.3", "Pro search & filters", "Multi-select filters, no result limits"),
        ("flag.2.crossed.fill", "All leagues & difficulties", "Beyond the Premier League and easy mode"),
        ("heart.fill", "Second chances & no timers", "Play your way, pressure optional"),
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 22) {
                    header
                    benefitsList
                    planSection
                    footerLinks
                }
                .padding(20)
            }
            .navigationTitle("")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { dismissPaywall() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                            .accessibilityLabel("Close")
                    }
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button("Restore") { Task { await subscriptions.restore() } }
                        .font(.subheadline)
                }
            }
        }
        .task {
            AnalyticsService.shared.log(.paywallShown(source: source))
            await subscriptions.loadPlans()
            selectDefaultPlan()
        }
        .alert("FTMP Pro", isPresented: messageBinding) {
            Button("OK", role: .cancel) {}
        } message: { Text(subscriptions.lastMessage ?? "") }
        .onChange(of: entitlements.isPro) { _, isPro in
            if isPro { dismiss() }
        }
    }

    // MARK: - Sections

    private var header: some View {
        VStack(spacing: 10) {
            Image(systemName: "crown.fill")
                .font(.system(size: 40))
                .foregroundStyle(.yellow)
            Text("FTMP Pro").font(.largeTitle.bold())
            Text("Unlock everything the app has to offer.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 8)
    }

    private var benefitsList: some View {
        VStack(alignment: .leading, spacing: 14) {
            ForEach(benefits, id: \.title) { benefit in
                HStack(spacing: 14) {
                    Image(systemName: benefit.icon)
                        .font(.title3)
                        .foregroundStyle(.tint)
                        .frame(width: 30)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(benefit.title).font(.subheadline.weight(.semibold))
                        Text(benefit.subtitle).font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .accessibilityElement(children: .combine)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var planSection: some View {
        switch subscriptions.loadState {
        case .idle, .loading:
            ProgressView().frame(maxWidth: .infinity).padding(.vertical, 30)
        case .failed(let message):
            VStack(spacing: 10) {
                Text(message).font(.subheadline).foregroundStyle(.secondary)
                Button("Try Again") { Task { await subscriptions.loadPlans() } }
            }
            .padding(.vertical, 20)
        case .loaded(let plans):
            VStack(spacing: 12) {
                ForEach(plans) { plan in
                    planRow(plan)
                }
                purchaseButton(plans: plans)
                Text(fineprint(for: plans))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
    }

    private func planRow(_ plan: SubscriptionPlan) -> some View {
        let isSelected = plan.id == selectedPlanID
        return Button {
            selectedPlanID = plan.id
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(planTitle(plan)).font(.headline)
                    if let perMonth = plan.localizedPricePerMonth {
                        Text("\(perMonth) / month").font(.caption).foregroundStyle(.secondary)
                    }
                    if plan.hasFreeTrial, let days = plan.trialDays {
                        Text("\(days)-day free trial").font(.caption.weight(.semibold)).foregroundStyle(.green)
                    }
                }
                Spacer()
                Text(plan.localizedPrice).font(.headline)
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(isSelected ? Color.accentColor.opacity(0.12) : Color(.secondarySystemBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(isSelected ? Color.accentColor : .clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    private func purchaseButton(plans: [SubscriptionPlan]) -> some View {
        Button {
            guard let plan = plans.first(where: { $0.id == selectedPlanID }) else { return }
            Task { await subscriptions.purchase(plan) }
        } label: {
            HStack {
                if subscriptions.isPurchasing { ProgressView().tint(.white) }
                Text(ctaTitle(plans: plans)).font(.headline)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
        }
        .buttonStyle(.borderedProminent)
        .disabled(subscriptions.isPurchasing || selectedPlanID == nil)
        .padding(.top, 4)
    }

    private var footerLinks: some View {
        HStack(spacing: 16) {
            Link("Terms of Use", destination: URL(string: "https://ftmpapp.com/terms")!)
            Text("·").foregroundStyle(.secondary)
            Link("Privacy Policy", destination: URL(string: "https://ftmpapp.com/privacy")!)
        }
        .font(.caption)
    }

    // MARK: - Helpers

    private var messageBinding: Binding<Bool> {
        Binding(
            get: { subscriptions.lastMessage != nil },
            set: { if !$0 { subscriptions.lastMessage = nil } }
        )
    }

    private func dismissPaywall() {
        AnalyticsService.shared.log(.paywallDismissed(source: source))
        dismiss()
    }

    private func selectDefaultPlan() {
        guard case .loaded(let plans) = subscriptions.loadState, selectedPlanID == nil else { return }
        selectedPlanID = plans.first(where: { $0.period == .yearly })?.id ?? plans.first?.id
    }

    private func planTitle(_ plan: SubscriptionPlan) -> String {
        switch plan.period {
        case .monthly: "Monthly"
        case .yearly: "Yearly"
        case .lifetime: "Lifetime"
        }
    }

    private func ctaTitle(plans: [SubscriptionPlan]) -> String {
        guard let plan = plans.first(where: { $0.id == selectedPlanID }) else { return "Continue" }
        return plan.hasFreeTrial ? "Start Free Trial" : "Continue"
    }

    private func fineprint(for plans: [SubscriptionPlan]) -> String {
        "Payment is charged to your Apple ID. Subscriptions renew automatically unless cancelled at least 24 hours before the end of the period. Manage or cancel anytime in Settings."
    }
}
