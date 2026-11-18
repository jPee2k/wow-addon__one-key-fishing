# Implementation Plan: Auction Scan

**Branch**: `018-auction-scan` | **Date**: 2026-11-17 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `specs/018-auction-scan/spec.md`; the author's decisions of 2026-11-17 in its
clarifications; the measurements and rules in [docs/auction-plan.md](../../docs/auction-plan.md) and
[docs/forever-api.md](../../docs/forever-api.md).

## Summary

The addon's own price scan is rebuilt inside `Catch/Auction.lua`: it searches an item only once the game holds the
item's key info, sends the next request on the game's ready signal (within the documented 100 a minute), stops paging
when the price is decided, covers every item the catch catalog shows, skips prices fresher than 15 minutes, and
notices an auction house that stopped answering within 10 seconds. The price rule does not change.

- **The request machine (R1 to R4)**: one `Pump` driven by the throttle, result and item-info events replaces the
  0.5 s poll and the 4 s timeout per item; `busySince` and `outstanding` give the stall and the item to blame.
- **The list (R5 to R7)**: own catches, then the bundled database, then other players' records, the last two handed
  in by `CatchDB.ScanItems()` through `Auction.SetItemSource` (the layer rule); unsellable, unknown, remembered and
  fresh items left out; the oldest first.
- **The protection (R8)**: `scanGuard` remembers an unanswered item with its group until the addon's next version;
  a shared one leaves the shared group out.
- **Saved data (R9)**: `priceScans` and `scanGuard`, by defaults; `prices` unchanged; `DB_SCHEMA` stays 1.
- **UI (R10)**: `GetState` / `CanScan` / `WhyNot` feed the four scan buttons and `/okf scan`; three new texts.
- **Measured before**: 40 items in 162 s on a first scan (31 prices) and 28 s on the next (32 prices). Expected: about
  0.6 s per item on both, the same prices; the whole catalog (80 bundled items and the own ones) in about a minute
  once, then seconds.

## Technical Context

**Language/Version**: Lua 5.1 (the WoW Forever client, Interface 16001), tests in fengari (Lua 5.3); Node.js 18+ for
the tools

**Primary Dependencies**: the game's `C_AuctionHouse` (the calls in use plus `GetItemKeyInfo` and six events,
contracts) and `C_Item.GetItemInfo`; the addon's own modules (`Catch/Prices.lua`, `Catch/Stats.lua`,
`CatchDB/Index.lua` and `Views.lua`, `Exchange` only through `ns.Share.IsEnabled()` inside CatchDB, as today). No
library, no other addon: Auctionator is read for knowledge of the API and not used.

**Storage**: `OneKeyFishingDB` (account-wide): `prices` unchanged; new `priceScans` and `scanGuard`, filled by
`ApplyDefaults`; no `DB_SCHEMA` bump, no migration (research R9)

**Testing**: `npm test`, `npm run check`; `tests/wow.lua` gets a stand-in auction house with a request line, item key
info and item quality / bind type (research R11)

**Target Platform**: WoW Forever client (Windows / macOS)

**Project Type**: game addon (single package `OneKeyFishing/`) with Node tooling

