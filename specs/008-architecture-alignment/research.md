# Research: Architecture Alignment

Inputs: the audit of 2026-11-06 (dead code, duplicates, game data, documentation drift, leftovers), a review of the
files over 550 lines, a map of every `VERIFY` marker against the in-game results of 1.1.0, and the lure and pole
values of the original game. Each decision below names what it settles in [spec.md](spec.md).

## R1. What goes into `GameData/` (FR-001, FR-004)

- **Decision**: `GameData/` holds data about the game's entities: items (lures, fished containers, fishing poles),
  spells (the Fishing ranks), objects (the bobber), NPCs (names), places (rank sources), the inventory slots and
  equip locations, the pole's item class, and entity icons (the unknown item icon). API vocabulary stays with the one
  module that talks to that API: chat types and restriction enum names (`Exchange/Comm.lua` `VIA`,
  `RESTRICTIONS`), the password popup name (`Exchange/Channel.lua`), the creature GUID template
  (`Fishing/Skill.lua`), UI textures and atlases, the CVars fishing mode sets (`Fishing/Mode.lua`). Addon tuning
  (timeouts, limits, grid, delays) stays in its module.
- **Rationale**: the model describes what exists in the game world, which a player could look up on a database
  site and which Forever may change; API names describe how the client is called, are read by one module and change
  with the client, not the content. Moving them would add an indirection with no second reader.
- **Alternatives**: every constant that names something in the client (rejected: `GameData/` would become a dump of
  unrelated strings, and the layer 0 model would hold UI atlas names); only by-ID lists (rejected by the author,
  Q3: the slot and class mappings are game data too).

## R2. Shape of the model (FR-001, FR-002, FR-003)

- **Decision**: one table `ns.GameData`, one file per entity, each file starting with
  `local GameData = ns.GameData or {}` / `ns.GameData = GameData` (the only statement besides table constructors).
  Records keyed by ID with named fields where an entity has more than one fact; a set (`[id] = true`) where it has
  one; an ordered array where order is the fact (the ranks). The full layout is in [data-model.md](data-model.md).
  `ns.FishingRanks`, `ns.FishingRankSpells`, `ns.NpcNames`, `ns.FISHING_SPELL_IDS`, `ns.BOBBER_OBJECT_ID` are
  replaced by `ns.GameData.*`; no alias of the old names stays.
- **Rationale**: one entry is easy to find and to check; named fields let the lure carry its requirement without a
  second parallel table; no aliases, so no reader keeps the old name (dead code otherwise).
- **Alternatives**: flat globals per table (rejected, Q2); accessor functions in `GameData/` (rejected, Q2: the files
  stay data only and `npm run check` can tell).

## R3. Load order of `GameData/` (FR-005, edge case "read at file load time")

- **Decision**: the `GameData\*.lua` lines move in the TOC to right after the locales, before `Core\Core.lua`.
  `Core/Data.lua` builds its spell lookup from the Fishing spells at load time and `GameData/FishingRanks.lua` reads
  the spells, so `FishingSpells.lua` is the first GameData file. GameData files read nothing but `ns.GameData`.
- **Rationale**: today `GameData/FishingRanks.lua` loads after `Core/Data.lua` because it reads
  `ns.FISHING_SPELL_IDS`; with the spells in `GameData/` the dependency turns around. Layer 0 data with no reader of
  its own can load first.
- **Alternatives**: keep GameData after `Core/Data.lua` and let Data.lua build its lookup lazily (rejected: a lazy
  path for no reason, and the TOC would no longer show the model before its readers).

## R4. `npm run check` rule for `GameData/` (FR-003)

- **Decision**: in `tools/check.mjs`, a file under `GameData/` fails when it contains the word `function`, an `L[`
  or `ns.L`, or an `ns.<Name>` other than `ns.GameData`. The ASCII rule stays as it is (UTF-8 only inside string
  literals). The test lives in `tests/tools/` with the other Node tests of the tools.
- **Rationale**: a text check is enough for files that hold tables only, and it is what the existing checks do.

## R5. The lure's required skill (FR-007 to FR-010)

