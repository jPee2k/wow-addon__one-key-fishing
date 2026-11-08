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
specs 002 to 006. Batches 3 and 4 were fixed by spec 009 and batch 1 by spec 010 on `002-shared-db` (release
1.2.0).

### Batch 2: where a catch is recorded (1.2.0, branch `002-shared-db`, before the first real harvest)

What the spike showed about places; every catch recorded before the fix keeps the wrong place, so it goes in before
`npm run harvest` builds the first seed.

- "Pool catches are written as open water" (medium; V3)
- "Catches in a cave go to the continent map" (medium; V2, V33)
- "The subzone of a cast is often not found" (medium; V34; needs a `/run` check of an ID-based source first)

Then: the `catch-catalog` steps 5 and 6. Markers: V3, V33, V34.

### Batch 5: small items (any time, with any of the above)

- "The next-rank advice reads a secret NPC name in a fight" (medium; a Lua error in instance fights)
- "A fishing pole above the Fishing skill may be chosen" (low)
- "A lure the game refused stays skipped after a skill-up" (low; waits for V43 / V44)
- "The private-table check reads only the plain form" (low; tooling)

## Open items

### Catches in a cave go to the continent map (medium)

- **Found**: in game, 2026-11-06 (V2, spike): in the cave before Wailing Caverns `C_Map.GetBestMapForUnit` gives
  Kalimdor 1414 (type 2, Continent), not The Barrens or a cave map.
- **Cause**: Forever has no map for the cave, and the best map falls back to the continent.
- **Where**: `CatchDB/CatchDB.lua` (the place key of a cast), the catalog and "What can be caught here" (a zone named
  "Kalimdor", a 100x100 cell grid over the whole continent).
- **Direction**: when the best map is of type Continent (or above), convert the position through
  `C_Map.GetWorldPosFromMapPos` and `C_Map.GetMapInfoAtPosition` / `GetMapPosFromWorldPos` to the zone map under it,
  checked in game first; or leave such casts out. Test: a continent map is never a place key.

### Pool catches are written as open water (medium)

- **Found**: in game, 2026-11-06 (V3, spike at Ratchet): a catch from an Oily Blackmouth School, the bobber in the
  pool, has the bobber (object 35591) as its loot source, like an open-water catch.
- **Cause**: `ns.IsPoolLoot` (`Catch/Catch.lua`) returns false (open water) when the source is the bobber; the
  assumed difference (the pool's own object ID) does not exist in Forever.
- **Where**: `Catch/Catch.lua` `ns.IsPoolLoot`, the pool counters of the catch database, the "Water" filter of
  "What can be caught here" and the catalog (catch-catalog step 9), the debug line "last catch from a pool".
- **Direction**: the fallback of V3: `ns.IsPoolLoot` returns nil always (no pool counters), the "Water" button stays
  hidden; drop the pool split from the record format later. Test: a bobber source gives nil.

### The subzone of a cast is often not found (medium)

- **Found**: in game, 2026-11-06, `/okf spike` (V34): at Stonebull Lake (Mulgore, map 1412) `GetSubZoneText()` is
  "Stonebull Lake", but `C_MapExplorationInfo.GetExploredAreaIDsAtPosition` at the player's position returns
  nothing at one spot and area 222 "Bloodhoof Village" a few steps away; in Thunder Bluff nothing. At Ratchet it
  works (area 392 "Ratchet", kept).
- **Cause**: the call returns the map's explored overlay regions (a region can be named after a nearby village),
  not the subzone the game shows, so the name never matches `GetSubZoneText()`.
- **Where**: `CatchDB/CatchDB.lua` (the area of a cast), the catalog's spot names ("Subzone (45, 72)").
- **Direction**: spots keep their coordinates (the fallback of FR-015, works today). Find an ID-based source of
  the area at a position (`C_Map.GetMapInfoAtPosition`, the area IDs of the map's explored overlays,
  `C_MapExplorationInfo.GetExploredMapTextures`), checked in game before any change.

### The next-rank advice reads a secret NPC name in a fight (medium)

- **Found**: in game, 2026-11-08, in a group in an instance, in a fight: a Lua error now and then (count 2)
  "Fishing/Skill.lua:54: attempt to compare local 'text' (a secret string value, while execution tainted by
  'OneKeyFishing')". Stack: the `CHAT_MSG_SKILL` handler, then `Check`, `Skill.GetNextRank`, `Where`, `NpcName`
  (line 111), then `NonEmpty` (line 54).
- **Cause**: `NpcName` reads the trainer's name from the first line of a creature tooltip
  (`C_TooltipInfo.GetHyperlink`). In a fight in an instance the client gives `leftText` as a secret value:
  `type` is `"string"`, but `text ~= ""` raises an error. The skill events of a fight (weapon and defense skill-ups
  fire `CHAT_MSG_SKILL` and `SKILL_LINES_CHANGED`) reach `Skill.GetNextRank`. That happens on every event while the
  "can learn" notice is not said yet: the skill is past `learnAt` but the character level is too low, so
  `done.now` stays unset. The name is cached only when it was read, so every such event reads the tooltip again.
- **Where**: `Fishing/Skill.lua` `NonEmpty`, `NpcName`, `Check`. The same `Skill.GetNextRank` runs for the minimap
  tooltip and the statistics window.
- **Direction**: `NonEmpty` returns nil for a secret value (`issecretvalue`, like the chat handlers of
  `Exchange/`). The advice then falls back to the name table for that call and reads the tooltip again later. Also
  `Check` can skip the advice in a fight (`InCombatLockdown()`): a notice is not needed there, and
  `PLAYER_REGEN_ENABLED` or the next skill event says it after the fight. Test: a secret `leftText` in the stub
  (`secret_values`) gives the table's name and no error; a skill event in a fight reads no tooltip.

### A fishing pole above the Fishing skill may be chosen (low)

- **Found**: specs/008-architecture-alignment research R5 (2026-11-06), not seen in game. The best pole is chosen
  by its Fishing bonus (`Fishing/Gear.lua` `Gear.FindBestPole`), whatever skill it needs (Strong Fishing Pole 10,
  Darkwood 50, Big Iron 100, Nat Pagle's 100, Arcanite 300).
- **Direction**: `GameData/FishingPoles.lua` already records each pole's `skill`; let the choice pass over a pole
  above `Skill.Get()` like the lures (`Fishing/Bags.lua` `FindLure`), with a test, once a player meets it.

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
