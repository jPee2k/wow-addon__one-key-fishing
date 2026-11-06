# Verification debt: Interface Languages and the Next Fishing Rank

Spec 001 shipped in release 1.1.0 (2026-11-05). Part of its next-rank advice (User Story 3) is still built on the
assumptions below. The ids are the research items that explain them: R11 for the rank data, R12 for the game names
by ID and R14 for the map pin ([research.md](research.md)). Code that depends on an item carries a
`-- VERIFY(Rn): ...` comment. `npm run check` lists the open markers, and `npm run build` refuses to package while
any is left. This page holds the current state; research.md keeps the history of each check.

To close an item:
1. Run its step in game ([docs/checklists/interface-language.md](../../docs/checklists/interface-language.md)
   "Next rank" and "Pin").
2. Record the answer in `docs/forever-api.md`.
3. Adjust the data in `OneKeyFishing/GameData/` or the code if the game differs.
4. Remove the markers, and update the row here.

| ID | Assumption we build on | Evidence | If it turns out wrong | How to verify | Status |
| --- | --- | --- | --- | --- | --- |
| R11 | Forever keeps the original game's way to learn each rank (`GameData/FishingRanks.lua`). Journeyman is taught by a trainer from skill 50. Expert comes from the book 16083 (sold by Old Man Heming, NPC 2626, in Booty Bay) from skill 125 and level 20. Artisan comes from the quest 6607 of Nat Pagle (NPC 12919) in Tidefury Cove (area 517 in 15, map 1445, point 0.586 / 0.602), from skill 225 and level 35 | Wowhead Classic, warcraft.wiki.gg and the Forever guides (2026-11-03); in game 2026-11-05/06 (below) | Change the value in `GameData/FishingRanks.lua`; the advice and its notice then follow the game | `interface-language.md` "Next rank": a character at each threshold, at Heming and at Nat Pagle | Partly closed. **Seen in game** (marks removed): area IDs 35, 33, 517, 15 and item 16083 give their names (2026-11-05); Journeyman taught by a trainer at level 10; the client uses the Classic map 1434 for Booty Bay; Heming (NPC 2626) at 0.274 / 0.770 sells the book 16083 (2026-11-06). **Open**: `learnAt` 50, 125 and 225; `level` 20 and 35; quest 6607 (the client gives no title for it yet), NPC 12919, maps 1445 / 70 and the point 0.586 / 0.602 |
| R12 | Game names come from the client by ID; an NPC's name comes from its creature tooltip and, while the client has not given it, from `GameData/NpcNames.lua`. The German name of Heming there is "Der alte Mann Heming" (the modern data; Wowhead's Classic data has the English name) | Wowhead's localized pages (2026-11-03) | Correct the name in `GameData/NpcNames.lua` | A deDE client at Heming, before and after his tooltip loaded | Partly closed. **Seen in game** (marks removed): the rank names come as spell subtexts; Heming's name comes from his creature tooltip (2026-11-06). **Open**: the German name of the table |
| R14 | The map pin works from addon code (`Core/MapPin.lua`, every pin of the addon since spec 008: the next rank and the catch catalog). It sets `C_Map.SetUserWaypoint` and the navigation arrow, gives the chat map link, and opens the world map out of combat with the global `OpenWorldMap` | Blizzard's `/mappin`; the export | The pin and the arrow stay; the map stays closed and the toast says to open it | `interface-language.md` "Pin"; `docs/checklists/catch-catalog.md` steps 3-5 | **Failed** (2026-11-06): after the addon opened the map, the map was blocked in a later fight (taint of `targetScrollY`, "Interface action failed because of an AddOn"); the fix (the map stays closed) waits in `docs/tech-debt.md`. **Seen in game** (marks removed): the arrow and the chat map link. The catalog's V32 (`specs/005-catch-catalog/verification.md`) is the same assumption and was replaced by R14 in spec 008 |
