# Research: Local Catch Database

Decisions taken for the plan, each with the reason and the alternatives that were rejected. The product decisions
(grid, skill range, filters, prices) were settled with the author before the spec and are recorded in
`docs/shared-db-plan.md` ("Releases and specs" -> "1.1.0"); this file covers how they are built.

## R1. In-game spike, built now, run after launch

- **Decision**: The game opens on 2026-11-04, so the feature is built before anything can be checked in game.
  Every assumption is listed in [verification.md](verification.md) (V1-V9) and marked `-- VERIFY(Vn): ...` in the
  code; `npm run check` lists the open markers and `npm run build -- --release` refuses to package while one is
  left. A temporary `OneKeyFishing/Spike.lua` (listed in the TOC while it exists) adds `/okf spike`, which
  prints a report into the copy window (`ns.ShowCopyWindow`, as `/okf debug` does). It answers:
  1. `C_Map.GetBestMapForUnit("player")` and `C_Map.GetPlayerMapPosition(mapID, "player")` while channeling
     Fishing, in open water, in a city, in a cave and in an instance (nil or a position?); `C_Map.GetMapInfo`
     `mapType` and `parentMapID` for each.
  2. On `LOOT_READY` for fishing loot: `GetLootSourceInfo(slot)` GUIDs for a pool and for open water (is the
     GUID type or entry different?).
  3. At the auction house, for one fished commodity and one non-commodity item: the result event,
     `C_AuctionHouse.GetNumCommoditySearchResults`, `GetCommoditySearchResultsQuantity`,
     `HasFullCommoditySearchResults`, whether `RequestMoreCommoditySearchResults` brings more, and
     `GetNumItemSearchResults` / `GetItemSearchResultInfo` quantities.
  4. `GetBuildInfo()` (the version string recorded with the data).
  The author runs it on launch day; the answers go into CLAUDE.md "Known API facts"; the file and its TOC line are
  removed before the release.
- **Rationale**: FR-002, FR-007 and FR-025 depend on behaviour only the game shows (Principle IV). Building on
  marked assumptions lets the work start now; the release gate makes sure none stays unchecked.
- **Fallbacks if the answers are negative**: no position while fishing -> every place is the whole map (`x` cell)
  until a later release finds another way; no pool difference -> no pool counters; too few auction results ->
  the price uses the results that arrived (they are the cheapest ones), and `/okf debug` shows the coverage.
- **Alternatives rejected**: waiting for the launch (the author wants to start now); a separate spike branch and
  release; treating Retail documentation as verified (Forever differs, Principle IV; it is used only to choose the
  assumptions, R11).

## R2. Place key

