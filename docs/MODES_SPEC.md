# FTMP — Search / Games / Simulate Mode Specification

Reference for the three "content" surfaces. Data comes from `ClubDataStore.shared`
(bundled/offline `ClubDatabase.json`: **184 clubs, 20 leagues, 5,468 players**).

## Player data model (shared by all modes)
`ClubSquadPlayer` (`test/Club/ClubModels.swift`) has exactly six fields:
`id`, `name`, `image` (`"portrait:<id>"` token; availability via `PortraitAsset.exists`),
`position` (free-text, mapped to 4 `PositionGroup`s), `marketValue` (`Int?` euros; ~176 null),
`nationality` (`[String]`, supports dual-nationals). League is a **separate** `ClubLeagueIndex.json`
(clubID→league). **No age, goals/assists, height, foot, contract, or transfer history exists** —
new features must rely only on the fields above + portrait + club/league.

---

## 1. Search (`test/Search/`, `test/Club/`)
Two sections via a segmented `Picker`: **Players** and **Clubs** (`SearchView.swift`).

- **Player search:** debounced (300 ms) free-text field; requires ≥2 chars or an active filter.
  Results = adaptive grid (regular width) or `List`; each → `PlayerProfileView(playerID:)`.
  Executed by `store.searchPlayers(query, filters:)` (diacritic-insensitive substring + filter predicates).
- **Club browse:** club search field + `ClubRowCard` grid → `ClubDetailView(clubID:)`.
- **Filters** (`SearchFiltersBar`, model `PlayerSearchFilters`): Club, League, Position group, Nationality — all **single-select** today. (Note: `advancedSearchFilters` advertises multi-select + value-range that are not yet built.)
- **Player profile:** portrait hero, stats grid (market value, squad rank, position group, photo availability), nationalities, current-club link.
- **Club detail:** logo header, squad-value stats, squad grouped by position and ranked by value.
- **Premium gating:** the whole filter bar is `.premiumGate(.advancedSearchFilters)`; free results capped at **20** with a "Showing N of Total — unlock with Pro" upsell (`unlimitedSearchResults`).

---

## 2. Games (`test/Games/`)
Hub is `GameView.swift`; modes are `GameTab` cases; visible set = `GameTab.selectable`
(currently **Club, Nation, Player, Higher-or-Lower**; **Wordle hidden but intact**).
Shared infra: `GameDesignSystem` components, `FuzzyMatcher` (+ abbreviation maps),
`FormationBuilder`, `HapticFeedback`, `GameAnimations`, `ClubDataStore` pools.

| Mode | Round source | Validation | Scoring | Timed | Difficulty |
|------|--------------|-----------|---------|-------|------------|
| **Guess Club** | `randomGameRound(for:)` — 4-3-3 of a filtered club (≥8 slots) | `ClubGuessValidator` + aliases + fuzzy | streak / `guessClubBestStreak` | no | Easy/Med/Hard (club sets) |
| **Guess Nation** | `randomNationalTeamRound` — XI from national squads | `NationalTeamGuessValidator` + fuzzy | `guessNationBestStreak` | no | Easy/Med/Hard (12/14/14 nations) |
| **Guess Player** | `randomGuessPlayerRound(for:)` — tiered pools (Easy ≥€25M elite, Med ≥€8M mid, Hard ≥€2M obscure) + portrait required | `PlayerGuessValidator` (full + last name) | `guessPlayerBestStreak` | **10s** | Easy/Med/Hard |
| **Higher-or-Lower** | `higherOrLowerPool` (value>0, portrait) | compare market values (equal = correct) | `higherOrLowerHighScore` | **5s** | none |
| **Wordle** (hidden) | `wordlePlayerPool` (elite ≥€25M) | 5-attribute tiles, 6 guesses | `wordleBestStreak` | no | none |

- **Persistence:** only the five `*BestStreak`/`HighScore` ints (persisted); **current** streaks are ephemeral `@State`. No games-played, win-rate, cross-mode history, or dates.
- **Premium gates:** `hardDifficulty` (Med/Hard via a gated difficulty `Binding`), `higherLowerRevive` (`PremiumGate.run` on `reviveHL`), `relaxedMode` (untimed; `@AppStorage("gameRelaxedMode")`). Paywall via `.paywallSheet(source:"game")`.

---

## 3. Simulate / Predictor (`test/Predictor/`)
Premier League 2026/27 (20 teams / 38 gameweeks). Sections: **Gameweek, Table, Stats**.

- **Predictions:** pick H/D/A per match → lock (`lockPrediction`, stamps `submittedAt`, simulates). Locked also if past the earliest kickoff. Post-lock: Edit / Re-simulate / Simulate Entire Season; result banner + `ShareLink`.
- **Simulation engine** (`MatchSimulator`, `PoissonMath`, `SquadStrengthModel`): team strength from squad **market values**; Poisson/Dixon-Coles λ (base 1.18, home ×1.13, cap 3.3, ρ −0.13); two-half sampling with a log-normal form swing; **deterministic seeded RNG** (`season|matchID|nonce`). Output = scoreline, xG, shots, possession, cards, goal events + XIs. Pre-match odds use the same model.
- **Table:** `PLStandingsCalculator` → 20-row table (pts=W·3+D, GD tiebreak), CL/relegation zones.
- **Season stats:** golden boot, top teams, clean sheets, biggest win. **Match report:** xG/shot bars, goal timeline.
- **Scoring:** flat **3 pts per correct H/D/A pick**; `seasonPoints()` = sum. No exact-scoreline bonus, streak, or multiplier (a clean gamification hook).
- **Premium gates:** `unlimitedSimulations` (full-season sim), `advancedMatchReport` (open report), `advancedSeasonStats` (whole Stats section). (Known bug: the Table-tab full-season button is currently ungated.)
- **Persistence (UserDefaults):** `plPredictorPredictionsV1`, `plPredictorSimulationsV2`, per-gameweek + season nonces; local-only, no account.
