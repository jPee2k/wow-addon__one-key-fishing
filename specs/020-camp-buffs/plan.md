# Implementation Plan: Fishing Camp Buffs

**Branch**: `020-camp-buffs` | **Date**: 2026-11-19 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `specs/020-camp-buffs/spec.md`; the author's decisions 1 to 20 in its
clarifications, and 21 to 31 of the follow-up after the first try in game (2026-11-20); the research and the
in-game session of 2026-11-19 in [docs/fishing-investigation.md](../../docs/fishing-investigation.md) and
[docs/forever-api.md](../../docs/forever-api.md).

## Summary

A new layer 1 module `ns.Camp` (`Fishing/Camp.lua`) reads the two camp auras by ID, keeps their state through a
fight and answers, per cast, the **mask** of the bonuses the cast counts for. The catch database writes a cast with
a mask into a part of its place's cell (`q["<mask>"]`, inside the totals), checks, copies and shares that part, filters
its sums by it and marks the bonus items of a view with their own chance. The two tabs get one "Camp bonus" button
in the Water button's place and a tag on the rows; the statistics, the toast, the settings, the debug report and the
harvest follow. Percentages get a fraction for small values, and Camper's Lure joins the lures.

- **The buff (R1, R2)**: `GameData/CampBonuses.lua`; `Camp` reads on four events, never while auras are restricted;
  a buff ends by the clock in a fight.
- **The cast (R3)**: the mask at the cast's start and at its settle must be known and equal, else the cast counts
  for no bonus.
- **The data (R4, R5, R16)**: disjoint, inclusive parts in the cell, keyed by the mask as a string; checked, copied
  by the exchange; 1.4.0 clients keep the totals and drop the parts.
- **The sums (R6, R7)**: `filter.bonus` (`all`, `none`, a key); a tagged item carries `item.bonus` with the chance,
  the catches and the players under its bonus, computed in the pass that sums its scope (no view fetches
  another).
- **The UI (R8, R19, R20)**: one button for the Water and the bonus filter, named "Camp bonus: <value>", in the
  second of two rows of buttons in both tabs; the value "Bonus catches only" is a filter of the list over "All
  catches"; the tag is the camp feature's icon on a row, its words are in the row's tooltip and in the item tooltip.
- **The layout (R21)**: the hints and the exchange line of "What can be caught here" at the top, its list a scroll
  list shared with the catalog (`ns.CreateList`); the catalog's status line under the search box; "Per catch"
  through `ns.FormatCount`.
- **Percentages (R9)**: one formatter, `ns.Percent`.
- **Notices, setting, statistics (R10 to R12)**: `CAMP_BONUS_WARNING`, `campBonusWarning`, two bucket fields.
- **Camper's Lure (R13)**: one row of game data.
- **The seed (R15)**: the harvest carries the parts.

## Technical Context

**Language/Version**: Lua 5.1 (the WoW Forever client, Interface 16001), tests in fengari (Lua 5.3); Node.js 18+ for
the tools

**Primary Dependencies**: `C_UnitAuras.GetPlayerAuraBySpellID`, `C_Secrets.ShouldAurasBeSecret`,
`InCombatLockdown`, `C_Timer.After`, the events `UNIT_AURA`, `PLAYER_REGEN_ENABLED`, `PLAYER_ENTERING_WORLD`; the
addon's `Catch/Catch.lua` (cast IDs), `CatchDB/*`, `Exchange/Share.lua`, `Catalog/Catalog.lua`, `Catch/Stats.lua`,
`UI/*`; `tools/harvest.mjs`

**Storage**: a cell's optional `q` in `OneKeyFishingDB.shared` (the own counts, the own record, others' records)
and in the bundled `CatchDB/SeedData.lua`; `OneKeyFishingDB.settings.campBonusWarning` (new, default on);
`bonusCasts` / `bonusCatches` in the character's statistics buckets. Added fields only: no `DB_SCHEMA` bump