**Performance Goals**: at most 1 s per searched item on average, first scan after a login included (SC-001; target
0.6 s, the floor between requests); a repeated scan within 15 minutes searches only what was not reached; building
the list (a few hundred IDs, one walk over other players' cells) once per press, no frame hitch; no work per frame
while no scan runs (events only, one timer while the line is busy)

**Constraints**:
- Principle I: one request at a time, only while the game's line is ready, at most 100 a minute, a stop on an
  unanswered request; a scan only on the player's press. Never `SearchForItemKeys`; only items from catches.
- Layers: `Auction` (1) names no module of layer 2; the item source is a callback set by `CatchDB` (2); the UI (3)
  reads the state and follows `AUCTION_STATE`.
- Principle II: items by ID; three new texts through `ns.L` with nine translations, looked up at runtime.
- Principle IV: four assumptions carry `VERIFY(V54)` to `VERIFY(V57)`; in-game auction checks one request at a time.
- ASCII outside the locales; 120-character lines in Lua; one new file in the TOC, `GameData/AuctionUnanswered.lua` (added in the code review: a game
  restart loads it).
- Lua 5.1 / 5.3: no integer division or `math.type`; a whole number is checked with `math.floor(n) == n`.

**Scale/Scope**:
- Addon: `Catch/Auction.lua` (rewritten around the request machine, about 450 lines), `Catch/Prices.lua` (two
  fields), `CatchDB/Views.lua` (`ScanItems`, the source), `Core/Core.lua` (defaults), `Core/Debug.lua`,
  `Core/Commands.lua` (a description), `UI/Widgets.lua`, `UI/AuctionButton.lua`, `UI/Minimap.lua`, `Locales/*.lua`
  (10 files, 3 keys).
- Tests: `tests/wow.lua`; `tests/catch/auction_price_test.lua` (adapted), `auction_pace_test.lua`,
  `auction_list_test.lua`, `auction_stall_test.lua` (new); `tests/catchdb/scan_items_test.lua`,
  `tests/ui/scan_buttons_test.lua` (new); `tests/core/migrations_test.lua` (extended).
- Documents: `CHANGELOG.md` (Unreleased), `OneKeyFishing/README.md` ("Auction prices", the command table),
  `CLAUDE.md` (the messages' wording, the item source rule, `verification.md` features list),
  `docs/architecture/catch-and-stats.md`, `catch-db.md`, `ui.md`, `core.md` (saved fields, the debug report),
  `docs/forever-api.md` (what the checklist confirms), new `docs/checklists/auction-scan.md` and its row in
  `docs/checklists/README.md`, `docs/ROADMAP.md` (018 leaves "Planned"), `docs/auction-plan.md` (feature 1 points
  to this spec; the file stays until spec 019 is done).

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Check | Result |
|---|---|---|
| I. Blizzard Policy | The scan starts only on a press; one request at a time, only while the game's line is ready, at most 100 a minute (the documented limit; today 86), a stop within 10 s when a request stays unanswered instead of a timeout that sends on; fewer requests than today per item (no blind pages, no unsellable items). The list grows from the own catches to the catalog (about 100 items, about a minute, once per 15 minutes at most by the freshness rule). No game action, no traffic outside the game | Pass |
| II. Language-Independent Game Data | Items by ID; quality and bind type by the game's numbers; three new texts with nine translations, read at runtime; the debug lines stay English | Pass |
| III. Safe, Restorable State | Two new saved fields by defaults; `prices` not renamed or reshaped; no CVar, gear or camera touched | Pass |
| IV. Verified Forever API | Built on the measurements of 2026-11-17 (`docs/forever-api.md`); one new call (`GetItemKeyInfo`, seen working) guarded like the present ones; four assumptions marked V54 to V57 with a checklist; the known jam causes are forbidden to the scan | Pass |
| V. Checked and Tested Changes | Five new test files and two adapted (quickstart), each failing without its change; the stand-in auction house lives in `tests/wow.lua` | Pass |
| VI. Simple Module Boundaries | Everything in the present modules; no new file, message, command or setting; the one new joint is `Auction.SetItemSource`, a callback from layer 2 down to layer 1 (precedent: `Comm.SetPartFilter`); the three fixed values are constants, not settings | Pass |
| Technical Constraints | One new data file in the TOC (`GameData/AuctionUnanswered.lua`, the items the auction house never answers); ASCII outside the locales; no packager keyword | Pass |

Re-check after Phase 1: the contracts add four functions to `Auction` (`GetState`, `WhyNot`, `SetItemSource`,
`Describe`), one to `CatchDB` (`ScanItems`), two fields to `Prices` and two saved fields; `CanScan`, `GetProgress`,
`Scan`, the two messages and the stored price keep their shape. The one widening is Principle I's "server-facing work
stays light": more items per scan, bounded by the pace, the freshness rule and the stop. Pass.

## Project Structure

### Documentation (this feature)

```text
specs/018-auction-scan/
├── plan.md              # This file
├── research.md          # Phase 0
├── data-model.md        # Phase 1
├── quickstart.md        # Phase 1
├── verification.md      # Phase 1: V54 to V57
├── contracts/
│   └── module-api.md    # Phase 1
├── checklists/
│   └── requirements.md
└── tasks.md             # /speckit-tasks
```

### Source Code (repository root)

```text
OneKeyFishing/
├── Catch/Auction.lua            # the request machine, the list, the guard, GetState / WhyNot / SetItemSource / Describe
├── Catch/Prices.lua             # FEW_PIECES, FEW_LOTS as fields
├── CatchDB/Views.lua            # CatchDB.ScanItems, set as the scan's item source
├── Core/Core.lua                # defaults: priceScans, scanGuard
├── Core/Debug.lua               # the "Auction scan" section
├── Core/Commands.lua            # the description of /okf scan
├── UI/Widgets.lua               # ns.UpdateScanButton: reason, hint, tooltip
├── UI/AuctionButton.lua         # the stalled text
├── UI/Minimap.lua               # the stalled entry
└── Locales/*.lua                # 3 new keys, nine translations
tests/
├── wow.lua                      # the stand-in auction house
├── catch/                       # auction_price_test.lua (adapted); auction_pace_test.lua, auction_list_test.lua,
│                                # auction_stall_test.lua (new)
├── catchdb/scan_items_test.lua  # new
├── ui/scan_buttons_test.lua     # new
└── core/migrations_test.lua     # extended
docs/
├── architecture/                # catch-and-stats.md, catch-db.md, ui.md, core.md
├── checklists/auction-scan.md   # new
└── forever-api.md, auction-plan.md, ROADMAP.md
```

**Structure Decision**: the existing layout, no new area; one new data file, `GameData/AuctionUnanswered.lua`. The scan stays one module of
`Catch/` (layer 1); the catch database (layer 2) hands it the catalog's items; the frames stay in `UI/`.

## Order of work (for the tasks)

1. The stand-in auction house in `tests/wow.lua` and the defaults (everything else stands on them).
2. User Story 1: the request machine with item key info, the turn, the paging rule, the unsellable filter.
3. User Story 3: the stall, the states, the buttons and the command.
4. User Story 2: `CatchDB.ScanItems`, the item source, the groups.
5. User Story 4: the scan times, the fresh rule, the order.
6. User Story 5: the guard and the debug report.
7. Texts and translations, the documents, the checklist; `npm run check`, `npm test`.

Stories 1 and 3 share the machine and are built together; 2, 4 and 5 are the list's rules and each can be tested alone.

## Complexity Tracking

No violation to justify.
