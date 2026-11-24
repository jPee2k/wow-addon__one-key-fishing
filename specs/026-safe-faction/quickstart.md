# Quickstart: "Safe for me" and the factions

## Run

```text
npm run check
npm test
```

## What the tests prove

| Test | Proves |
|---|---|
| `tests/gamedata/shape_test.lua` | `GameData.ZoneFactions`: map IDs, only the two tags, nine Alliance and eight Horde entries, each a zone of `ZoneLevels` |
| `tests/catalog/best_places_test.lua` | `ZoneFaction` of a listed map, of a map inside it (parent walk), of a contested one (nil); with Safe for me on a Horde character's list has no Alliance zone or capital and an Alliance character's no Horde one (SC-001); contested zones pass for both, under the level rule (SC-002); no faction (nil, "Neutral"): only the level rule; with Safe for me off both sides are ranked; `Unsafe` is true for a hostile zone; `Describe` names the faction; a listed zone's spots are never filtered by faction (FR-007) |
| `tests/ui/best_tab_test.lua` | an enemy zone's Level drawn red with Safe for me off; an own-faction zone within the level not red; "Nothing matches the filters." when only enemy zones hold data |

The tests set `player_faction` through the `UnitFactionGroup` stub of `tests/wow.lua` and list test maps in
`GameData.ZoneFactions` as they do in `GameData.ZoneLevels`.

## In game (V77, checklist `docs/checklists/best-places.md`)

1. Each character in two zones of its own faction and one contested zone (no trip into enemy land): the Horde
   character in Durotar, The Barrens and Ashenvale, the Alliance character in Elwynn Forest, Westfall and Wetlands.
   `/run print(C_PvP.GetZonePVPInfo())` gives `friendly` in the own zones and `contested` in the contested
   one, as `GameData/ZoneFactions.lua` says, and the zone text agrees (SC-003).
2. A Horde character, Safe for me on: no Alliance zone or capital in "Best places"; off: they show, Level in red.
3. The same on an Alliance character, mirrored.
