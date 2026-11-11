# Technical debt

Known issues that are not fixed yet, with the reason they matter and a suggested direction. Each item says where
it was found and how serious it is. Remove an item when it is fixed (with a test), or move it to the spec of the
feature that takes it on.

Severity: **high** loses data or cuts off honest players; **medium** wrong state or wasted traffic; **low**
cleanup, no wrong behaviour.

## Fix batches

The open items grouped into fixes that can be taken in one go (one spec or one patch each, `/speckit-specify` with
the batch as its description). Each batch says where it is built, what it closes and what the game still has to
show. The facts behind them: `docs/forever-api.md` "Verified in game" (2026-11-06/07) and the `verification.md` of
specs 002 to 006. Batches 3 and 4 were fixed by spec 009, batch 1 by spec 010, and batches 2 and 6 with the pole
item of batch 5 by spec 011, on `002-shared-db` (release 1.2.0).

The batches are in the order to take them: the top one first.

### Batch 10: the bobber in an instance (before 1.2.0; check in a dungeon with water)

A Lua error on every indicator update while fishing in a dungeon (fishing itself works); 1.1.0 has the same code.

- "The bobber's GUID is a secret value in an instance" (high)

### Batch 7: the minimap tooltip (any time; reproduce in game first)

Cosmetic, no wrong data; the fix waits for a way to make it happen on purpose.

- "The minimap tooltip loses its colours" (low)

### Batch 5: gear choices (when a player meets them)

Seen only in the code; waits for a case in game.

- "A lure the game refused stays skipped after a skill-up" (low; waits for V43 / V44)

### Batch 8: tooling (when a file needs an alias)

- "The private-table check reads only the plain form" (low)

### Batch 9: two status texts (any time; no game needed)

Seen in game, the fix and its test run without the game.

- "The hint says only own catches while others' are shown" (low)
- "Exchange: 1 players" (low)

## Open items

### The bobber's GUID is a secret value in an instance (high)

