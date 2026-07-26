# FTMP Design System

One source of truth for color, type, spacing, radius, elevation, and reusable
components. Lives in `test/DesignSystem/`. Replaces the previously-fragmented
theming (4+ mechanisms, 15+ accents, no type scale, Games-only spacing).

## Tokens (`test/DesignSystem/`)

### Color — `DSColor.swift`
Adaptive (light/dark) `UIColor`-dynamic roles that resolve in any view without
`@Environment` threading.
- **Surfaces (layered depth):** `background` → `groupedBackground` → `surface` → `surfaceElevated`; plus `fill` (insets) and `separator` (hairlines).
- **Text:** `textPrimary` / `textSecondary` / `textTertiary`.
- **Accent (unified):** `accent` follows the user's `AppAccent` choice, so the tab bar, buttons, chips, and checks all agree. `onAccent` for content on top; `accentSoft` for tints.
- **Semantic:** `success` / `warning` / `danger`; podium `gold` / `silver` / `bronze`.

### Typography — `DSTypography.swift`
Semantic ramp on the built-in text styles (scales with Dynamic Type): `largeTitle, title, title2, title3, headline, body, callout, subheadline, footnote, caption, caption2`, plus `statValue` / `statLabel` / `mono`. Use `.dsFont(.headline)` or `DSFont.headline`. **This replaces every `.system(size:)`.**

### Spacing — `DSSpacing` (`DSLayout.swift`)
`xxs 4 · xs 8 · sm 12 · md 16 · lg 20 · xl 24 · xxl 32 · xxxl 40 · huge 48 · giant 64`.

### Radius — `DSRadius` (`DSLayout.swift`)
`sm 8 · md 12 · lg 16 · xl 20 · xxl 24 · pill`.

### Elevation — `DSElevation` (`DSLayout.swift`)
Shadow tokens `sm / md / lg`, plus `.dsElevation(_)` and `.dsCard(radius:padding:elevation:)` view modifiers — the "real depth" that replaces flat outlined cards.

## Components (`test/DesignSystem/Components/`)
All ship VoiceOver labels, ≥44pt targets, Dynamic-Type text, and Reduce-Motion-aware animation.
- **Containers:** `DSCard`, `DSSectionHeader`, `DSHero` (gradient header).
- **Actions:** `DSPrimaryButton`, `DSSecondaryButton`, `DSBadge`, `DSSegmentedControl`.
- **Content:** `DSStatTile`, `DSRow` (+ `DSChevron`).
- **States:** `DSLoadingState`, `DSEmptyState`, `DSErrorState`.
- **Motion:** `DSMotion` + `.dsAnimation(_:value:)` + `DSPressStyle`.

## Adoption status
- ✅ **Foundation** (tokens + components) built and green.
- ✅ **Accent unified** app-wide (`BrowseTheme.accent` → `DSColor.accent`; `AppAccent.classic` = refined orange); Games `success`/`danger` and `TeamTheme` surfaces/semantics alias the tokens.
- ✅ **High-impact fixes:** My Team invisible-title bug (removed forced dark toolbars); pure-white card surfaces retired; Predictor full-season progress feedback; Wordle forced-white input island made adaptive.
- ⏳ **Remaining (follow-up):** full rebuild of Settings + My Team dashboard on native `Form`/`List`; migrate the remaining `.system(size:)` fonts to `DSFont`; collapse the triplicated `PredictorStyle`/`SimulateStyle`/`DetailStyle`; full VoiceOver labeling + `@ScaledMetric` pass; DB load/error state in Search.

## Usage examples
```swift
VStack(spacing: DSSpacing.md) {
    DSSectionHeader(title: "Squad", icon: "person.3.fill")
    DSCard { DSStatTile(value: "24", label: "Players", icon: "figure.run") }
    DSPrimaryButton(title: "Save", icon: "checkmark") { save() }
}
.padding(DSSpacing.md)
.background(DSColor.groupedBackground)
```
