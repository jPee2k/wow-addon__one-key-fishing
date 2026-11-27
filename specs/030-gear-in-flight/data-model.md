# Data Model: Fishing Gear Waits for the Game's Swap

## Saved: the gear swap record (unchanged)

`OneKeyFishingCharDB.gearSwap[slot] = { previous = <item link or false>, equipped = <itemID or false>, restoring = true? }`
([docs/architecture/core.md](../../docs/architecture/core.md)). Same fields, same writers, same meaning. The fix only
changes *when* `RestoreSlots` and `Gear.Equip` read and write it: never while a slot waits. No `DB_SCHEMA` change.

## In memory: the waiting slots (`Fishing/Gear.lua`, local)

`waiting[slot] = <GetTime() at which the wait ends>`

"Waiting" is the same as "in flight" (the branch name and the debug line "swap in flight"): a swap the addon asked
for that the game has not answered yet.

| Event | Change |
|---|---|
| Gear asks the game to swap `slot` (`C_Item.EquipItemByName`) | `waiting[slot] = now + 5` |
| Gear equips a two-handed pole while slot 17 holds an item | also `waiting[17] = now + 5` |
| Gear moves an item of a slot that was empty before fishing to the bags (`UnequipToBags`) | `waiting[slot] = now + 5` |
| `PLAYER_EQUIPMENT_CHANGED(slot)` | `waiting[slot] = nil` |
| A read after `now` passed the slot's time (no answer: refused) | `waiting[slot] = nil` |
| `/reload`, logout | lost (the records are saved; the login restore runs after the answer) |

"A slot waits" = `waiting` has an entry whose time has not passed. An equip and a full restore wait for any slot; a
restore of the weapons only for the weapon slots.

## In memory: the queued action (`Fishing/Gear.lua`, local)

`queued = nil | { kind = "equip" } | { kind = "restore", slots = <nil = all | set of slots> }`

| Asked while a slot waits | Queued before | Queued after |
|---|---|---|
| `Gear.Equip` | anything | `equip` |
| `Gear.Restore` | none or `equip` | `restore`, all |
| `Gear.Restore` | `restore` (any scope) | `restore`, all |
| `Gear.RestoreWeapons` | none or `equip` | `restore`, weapons |
| `Gear.RestoreWeapons` | `restore`, all | `restore`, all (wider scope kept) |
| `Gear.RestoreWeapons` | `restore`, weapons | `restore`, weapons |

Asked while no slot waits: the action runs at once, as today, and clears `queued`.

## Running the queued action

```text
answer or time limit -> none of its slots waits? -> next frame -> still none? -> take queued, set it nil
  equip:   in the lockdown                         -> stays queued; Gear's PLAYER_REGEN_ENABLED settles it again
           fishing mode on, not leaving, gear on   -> Gear.HasRoomForPole()? Gear.Equip() : the chat line (else dropped)
  restore: fishing mode off, or on and leaving     -> RestoreSlots(scope)   (else dropped)
```

`RestoreSlots` keeps its own order: the combat lockdown first (`restoreAfterCombat`), then the wait, then the cast
(`deferredSlots`), then the slots.

## The room check (`Gear.HasRoomForPole()`)

False only when all hold: the gear setting is on; `Gear.GetPole()` gives a pole; its equip location is
`INVTYPE_2HWEAPON`; it is not the main hand's item; slot 17 holds an item; the free slots of the regular bags
(`bagType == 0`, bags 0 to `NUM_BAG_SLOTS`) sum to 0. Returns also the off-hand item's link for the message.
