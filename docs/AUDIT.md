# FTMP — Principal Product, Architecture & Monetization Audit

**App:** FTMP (`com.ftmpapp.app`) — a SwiftUI iOS football app: player/club **Search**, a 5-mode **Game** hub, a Premier League **Simulator/Predictor**, a **My Team** manager (migrated from a legacy futsal app), and **Settings**.
**Stack:** SwiftUI, iOS 26.5 deployment target (builds against the 26.0 SDK), Swift 5, **zero external dependencies**, Xcode file-system-synchronized groups (new files under `test/` are auto-compiled). ~13k LOC.
**Baseline:** `** BUILD SUCCEEDED **` (generic iOS Simulator) established before any change and preserved after every change.

This document is the full audit (Reports 1–10). Report 11 (PR summary) lives in the PR description. Items already implemented in this pass are marked **✅ DONE**; the rest are prioritized recommendations.

---

## Executive summary — the three 🔴 Critical items

| # | Issue | Status |
|---|-------|--------|
| 1 | **158MB of static data bundled in the app** (5,327 portrait PNGs @153MB + 184 logos + 1.4MB JSON), frozen at build time. | **✅ DONE** — portraits converted PNG→HEIC: **PlayerPortraits 153MB→35MB, total bundled data 158MB→40MB (~118MB / 75% cut)**. Offline preserved. Loader centralized, made thread-safe + downsampling + CDN-ready. |
| 2 | **No monetization / analytics / backend of any kind.** | **✅ DONE (foundation)** — full provider-agnostic subscription stack (`StoreProvider` adapter → `SubscriptionRepository` → `EntitlementService`/`SubscriptionService`), centralized `PremiumGate`, a native `PaywallView`, a centralized `AnalyticsService`, and an additive **FTMP Pro** section in Settings (upgrade / restore / manage). Which features are premium is data-driven (`FeatureCatalog`) and not yet applied to existing free features, so nothing is broken. |
| 3 | **Empty `Info.plist` + no `PrivacyInfo.xcprivacy`** despite heavy `UserDefaults` use. | **✅ DONE** — added `PrivacyInfo.xcprivacy` (declares UserDefaults reason `CA92.1`, no tracking, no collected data) and `ITSAppUsesNonExemptEncryption=NO`. (Note: the ImagePicker "crash risk" was disproven — it uses `PHPicker`, which needs no usage-description key.) |

---

## Report 1 — Architecture

**Current state.** Five feature modules under a `TabView` shell. Patterns are inconsistent across modules:

- **My Team** — clean MVVM (`TeamStore: ObservableObject` + service/parser/exporter layers). The best-architected module.
- **Predictor** — good separation: a pure, stateless simulation engine (`MatchSimulator`), pure calculators (`PLStandings`, `PLSeasonStats`, `SquadStrengthModel`), and an `@MainActor` `PredictorStore`. **God-object smell:** `PredictorStore` (645 LOC) also embeds `PLFixtureFetcher` (network + a bespoke openfootball text parser) — a second concern that should be its own type.
- **Games** — **worst offender.** `GameView` (720 LOC) is a God-View holding **~40 `@State`/`@AppStorage` properties for all 5 games at once** and all game logic as private methods. **Zero unit-testable game logic** except the pure validators. No ViewModels anywhere in the module.
- **Search/Club** — `ClubDataStore` (427 LOC) is a **non-observable singleton god-object** that also houses unrelated game pools (guess/wordle/national-team), all built eagerly in a synchronous `init` on the main thread.

**Cross-cutting problems:** no dependency injection (singletons referenced directly → not mockable); business logic inside Views (Games); heavy work on the main thread (JSON parse + per-player disk checks at `init`, full-season simulation); four fragmented design systems (see Report 7); navigation inconsistency (Search/Settings own their `NavigationStack`, the other three receive it from the shell; `TabView` has no `selection` binding; no deep-linking or state restoration).

