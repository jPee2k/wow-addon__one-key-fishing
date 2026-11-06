# Technical debt

Known issues that are not fixed yet, with the reason they matter and a suggested direction. Each item says where
it was found and how serious it is. Remove an item when it is fixed (with a test), or move it to the spec of the
feature that takes it on.

Severity: **high** loses data or cuts off honest players; **medium** wrong state or wasted traffic; **low**
cleanup, no wrong behaviour.

## Open items

### The map pin opens the world map, and the map then fails in a fight (high)

- **Found**: in game, 2026-11-06, release 1.1.0, enUS client: `/okf stats` -> Pin (the map opens), close the map,
  a fight, open the map with M: "Interface action failed because of an AddOn". Without pressing Pin first, no
  such line.
- **Cause**: `Logs/taint.log` (`/console taintLog 1`): "Execution tainted by OneKeyFishing while reading field
  targetScrollY" (`Blizzard_MapCanvas/MapCanvas_ScrollContainerMixin.lua:445`), then "An action was blocked in
  combat because of taint from OneKeyFishing - Button:SetPassThroughButtons()" while the map adds its quest pins
  (`QuestDataProvider.lua:194`). The field is written by `OpenWorldMap(mapID)` called from addon code. The pin
  (`C_Map.SetUserWaypoint`) and the arrow (`C_SuperTrack.SetSuperTrackedUserWaypoint`) do not show in the log.
- **Where**: `Core/MapPin.lua` `MapPin.Set`, every pin of the addon: the next-rank Pin button and minimap menu
  entry (released in 1.1.0) and the catalog's pin buttons (not released, through `MapPin` since spec 008); marker
  `VERIFY(R14)`.
- **Direction**: the fallback of V32: set the pin and the arrow, do not open the map; the toast and the manual say
  to open the map to see the pin. Tests: no `OpenWorldMap` call from `MapPin.Set`. Then the manual, `CHANGELOG.md`
  (Fixed), FR-022 of spec 001 and FR-011 of spec 005, and a 1.1.x patch for the release.

### Leaving fishing mode in a fight raises "Interface action failed" (medium)

- **Found**: in game, 2026-11-06, release 1.1.0: in the mode, a fight, the toggle key: "Interface action failed
  because of an AddOn" and "Leaving fishing mode after combat."; after the fight the mode ends and the gear comes
  back.
- **Cause**: `taint.log`: "An action was blocked in combat because of taint from OneKeyFishing - EquipItemByName()"
  from `Gear.lua` `RestoreSlots` <- `RestoreWeapons` <- `Mode.Exit` (`InCombatLockdown()` branch) <-
  `OneKeyFishing_ToggleMode`. `C_Item.EquipItemByName` is protected in combat, weapons too; the swap on an attack
  works only because `PLAYER_REGEN_DISABLED` runs before the lockdown. The constitution (Principle III,
  "weapons return at once") and `fishing-mode.md` say weapons can be swapped in combat: wrong.
- **Where**: `Fishing/Mode.lua` `Mode.Exit`, `Fishing/Gear.lua` `RestoreWeapons` / `RestoreSlots`.
- **Direction**: in the lockdown only set the pending exit and say so; no `EquipItemByName` until
  `PLAYER_REGEN_ENABLED`. Test: `Mode.Exit` with `in_combat` calls no equip. Fix the docs' claim.

### The fishing key keeps its cast in a fight (low)

- **Found**: in game, 2026-11-06, release 1.1.0, "Leave fishing mode when attacked" off: the fishing key pressed in
  a fight gives the game's "can't do that in combat" and no "The fishing key is paused in combat." line.
- **Cause (to confirm)**: the `[combat]` state driver of `Fishing/Action.lua` should clear the override bindings, so
  the key falls back to its own binding (`OneKeyFishing_ActionKeyIdle`); the game's message says the key still
  clicked the secure cast button. Nothing wrong happens (the game refuses the cast), only the addon's line is
  missing. Check in game with `/run print(GetBindingAction("<key>", true))` in a fight.
- **Direction**: find why `ClearBindings` in `_onstate-combat` does not drop the overrides (owner, timing); a test
  of the state handler if the stubs allow it.

### No chat line when an attack ends fishing mode (low)

- **Found**: in game, 2026-11-06: with "Leave fishing mode when attacked" on, an attack swaps the weapons back
  without any line; the checklist expected one. `PLAYER_REGEN_DISABLED` in `Fishing/Mode.lua` prints nothing; the
  line comes only when a key is pressed.
- **Direction**: print "Leaving fishing mode after combat." once on the attack (and test it), or change the
  checklist's expectation. The author decides.

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