- **Found**: in game, 2026-11-11 (game 70888, enUS, addon in Ukrainian, a dungeon with water): while fishing, the
  game's error window twice ("Count: 2", then "Count: 6"): `attempt to perform string conversion on a secret string
  value (execution tainted by 'OneKeyFishing')` in `strsplit`, `Core/Data.lua:13` `GameObjectID`, called from
  `Core/Data.lua:253` `IsBobberTargeted`, from `UI/Indicator.lua:123` (`ShowNoBobber`) on the indicator's update;
  the local `guid` is `<secret string>`. Casting, hooking and loot still worked; only the error window kept coming.
  In the open world the same GUID is readable (spike, 2026-11-06). Release 1.1.0 has the same code (`Data.lua`).
- **Cause**: in an instance `UnitGUID("softinteract")` returns a secret value, and `ns.GameObjectID` splits it with
  no `issecretvalue` check (the pattern used in `CatchDB.lua`, `Comm.lua`, `Skill.lua`).
- **Direction**: `ns.GameObjectID` returns nil for a secret value; `IsBobberTargeted` then needs a third answer
  ("unknown"), so the indicator does not show "No bobber" in an instance where the bobber cannot be told apart, and
  the key keeps `INTERACTTARGET` while channeling as now. Check every other reader of `softinteract` (name, GUID) for
  the same guard. Test: a stubbed `UnitGUID` returning a value `issecretvalue` reports as secret gives no error and
  no "No bobber". Then a dungeon with water in game: no error, hooking works.

### The hint says only own catches while others' are shown (low)

- **Found**: in game, 2026-11-10, English client: "What can be caught here" in Thunder Bluff shows "51 catches from 2
  players" and "Exchange: 1 players, 0m ago", and under them "No bundled data in this version: only your own catches
  are shown." The first half is true (no seed yet), the second is wrong once the exchange brought other players'
  records.
- **Cause**: `UI/CatchHere.lua` (the hints) adds the line whenever the source filter is "All" and
  `CatchDB.HasSeed()` is false; the text dates from part 1, before the exchange.
- **Direction**: add the line only when no other player's record is held either (a `CatchDB` query over
  `shared.records` without the own ones), or split it: "No bundled data in this version." alone once others' records
  are held. Test: with no seed and one record of another player the hint has no "only your own catches"; with
  neither it keeps the full line. Texts change in all nine languages.

### "Exchange: 1 players" (low)

- **Found**: in game, 2026-11-10, English client: the status line on the settings page "Shared database", on "What
  can be caught here" and in `/okf share` reads "Exchange: 1 players, 1m ago".
- **Cause**: `Exchange/ShareGame.lua` formats `L["Exchange: %d players, %s ago"]` for every count; spec 010 gave
  "1 catch" its own singular text, the exchange line was left out.
- **Direction**: a singular key for one player ("Exchange: 1 player, %s ago"), as spec 010 did for the catches, in
  all nine languages. Test: the status text for one and for two players.

### The minimap tooltip loses its colours (low)

- **Found**: in game, 2026-11-08, English client, the addon in Ukrainian, fishing mode on, the statistics window
  open: on one hover every line of the minimap button's tooltip was white. The gold next-rank line and key labels,
  the grey help lines and the green click lines all lost their colour. Only colour codes inside the text survived
  (the green "ON", the grey version). On a later hover the colours were right again. This came back: spec 007
  research R9 (2026-11-05) saw the same white tooltip on every second hover, then only with the addon in Korean or
  Chinese, and left it for an issue from players.
- **Cause**: not known. `UI/Minimap.lua` `ShowTooltip` passes the colour on every `AddLine` / `AddDoubleLine`, so
  something resets the line colours of the shared `GameTooltip` after the lines are added or before they are drawn.
  Candidates: a tooltip-data refresh of the game (`TooltipDataProcessor`) left from an item tooltip shown just
  before (the statistics window's item rows, the item hooks); the font's colour once a line wraps
  (`ns.TallGlyphs()` was on in R9).
- **Where**: `UI/Minimap.lua` `ShowTooltip`, the shared `GameTooltip`.
- **Direction**: reproduce first: the hover order (an item row of the statistics window, then the minimap button),
  the language, and whether `GameTooltip:GetTooltipData()` is still set when the lines are added. Then clear the
  tooltip's data before the lines (`GameTooltip:ClearLines()` after `SetOwner`), or colour the text with colour
  codes as the "ON" state does. Cosmetic: no wrong data.

### A lure the game refused stays skipped after a skill-up (low)

- **Found**: the spec 008 review, round 3 (2026-11-06), from the code; not seen in game.
- **Cause**: `Fishing/Bags.lua`. A lure the game refuses goes into `skippedLures` until fishing mode is entered again.
  With the skill rule of spec 008 a known lure is offered only once the skill reaches `GameData.Lures[id].skill`,
  so a refusal can still happen only when that value or V44 (base skill, not skill with bonuses) is wrong. Then the
  lure stays skipped after the skill rises, until the mode is entered again.
- **Direction**: when V43 / V44 are checked in game. If either fails, fix the value in `GameData/Lures.lua`. If
  refusals still happen, drop the skipped entries of lures whose requirement is met on `SKILL_LINES_CHANGED`. Test: a
  refused lure is offered again after a skill-up past its requirement.

### The private-table check reads only the plain form (low)

- **Found**: the spec 008 review, round 3 (2026-11-06).
- **Cause**: `tools/addon.mjs` `privateProblems` finds `<Module>.private` by the module's own name, as every file
  of the addon writes it today. It does not see an alias (`local C = ns.CatchDB; C.private`) or `ns["CatchDB"].private`.
  It also cuts a line at `--` even inside a string, so a read after such a string is missed.
- **Direction**: read the code with luaparse (already a dependency of the checks) and follow the locals bound to
  `ns.<Module>`, if a file ever needs an alias. Test: an aliased read from another folder is reported.

## History

Every review of the shared catch database was closed with tests the same or the next day; the details are in the
commit history of `002-shared-db` (commits "Fix ..." between 2026-10-29 and 2026-10-31).

- 2026-10-29, the local catch database: thirteen items fixed; the forged-record part moved to the design and was
  closed by the public channel's version chain.
- 2026-10-30, the catch exchange (three independent reviews): four high and six medium items fixed; the flood of
  message parts was closed by the public channel.
- 2026-10-31, the public channel (three review-and-fix cycles): every blocker, high and medium finding fixed.
- 2026-10-31, the low items of all reviews: the real ones fixed (channel, exchange and harvest), the rest recorded
  as accepted limits in `specs/004-public-channel-sync` (spec edge cases, data-model.md) or left as style.
- 2026-10-31, a review of the whole branch against `develop` (five areas): one high, two medium and six low items,
  recorded as batches A to E. SHA-256, the codec, the merges and the session states held up. Batch A (item IDs
  from the loot link) and batch B (the pool part of a cell must fit the cell) were fixed the same day, and batch C
  (each of the addon's own channel leaves owes one `YOU_LEFT` of its name, used up when it comes) after them; batch D
  (a remembered peer's new tag replaces its old one in `byTag`, so the table stays within the peer bound) next.
- 2026-10-31, a triage of the open items: kept only the three confirmed in play. Dropped as cases that do not come
  up: a nil player count no caller passes, the "Only mine" guard that holds today, the repeated ready rule, the
  spot cache (a few hundred entries) and the pin rule changing mid-session; the pool-data scan (unmeasured; the
  step time is checked in game by V28 and V39); and the channel's notice-order cases of the batch C reviews (the
  order is V41, the delays are milliseconds, and nobody joins a fallback name or gets `YOU_CHANGED` by hand).
- 2026-11-01, batch E (the catalog): a `CatalogTab.Show` while the index is still building waits for it and
  `Tick` makes the choice once it is ready; the map pin's answers show with catch notifications off.
- 2026-11-06, spec 008 (architecture alignment), three review-and-fix rounds of the working tree. Fixed with tests:
  - the login check of the own record follows `CatchDB.OwnRecord`;
  - the indicator redraws on a skill change;
  - the catch database's range constants stay literals, held equal to the ranks by a test;
  - the CVars of fishing mode come from one table;
  - the GameData check finds calls, also without brackets;
  - the cave fallback of the map pin uses only the point's own map.

  Also cleaned: dead locals, a dead branch, a dead stub, stale names in docs and comments. Two low items stay
  above. Dropped as cases that do not come up:
  - a fifth Fishing rank (Forever has none above 300);
  - a record whose `id` differs from its key;
  - an own record damaged during a session;
  - the per-row pin lookups of a spot list (cached with the rows);
  - the lure `order` field, held 1..n by the shape test.
- 2026-11-07, spec 009: batches 3 and 4 fixed with tests (the map pin no longer opens the map; no equip call in
  the combat lockdown; the attack line; the combat state handler compares the number the driver sends); R14 and
  V45 confirmed in game the same day.
- 2026-11-07, spec 010: batch 1 and "1 catches" fixed with tests (names as the game gives them, the public channel
  off, the proof step budget, the hidden "No player named" line as the offline signal, the singular texts; the
  spike trimmed); V11 (friends list, other realm), V12 and V26 wait for the game.
- 2026-11-08, spec 011: batch 2, batch 6 and the pole item of batch 5 fixed with tests (a cave's continent map
  becomes the zone under the point; the subzone found by its name among the game's area names, walked over frames;
  the loot source of a catch is unknown, no pool part written; a secret name in a fight counts as missing and the
  skill check waits for the fight's end; the best pole within the Fishing skill). The `/run` checks before the code
  confirmed the zone under the cave and the area names (`docs/forever-api.md`).
