# Contract: fishing mode in a fight (`Fishing/Gear.lua`, `Fishing/Mode.lua`, `Fishing/Action.lua`)

"The lockdown" means `InCombatLockdown()` is true. It is still false in the `PLAYER_REGEN_DISABLED` handlers
(`docs/forever-api.md`, verified 2026-11-06).

## Gear

| # | Rule |
|---|---|
| C1 | While the lockdown is on, `Gear.RestoreWeapons`, `Gear.Restore` and the cast-end retry make no `C_Item.EquipItemByName` call and no unequip. `charDB.gearSwap` stays as it is. |
| C2 | A restore refused by C1 sets Gear's `restoreAfterCombat` (only while gear is owed). On `PLAYER_REGEN_ENABLED`, when fishing mode is not active, Gear does a full restore (every slot); any full restore outside the lockdown clears the flag. Gear owed for another reason (full bags, an item gone) is not retried after every fight (review: a plain `HasPendingRestore()` retry was tried and reverted). When the mode is active, Gear does nothing; Mode's handler owns that case (C5). |
| C3 | Outside the lockdown nothing changes: the "still ours" check, `restoring` until `PLAYER_EQUIPMENT_CHANGED`, the cast deferral (`deferredSlots`), and the unequip of slots that were empty. |
| C4 | `RestoreWeapons` in the `PLAYER_REGEN_DISABLED` handler (before the lockdown) still swaps the weapons (constitution 1.5.3 Principle III). |

## Mode

| # | Rule |
|---|---|
| C5 | `Mode.Exit` in the lockdown sets `pendingExit`, prints `L["Leaving fishing mode after combat."]` once (only when `pendingExit` was not set yet) and calls no Gear function. On `PLAYER_REGEN_ENABLED`, `pendingExit` leads to a full `Mode.Exit`: `Action.Disable`, `Gear.Restore`, `Camera.Restore`, the CVars, the "OFF" line and `MODE_CHANGED(false)`. |
| C6 | `PLAYER_REGEN_DISABLED` with the mode active and `settings.exitOnCombat` on sets `pendingExit`, calls `Gear.RestoreWeapons` and prints `L["Leaving fishing mode after combat."]` once. With the setting off, or the mode off, it prints nothing. |
| C7 | The lines of C5 and C6 set the key hint's time (`lastHint`). `OneKeyFishing_ActionKeyIdle` does not print again within 5 s of them. |
| C8 | `PLAYER_ENTERING_WORLD` + 1 s with gear owed and the mode not resumed calls `Gear.Restore` (C1/C2 handle the lockdown). Mode's own `restoreAfterCombat` is removed. |

## Action

| # | Rule |
|---|---|
| C9 | The owner's `_onstate-combat` snippet calls `self:ClearBindings()` when `tonumber(newstate) == 1`. The game's state driver sends the number `1` (research R1). In a fight the fishing key then runs its own binding, `OneKeyFishing_ActionKeyIdle`, which prints `L["The fishing key is paused in combat."]`, or the exit line while exiting. The snippet carries `-- VERIFY(V45)`. |
| C10 | `PLAYER_REGEN_ENABLED` with the mode on and not exiting calls `Action.Rebind()` (unchanged). The key casts again after the fight. |

## Messages

No new message. `MODE_CHANGED` fires as today: `true` on enter, `false` when the exit finishes, after the fight
when it was pending.
