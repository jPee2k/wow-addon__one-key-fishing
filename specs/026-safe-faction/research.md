# Research: "Safe for me" and the factions

The facts behind these decisions (the client export, the game's DB2 tables, the web) are in
[docs/best-places-research.md](../../docs/best-places-research.md), section 4; the decisions of the author's quiz of
2026-11-24 are in the spec. This file records the technical choices.

## R1. Where a zone's faction comes from

- **Decision**: a data table `GameData.ZoneFactions` (`GameData/ZoneFactions.lua`), `[UiMapID] = "Alliance" |
  "Horde"`, the 17 maps whose area has `AreaTable.FactionGroupMask` 2 (Alliance) or 4 (Horde), read through
  `UiMapAssignment` (UiMap -> area), wago.tools product `wowf`, build 1.60.1.71037. A map not listed is contested.
- **Rationale**: no client API gives the territory of an arbitrary zone (`UiMapDetails` has no faction;
  `C_PvP.GetZonePVPInfo` answers for the player's own zone only). The data is small and stable, as `ZoneLevels`.
- **Alternatives**: `C_PvP.GetZonePVPInfo` remembered per zone as the player visits (an empty list for a new
  character, and a record per character to keep); a field in `ZoneLevels` (mixes two entities in one file, against
  one file per entity); a `tools/` script fetching the CSV (a network step for 17 stable rows; the author chose a
  hand-written table with its source).

## R2. The table's values

- **Decision**: the strings `"Alliance"` and `"Horde"`, the same untranslated tags `UnitFactionGroup` returns as its
  first value, so the rule compares them directly.
- **Rationale**: the tags are the game's own fixed tokens (not the localized second value), so Principle II holds.
- **Alternatives**: the mask numbers 2 and 4 (one more mapping in code, less readable in the data file).

## R3. A map inside a zone

- **Decision**: `BestPlaces.ZoneFaction(mapID)` walks up `C_Map.GetMapInfo(...).parentMapID` until a listed map, as
  `ZoneLevels` does (at most 8 steps; a continent or a map without info ends it with nil = contested). The walk is
  shared by both: one local helper `FirstListed(table, mapID)` returns the first listed parent's entry.
- **Rationale**: caves and buildings (Micro and Dungeon maps) keep their zone's catches under their own map ID.
- **Alternatives**: listing every micro map (many IDs, breaks when the game adds one).

## R4. The character's faction

- **Decision**: `BestPlaces.PlayerFaction()` returns `"Alliance"` or `"Horde"` from `UnitFactionGroup("player")`,
  else nil ("Neutral", nil, or the function missing). Read when the list is read (no cache, no event), so it is right
  as soon as the game knows it.
- **Rationale**: the faction never changes in a session (no neutral race in Forever's play: the Skyborne pick a side
  at creation); one cheap call per read. The tab redraws on any change of the filters or the data, and on opening.
- **Alternatives**: caching at login and listening to a faction event (more code for a case the game does not have).

## R5. The filter and the colour

- **Decision**: `Compute` stores `zone.faction = BestPlaces.ZoneFaction(mapID)` with the levels. `Hostile(zone)` is
  true when both the zone's and the character's factions are known and differ. `Passes` hides a hostile zone when
  Safe for me is on, before the level rule; `Unsafe(zone)` (the red Level) is true when the zone is hostile or its
  lowest level is above the character's.
- **Rationale**: both rules stay filters of the read, so switching Safe for me only redraws (`Bump`), as today; the tab
  needs no change, as it already colours by `Unsafe`.
- **Note**: a capital reads 1-60 in `ZoneLevels`; listed in `ZoneFactions`, it is hidden for the other faction.

## R6. The debug report

- **Decision**: `BestPlaces.Describe` adds the character's faction to its last line (`safe true, continent all,
  faction Horde`).
- **Rationale**: a bug report about a missing zone needs it; a faction is not a name of a player or a place.

## R7. The in-game check (V77)

- **Decision**: one `VERIFY(V77)` marker, in `BestPlaces.ZoneFaction` (the one reader of the table; the data file
  stays data only, its header names the source): each character stands in two zones of its own faction and one
  contested zone (Horde: Durotar, The Barrens, Ashenvale; Alliance: Elwynn Forest, Westfall, Wetlands), so no one
  enters enemy land; `/run print(C_PvP.GetZonePVPInfo())` gives `friendly` / `contested` as the table says, and the
  zone text agrees (SC-003); the tab on a Horde and an Alliance character hides the other
  side's zones and capitals with Safe for me on and shows them in red with it off.
- **If wrong**: a zone is hidden for the wrong faction or not hidden; its row in the table is corrected.
- **Closing it**: the answer goes into `docs/forever-api.md` (the zone territory facts), the row of
  `verification.md` says Confirmed, the marker is removed (CLAUDE.md "Hard rules").

## R8. The known limit

- **Decision**: hostile towns inside contested zones are not filtered (the data marks only Dalaran); recorded in
  `docs/ROADMAP.md` as a possible later step, not in the tech-debt list (it is a choice, not a defect).