**Recommendations (prioritized).**
1. Split `GameView` into 5 `ObservableObject` view-models (one per mode) — makes logic testable and kills the God-View. *(Report 9 risk: medium; high value.)*
2. Load `ClubDataStore` **asynchronously off the main thread** with a real loading state; split the game pools out of the search store.
3. Extract `PLFixtureFetcher` from `PredictorStore` into its own file/type.
4. Introduce a lightweight DI seam (an `AppEnvironment`/container — the new `MonetizationContainer` is the template) so singletons become injected services.
5. Bind `TabView` selection to `@SceneStorage` for state restoration; unify `NavigationStack` ownership.

---

## Report 2 — Business Logic (bugs & edge cases)

Ordered by severity. File:line references are from the pre-change tree.

**🔴 High**
- **HL ties are an unwinnable instant loss.** `GameView.processHLGuess` uses strict `>`/`<`; equal market values score *both* Higher and Lower wrong. `pickHLChallenger` even re-allows equal values as a fallback. *(Games BUG-1)*
- **HL pool includes €0 / portrait-less players.** `ClubDataStore.fetchHigherOrLowerPool` maps every player with `marketValue ?? 0` and no portrait filter → frequent €0 ties (triggers BUG-1) and silhouette faces. *(Games BUG-2)*
- **Perpetual spinners on data-load failure for 3 of 5 game modes.** Guess-Player, Wordle, and Higher-Lower show an infinite "Loading…" with no error path if their pool is empty (e.g. a JSON decode failure, which is silently swallowed to an empty DB). *(Games BUG-3)*
- **Predictor season simulation runs synchronously on `@MainActor`** and is **O(N²)**: each of 38 gameweeks re-encodes the entire growing simulations blob to JSON *and* recomputes standings + season stats over all gameweeks; `simulateFullSeason` then recomputes once more at the end. 380 sims block the run loop with no feedback. *(Predictor BUG-1/§5)*
- **Predictor loading spinner never renders.** `isSimulatingSeason` is set true then false inside one synchronous main-thread call — SwiftUI never observes `true`, so all progress UI is dead code. *(Predictor BUG-2)*
- **Portrait image cache data race.** The old loader read the shared `[String:UIImage]` dictionary *outside* the lock (broken double-checked locking) → undefined behavior under concurrent access. **✅ FIXED** — replaced with thread-safe `NSCache` (`PortraitStore`).

**🟠 Medium**
- **Fuzzy matcher is over-permissive** → false-positive correct answers. `directMatch` accepts any ≥3-char substring of the answer ("sen" wins "Arsenal"). *(Games BUG-6)*
- **Quadratic alias expansion mutating a collection while iterating it** in both `ClubGuessValidator` and `NationalTeamGuessValidator`; loose `contains` pulls in unrelated aliases. *(Games BUG-7)*
- **Guess-Player timer not reset on tab re-entry / scene resume** → unfair instant timeouts. *(Games BUG-8)*
- **Predictor simulations are not season-namespaced** (keyed by bare `match.id`, identical across seasons) → latent cross-season corruption + inflated `simulatedMatchCount`. Masked only because the season is hardcoded `"2026/27"`. *(Predictor BUG-3/4)*
- **Search has no debouncing** — every keystroke runs an O(n) diacritic-folding scan of ~5,468 players on the main thread. Club search and filter option lists **recompute on every render**.
- **Silent search truncation** (50/100 cap) with no "showing N of M" affordance; results unsorted. Nationality filter is case-insensitive but *not* diacritic-insensitive (inconsistent with name matching).

**🟡 Low**
- Main-thread disk decode of portraits during scroll (**✅ FIXED** — now off-main + downsampled). Unbounded in-memory image cache (**✅ FIXED** — NSCache eviction).
- National-team squads grouped by `nationality.first` only → dual-nationals misassigned.
- Per-half λ cap not re-enforced after the half-split/game-state multipliers; a 16–16 scoreline is representable (astronomically unlikely).
- My Team: child screens (`TeamGamesView`, `TeamProfileView`, `CoachDetailView`) force `.toolbarColorScheme(.dark)` while the root dropped it → dark nav bar only on children in light mode (cosmetic).