**Testing**: `npm test`, `npm run check`; a stub `C_UnitAuras` / `C_Secrets` in `tests/wow.lua` set per test (R17)

**Target Platform**: WoW Forever client (Windows / macOS)

**Project Type**: game addon (single package `OneKeyFishing/`) with Node tooling

**Performance Goals**: two aura reads per player `UNIT_AURA` out of combat and per cast; a cast writes at most one
more small table per target cell; a view with `bonus == "all"` sums one more time per bonus only for a scope
that holds such data (none today); the catalog keeps its two indexes

**Constraints**:
- Principle I: the addon only reads the buff; it casts, uses and places nothing, and reacts to nothing for the
  player. No new traffic: the parts travel inside the records already exchanged.
- Principle II: the auras and the items by ID (`GameData/CampBonuses.lua`); nineteen new texts through `ns.L`
  with nine translations, read at runtime; the debug lines English.
- Principle III: added saved fields only; nothing renamed or reshaped; no CVar, gear or camera.
- Principle IV: the aura read was measured in game on 2026-11-19; reads are skipped while auras are restricted;
  eight assumptions marked `VERIFY(V60)` to `VERIFY(V67)`; `C_UnitAuras` and `C_Secrets` in `.luacheckrc`.
- Layers: `Camp` in layer 1 (asked by `Stats`, layer 1, and `CatchDB`, layer 2); the tag and the filter in
  `CatchDB` and `Catalog` (layer 2); frames only in `UI/`; `Camp` names no UI module (a message to the toast).
- Compatibility: a 1.4.0 client must accept every record this version sends (FR-011): the parts are inclusive, the
  place keys and the messages do not change.
- ASCII outside the locales; 120-character lines; Lua 5.1 / 5.3 neutral.

**Scale/Scope**:
- Addon: two new files (`GameData/CampBonuses.lua`, `Fishing/Camp.lua`, both in the TOC: a game restart);
  `CatchDB/CatchDB.lua` (`Settle`), `Checks.lua`, `Views.lua` (the filter, the tag, `HasBonusData`), `Events.lua`;
  `Exchange/Share.lua` (`CleanCell`); `Catalog/Catalog.lua`; `Catch/Stats.lua`; `Core/Data.lua` (`ns.Percent`),
  `Core/Core.lua` (a default), `Core/Debug.lua`; `GameData/Lures.lua`; `UI/CatchHere.lua`, `CatalogTab.lua`,
  `ItemHooks.lua`, `Toast.lua`, `StatsFrame.lua`, `Settings.lua`; `Locales/*.lua` (10 files); `.luacheckrc`.
