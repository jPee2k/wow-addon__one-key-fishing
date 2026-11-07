# Data Model: Pin and Combat Fixes

No saved field changes (`DB_SCHEMA` stays). This page lists the session state that changes, the visible texts and
the test stubs.

## Saved data (unchanged)

| Field | Owner | Role in this fix |
|---|---|---|
| `charDB.gearSwap[slot] = { previous, equipped, restoring }` | `Fishing/Gear.lua` | Written before a change, kept until the swap lands (`PLAYER_EQUIPMENT_CHANGED`). In the lockdown it is left as it is, so the restore after the fight and a logout in a fight still find it |
| `charDB.pin = { mapID, x, y }` | `Core/MapPin.lua` | Unchanged: the addon's last pin, replaced without asking |
| `charDB.savedCVars`, `charDB.resumeMode` | `Fishing/Mode.lua` | Unchanged |

## Session state

### Gear (`Fishing/Gear.lua`)

| State | Meaning | Set | Cleared |
|---|---|---|---|
| `deferredSlots` (unchanged) | a restore waits for the current cast to end (`true` = all slots, or a slot set) | `RestoreSlots` while casting | `OnCastEnd` |
| `restoreAfterCombat` (new, moved from Mode) | a restore the lockdown refused waits for the fight to end | `RestoreSlots` while `InCombatLockdown()` and gear is owed | any full restore outside the lockdown (Gear's `PLAYER_REGEN_ENABLED` when the mode is not active, or `Mode.Exit`) |

Rule: `RestoreSlots` makes no `C_Item.EquipItemByName` call and no unequip while `InCombatLockdown()` is true
(contracts/combat.md C1).

### Mode (`Fishing/Mode.lua`)

| State | Change |
|---|---|
| `pendingExit` | unchanged meaning; `Mode.Exit` in the lockdown sets it without a gear call |
| `restoreAfterCombat` | removed (Gear owns it, research R3) |
| `lastHint` | also set by the attack line and the in-fight toggle line (R4) |

Fishing mode in a fight:

```text
on ──PLAYER_REGEN_DISABLED, exitOnCombat──> exiting   (weapons swapped before the lockdown, one line)
on ──toggle key in the lockdown──────────> exiting   (no gear call, one line)
on ──PLAYER_REGEN_DISABLED, setting off──> on        (key overrides cleared by the secure handler, no line)
exiting ──toggle key──────────────────────> exiting   (nothing)
exiting ──PLAYER_REGEN_ENABLED────────────> off       (Mode.Exit: gear, camera, CVars, "OFF" line)
on ──PLAYER_REGEN_ENABLED─────────────────> on        (Action.Rebind)
off, gear owed ──PLAYER_REGEN_ENABLED─────> off       (Gear: full restore)
```

### Action (`Fishing/Action.lua`)

| State | Change |
|---|---|
| the owner's `state-combat` attribute | set by the game's state driver to the number `1` in a fight, `0` outside; the `_onstate-combat` snippet clears the overrides when `tonumber(newstate) == 1` |

## Visible texts

| Key | Where | Change |
|---|---|---|
| `"Map pin: %s. Open the world map to see it."` | `UI/Toast.lua` (`MAP_PIN_SET` with a place) | new; `enUS.lua` plus nine translations |
| `"Map pin: %s"` | — | removed from `enUS.lua` and the nine translations (no other user) |
| `"Leaving fishing mode after combat."` | `Fishing/Mode.lua` | existing; now also on the attack |
| `"The fishing key is paused in combat."` | `Fishing/Mode.lua` (`OneKeyFishing_ActionKeyIdle`) | existing; now reached in a fight (R1) |

## Test stubs (`tests/wow.lua`)

Each new stub is listed in the header of `tests/wow.lua`.

| Stub | Purpose |
|---|---|
| `equip_calls` (read): `{ item, slot }` for each `C_Item.EquipItemByName` call | no equip in the lockdown; the restore after the fight |
| `inventory[slot] = itemID`: `GetInventoryItemID("player", slot)` | the "still ours" check of `RestoreSlots` |
| `Frame:SetAttribute` / `Frame:GetAttribute` storage (if `NewFrame` has none) | read the `_onstate-combat` snippet of `OneKeyFishingBindingOwner` |
| `override_bindings[owner][key] = action` with `SetOverrideBinding`, `SetOverrideBindingClick` and `ClearOverrideBindings` | the snippet clears the overrides; the key falls back to its binding |
| `channel_info = { ... }`: `UnitChannelInfo("player")` (if a test needs a cast in progress) | path 2 of R2 |
| `known_spells[spellID] = true`: `IsSpellKnown` | `ns.GetFishingSpellID()` answers, so `Mode.Enter` works in a test |
| helpers `enter_fishing_mode()`, `owe_gear()`, `chat_count(text)` | enter the mode without a gear swap; owed gear in slots 16, 17 and 1; count the chat lines that contain a text (each line carries the addon's prefix) |

The snippet test runs the snippet text with `loadstring` in a small environment (`self` with `ClearBindings`,
`tonumber`, `newstate`), as the restricted environment would run it.