---

## Report 3 — Feature Gap vs `original/`

`original/` is the legacy "Cognaize Futsal" manager, folded in as the **My Team** tab. **All business logic migrated byte-for-byte** (scoring, bonus, GK rating, the paste-parser regex, JSON export/import, seed roster/games). Data models are field-identical (only type renames: `Game`→`TeamGame`, `Player`→`TeamPlayer`).

**Genuine losses (app-shell only, no business logic):**
| Feature | Status | Recommendation |
|---|---|---|
| Animated `SplashView` (branded intro) | **Missing** | Optional — fold into the existing FTMP `OnboardingView` or restore as a brand moment. |
| 3D character viewer (`GLBSceneView`) + "Open 3D Preview" button | **Rejected** | Correct to drop — out of scope for FTMP. |
| `board` hero image | **Downgraded** to a synthetic pitch gradient | Add the asset or keep the gradient (intentional). |

**Improvements introduced by the migration:** role state moved from a global mutable static (`AppConfig`) to observable `@Published isAdmin`; dark-only theme → adaptive light/dark; added iPad max-width layout. **One regression:** the forced-dark nav bar inconsistency noted above.

**Migration verdict:** faithful and lossless on logic; only three shell elements lost, two of them intentionally.

---

## Report 4 — Monetization

**Recommended model:** a single **FTMP Pro** subscription (Auto-Renewable, one Subscription Group) with **Monthly**, **Yearly (+ 7-day free trial)**, and an optional **Lifetime** non-consumable. Yearly is the default/promoted plan.

**Free vs Premium feature matrix** (data-driven via `FeatureCatalog`; every case is a `PremiumFeature`):
| Feature | Free | Pro |
|---|---|---|
| Quiz modes (Easy) | ✅ | ✅ |
| Harder difficulties (Medium/Hard) | — | ✅ `hardDifficulty` |
| Higher-or-Lower "revive" / untimed | — | ✅ `higherLowerRevive` |
| Match simulation (gameweek) | ✅ | ✅ |
| Full-season / unlimited simulations | capped | ✅ `unlimitedSimulations` |
| Full match reports (xG, shot map, timeline) | scoreline only | ✅ `advancedMatchReport` |
| Advanced season stats | — | ✅ `advancedSeasonStats` |
| Player search | ✅ (result cap) | ✅ `unlimitedSearchResults` |
| Advanced/multi-select filters | — | ✅ `advancedSearchFilters` |
| Leagues beyond the Premier League | — | ✅ `extraLeagues` |
| Theme packs (cosmetic) | — | ✅ `themePacks` |

**Architecture delivered** (matches the requested layering exactly):
```
UI (PaywallView / PremiumGate)
  → SubscriptionService (actions)  /  EntitlementService (state + gating)
    → SubscriptionRepository (+ offline entitlement cache)
      → StoreProvider  (protocol — the adapter seam)
        → StoreKitProvider (StoreKit 2)   |   MockStoreProvider (tests/preview/DEBUG)
          → Apple App Store
```
- **Business logic never imports StoreKit** — only `StoreKitProvider.swift` does. A future `PlayBillingProvider` conforms to the same `StoreProvider` protocol → Android is a drop-in.
- **Testable end-to-end:** DEBUG builds use `MockStoreProvider`, so the paywall → purchase → unlock → gate flow works in the simulator with **no App Store Connect account**. Release uses real StoreKit.
- **App Store requirements covered:** Restore Purchases, Manage Subscription, offline entitlement honoring (`SubscriptionRepository` disk cache), transaction listener for renewals/expirations/refunds (`Transaction.updates`), free-trial intro offer support, and StoreKit `Transaction` verification.
- **Centralized gate:** `.premiumGate(_:source:)` (section lock), `.paywallSheet(isPresented:source:)` (action gate), and `PremiumGate.run(...)`. No call site hard-codes `if isSubscribed`.

