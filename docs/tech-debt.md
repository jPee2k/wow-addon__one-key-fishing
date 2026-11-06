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
- **Where**: `Core/MapPin.lua` `MapPin.Set` (the next-rank Pin button and minimap menu entry, released in 1.1.0)
  and `UI/CatalogTab.lua` `CatalogTab.Pin` (the catalog, not released); markers `VERIFY(R14)` and `VERIFY(V32)`.
- **Direction**: the fallback of V32: set the pin and the arrow, do not open the map; the toast and the manual say
  to open the map to see the pin. Tests: no `OpenWorldMap` call from either pin. Then the manual, `CHANGELOG.md`
  (Fixed), FR-022 of spec 001 and FR-011 of spec 005, and a 1.1.x patch for the release.

### Leaving fishing mode in a fight raises "Interface action failed" (medium)

- **Found**: in game, 2026-11-06, release 1.1.0: in the mode, a fight, the toggle key: "Interface action failed
  because of an AddOn" and "Leaving fishing mode after combat."; after the fight the mode ends and the gear comes
  back.
- **Cause**: `taint.log`: "An action was blocked in combat because of taint from OneKeyFishing - EquipItemByName()"
  from `Gear.lua` `RestoreSlots` <- `RestoreWeapons` <- `Mode.Exit` (`InCombatLockdown()` branch) <-
  `OneKeyFishing_ToggleMode`. `C_Item.EquipItemByName` is protected in combat, weapons too; the swap on an attack
  works only because `PLAYER_REGEN_DISABLED` runs before the lockdown. CLAUDE.md and `fishing-mode.md` say weapons
  can be swapped in combat: wrong.
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

### A lure above the Fishing skill is offered until it fails (low)

- **Found**: in game, 2026-11-06, release 1.1.0 (the author): a lure in the bags that needs more Fishing skill
  is offered by the indicator and the key for a few seconds (up to 5), the game refuses it, and only then is it
  skipped (until fishing mode is entered again). The checklist step "Lure too high" passed this way.
- **Cause**: `Fishing/Bags.lua` `FindLure` treats a lure as usable when `C_Item.IsUsableItem` says so, and that is
  true for a lure above the skill; the attempt is only counted as failed later (`LURE_FAIL_DELAY`).
- **Direction** (the author's wish): never offer a lure until the character's Fishing skill reaches the lure's
  requirement. Keep the required skill per lure by ID with the lure list (it moves to `GameData/` in 1.2.0,
  `docs/release-plan.md`), take the values from the original game and mark them `VERIFY` until each is seen in
  game, and let `FindLure` skip a lure above `Skill.Get()`. The failure path stays for anything the table misses.
  Tests: a lure above the skill is never offered; one at the skill is.

### No chat line when an attack ends fishing mode (low)

- **Found**: in game, 2026-11-06: with "Leave fishing mode when attacked" on, an attack swaps the weapons back
  without any line; the checklist expected one. `PLAYER_REGEN_DISABLED` in `Fishing/Mode.lua` prints nothing; the
  line comes only when a key is pressed.
- **Direction**: print "Leaving fishing mode after combat." once on the attack (and test it), or change the
  checklist's expectation. The author decides.

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
