# Implementation Plan: Auctionator Prices

**Branch**: `019-auctionator-prices` | **Date**: 2026-11-18 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `specs/019-auctionator-prices/spec.md`; the author's decisions 9 to 23 and the
clarify session of 2026-11-18 in its clarifications; the API facts in [docs/auction-plan.md](../../docs/history/auction-plan.md)
("Feature 2") and [docs/forever-api.md](../../docs/forever-api.md).

## Summary

`Catch/Prices.lua` learns a second source of auction prices: Auctionator's public API, read per item on demand when
Auctionator is installed (both functions there) and the two switches are on. The value rule does not change (the
higher of the auction and the vendor price; the own fallback keeps "few lots"). While Auctionator is in use the
addon's scan refuses with one line and its three entries hide; a new settings page "Auction prices" holds the moved
switch, the nested Auctionator switch, the source and the counts of the own catches by price source, which the
statistics line and the debug report share.

- **The source (R1, R2, R5)**: `HasAuctionator` / `UsesAuctionator` / `GetSource` in `Prices`; every call in `pcall`;
  the first failure logs once and turns Auctionator off for the session.
- **Prices (R3, R6, R7)**: `GetAuction` returns a third value, the source; nothing of Auctionator's is kept; no own
  tooltip line for an Auctionator price (V59).
- **Updates (R4)**: one registration at login; notices coalesce into one `PRICES_CHANGED` per 0.5 s.
- **Counts (R8)**: `CountSources` over the own sellable catches; `CanAuction` moves from `Auction` to `Prices`.
- **Entries and command (R9)**: `Auction.WhyNot` answers "Prices come from Auctionator."; the UI hides three entries.
- **Settings (R10)**: `auctionatorPrices` (default on), two setters, the new page.
- **Texts (R13)**: eleven new keys with nine translations.

## Technical Context

**Language/Version**: Lua 5.1 (the WoW Forever client, Interface 16001), tests in fengari (Lua 5.3); Node.js 18+ for
the tools

**Primary Dependencies**: Auctionator's public `Auctionator.API.v1` (three calls, optional: the addon works the same
without it); the addon's `Catch/Prices.lua`, `Catch/Auction.lua`, `Catch/Stats.lua`, `UI/*`; `C_Item.GetItemInfo`,
`C_Timer.After`

**Storage**: `OneKeyFishingDB.settings.auctionatorPrices` (new, default on, `ApplyDefaults`); no `DB_SCHEMA` bump;
nothing of Auctionator's stored

**Testing**: `npm test`, `npm run check`; a stub `Auctionator.API.v1` set per test (R14)

**Target Platform**: WoW Forever client (Windows / macOS)

**Project Type**: game addon (single package `OneKeyFishing/`) with Node tooling