**To go live (requires your accounts — cannot be done from code):** create the three products in App Store Connect under a `ftmp_pro` subscription group with IDs matching `StoreConfig`; attach `Products.storekit` to the scheme for sandbox testing; flip `MonetizationContainer.defaultUseMock` DEBUG path to real StoreKit; host real Terms/Privacy URLs (placeholders in `PaywallView`).

---

## Report 5 — Analytics

**Current:** none. **Delivered:** a centralized `AnalyticsService` (singleton) with an `AnalyticsBackend` protocol and a typed `AnalyticsEvent` enum (snake_case names + parameters). A `ConsoleAnalyticsBackend` logs in DEBUG. **No analytics calls are scattered** — everything goes through `AnalyticsService.shared.log(_:)`. The monetization funnel is already instrumented (`paywall_shown`, `feature_blocked`, `purchase_started/completed/cancelled/failed`, `restore_*`), plus `app_opened`, `screen_viewed`, onboarding, and game events.

**Recommendation:** adopt **Firebase** as the first real backend — **Analytics + Crashlytics + Remote Config** (the last lets `FeatureCatalog` become server-driven for A/B pricing without an app update). Integration is one file (`FirebaseAnalyticsBackend: AnalyticsBackend` wrapping `Analytics.logEvent`) + one `register(...)` call — no call-site changes. Add Firebase's SDK via SPM. **RevenueCat is optional** and only worth it if you want cross-platform entitlements + server receipt validation without running your own backend. **When any of these land, update `PrivacyInfo.xcprivacy`** (collected data types) — noted in the file.

---

## Report 6 — Backend

**Core app needs no backend** (fully offline). Two things justify a minimal backend as you scale:
1. **Live roster/data + image delivery (the real fix for "frozen at build time").** Even after the 118MB cut, the roster is still a build-time snapshot. Serve `ClubDatabase.json` + portraits from a **CDN** behind a versioned manifest; the app already has the seam (`PortraitAsset.remoteBaseURL`) to prefer remote with a bundle fallback. This is the highest-value backend investment.
2. **Subscription integrity.** For production-grade entitlements: **App Store Server Notifications V2** + the **App Store Server API** for server-side validation and a server source-of-truth. Simplest path: **Firebase (anonymous Auth + Firestore + Cloud Functions + Remote Config)**, or offload entirely to **RevenueCat**.

Recommended minimal shape if you go Firebase: Cloud Function receiving ASSN v2 → writes entitlement to Firestore keyed by anonymous UID → app reads as a secondary source (the on-device StoreKit entitlement remains primary). Remote Config drives `FeatureCatalog` + paywall copy/pricing experiments.

---

## Report 7 — UI / UX

**🔴 Design system is fragmented** — **4 independent color systems** (`AppPalette`, `GameModeTheme` ×10 variants, `BrowseTheme`, `TeamTheme`) via **4 different delivery mechanisms**, **3 conflicting "accent" definitions** (orange `BrowseTheme.accent` used app-wide, a purple `AppPalette.accentGlow`, per-mode game accents), "success/danger" defined 5×/3×, and the same light-mode literal `(0.07,0.09,0.13)` hand-copied in 4+ places. **Spacing exists only for the Games layer; typography tokens exist nowhere.** Names mislead: `AppTheme.swift` has no colors, `GameTheme.swift` has no tokens. **Recommendation:** consolidate into one `DesignSystem` (semantic color roles + type ramp + spacing/radius scale), one delivery mechanism, one accent; migrate module themes to alias it. Medium effort, high maintainability payoff.

**🟠 Accessibility** — **VoiceOver is effectively absent** (one `accessibilityLabel` in the entire app). Fixed-point fonts (`size: 8/10`) and fixed-height hero/containers won't scale with Dynamic Type; no `@ScaledMetric`. Reduce-Motion is handled well in Games but not in Main/Onboarding. **Localization: zero** — no catalog, all strings hardcoded (though SwiftUI `Text` would localize for free once a catalog is added).

