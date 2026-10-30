# Verification debt: Local Catch Database

The game cannot be played before its launch on 2026-11-04, so part 1 of the shared catch database is built on the
assumptions below and verified afterwards. Each item has an ID. The code that depends on V1-V7 carries a
`-- VERIFY(Vn): ...` comment; `npm run check` lists the open markers, and `npm run build` (release) refuses to
package while any marker is left, so release 1.2.0 (all four parts) cannot ship with those open. V8 and V9 have no
marker in the code: they are checked in game with the checklist and are not enforced by the build. The temporary
spike command carries `-- VERIFY(spike)` (`Spike.lua`, its `Commands.lua` entry); that marker goes when the spike
code is removed (tasks.md T042), after the spike steps of every part have run.

Closing an item: run the step in game (`/okf spike` prints the facts), record the answer in CLAUDE.md "Known API
facts", adjust the code if the answer differs from the assumption, remove its markers, and tick it here.

| ID | Assumption we build on | Evidence before launch (R11) | If it turns out wrong | How to verify | Status |
| --- | --- | --- | --- | --- | --- |
| V1 | `C_Map.GetPlayerMapPosition(mapID, "player")` returns a position while channeling Fishing in the open world and in cities; nil in instances | In the 1.60.1 API dump, nullable, no secret marker; nil in instances on Retail | No position anywhere: every catch goes to the `x` cell (whole map); the tab shows only whole-map numbers | Spike steps 1, 3, 4 | Built, waiting for launch |
| V2 | `C_Map.GetBestMapForUnit("player")` gives a stable map ID per fishing spot (cities and caves may have their own maps) | In the dump; `mapType` and `parentMapID` available | Nothing breaks; places in caves and cities are their own maps, as decided | Spike steps 1, 3 | Built, waiting for launch |
| V3 | Pool loot: `GetLootSourceInfo` returns a `GameObject` GUID whose object ID is the pool, not the bobber (35591); `IsFishingLoot()` is true for pools too | Function in the dump; pool vs bobber GUID only from server emulators; spawn IDs scrambled, object ID kept | Without a difference no pool counters are written (`ns.IsPoolLoot` returns nil) | Spike step 2 | Built, waiting for launch |
| V4 | Commodity search results carry `unitPrice` and `quantity`, `GetCommoditySearchResultsQuantity` gives the total listed, and `HasFullCommoditySearchResults` / `RequestMoreCommoditySearchResults` page the results | Fields and paging functions in the dump; page size and sort order undocumented | The price uses the loaded results only; `/okf debug` shows the coverage | Spike step 5 | Built, waiting for launch |
| V5 | Item (non-commodity) search results carry `buyoutAmount` for the whole auction and `quantity` | `buyoutAmount` is for the whole auction (inferred from Blizzard's UI) | Unit price wrong for stacked non-commodities; switch to the field the spike shows | Spike step 5 | Built, waiting for launch |
| V6 | `PanelTabButtonTemplate` and `PanelTemplates_SetNumTabs` / `PanelTemplates_SetTab` exist | Template and functions in the Forever FrameXML | The fallback draws the tabs with `ns.CreateButton` | Open `/okf stats` | Built, waiting for launch |
| V7 | `GetBuildInfo()` returns the version as `"1.60.1"`-style text | Return values in the dump | Data is recorded under `"unknown"`: it counts in the tab, but Share never sends that build and the harvest skips it, so no data reaches peers or the seed | Spike report header (any step) | Built, waiting for launch |
| V8 | Login and the window stay smooth with a whole-world seed (SC-004) | None | Load the seed lazily on first use of the tab | Feature step 10 with a generated large seed | Built, waiting for launch |
| V9 | The whole in-game checklist of the feature passes | None | Fix and re-run | quickstart.md "In game: the feature" | Built, waiting for launch |

Evidence found before launch (research.md, R11) lowers the risk but does not close an item: only the game does.
