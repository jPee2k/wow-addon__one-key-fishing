# Verification debt: Local Catch Database

The game cannot be played before its launch on 2026-11-04, so part 1 of the shared catch database is built on the
assumptions below and verified afterwards. Each item has an ID. The code that depends on V1-V7 carries a
`-- VERIFY(Vn): ...` comment; `npm run check` lists the open markers, and `npm run build` (release) refuses to
package while any marker is left, so release 1.2.0 (all four parts) cannot ship with those open. V8 and V9 have no
marker in the code: they are checked in game with the checklist and are not enforced by the build. The temporary
spike command carries `-- VERIFY(spike)` (`Spike.lua`, its `Commands.lua` entry); that marker goes when the spike
code is removed (tasks.md T042), after the spike steps of every part have run.

Closing an item: run the step in game (`docs/checklists/spike.md` for V1-V7, `docs/checklists/catch-database.md` for
V6, V8 and V9), record the answer in `docs/forever-api.md`, adjust the code if the answer differs from the
assumption, remove its markers, and tick it here.

| ID | Assumption we build on | Evidence before launch (R11) | If it turns out wrong | How to verify | Status |
| --- | --- | --- | --- | --- | --- |
| V1 | `C_Map.GetPlayerMapPosition(mapID, "player")` returns a position while channeling Fishing in the open world and in cities; nil in instances | In the 1.60.1 API dump, nullable, no secret marker; nil in instances on Retail | No position anywhere: every catch goes to the `x` cell (whole map); the tab shows only whole-map numbers | Spike part 1, open water, city, instance | Built; partly seen 2026-11-06 (release 1.1.0): in Booty Bay `GetBestMapForUnit` gives the zone map 1434 (no town map of its own) and `GetPlayerMapPosition` a position there. Not seen yet: a position while channeling, a capital, a cave, an instance |
| V2 | `C_Map.GetBestMapForUnit("player")` gives a stable map ID per fishing spot (cities and caves may have their own maps) | In the dump; `mapType` and `parentMapID` available | Nothing breaks; places in caves and cities are their own maps, as decided | Spike part 1, open water, city, cave | Built; partly seen 2026-11-06: Booty Bay reports the zone map 1434, the same for every spot there. Not seen yet: other towns and caves |
| V3 | Pool loot: `GetLootSourceInfo` returns a `GameObject` GUID whose object ID is the pool, not the bobber (35591); `IsFishingLoot()` is true for pools too | Function in the dump; pool vs bobber GUID only from server emulators; spawn IDs scrambled, object ID kept | Without a difference no pool counters are written (`ns.IsPoolLoot` returns nil) | Spike part 1, fishing pool | Built; the bobber side seen 2026-11-06 (release 1.1.0): the bobber is object 35591 in the `softinteract` GUID (cast, hook, no bobber pass). Not seen yet: the pool loot source |
| V4 | Commodity search results carry `unitPrice` and `quantity`, `GetCommoditySearchResultsQuantity` gives the total listed, and `HasFullCommoditySearchResults` / `RequestMoreCommoditySearchResults` page the results | Fields and paging functions in the dump; page size and sort order undocumented | The price uses the loaded results only; `/okf debug` shows the coverage | Spike part 1, auction house | Built; partly seen 2026-11-06: commodity result 1 has `unitPrice` and the scan gives prices (release 1.1.0). Not seen yet: `quantity`, the total quantity, paging |
| V5 | Item (non-commodity) search results carry `buyoutAmount` for the whole auction and `quantity` | `buyoutAmount` is for the whole auction (inferred from Blizzard's UI) | Unit price wrong for stacked non-commodities; switch to the field the spike shows | Spike part 1, auction house | Built; partly seen 2026-11-06: item result 1 has `buyoutAmount` and the scan gives prices. Not seen yet: whether it is for the whole auction, bid-only auctions |
| V6 | `PanelTabButtonTemplate` and `PanelTemplates_SetNumTabs` / `PanelTemplates_SetTab` exist | Template and functions in the Forever FrameXML | The fallback draws the tabs with `ns.CreateButton` | Checklist step 1 | Built, waiting for launch |
| V7 | `GetBuildInfo()` returns the version as `"1.60.1"`-style text | Return values in the dump | Data is recorded under `"unknown"`: it counts in the tab, but Share never sends that build and the harvest skips it, so no data reaches peers or the seed | Spike report header (any step) | Closed 2026-11-06 (spec 008): the debug reports of release 1.1.0 show `GetBuildInfo` as 1.60.1 / 70790; marker removed |
| V8 | Login and the window stay smooth with a whole-world seed (SC-004) | None | Load the seed lazily on first use of the tab | Checklist step 9 with a generated large seed | Built, waiting for launch |
| V9 | The whole in-game checklist of the feature passes | None | Fix and re-run | `docs/checklists/catch-database.md` | Built, waiting for launch |

Evidence found before launch (research.md, R11) lowers the risk but does not close an item: only the game does.