**🟠 Missing states & screens** — Settings (hand-rolled, not a `Form`) lacks version/build display, Privacy Policy, Terms, Rate App, Contact Support, data reset, and (pre-this-pass) any subscription surface (**✅ added**). No "showing N of M" on truncated search; silent empty/error handling in several places.

**Severity-ranked UX fixes:** (1) unify design system, (2) add VoiceOver labels + Dynamic Type on core flows, (3) real loading/error/empty states for the 3 game modes + season sim, (4) localization catalog, (5) Settings completeness (version, legal links, rate/support).

---

## Report 8 — Performance

| Bottleneck | Impact | Status |
|---|---|---|
| 158MB bundle | Install size, slow download, App Store cellular limit | **✅ 158→40MB** |
| Main-thread portrait decode during scroll; unbounded in-memory cache | Scroll jank, memory growth → jetsam | **✅** off-main + downsampled + NSCache eviction |
| `ClubDataStore.init` synchronous JSON parse + per-player `Bundle.url` disk checks on main thread | First-navigation hitch | Recommend async load (not yet done — needs a loading-state refactor) |
| Season simulation O(N²) + synchronous on `@MainActor` | Multi-hundred-ms UI freeze, no feedback | Recommend: simulate on a detached task, save + recompute **once**, publish incremental progress |
| Per-keystroke O(n) search on main thread; per-render store recompute | Typing jank | Recommend: debounce + move filter-option lists out of `body` |

---

## Report 9 — Code Quality

**God files:** `PredictorView` 815, `GameView` 720, `HigherOrLowerUI` 701, `PredictorStore` 645, `MatchSimulator` 601 (cohesive), `GameDesignSystem` 490, `ClubDataStore` 427.
**Dead code (confirmed):** `DifficultyPicker`, `NationalTeamDifficultyPicker`, `HLDuelStage`, `GameGlassCard`, `GamePitchBackground`, `GameStreakBar`, `GPPlayerTopBar`, `GPShakeEffect`/`HLShakeEffect` typealiases, `GameMotion.present/.quick`, `HapticFeedback.medium()`.
**Duplication:** `FormationBuilder.build` vs `buildNationalTeam` (~90 lines copy-paste), guess-pool vs wordle-pool builders, the two guess validators, the two `formationView`s, HL's reimplemented score/timer bars, and 4 parallel theme systems.
**Tests:** **none.** The `test/` directory is the *app*, not a test target — there is zero automated coverage. The new monetization layer is designed to be testable (`MockStoreProvider`); recommend adding a unit-test target starting with the pure engines (`MatchSimulator`, validators, `WordleEvaluator`, `PoissonMath`) and the entitlement logic.
**Risk/tech-debt:** medium overall — the app works and is reasonably factored in 3 of 5 modules; the concentrated debt is the Games God-View and the fragmented design system.

---

## Report 10 — Migration Checklist (this pass)

- [x] Baseline build green captured before changes.
- [x] Portraits PNG→HEIC (5,327 files, 1:1 verified before deleting PNGs). 158→40MB.
- [x] Centralized portrait access (`PortraitAsset`) + thread-safe downsampling loader (`PortraitStore`); updated all 4 call sites; async off-main decode in the view.
- [x] `PrivacyInfo.xcprivacy` added; `ITSAppUsesNonExemptEncryption=NO` added.
- [x] Full monetization stack (10 files) + paywall + centralized gate + analytics + Settings Pro section + app-root injection.
- [x] `Products.storekit` config authored (for sandbox testing of the real path).
- [x] Build green after every step.
- [ ] **Remaining (recommended, needs product/account decisions):** apply feature gates to chosen features; async `ClubDataStore` load; detached season simulation; design-system consolidation; accessibility + localization pass; unit-test target; Firebase + CDN backend.

---

*Report 11 (PR summary, per-decision rationale) is in the pull-request description.*