- **Decision**: values from the original game (Wowhead Classic tooltips, cross-checked with a Classic fishing guide):

  | Item | Lure | Requires Fishing | Bonus |
  |---|---|---|---|
  | 6533 | Aquadynamic Fish Attractor | 100 | +100 (5 min) |
  | 7307 | Flesh Eating Worm | 100 | +75 |
  | 6532 | Bright Baubles | 100 | +75 |
  | 6811 | Aquadynamic Fish Lens | 50 | +50 |
  | 6530 | Nightcrawlers | 50 | +50 |
  | 6529 | Shiny Bauble | none | +25 |

  No other Classic lure exists (Sharpened Fish Hook 34861 is TBC and later). The requirement is compared with the
  base Fishing skill `Skill.Get()` returns (the rank of `GetProfessionInfo`, without the lure or pole bonus).
  `Bags.FindLure` skips a known lure whose `skill` is above it; when `Skill.Get()` returns nil, nothing is held back.
  The failure path (`LURE_FAIL_DELAY`, `skippedLures`) stays. `Bags.DescribeLures` (the debug report) adds the
  requirement to each line.
- **VERIFY**: `V43` (each requirement as the game applies it; the in-game step "Lure too high"), `V44` (the game
  compares the base skill, not the skill with bonuses). Explained in this spec's [verification.md](verification.md).
- **Rationale**: the author's wish (tech-debt "A lure above the Fishing skill is offered until it fails"); 1.1.0
  showed the game refuses such a lure with "Cannot apply ...".
- **Alternatives**: `C_Item.IsUsableItem` alone (rejected: it is true for a lure above the skill, seen in game);
  reading the requirement from the tooltip (rejected: localized text, Principle II, while the IDs are known).
- **Also found**: the poles carry a requirement too (Strong 10, Darkwood 50, Big Iron 100, Nat Pagle's 100,
  Arcanite 300). `GameData.FishingPoles` records it with the bonus, but the best-pole choice is not changed here: no
  player report, and the gear swap's own failure path covers it. It goes into `docs/tech-debt.md` as a low item.

## R6. One map pin (FR-011 to FR-013)

- **Decision**:
  - `MapPin.Target(maps, x, y)` gains the catalog's fallback: when no candidate map allows a pin, the point is
    carried through the world position to the parent map (`C_Map.GetWorldPosFromMapPos`, then
    `GetMapPosFromWorldPos` on the parent) and tried there. The `VERIFY(V33)` marker moves with the code.
  - `Catalog.Spots` keeps only the catalog's own rules (a dungeon cell, a cell without a position get no pin) and
    calls `ns.MapPin.Target`.
  - `CatalogTab.Pin` becomes a call of `ns.MapPin.Set(target, placeName)`. The toast comes from `UI/Toast.lua`
    through `MAP_PIN_SET`.
  - Removed: `Catalog.PinTarget`, `CatalogTab.Pin`'s body, `IsOwnPin`, `PIN_EPSILON`, the popup key literal in
    `UI/CatalogTab.lua`, and the duplicate checks of the waypoint API and the game rule.
  - `VERIFY(V32)` goes. `specs/005-catch-catalog/verification.md` closes V32 as "replaced by R14" (the same
    `OpenWorldMap` taint, one place now). The fix of that taint stays in `docs/tech-debt.md`, not here.
- **Visible change**: a catalog pin to the place the addon's pin already marks no longer asks; the catalog's pin
  gets the shared checks. The catalog is unreleased, so no changelog line.
- **Alternative**: keep the fallback in Catalog and pass a ready list of maps (rejected, Q R2-4: the rank advice
  would not get it).

## R7. Dead code and test seams (FR-014, FR-015)