- Tools: `tools/harvest.mjs`; `tools/addon.mjs` if the check lists the game data files.
- Tests: about fifteen new files, six extended (quickstart).
- Documents: `CHANGELOG.md` (Unreleased), `OneKeyFishing/README.md` (the camp bonus, the filter, the notices, the
  statistics rows, Camper's Lure), `CLAUDE.md` (the `GameData` and `Fishing/Camp.lua` rows, the new message, the
  `verification.md` features list), `docs/architecture/fishing-mode.md`, `catch-db.md`, `exchange.md`,
  `catalog.md`, `catch-and-stats.md`, `game-data.md`, `ui.md`, `core.md` (the saved fields, `ns.Percent`, the debug
  section), `specs/002-local-catch-db/data-model.md` (the cell's shape), new `docs/checklists/camp-buffs.md` and
  its row in `docs/checklists/README.md`, `docs/fishing-investigation.md` (what the feature settles),
  `docs/release-plan.md` (the open markers at the release, T040).

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Check | Result |
|---|---|---|
| I. Blizzard Policy | The addon reads a player buff and counts casts; no cast, item use or placing; the notices are text; no new addon message, the parts ride in the records already exchanged under the same budget | Pass |
| II. Language-Independent Game Data | Auras and items by ID in the game data model; texts through `ns.L` with nine translations at runtime; the tag names the game's own feature names per language; debug lines English | Pass |
| III. Safe, Restorable State | Only added fields (a cell's part, a setting, two bucket counts), defaults fill the setting; nothing renamed or reshaped, so no `DB_SCHEMA` bump; no CVar, gear or camera | Pass |
| IV. Verified Forever API | `GetPlayerAuraBySpellID` measured in game (out of combat, in a fight, after a relog); reads skipped while restricted and guarded against secret values; V60 to V67 with a checklist; the two globals in `.luacheckrc`; the new facts already in `docs/forever-api.md` | Pass |
| V. Checked and Tested Changes | Every rule that runs without the game has a test that fails without it (quickstart): the state, the cast rule, the parts, the checks, the views, the tag, the exchange copy, the harvest, the percentages, the statistics | Pass |
| VI. Simple Module Boundaries | One new module in an existing area (`Fishing/`) and one game data file; one new message, listed in `CLAUDE.md`; no command; the one new setting has a concrete need (decision 13); no new frame type (a button and a menu like the Water one) | Pass |
| Technical Constraints | Two TOC lines; the game data file is data only; ASCII outside the locales | Pass |

Re-check after Phase 1: the contracts add `ns.Camp` (nine functions), three functions and one filter field to
`CatchDB`, four functions and a fourth argument of `ChanceText` to `Catalog`, two helpers to `UI/Widgets.lua`;
`FISH_CAUGHT` / `FISH_MISSED` keep their arguments (the mask is asked from `Camp`, not sent); the cell's shape
grows by one optional field that 1.4.0 ignores. One message is new. Pass.

## Project Structure

### Documentation (this feature)

```text
specs/020-camp-buffs/
├── plan.md              # This file
├── research.md          # Phase 0: R1 to R21
├── data-model.md        # Phase 1
├── quickstart.md        # Phase 1
├── verification.md      # Phase 1: V60 to V67
├── contracts/
│   └── module-api.md    # Phase 1
├── checklists/
│   └── requirements.md
└── tasks.md             # /speckit-tasks
```

### Source Code (repository root)

```text
OneKeyFishing/
├── OneKeyFishing.toc            # GameData\CampBonuses.lua; Fishing\Camp.lua after Fishing\Skill.lua
├── GameData/CampBonuses.lua     # new: the bonuses (key, bit, aura, the feature's item, known items)
├── GameData/Lures.lua           # Camper's Lure, the orders below it
├── Fishing/Camp.lua             # new: ns.Camp (state, the cast mask, the notices, Describe)
├── CatchDB/CatchDB.lua          # Settle writes q["<mask>"]
├── CatchDB/Checks.lua           # CheckCell: the rules of q
├── CatchDB/Views.lua            # filter.bonus, item.bonus, HasBonusData, BonusKeys, DescribeBonusParts
├── CatchDB/Events.lua           # cast.mask from Camp.CastMask
├── Exchange/Share.lua           # CleanCell copies q
├── Catalog/Catalog.lua          # the filter field, the bonus chance of a place, the texts of the tag
├── Catch/Stats.lua              # bonusCasts, bonusCatches
├── Core/Data.lua                # ns.Percent
├── Core/Core.lua                # default campBonusWarning
├── Core/Debug.lua               # the "Camp bonus" section, the place's parts
├── UI/Widgets.lua               # ShowItemTooltip: the tag's lines
├── UI/CatchHere.lua             # the bonus button and menu, the tag's icon
├── UI/CatalogTab.lua            # the bonus button, the tag's icon
├── UI/ItemHooks.lua             # the tag's tooltip line
├── UI/Toast.lua                 # CAMP_BONUS_WARNING
├── UI/StatsFrame.lua            # the two rows, HEIGHT 736
├── UI/Settings.lua              # the campBonusWarning row
└── Locales/*.lua                # the new keys, nine translations
.luacheckrc                      # C_UnitAuras, C_Secrets
tools/harvest.mjs                # q in clean, check, scale, sum, write
tests/
├── fishing/                     # camp_state, camp_cast, camp_notice (new); lures_test (extended)
├── gamedata/                    # camp_bonuses_test (new)
├── catchdb/                     # bonus_recording, bonus_check, bonus_views, bonus_tag (new)
├── exchange/share/              # bonus_clean, bonus_old_client (new)
├── catalog/                     # bonus_test (new)
├── catch/                       # stats_bonus_test (new)
├── core/                        # percent_test (new); report_sections, migrations (extended)
├── ui/                          # here_bonus, catalog_bonus (new); tooltips, stats_window (extended)
├── tools/harvest_test.mjs       # extended
└── wow.lua                      # the aura stubs
docs/
├── architecture/                # fishing-mode, catch-db, exchange, catalog, catch-and-stats, game-data, ui, core
├── checklists/camp-buffs.md     # new
└── fishing-investigation.md, release-plan.md
```

**Structure Decision**: the existing layout; no new area. `ns.Camp` belongs to the fishing area (`Fishing/`,
layer 1, documented in `fishing-mode.md`, tested in `tests/fishing/`); the bonuses are an entity of the game data
model. Everything about parts, filters and tags stays in the modules that own the cell and the views.

## Order of work (for the tasks)

1. Foundations: `GameData/CampBonuses.lua`, the TOC, the stubs in `tests/wow.lua`; `ns.Percent`
   (User Story 4, independent of the rest).
2. User Story 1: `Camp` (state, `Mask`, `CastMask`, with `.luacheckrc`), `Settle` and the handlers of
  `CatchDB/Events.lua`, the checks.
3. User Story 8: `CleanCell`, the old-client test, the harvest (the record's size is read in game, V67).
4. User Story 2: `filter.bonus` in the sums (the tag's chance needs it), `item.bonus`, the catalog's places, spots
   and texts, the icon on the rows of both tabs, the tooltip lines.
5. User Story 3: `HasBonusData`, the button and its menu in both tabs.
6. User Stories 5 and 6: the notices and the setting; the statistics fields and rows.
7. User Story 7: Camper's Lure.
8. The debug section, the texts and translations, the documents, the checklist; `npm run check`, `npm test`.

Stories 1 and 8 are the data and can be tried in game without any visible change (a release needs the documents
of the last step too); 2 and 3 are the views over them; 4 (the
percentages) and 7 (the lure) are independent of everything else.

## Follow-up after the first try in game (2026-11-20)

Decisions 21 to 31 of the spec, requirements FR-041 to FR-048, tasks T041 onwards (Phase 12). No data changes:
`CatchDB` and the saved data stay as they are, and no `VERIFY` marker is added (the fit of the buttons is a
checklist step).

- **Two rows of buttons (R8)**: in both tabs row A holds Skill and Source, row B the one slot (Water or Camp
  bonus) and Kinds (and Sort in the catalog). `CatchHere.CreateWaterButton` and `CreateBonusButton` make the slot's
  buttons for both tabs; `CatchHere.UpdateFilterSlot` sets them and places the next button of row B after the one
  shown. The Kinds button leaves the top right corner of "What can be caught here".
- **The button's text (R8)**: `Catalog.BonusButtonText(value)`, five whole texts ("Camp bonus: All" ...);
  `CatchHere.BonusButtonText` is gone.
- **"Bonus catches only" (R20)**: the value `"bonusOnly"`, UI and catalog only. "What can be caught here" queries
  `"all"` (`CatchHere.QueryBonus`) and keeps the tagged items (`CatchHere.BonusItems`); the catalog maps it to the
  index of `"all"` (`IndexFilter`) and `Catalog.Items` drops the untagged rows. Two empty texts.
- **The layout (R21)**: `ns.CreateList` moves from `UI/CatalogTab.lua` to `UI/Widgets.lua` and serves the list of
  "What can be caught here" too, in place of its 16 fixed rows; the hints (up to three lines) and the exchange line
  move above the counts; the catalog's status line moves under the search box.
- **Per catch**: `ns.FormatCount(value)` in `Core/Data.lua`, beside `ns.Percent`.
- **Texts**: eight new keys (`Bonus catches only`, the five button texts, the two empty texts), nine translations
  each.
- **Files**: `Catalog/Catalog.lua`, `Core/Data.lua`, `UI/CatchHere.lua`, `UI/CatalogTab.lua`, `UI/Widgets.lua`,
  `Locales/*.lua`; tests `tests/wow.lua` (`list_rows(list)`), `tests/core/count_format_test.lua` (new),
  `tests/ui/here_bonus_test.lua`, `catalog_bonus_test.lua` (new cases), and the tests that read the rows of "What
  can be caught here" or the catalog's layout (`here_page_test`, `here_kinds_test`, `here_seed_test`,
  `catalog_kinds_test`, `catalog_kinds_saved_test`, `catalog_sort_test`).

## Follow-up after the Hut session (2026-11-20)

Decisions 32 to 34 of the spec, requirements FR-049 to FR-052, research R22, tasks T048 onwards (Phase 13). No
saved data change; old statistics are not recounted. Two new markers, `VERIFY(V68)` and, from the review,
`VERIFY(V69)` (the combat flag in `Restricted()`; `.luacheckrc` gains `UnitAffectingCombat`).

- **Bloated fish under both bonuses**: `GameData/CampBonuses.lua` names one local `BLOATED` table in both entries;
  `Camp.KnownBonuses(itemID)` (a list of keys) replaces `Camp.KnownBonus`. `CatchDB/Views.lua`'s `Tag` picks, in an
  "all" view, the bonus with the most catches of the item in the scope, else the Rack; every tag of such an item
  carries `several = true`, and `Catalog.BonusTip(key, several)` then names both camp features (one new key).
- **Bonus catches**: `Camp.IsBonusCatch` also counts a catch with two loot slots or more once the fished quest items
  are left out; the quest items are the new `GameData/FishedQuestItems.lua` (in the TOC after `CampBonuses.lua`).
- **Coloured lines**: `ns.ColoredText` (`Core/Data.lua`, from `UI/Minimap.lua`) and `ns.AddColoredLine`
  (`UI/Widgets.lua`) for the addon's coloured lines in item tooltips, the "(few lots)" price line and the minimap
  tooltip.
- **Files**: `GameData/CampBonuses.lua`, `GameData/FishedQuestItems.lua` (new), `OneKeyFishing.toc`,
  `Fishing/Camp.lua`, `CatchDB/Views.lua`, `Catalog/Catalog.lua`, `Core/Data.lua`, `UI/Widgets.lua`,
  `UI/ItemHooks.lua`, `UI/Minimap.lua`, `Catch/Prices.lua`, `Locales/*.lua`; the tests of task T054.

## Risks

- **A record grows** by its bonus parts (R16): the test stubs cannot measure the encoded size, so it is read in
  game from the debug report (V67) before the release; the fallback is named there.
- **The split is lost through 1.4.0 relays** (decision 5): accepted; totals stay right. Its size cannot be
  measured.
- **The Hut is built blind** (V60): if its aura cannot be read like the Rack's, the Hut's part is never written and
  nothing else breaks.
- **A known item caught without a buff** (V61) shows a wrong tag until it leaves the list.
- **Button width** (R8): the buttons grow to their text, and row B's buttons follow one another, so the risk is a
  row wider than the tab in French or German ("Bonus de camp : bonus seul", then Kinds and Sort); a checklist step,
  with the fallback of a shorter translation. The tag is an icon and its words are in the tooltip (R19), so the rows'
  columns keep their widths.
- **A table with keys 1, 2, 3** would be at the mercy of the game's array encoding (CBOR, the saved file), so the
  parts are keyed by the mask as a string (R4).

## Complexity Tracking

No violation to justify.
