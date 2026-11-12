# Research: Catch Place Fixes

The facts behind each decision are in `docs/forever-api.md` "Verified in game" (2026-11-06/07 and the `/run`
checks of 2026-11-08) and in the spec's "In-game checks before the plan".

## R1. A secret name in a fight (batch 6)

- **Decision**:
  - `NonEmpty` in `Fishing/Skill.lua` returns nil for a secret value (`issecretvalue`, guarded like the chat
    handlers of `Exchange/`). Every name the advice reads goes through it: the spell subtext, the area, the item,
    the quest and the NPC tooltip line. A secret NPC name is then not cached (the cache is filled only after
    `NonEmpty` passes), and the next call reads the tooltip again.
  - `Check` returns at once while `InCombatLockdown()` is true, before it builds the advice. A new
    `PLAYER_REGEN_ENABLED` handler runs `Check(false)` after the fight, so a notice owed during the fight comes
    once.
- **Rationale**: the error came from `text ~= ""` on a secret string (`type` is "string"). The guard makes the
  advice safe wherever it is built (the minimap tooltip and the statistics window can be open in a fight too). The
  fight skip removes the repeated tooltip reads on every weapon skill-up, which happen while the "can learn" notice
  waits for a character level.
- **Alternatives considered**: `pcall` around the comparison (hides other errors); only the fight skip (the
  minimap tooltip in a fight would still fail); caching "no name" (the name would stay missing after the fight).

## R2. A cave on the continent map (V2, V33)

- **Decision**: in `CatchDB.GetCurrentPlace`, when `C_Map.GetMapInfo(mapID).mapType` is Continent or lower
  (`Enum.UIMapType.Continent` 2, World 1, Cosmic 0), the player's position on that map goes to
  `C_Map.GetMapInfoAtPosition(mapID, x, y)`. A result of type Zone (3) or deeper replaces the map, and the cell
  and position are read on it with `C_Map.GetPlayerMapPosition(zoneID, "player")`. Without a zone, or without a
  position on it, `GetCurrentPlace` returns nil: the cast is not recorded and "What can be caught here" shows its
  "no place" state.
- **Rationale**: the `/run` of 2026-11-08 in the cave gave The Barrens 1413 (type 3) under the continent point. All
  readers of the place (`Events.lua` at cast start, `CatchHere`, `Catalog.MinimapLines`, the debug report) go
  through `GetCurrentPlace`, so FR-006 holds without other changes. The `CatchHere` refresh that reads
  `CatchDB.GetCell(shown.mapID)` for a shown map keeps working, because the shown map is then the zone.
- **Checked in game** (2026-11-08, `/run` in the cave): `C_Map.GetPlayerMapPosition(1413, "player")` gives a
  position there (x 0.461), so the cell is read on the zone map directly; no marker and no world-position fallback
  are needed.
- **Alternatives considered**: not recording continent casts (the fallback of the spec, not needed now); keeping the
  continent and naming the cave (the place would still be a continent grid).
- **Not changed**: the statistics zone list (`Catch/Stats.lua` `ReadZone`) keeps the game's map and subzone text
  ("Kalimdor - Wailing Caverns"): it is the player's own statistics, not shared data, and the name is readable.

## R3. The subzone by name (V34)

- **Decision**: the area of a cast is found by the game's subzone text among the game's area names:
  - The text is `GetSubZoneText()`; empty means no area. The needle is folded with `ns.FoldCase` (Principle II).
  - The walk calls `C_Map.GetAreaInfo(id)` for the IDs 1 to `MAX_AREA_ID` (20000; the highest named ID seen is
    17853) and keeps the lowest ID whose folded name equals the needle (deterministic, FR-009).
  - The answer is cached per folded subzone text for the session (`areaByName[text] = id | false`), so a walk
    happens once per new subzone.
  - The walk is spread over frames: `AREA_CHUNK` IDs per step (2000, about 0.5 ms), the next step through
    `C_Timer.After(0, ...)`. A cast that starts while its subzone is still being walked gets its area when the walk
    ends (`cast.area` is filled by a callback); a cast settled before that keeps no area.
  - The search through `C_MapExplorationInfo.GetExploredAreaIDsAtPosition` goes, with its `VERIFY(V34)` marker:
    the name lookup finds every area it found (Ratchet 392) and those it missed (Stonebull Lake 223).