- **Decision**:
  - Removed: `ns.FISHING_SKILL_LINE` (`Skill.Get` reads the profession slot of `GetProfessions`), the export
    `ns.Minimap` (the module table stays local).
  - Moved to private tables:
    - `CatchDB.OwnProofReady` becomes `CatchDB.private.OwnProofReady`.
    - `CatchDB.STEP_SECONDS` becomes `CatchDB.private.STEP_SECONDS`.
    - `Comm.GetPaths` becomes `Comm.private.GetPaths`; `Comm.private` is new and is also needed by the Comm split
      (R9).
  - The tests read `ns.<Module>.private.<name>`.
  - `ns.earlyLookups` gets a real reader instead: the `/okf debug` report lists the keys looked up before the
    language was set. That is the "no `L[...]` lookup while the files load" rule, made visible. The report is not
    localized, so no translation is needed.
  - `ns.ReportSection` (used only by the spike) stays; it is added to the spike-removal step of
    `docs/release-plan.md` (spec 009).
- **Rationale**: a public name nobody but a test calls looks like API; the private table is the existing pattern
  (`CatchDB.private`, `Share.private`).
- **Rule for the future** (into `docs/development.md`): a value or function only the tests need lives in the
  module's private table; the dead code audit ignores the private tables.

## R8. The duplicates (FR-016)

| Duplicate | Decision |
|---|---|
| The range label: `UI/CatalogTab.lua` `SpanLabel` and `UI/CatchHere.lua` `RangeLabel` | One `ns.RangeLabel(min, max)` in `UI/Widgets.lua`; both tabs use it |
| The little data threshold: `Exchange/Share.lua` `RARE_CATCHES` and `CatchDB/Views.lua` `LITTLE_DATA` (both 50) | `CatchDB.LITTLE_DATA` exported; Share reads it |
| The own record: `CatchDB.lua` `OwnRecord()` and `Share.lua` `OwnRecord(store)` (with checks) | One `CatchDB.OwnRecord(store)` with Share's checks, store defaulting to `ns.db.shared`; the CatchDB callers already handle a missing own record (checked in the tasks, with a test of a damaged own record) |
| The scan button: `UI/Settings.lua` and `UI/StatsFrame.lua` `UpdateScanButton` | One `ns.UpdateScanButton(button, hint)` in `UI/Widgets.lua` (hint optional) |
| The default catalog filter: `Catalog.lua` and `CatalogTab.lua` | `Catalog.DefaultFilter()` returns a fresh copy; the tab uses it |
| The reported CVars: `Core/Debug.lua` `REPORT_CVARS` and `Fishing/Mode.lua` `DesiredCVars` | `Mode.CVAR_NAMES` (every CVar the mode may change) used by `DesiredCVars`' callers and Debug |
| The rank spell IDs: `Fishing/Skill.lua` fallback names keyed by 7620... | The names in rank order (`{ L["Apprentice"], ... }`, built on first use) indexed by the rank's position in `GameData.FishingSpells`; no ID repeated |

Smaller repeats the audit named, which each take 1 to 3 lines (the `issecretvalue` guard, the share gate, walks
over `record.builds`), stay as they are: a helper would be longer than the repeat.

## R9. Splitting files (FR-017, FR-018)

- **Rule** (into `docs/development.md`): a file over 600 lines is split along its logical seams when it holds more
  than one role; a file that is one role stays whole; shared helpers of an area go into one file of that area. The
  files of one module share its private table (`<Module>.private`), as `CatchDB/` and `Share` do.
- **Review** (lines total / code):

  | File | Lines | Roles | Verdict |
  |---|---|---|---|
  | `Exchange/Comm.lua` | 750 / 591 | outgoing transport (queue, pace, budget, send results, paths); incoming reassembly with flood defence | **Split**: `Exchange/CommReceive.lua` gets the receive side (handler registration but `OnOffline`, flood control, part buffers, `OnMessage`, the `CHAT_MSG_ADDON` / `BN_CHAT_MSG_ADDON` handlers, the part constants, `VIA`) |
  | `CatchDB/Views.lua` | 732 / 598 | index upkeep (incremental, driven by Events.lua); computing and caching views | **Split**: `CatchDB/Index.lua` gets the indexes (`SeedIndex`, record indexing, `Others`, `Frozen`, `OwnIndex`, the per-item sets `SeedItems`, `OwnItems`) |
  | `Exchange/ShareProtocol.lua` | 611 / 526 | one role: what a node does with the wire messages | Keep (seam if it grows: the merge queue) |
  | `CatchDB/CatchDB.lua` | 602 / 447 | one role: the own record's lifecycle (chain and writes interleave) | Keep |
  | `UI/StatsFrame.lua`, `Exchange/Channel.lua`, `Catalog/Catalog.lua` | under 600 | | Keep |
  | `Core/Spike.lua` | 653 | temporary | Out of scope (spec 009) |