**Performance Goals**: values follow an Auctionator scan within 1 s (SC-001: a 0.5 s coalescing timer); a value costs
one table lookup in Auctionator inside `pcall` (the catalog's sort reads a few hundred); the counts walk the own
catches (a few hundred at most) only when shown

**Constraints**:
- Principle I: while Auctionator is in use the addon sends no auction request at all; no scan starts by itself.
- Principle IV: Auctionator's presence and shape checked at runtime, never at load; every call guarded; one
  assumption marked `VERIFY(V59)`; the rest measured on 2026-11-17.
- Principle II: eleven new texts through `ns.L`, nine translations, read at runtime; the debug lines English.
- Layers: everything in `Prices` and `Auction` (layer 1); the UI reads `Prices.UsesAuctionator()` and follows the
  existing messages; no lower layer names a frame.
- Licence: only Auctionator's public API; none of its code copied.
- ASCII outside the locales; 120-character lines; Lua 5.1 / 5.3 neutral.

**Scale/Scope**:
- Addon: `Catch/Prices.lua` (about +150 lines), `Catch/Auction.lua` (`WhyNot`, the moved rule), `Core/Core.lua` (a
  default), `Core/Debug.lua` (a section), `Core/Commands.lua` (a description), `UI/Settings.lua` (a page, a toggle
  less), `UI/AuctionButton.lua`, `UI/StatsFrame.lua`, `UI/Minimap.lua`, `Locales/*.lua` (10 files, 11 keys),
  `OneKeyFishing.toc` (`OptionalDeps`), `.luacheckrc`.
- Tests: four new files, five extended (quickstart).
- Documents: `CHANGELOG.md` (Unreleased), `OneKeyFishing/README.md` ("Auction prices", the settings pages, `/okf
  scan`), `CLAUDE.md` (the `Prices` row, the setters rule, `verification.md` features list),
  `docs/architecture/catch-and-stats.md`, `ui.md`, `core.md` (the saved field, the debug section),
  new `docs/checklists/auctionator-prices.md` and its row in `docs/checklists/README.md`, `docs/ROADMAP.md` (019
  leaves "Planned"), `docs/auction-plan.md` (feature 2 points to this spec; the file moves to `docs/history/` once
  this is built).

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Check | Result |
|---|---|---|
| I. Blizzard Policy | No game action; with Auctionator in use the addon sends no auction request; reading another addon's saved prices through its public API is local; no traffic outside the game | Pass |
| II. Language-Independent Game Data | Items by ID (Auctionator's lookup by item ID); eleven texts with nine translations at runtime; debug lines English | Pass |
| III. Safe, Restorable State | One new saved key by defaults; nothing renamed or reshaped; the own prices untouched while Auctionator is in use; no CVar, gear or camera | Pass |
| IV. Verified Forever API | The API was measured in WoW Forever on 2026-11-17; presence checked at runtime; every call in `pcall`; one marker V59 with its checklist step; `Auctionator` in `.luacheckrc` | Pass |
| V. Checked and Tested Changes | Four new and five extended tests, each failing without its change (quickstart) | Pass |
| VI. Simple Module Boundaries | No new module, file, message or command; the source lives in `Prices` (layer 1); the one new setting has a concrete player need (going back to the own scan, decision 10) and its setter; the new page groups the auction settings (decision 17) | Pass |
| Technical Constraints | One TOC line (`OptionalDeps`), no new file in the TOC; ASCII outside the locales | Pass |

Re-check after Phase 1: the contracts add nine functions to `Prices` and a third return value to
`Prices.GetAuction` (every caller reads the first two); `Auction` loses its local bind rule to `Prices.CanAuction`
and gains one reason in `WhyNot`; no message, saved shape or command changes. Pass.

## Project Structure

### Documentation (this feature)

```text
specs/019-auctionator-prices/
├── plan.md              # This file
├── research.md          # Phase 0: R1 to R14
├── data-model.md        # Phase 1
├── quickstart.md        # Phase 1
├── verification.md      # Phase 1: V59
├── contracts/
│   └── module-api.md    # Phase 1
├── checklists/
│   └── requirements.md
└── tasks.md             # /speckit-tasks
```

### Source Code (repository root)

```text
OneKeyFishing/
├── OneKeyFishing.toc            # ## OptionalDeps: Auctionator
├── Catch/Prices.lua             # the source, Auctionator's prices, CanAuction, CountSources, setters, Describe
├── Catch/Auction.lua            # WhyNot's Auctionator reason; Prices.CanAuction
├── Core/Core.lua                # default auctionatorPrices
├── Core/Debug.lua               # the "Auction prices" section
├── Core/Commands.lua            # the description of /okf scan
├── UI/Settings.lua              # the "Auction prices" page; auctionPrices leaves the main page
├── UI/AuctionButton.lua         # hidden while Auctionator is in use
├── UI/StatsFrame.lua            # the scan button hidden; the values line
├── UI/Minimap.lua               # no scan entry
└── Locales/*.lua                # 11 new keys, nine translations
.luacheckrc                      # Auctionator
tests/
├── catch/                       # prices_auctionator_test.lua, prices_counts_test.lua, prices_update_test.lua (new)
├── ui/                          # auction_page_test.lua (new); scan_buttons_test.lua, stats_window_test.lua,
│                                # tooltips_test.lua (extended)
└── core/                        # report_sections_test.lua, migrations_test.lua (extended)
docs/
├── architecture/                # catch-and-stats.md, ui.md, core.md
├── checklists/auctionator-prices.md   # new
└── ROADMAP.md, auction-plan.md
```

**Structure Decision**: the existing layout, no new area or file in the TOC. The source is part of `Prices`
(layer 1, `Catch/`); the page and the hidden entries are in `UI/`.

## Order of work (for the tasks)

1. The default, the setters, `HasAuctionator` / `UsesAuctionator` / `GetSource`, the TOC and `.luacheckrc` (all
   else stands on them).
2. User Story 1: `GetAuction` with the source, the fallback, the failure rule, the update notice, the tooltip line
   (V59).
3. User Story 2: `Auction.WhyNot`, the three hidden entries, the command's description.
4. User Story 3: `CanAuction`, `CountSources`, the settings page.
5. User Story 4: the statistics line.
6. User Story 5: `Prices.Describe` and the debug section.
7. Texts and translations, the documents, the checklist; `npm run check`, `npm test`.

Stories 1 and 2 are the P1 core and can ship alone; 3 to 5 share the counts.

## Complexity Tracking

No violation to justify.
