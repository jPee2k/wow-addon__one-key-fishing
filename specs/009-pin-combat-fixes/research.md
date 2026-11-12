# Research: Pin and Combat Fixes

The facts come from `docs/forever-api.md` "Verified in game" (2026-11-06/07), the `taint.log` evidence in
`docs/tech-debt.md`, and the client's own code in the author's export (build 70685,
`BlizzardInterfaceCode/Interface/AddOns/Blizzard_RestrictedAddOnEnvironment/`, read 2026-11-07).

## R1. Why the fishing key keeps its cast in a fight

**Finding**: the combat handler of `Fishing/Action.lua` never clears the overrides.

- `SecureStateDriver.lua` `resolveDriver` turns every state value into a number when it can:
  `newValue = tonumber(newValue) or newValue`. So `"[combat] 1; 0"` sets the attribute `state-combat` to the
  number `1`.
- `SecureHandlers.lua` `SecureHandler_StateOnAttributeChanged` passes that value unchanged to the snippet as
  `newstate`.
- The snippet tests `if newstate == "1" then`. In Lua, `1 == "1"` is false, so `self:ClearBindings()` never runs.
- `RestrictedFrames.lua` `HANDLE:ClearBindings()` is `ClearOverrideBindings(frame)`. It would clear the overrides
  the insecure code set with the same owner, so the owner is not the problem.