- **Shared state**:
  - Comm: `Comm.private` carries `PREFIX`, `MAX_MESSAGE`, `MAX_PARTS`, `Enabled`, and the tables `buffers` and
    `flooded`. Both tables are created in Comm.lua and never reassigned.
  - CatchDB: `CatchDB.private` carries `SeedIndex`, `Others`, `Frozen`, `OwnIndex`, `SeedItems`, `OwnItems`,
    `IsOwnKey`, `IndexRecord`, `UnindexRecord`.
- **TOC**:
  - `Exchange\Comm.lua`, `Exchange\CommReceive.lua`, `Exchange\Channel.lua`. CommReceive calls Channel only at
    runtime.
  - `CatchDB\SeedData.lua`, `CatchDB.lua`, `Checks.lua`, `Index.lua`, `Views.lua`, `Events.lua`. Views and Events
    bind the index functions at load time.
- **Tests**: every test loads the whole TOC, so no load list changes. The headers of the Comm and CatchDB tests
  name the new files where their cases now live.
- **Inside CatchDB**: three slightly different checks of "the own ID" (`IsOwnKey`, `OwnItems`, `CountedUnit`) all
  land in Index.lua. `OwnItems` reuses `IsOwnKey`, after a test shows the key and `record.id` cannot differ there.

## R10. Test names and places (FR-020)

The rule of `docs/development.md`: the folder names the area or module, the file names its subject, not
`<module>_test.lua`. Mapping (`git mv`, contents unchanged except the header line):