- **Rationale**: the `/run` of 2026-11-08 found exactly one area for Ratchet and for Stonebull Lake, and the whole
  walk took 4.3 to 4.7 ms. Spreading it keeps every frame under 1 ms (FR-011, SC-004). The cache keeps the cost to
  a few walks per session. The ID, not the name, is stored, so other languages show their own name.
- **Alternatives considered**: one full name index built at login (about 18000 calls and a table of every area
  name held all session, for no gain over a few walks); a synchronous walk on the first cast in a subzone (4.5 ms on
  a fast PC, more on a slow one); a bundled table of area IDs per zone from the client database (data to keep up to
  date, and the name match is still needed).
- **The spike**: the "Areas" section of `Core/Spike.lua` (V34) goes, with its test lines; V34 is answered.

## R4. Pool catches (V3)

- **Decision**: `ns.IsPoolLoot()` returns nil always (the loot source walk and its `VERIFY(V3)` go); `FISH_CAUGHT`
  passes nil, `Settle` writes no pool part, `P.lastPool` is nil and the debug line reads "last catch from a pool:
  unknown". Code review round 1 removed that dead path: `ns.IsPoolLoot`, the `fromPool` argument of `FISH_CAUGHT`,
  `P.lastPool` and the debug line. The record format, `CatchDB/Checks.lua`, the water views and the "Water" filter
  stay: a pool part from
  an older build is still accepted, and `HasPoolData` stays false without one, so the filter stays hidden.
- **Rationale**: the decision of the quiz (keep the format); in Forever a pool catch's loot source is the bobber,
  so nothing tells it apart.
- **Alternatives considered**: removing the pool part everywhere (changes the 1.2.0 exchange format and many
  files; the quiz chose against it).

## R5. The pole by skill (batch 5)

- **Decision**: `Gear.FindBestPole` reads `ns.Skill.Get()` once and passes over a pole whose
  `GameData.FishingPoles[itemID].skill` is above that rank. An unknown rank, or a pole without an entry, holds
  nothing back (the rule of `Fishing/Bags.lua` for lures). `Gear.GetPole` keeps a pole the player chose by hand.
  The choice is read at every entry into fishing mode, so a skill-up past a pole's requirement takes it next time.
- **Rationale**: the data is recorded already; the base skill is compared, as for lures (V44, still open there; the
  same marker covers both).
- **Alternatives considered**: reading the requirement from the item tooltip (needs the tooltip and a localized
  needle; the table is enough).

## R6. Documents

- `CHANGELOG.md` `[Unreleased]`: under "Fixed", the Lua error in fights (a fix of the released 1.1.0), the pole
  choice; the cave and subzone and pool changes are part of the unreleased shared database, so they need no line
  (CLAUDE.md, "fixes of an unreleased feature need no changelog line").
- The verification records: V2 and V3 in `specs/002-local-catch-db/verification.md`, V33 and V34 in
  `specs/005-catch-catalog/verification.md`, with a "Spec 011" note.
- `docs/forever-api.md` already has the `/run` results (2026-11-08); the CLAUDE.md "Places" line too.
- `docs/architecture/catch-db.md` (the place of a cast, the area lookup, the pool source), `fishing-mode.md` (the
  pole rule, the fight skip of the skill check), `docs/tech-debt.md` (batches 2 and 6 and the pole item go, a
  history line), `docs/release-plan.md`, the checklists `catch-catalog.md` (steps 5 and 6), `spike.md` (Areas
  gone), and the 1.2.0 test page (phase "After spec 011").