This explains what the game showed (2026-11-06): in a fight the key still clicks the secure cast button, the game
refuses the cast ("can't do that in combat"), and `OneKeyFishing_ActionKeyIdle` (the key's own binding body) never
runs, so "The fishing key is paused in combat." never shows. The documents that say "the overrides are dropped
inside combat" (`docs/architecture/fishing-mode.md`, the comments of `Action.lua` and `Mode.lua`) describe the
intent, not the behaviour.

**Decision**: compare the number. The snippet becomes `if tonumber(newstate) == 1 then self:ClearBindings() end`.
`tonumber` is in the restricted environment (`RestrictedEnvironment.lua`), and it also accepts a string `"1"` if a
client ever passes one. Nothing else changes: `PLAYER_REGEN_ENABLED` already calls `Action.Rebind()` while the mode
is on, and `Rebind` refuses in the lockdown.

**The in-game check** (`docs/tech-debt.md`): `/run print(GetBindingAction("<key>", true))` in a fight. It is the
first step of `fishing-mode.md` section 1, run after the implementation (the author's order): it prints
`ONEKEYFISHING_ACTION`. On a build from before the fix it would print `CLICK OneKeyFishingButton:LeftButton`; that
run is optional and not planned. The cause is read from the client's code, not seen in game,
so the change carries `VERIFY(V45)` (`verification.md`) until the author runs the step (spec FR-011, FR-015).

**Effects of the fix, by design**: in a fight, the hook (`INTERACTTARGET`) is cleared too, so a bobber still out
cannot be hooked until the fight ends. Fishing mode was always meant to pause in a fight (the manual's "The fishing
key is paused in combat").

**Alternatives considered**:
- Wrap the button's `OnClick` with a secure pre-body that returns `false` in a fight. It stops the click but prints
  nothing (the press never reaches insecure code), so the spec's line would still be missing. Rejected.
- Guard the insecure `BindCast` / `BindInteract` with `UnitAffectingCombat` against a rebind between the state
  driver and the lockdown. That race is not seen and the R1 cause explains the finding fully. Not done; the in-game
  step after the fix would show it (the key still clicks in a fight).

## R2. When equipping is still allowed in a fight

**Facts** (`docs/forever-api.md`, verified 2026-11-06):
- `C_Item.EquipItemByName` from addon code is blocked in the lockdown, weapons too.
- In the `PLAYER_REGEN_DISABLED` handler it still works, because `InCombatLockdown()` is still false there.

**Decision**: one rule inside `Gear`. `RestoreSlots` returns without any equip or unequip call while
`InCombatLockdown()` is true, and remembers the restore for the end of the fight. The weapon swap of
`PLAYER_REGEN_DISABLED` (`Mode.lua`) keeps running before the lockdown and needs no special case: the rule tests
the lockdown, not "in a fight".

**Paths that called it in the lockdown** (each gets a test):

1. `Mode.Exit` in the lockdown -> `Gear.RestoreWeapons` (the in-game finding, toggle key in a fight).
2. `OnCastEnd` (`Gear.lua`) in the lockdown -> `RestoreSlots(WEAPON_SLOTS)`. This happens when the attack came
   while channeling: the pre-lockdown swap was deferred because equipping fails while casting, and the channel's end
   arrives in the lockdown.
3. `PLAYER_ENTERING_WORLD` + 1 s in the lockdown with a pending restore -> `Gear.RestoreWeapons` (`Mode.lua`).

**Alternatives considered**: keep the call sites and add `InCombatLockdown()` checks at each. That makes three places
to keep in step, and the next caller can forget it. Rejected for one guard in `RestoreSlots`.

## R3. Who finishes a restore after the fight

**Today**:
- Mode finishes a pending exit on `PLAYER_REGEN_ENABLED` (`Mode.Exit` -> `Gear.Restore`).
- Mode keeps `restoreAfterCombat` for the login path.
- A restore deferred by a cast that ends in the lockdown (path 2 with the mode already off) is lost until the next
  restore call.

**Decision**: Gear keeps one session flag, `restoreAfterCombat`, set when `RestoreSlots` is refused by the lockdown.
Gear's own `PLAYER_REGEN_ENABLED` handler finishes it with a full restore when fishing mode is not active. When the
mode is active (on, or exiting), Mode's handler owns the end of the fight: `Mode.Exit` calls `Gear.Restore` for a
pending exit, and a mode that stays on keeps its gear. Mode's own `restoreAfterCombat` goes.

**Review note** (2026-11-07): replacing the flag with `Gear.HasPendingRestore()` was tried and reverted. It retried
every owed swap after every fight (a "No free bag space" line after each fight, a fishing item the player put back
on taken off again), not only the restore the lockdown refused.

**Order**: `Gear.lua` is earlier in the TOC than `Mode.lua`, so Gear's handler runs first. It does nothing while
`Mode.IsActive()`, so no slot gets two equip calls. A restore that is still refused (a cast still running after the
fight) falls back to the existing `deferredSlots` path.

**Alternatives considered**: keep the flag in Mode and add path 2 there. Then Mode would track Gear's cast deferral.
Rejected: the gear owns its restore state.

## R4. The attack line and the hint pause

**Decision**: the attack branch of `PLAYER_REGEN_DISABLED` (mode active, `exitOnCombat` on) prints
`L["Leaving fishing mode after combat."]`. This is the existing key, already in nine translations (the author's
choice, spec US3). It sets `lastHint = GetTime()`, so a fishing-key press within 5 s does not repeat it through
`OneKeyFishing_ActionKeyIdle`.

`Mode.Exit` in the lockdown keeps printing the same line once, through `pendingExit`. After an attack, `pendingExit`
is already set, so the toggle key adds nothing (spec US2 scenario 3). The toggle line also sets `lastHint`.

The line is printed in the handler that runs before the lockdown. Printing is not protected, so this is only the
natural place.

**Alternatives considered**: a toast as well. Not asked for; the indicator and the chat are where the mode talks.

## R5. The map pin without the map

**Decision**:
- Remove the `OpenWorldMap(target.mapID)` block of `MapPin.Set`, the fallback written in R14 / V32 before the change.
- Keep `C_Map.SetUserWaypoint` and `C_SuperTrack.SetSuperTrackedUserWaypoint(true)`. Neither shows in `taint.log`,
  and the tracking gives the minimap's edge arrow (V31).
- The toast text becomes a new key, `"Map pin: %s. Open the world map to see it."`. It replaces `"Map pin: %s"`,
  which has no other user, in `enUS.lua` and all nine translations.
- `VERIFY(R14)` stays on `MapPin.Set` with the new assumption: "a pin set without opening the map leaves the map
  untainted for a later fight". It is removed when `interface-language.md` section 10 passes.
- `OpenWorldMap` leaves `.luacheckrc` `read_globals`, and the test stub `world_maps_opened` stays so the test can
  prove that the map is not opened.

The chat map link is not touched. The game's own handler opens the map there, and the game showed no blocked action
afterwards.

**Alternatives considered**:
- Open the map through `C_Map.OpenWorldMap`: it has restrictions (`HasRestrictions`). Rejected.
- `ToggleWorldMap()`: it is the same insecure FrameXML path as `OpenWorldMap`, with the same taint of the map
  canvas. Rejected.
- Show the toast elsewhere: with the map closed it is no longer covered.

## R6. The manual and the changelog

**Decision**:
- `OneKeyFishing/README.md`:
  - The next-rank part (line ~220) says: "the game's map pin, with the minimap's arrow, marks the seller or the
    quest giver; open the world map to see it".
  - The catalog part (line ~152) drops "and opens the world map at that zone (not in combat)".
  - The arrow sentence stays: "The arrow on screen depends on the game's navigation setting".
  - "Safe in combat" (line 64) says: "when attacked (with 'Leave fishing mode when attacked' on), the weapons come
    back at once and fishing mode ends after the fight; in a fight the fishing key pauses".
- `CHANGELOG.md` `[Unreleased]` "Fixed" (1.1.0 released the pin and the combat behaviour):
  - the map no longer breaks in a fight after a map pin, and the pin does not open it;
  - leaving fishing mode in a fight no longer raises "Interface action failed";
  - the fishing key pauses in a fight;
  - an attack says that fishing mode ends after the fight.
  The 1.1.0 entry stays as released.
- The unreleased catalog pins need no line of their own.

Constitution: the hidden `showInGameNavigation` CVar stays untouched (Principle III: only what the addon changed is
restored, and the addon does not change it).