| Now | New |
|---|---|
| `catch/prices_test.lua` | `catch/auction_price_test.lua` |
| `catch/stats_test.lua` (tests the statistics window) | `ui/stats_window_test.lua` |
| `fishing/bags_test.lua` | `fishing/fished_loot_test.lua` |
| `fishing/skill_test.lua` | `fishing/cap_warning_test.lua` |
| `core/commands_test.lua` | `core/english_commands_test.lua` |
| `core/debug_test.lua` | `core/report_sections_test.lua` |
| `core/mappin_test.lua` + the target and setting cases of `catalog/pin_test.lua` | `core/pin_target_test.lua`, `core/pin_set_test.lua` |
| the catalog's own pin rules of `catalog/pin_test.lua` (dungeon, cell without a position) | `catalog/spot_pin_test.lua` |
| `ui/catchhere_test.lua`, `ui/catchhere_login_test.lua`, `ui/catchhere_seed_test.lua` | `ui/here_page_test.lua`, `ui/here_login_test.lua`, `ui/here_seed_test.lua` |
| `ui/catalogtab_test.lua`, `ui/catalogtab_fallback_test.lua`, `ui/catalogtab_pending_test.lua` | `ui/catalog_list_test.lua`, `ui/catalog_fallback_test.lua`, `ui/catalog_pending_test.lua` |
| `ui/settings_test.lua`, `ui/settings_gear_test.lua`, `ui/settings_nochannel_test.lua` | `ui/shared_page_test.lua`, `ui/gear_page_test.lua`, `ui/shared_page_nochannel_test.lua` |
| `exchange/share/notice_*_test.lua` (7, test the popup of `UI/ShareNotice.lua`) | `ui/notice_*_test.lua` (same suffixes) |
| `catchdb/views_test.lua` (QueryMap, QueryCells, Maps, stamps; named after `CatchDB/Views.lua`) | `catchdb/map_views_test.lua` |
| `exchange/comm/channel_test.lua` (named after `Exchange/Channel.lua`, tests Comm's channel path) | `exchange/comm/channel_path_test.lua` |
| `exchange/share/channel_test.lua` (named after `Exchange/Channel.lua`, tests the node in the channel) | `exchange/share/channel_sessions_test.lua` |

The last three were found by the analysis of the tasks: a strict check (contract C5: no test named after a `.lua`
file of its area's addon folder) flags them. Renaming them keeps the rule free of exceptions.

New tests: `gamedata/shape_test.lua`, `gamedata/load_order_test.lua`, `fishing/lure_skill_test.lua`,
`core/pin_fallback_test.lua` (or a case in `pin_target_test.lua`), `tools/gamedata_check_test.mjs`.

`ui/spike_test.lua` stays where it is: it goes with the spike in spec 009, so moving it now is wasted work
(the spec's FR-020 says so).

## R11. VERIFY bookkeeping (FR-013, FR-024, FR-025)

- **Spec 001**: a new `specs/001-interface-language/verification.md`, in the format of 002 to 006, carries:
  - R11: open values `learnAt = 50`, `learnAt = 125` and `level = 20`, `learnAt = 225` and `level = 35`, quest 6607,
    NPC 12919, maps 1445 / 70, point 0.586 / 0.602. Already closed: map 1434, Heming's point, level 10, item 16083,
    NPC 2626, Heming's merchant list.
  - R12: open, the German Heming name.
  - R14: failed, the `OpenWorldMap` taint (fix in tech-debt). Closed: the arrow and the chat map link.
  - The header sentence of `GameData/FishingRanks.lua` is reworded so it no longer contains the marker syntax.
- **Closed now** (confirmed by the 1.1.0 runs, recorded and the marker removed):
  - V7: `GetBuildInfo` gives "1.60.1" / "70790".
- **Recorded as partly seen** (marker kept, the part seen ticked in its `verification.md` and written in
  `docs/forever-api.md`):
  - V1 / V2: Booty Bay reports map 1434 with a position.
  - V3: the bobber side; object 35591 in the `softinteract` GUID.
  - V4 / V5: the result fields exist and give prices.
  - V30: the game rule is inactive in the open world.
  - V34: `GetAreaInfo` names areas a character has not explored.
  - V35: one item name request answers.
  - V38: the post call fires for bag tooltips.
- **Also into `docs/forever-api.md` "Verified in game"**:
  - the bobber's object ID 35591;
  - `GetBuildInfo`'s values;
  - Booty Bay's map and position;
  - `C_Map.HasUserWaypoint` / `GetUserWaypoint` see a pin the player set;
  - the auction result fields;
  - the `TooltipDataProcessor` post call on bag items;
  - a lure above the skill fails with "Cannot apply ...";
  - the Addon Compartment exists;
  - a settings page frame created shown gets no `OnShow` on its first view.
- **Inconsistencies fixed**: the R11 text of spec 001 research (Heming's merchant list is done) is history and
  stays. The new `verification.md` states the current truth, and so do the Results of
  `docs/checklists/interface-language.md`.
- **CLAUDE.md**: "features 001 to 006 and 008 have one".

## R12. Documentation drift (FR-022 to FR-026)

Each item of the audit, by document:

- **`CLAUDE.md`**:
  - layer table with `GameData/`;
  - the `Core/MapPin.lua` row (now true for the catalog);
  - the UI row (no "map pin", the TOC order);
  - the module rows of Comm / CommReceive and the CatchDB files with Index;
  - a `GameData/` row per file;
  - the VERIFY sentence;
  - the cross-module rule on game data (`ns.GameData`).
- **`docs/architecture/core.md`**:
  - the layer table (`GameData/`, `MapPin.lua`);
  - the stray dispatcher bullet under MapPin moves to Core.lua;
  - `ns.ReportSection` is in Debug.lua;
  - no `FISHING_SKILL_LINE`;
  - the saved fields: `charDB.session`, every writer of `settings`, `shareNotice*` written by
    `Exchange/ShareGame.lua`.
- **New `docs/architecture/game-data.md`**: entities, fields, sources, readers, the rule, the load order. Linked from
  `docs/README.md` and `CLAUDE.md`.
- **`docs/architecture/fishing-mode.md`**:
  - the GameData section becomes a link to game-data.md;
  - the lure requirement;
  - the combat claim the tech-debt item names.
- **`docs/architecture/exchange.md`**: the Comm split.
- **`docs/architecture/catch-db.md`**: six files, the index in Index.lua.
- **`docs/architecture/catch-and-stats.md`**: the listener is `CatchDB/Events.lua`.
- **`docs/architecture/ui.md`**: the catalog pin flow through `MapPin`, `ns.RangeLabel`, `ns.UpdateScanButton`.
- **`docs/architecture/catalog.md`**: `Catalog.DefaultFilter`, the pin through `MapPin.Target`.
- **`docs/development.md`**:
  - the test table and naming (examples after R10);
  - `gamedata/` folder;
  - the file size rule (R9);
  - the private table rule (R7);
  - testable modules.
- **Root `README.md`**:
  - `OneKeyFishing/CatchDB/SeedData.lua`;
  - the docs table gains `development.md`, `forever-api.md`, `tech-debt.md`, `architecture/`.
- **`docs/README.md`**:
  - release-plan "what 1.2.0 waits for";
  - tech-debt "known issues" (not only low);
  - game-data.md.
- **`docs/release-plan.md`**:
  - drop the two settled debt items;
  - the spike-removal step names `ns.ReportSection` and `tests/ui/spike_test.lua`.
- **`docs/tech-debt.md`**:
  - drop "A lure above the Fishing skill ..." once tested;
  - fix the combat sentence (the claim is in the constitution and fishing-mode.md, not CLAUDE.md);
  - add the pole requirement (R5) as low.
- **`docs/checklists/catch-database.md`**: the `SeedData.lua` path.
- **`docs/checklists/interface-language.md`**: line 120 names `Core/MapPin.lua` and no Skill.lua marks.
- **`tests/wow.lua`**: the `UI/MapPin.lua` comment.
- **`OneKeyFishing/Core/MapPin.lua`**: its header becomes true once the catalog uses it.
- **`.specify/memory/constitution.md`** (PATCH 1.5.2 through `/speckit-constitution`):
  - Principle V lists the testable logic (adds Channel, Catalog, Skill, GameData);
  - Principle VI names `GameData/` as the layer 0 model of game entities.
- **Specs 002 to 006**: `verification.md` (V7 closed, partial results, V32 replaced, moved markers' file:line);
  `quickstart.md` where it names a renamed test.

## R13. In-game checklists (FR-027)

- **Untick in `docs/checklists/fishing-mode.md`**, with a note "re-run after spec 008":
  - On., Off., `/reload` in the mode, Relog in the mode;
  - Gear page first view, Chosen pole and extra items, Remove, Find fishing items, Leaving during a cast, Full bags;
  - Lure; Lure too high (its expectation becomes "never offered");
  - Clam;
  - Can learn, At the cap, Off;
  - Settings page, Debug report (also: the line `early L lookups: none`).
- **Untick in `docs/checklists/interface-language.md`** only the steps whose code changes:
  - the next-rank steps that read `GameData`: Journeyman taught, `/okf debug` next rank, the rank names, the
    next-rank notices;
  - the pin steps: Pin button, own-pin replace popup, chat map link.

  These are released 1.1.0 behaviour. The steps of the languages themselves stay ticked.
- **`docs/checklists/catch-catalog.md`**: its pin steps (3, 4, 5) are still open; their expectations change to the
  shared pin (no question when the pin is already there; the parent map through the world position).
- **No new step** where an existing one covers it. The only new expectation is in "Lure too high".

## R14. Changelog and manual (FR-010, spec Q5)

- **`CHANGELOG.md` `[Unreleased]` / Changed**: "A lure your Fishing skill is too low for is no longer offered; it is
  used once the skill is high enough."
- **The debug report** lists the early lookups: no line, the report is for bug reports.
- **The manual**: `OneKeyFishing/README.md` gets the same sentence where it describes lures. No slash command
  changes.
- **The catalog**: unreleased, so the pin change needs no line.
- **No saved field changes**: the range step and the number of ranges keep their values (75 and 4), derived from
  the Fishing spells; a test pins both, because the catch database's keys depend on them.