- **Decision**: `"<mapID>:<range>:<cell>"`, for example `"1415:3:47"`.
  - `mapID`: `C_Map.GetBestMapForUnit("player")` as returned, no climb to a parent map (author's decision).
  - `range`: `min(4, floor(rank / 75))` from `ns.Skill.Get()` (base rank, no bonuses): 0-74, 75-149, 150-224,
    225-299, 300+.
  - `cell`: from `C_Map.GetPlayerMapPosition(mapID, "player"):GetXY()`, `cx = min(9, floor(x * 10))`, same for y,
    written as two digits `cx .. cy`; `"x"` when there is no position.
  - Read once at `FISHING_CAST_START` and kept for that cast, so the catch or miss lands where the cast was made
    even if the player moves before the loot.
- **Rationale**: numbers only (Principle II, FR-001); one string key keeps saved data and the seed small and easy
  to read; fixing it at cast start makes a catch and its miss/loot attribution deterministic.
- **Alternatives rejected**: zone-level map climb (rejected by the author); nested tables per map/range/cell
  (larger saved data, harder to diff in review); reading the position at loot time (the player may have moved).

## R3. Recording and counts

- **Decision**: A new module `OneKeyFishing/CatchDB.lua` (after `Stats.lua` in the TOC) listens to
  `FISHING_CAST_START`, `FISHING_CAST_STOP`, `FISH_CAUGHT` and `FISH_MISSED` and adds to two tables of the same
  cell shape (data-model.md):
  - `mine`: lifetime counts of the account, never reset; used by "Only mine".
  - `records[myID]`: the contribution since it was last absorbed into the seed, split by game version; used with
    the seed by "All" and read by `harvest`.
  Per cell: catches `c`, misses `m`, casting seconds `t`, position sums `px`/`py` (per cast, in 1/1000 of the map),
  and per item `{catches containing it, pieces}`. Pool catches are also added to a `p` sub-cell when the spike
  shows pools can be told apart (`ns.IsPoolLoot`, guarded).
- **Time**: casting seconds per cell (from cast start to stop) instead of fishing-mode minutes: mode time cannot be
  split across cells without polling the position, and casting time is what the plausibility check needs (a cast
  takes at least a second).
- **A cast across a /reload**: the place is read when the cast is picked up, like any cast start; nothing is counted
  at the start, so its catch or miss is recorded once and `t` runs from the pickup. (Stats needs its `countedCast`
  check only because it counts casts at the start.)
- **`seq`**: bumped on the first change at least 60 s after the previous bump and on logout, so `harvest` can keep
  the newest version of a record.
- **Alternatives rejected**: extending the Stats buckets (per character, keyed by localized names, would mix two
  responsibilities); one table for "mine" and the contribution (the contribution is reset when absorbed into a
  seed, which would empty "Only mine").

## R4. Seed, epochs and counting once

- **Decision**: `OneKeyFishing/SeedData.lua` defines `ns.SeedData = { epoch, built, build, cells, absorbed,
  resets }` (contracts/seed-data.md). The tab shows `seed + own contribution`, where the own contribution counts
  unless the seed absorbed it:
  - If `seed.absorbed` lists `myID` with an epoch >= the record's epoch, the record is already in the seed: it is
    replaced by an empty record with `epoch = seed.epoch` (once, at login).
  - Otherwise the record counts in full.
  `mine` is never touched, so "Only mine" keeps the full history.
- **Rationale**: FR-019 (never twice), also for the author whose data went into the seed; the loss is limited to
  catches between the harvest and the player's update, which for the author is hours (plan, "Epochs").
- **Seed load cost**: a Lua table constructor of up to ~1 MB parses in well under a second; place sums are read
  lazily and cached per key, and a per-map index (for the whole-map fallback) is built once on first use.
- **Alternatives rejected**: subtracting an absorbed snapshot on the client (the client cannot know the counts at
  harvest time without shipping them); storing compressed strings (needs a library this release does not need).

## R5. The harvest command

- **Decision**: `tools/harvest.mjs`, `npm run harvest [-- <file>...] [--reset <mapID>]`:
  1. Finds `WTF/Account/*/SavedVariables/OneKeyFishing.lua` two levels above `WOW_ADDONS_DIR` (`addonsDir()` from
     `tools/addon.mjs`), plus the files given as arguments.
  2. Reads each file with `luaparse` (already a dev dependency) and converts only table constructors to JS; the
     file is never executed, so a friend's file cannot run code.
  3. Validates every record (contracts/harvest-command.md) and rejects failing ones with a reason.
  4. Merges into `seed/contributions.json` (repository, not packaged), keyed by `id@epoch`: a record replaces the
     stored one only with a higher `seq`, so the same input never counts twice; a run that changes no sums
     leaves the seed and its epoch alone.
  5. Sums all stored contributions (dropping old-build cells of reset maps) into `OneKeyFishing/SeedData.lua` with
     `epoch + 1`, the `absorbed` map `id -> epoch`, sorted keys and lines up to 120 characters.
  6. Prints the report; stops with an error instead of writing a file over 1 MB.
- **Rationale**: one command, no manual steps (SC-006); keeping the absorbed contributions in the repository makes
  the merge idempotent (the same contribution is replaced, not added) and lets a reset recompute the sums.
- **Alternatives rejected**: adding new data onto the previous seed sums (running twice would double them);
  executing the saved files in fengari (runs untrusted code); one file per contribution (many small files).
- **Privacy**: contributions carry only random IDs, counts and averaged positions, the same data the seed ships.

## R6. Robust auction price

- **Decision**: In `Auction.lua`, on the result event, sort the loaded results by unit price (the order is not
  documented, R11), walk them cheapest first and average the unit
  price of the first 20% of all listed pieces (`ceil(total * 0.2)`, at least 1); `total` from
  `GetCommoditySearchResultsQuantity` when available, else the loaded quantities. Non-commodity results use
  `buyoutAmount / quantity`, skipping bid-only results. Stored as `prices[itemID] = { price, quantity, time }`.
  `Prices.Get` (value sums) returns the vendor price on few lots (`quantity < 5` or `lots < 3`, `lots` = the
  result rows on sale, i.e. price points, so one seller's stack alone is not a market); `Prices.GetAuction` returns the price and
  a "few lots" flag for display. Prices saved by 1.0.0 have no `quantity` and are used as they are until rescanned.
- **Rationale**: FR-025 to FR-027; a single cheap or expensive lot moves the average of the cheapest 20% very little
  (SC-005).
- **Alternatives rejected**: the most listed price (unstable when sellers undercut by a copper); the median of all
  pieces (a wall of overpriced unsold stock pulls it up); wiping 1.0.0 prices in a migration (the player loses
  values until the next scan for no gain).

## R7. Tabs and the "What can be caught here" panel

- **Decision**: `UI/StatsFrame.lua` gets two tabs at the bottom (`PanelTabButtonTemplate` with
  `PanelTemplates_SetNumTabs` / `PanelTemplates_SetTab`, guarded with a fallback to `ns.CreateButton`). Today's
  content moves into a child frame; the new panel lives in `UI/CatchHere.lua` (loaded before `StatsFrame.lua`),
  which `StatsFrame` creates at runtime. The last tab is saved in `OneKeyFishingDB.statsTab`.
- **Panel**: a header (place name built from `C_Map.GetMapInfo(mapID).name` plus `GetSubZoneText()`, whether the
  numbers are for the spot or the whole map, "N catches", the miss rate), two filter buttons opening menus through
  `MenuUtil` (as the language setting does), and up to 16 item rows sorted by chance (icon, name, chance or
  "little data", average pieces, price with a "few lots" mark), plus "and N more".
- **Refresh**: `CatchDB.GetVersion()` is bumped on every change; the existing 1 s tick redraws the panel when the
  version, the current place key or the filters changed, and on `PRICES_CHANGED` / `GET_ITEM_INFO_RECEIVED`.
- **Alternatives rejected**: a separate window (the author chose tabs; 1.4.0 adds a third tab); a scroll list (16
  rows cover the items of a fishing spot; "and N more" keeps it simple, Principle VI).

## R8. Saved data and schema

- **Decision**: `OneKeyFishingDB.shared = { myID, mine, records }` and `OneKeyFishingDB.statsTab`, added through
  `DB_DEFAULTS`; `myID` is created on first load (8 random base32 characters). `DB_SCHEMA` stays 1: only new
  fields, which `ApplyDefaults` fills (a bump would make 1.0.0 warn about "newer data" that it can read fine).
  `prices` entries gain an optional `quantity` and `lots`.
- **Rationale**: Principle III; ApplyDefaults fills new keys without overwriting; existing statistics are untouched
  (FR-008, SC-007).

## R9. Tests

- **Decision**: New `tests/catchdb_test.lua` (key, range, recording, misses, pool sub-cell, seed merge, epoch reset,
  fallback and filters), `tests/prices_test.lua` (robust price, few lots, 1.0.0 entries), a panel test in
  `tests/catchhere_test.lua` (tabs, remembered tab, filters reset, texts). Stubs in `tests/wow.lua`: configurable
  `C_Map.GetPlayerMapPosition`, `GetProfessions` / `GetProfessionInfo`, commodity and item search results with
  quantities. `tests/run.mjs` also runs `tests/*_test.mjs` modules, used by `tests/harvest_test.mjs` (fixtures:
  two accounts, a friend's file, a broken file, a reset, a second run).
- **Rationale**: Principle V; everything except the game's answers can run in fengari or Node.

## R10. Debug report

- **Decision**: `/okf debug` gains a "Catch database" section: seed epoch and number of places, own places, the
  current place key, pool detection on/off, and the last price scan coverage. `myID` is left out: the report is
  pasted into public bug reports and the ID would link them to the seed.

## R11. What public sources say before launch (2026-10-29)

Found by web research and a check of the API dump; none of it closes a verification item (verification.md), but it
chooses the assumptions.

- **API dump for Forever 1.60.1**: the `forever` branch of Gethe/wow-ui-source
  (<https://github.com/Gethe/wow-ui-source/tree/forever>, `version.txt` `1.60.1.70532`, with
  `Blizzard_APIDocumentationGenerated`) and of Ketho/BlizzardInterfaceResources
  (<https://github.com/Ketho/BlizzardInterfaceResources/blob/forever/Resources/GlobalAPI.lua>). API notes:
  <https://warcraft.wiki.gg/wiki/Patch_1.60.1/API_changes/notes> (Midnight secret values and addon restrictions are
  active; GUID server and spawn IDs are scrambled but stable within a session).
- **V1/V2 (map)**: `C_Map.GetPlayerMapPosition`, `GetBestMapForUnit`, `GetMapInfo` exist with nullable returns and no
  secret-return markers; `AddOnRestrictionType.Map` targets dungeons and raids; on Retail the position is nil in
  instances since 7.1. `GetMapInfo` gives `mapType` (`Enum.UIMapType` 0-6) and `parentMapID` (0 at the top).
- **V3 (pools)**: `GetLootSourceInfo` exists (pairs of GUID and quantity). No source documents fishing; server
  emulators create pool loot under the pool's GameObject GUID and open-water loot under the bobber's (35591). The
  assumption stays: a GameObject source whose object ID is not 35591 is a pool; only the object ID is used, since
  spawn IDs are scrambled. Other fishing addons do not tell pools apart.
- **V4/V5 (auction)**: all named functions exist; commodity results have `unitPrice` and `quantity`, item results
  have `buyoutAmount` (whole auction) and `quantity`; Blizzard's own list pages with
  `HasFullCommoditySearchResults` / `RequestMoreCommoditySearchResults` and shows `GetCommoditySearchResultsQuantity`
  as the total before all pages load. Page size and sort order are not documented. `SendSearchQuery` is limited to
  100 calls per minute. The auction house ships with Forever; its scope without realms is not described.
- **V6 (tabs)**: `PanelTabButtonTemplate` (`parentArray="Tabs"`), `PanelTemplates_SetNumTabs`, `SetTab` and
  `TabResize` exist in the Forever FrameXML; only the look in game is left to check.
- **V7 (version)**: `GetBuildInfo` returns `buildVersion, buildNumber, buildDate, interfaceVersion`, so
  `"1.60.1"` is expected.
- **Fishing in Forever** (fan guides from the beta, capped at level 30): Classic-like, skill 1-300, loot by zone,
  skill mainly stops fish from escaping; new Uncommon and Rare fish that need camp buffs. Loot tables above level 30
  were never public, so patches may still change them (the reset in R5 covers that).
- **For 1.4.0**: `C_Map.SetUserWaypoint`, `CanSetUserWaypointOnMap` and `C_SuperTrack.SetSuperTrackedUserWaypoint`
  exist in the dump.
- **SavedVariables**: no official size limit; community reports of trouble only far above this feature's size.
