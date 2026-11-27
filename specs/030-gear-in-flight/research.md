# Research: Fishing Gear Waits for the Game's Swap (spec 030)

The facts the fix is built on: the client's own code, the add-on's code and the author's spike in game on
2026-11-27. The game facts are also in [docs/forever-api.md](../../docs/forever-api.md) ("Verified in game").

## R1 - The report and the first hypothesis

A player on 1.6.1: "It just deleted my weapon when swapping back out of fishing mode. I had plenty of bag space open
too." A second player read `Fishing/Gear.lua` (unchanged since 1.2.0) and suspected `RestoreSlots`: with a two-handed
pole it equips the main hand and at once the off hand, without waiting for the first swap; if the game refused the
off hand, it would stay in the bags, and nothing retries it.

**Read in the code**: true that nothing retries a slot whose swap never lands (`restoring` stays set, only the next
exit or login tries again), and that "Fishing mode OFF" prints before any answer. Nothing in the add-on can destroy an
item: no `DeleteCursorItem`; `UnequipToBags` runs only for slots that were empty before fishing.

**Tests could not see it**: the stub `C_Item.EquipItemByName` of `tests/wow.lua` equips nothing and the tests set
`inventory` by hand, so every swap "lands" at once or never; `owe_gear` models the off hand as a normal item, not
as the `equipped = false` record of a two-handed pole.

## R2 - The client export (build 1.60.1.70685)

- `Blizzard_FrameXML/Mainline/EquipmentManager.lua` (used by the Forever paper doll,
  `Blizzard_UIPanels_Game/Camelot/PaperDollFrame.lua`): before a swap Blizzard checks `IsInventoryItemLocked(invSlot)`
  and gives up when it is locked; it clears its own locks on `ITEM_UNLOCKED` (slot, or bag and slot).
- `ITEM_LOCK_CHANGED`, `ITEM_LOCKED`, `ITEM_UNLOCKED` (`ContainerDocumentation.lua`) and `PLAYER_EQUIPMENT_CHANGED`
  (`equipmentSlot`, `hasCurrent`; `PaperDollInfoDocumentation.lua`) are synchronous events.
- `C_Item.EquipItemByName(itemInfo, dstSlot)` returns nothing: a refusal is seen only through events or a later look
  at the slot.
- `C_EquipmentSet.UseEquipmentSet` swaps a whole set in one request (`EQUIPMENT_SWAP_FINISHED`), but needs a set of
  the player's: rejected, it would change the player's own equipment sets.

## R3 - The spike in game (2026-11-27)

Build 1.60.1.71139, a level 10 paladin, the Forsaken Maul 3269 (one-handed) and the Cracked Buckler 2212 (shield) in
hand, the Fishing Pole 6256 (two-handed) in the bags, "Leave fishing mode when attacked" on, add-on 1.7.1 unchanged.
Every chat command was counted (at most 255 characters).

The commands:

```
C0  /run OKM,OKO=GetInventoryItemID("player",16),GetInventoryItemID("player",17)print(OKM,OKO)
C1  /run local f=CreateFrame("Frame")OKFL=f f:SetScript("OnEvent",function(_,e,...)print(format("%.3f",GetTime()),e,...)end)for _,e in ipairs{"ITEM_LOCK_CHANGED","ITEM_UNLOCKED","PLAYER_EQUIPMENT_CHANGED","UI_ERROR_MESSAGE"}do f:RegisterEvent(e)end
C3  /run local n=0 for b=0,4 do local f,t=C_Container.GetContainerNumFreeSlots(b)if t==0 then n=n+f end end print("free",n)
C4  /run for _,id in ipairs{OKM,OKO}do print(id,C_Item.GetItemCount(id),C_Item.IsEquippedItem(id))end
```

| Step | Done | Seen |
|---|---|---|
| 1 | C0 | `3269 2212` |
| 2 | C1, `/okf toggle`, wait for the pole, `/okf toggle`, C4 | Entering: `ITEM_LOCK_CHANGED 1 1` at the call; 250 ms later `ITEM_LOCK_CHANGED 16`, `ITEM_UNLOCKED 16`, `PLAYER_EQUIPMENT_CHANGED 16 false`, `PLAYER_EQUIPMENT_CHANGED 17 true`. Leaving: in one frame 16 (lock, unlock, changed false) then 17 (lock, unlock, changed false). C4 `3269 1 true`, `2212 2 true`; no red text. **The off hand is not refused.** |
| 3 | `/run OneKeyFishing_ToggleMode()C_Timer.After(0.1,OneKeyFishing_ToggleMode)`, C4, `/okf debug` | "ON" and "OFF" at the same time; 170 ms later the pole swap's answer (16 changed false, 17 true). C4 `3269 1 false`, `2212 2 false`; debug "main hand: [Fishing Pole]", "pending restore: none". **B1: the weapons stay in the bags for good.** |
| 4 | `/run OneKeyFishing_ToggleMode()print("now",IsInventoryItemLocked(16),IsInventoryItemLocked(17))C_Timer.After(0.1,function()print("0.1",IsInventoryItemLocked(16),IsInventoryItemLocked(17))end)` | `now false false`, `0.1 false false`, then the answer 180 ms after the call. The slots are not locked while the swap is on its way. Leaving normally: both back. |
| 5 | Bags filled (C3 `free 0`), `/okf toggle`, C4, debug, `/okf toggle`, C4 | `ITEM_LOCK_CHANGED 1 1`, 155 ms later `ITEM_LOCK_CHANGED 1 1`, `ITEM_UNLOCKED 1 1`, `UI_ERROR_MESSAGE 3 Inventory is full.`; no `PLAYER_EQUIPMENT_CHANGED`. Mode on, "main hand: [Forsaken Maul]", "pending restore: slot 16 [Forsaken Maul] -> 6256", "slot 17 [Cracked Buckler] -> false". After leaving: both in hand. **B3: mode on without the pole, nothing lost.** |
| 6 | C3 `free 1`, `/okf toggle`, `/okf toggle`, C4 | Pole in hand; leaving: 16 then 17 in one frame; both in hand. One free slot is enough. |
| 7 | In the mode, `/run OneKeyFishing_ToggleMode()C_Timer.After(0.1,OneKeyFishing_ToggleMode)`, C4, debug, `/okf toggle`, C4 | "fishing mode: true", "main hand: [Forsaken Maul]", both pending records left. After leaving: both in hand. **B2: mode on with the weapon, nothing lost.** |
| 8 | In the mode, a fight | In the fight: mode paused, mace and shield in hand; after it "Fishing mode OFF", both in hand. |
| 9 | In the mode, cast, `/okf toggle` while the line is out, the channel ends | `ITEM_LOCK_CHANGED 0 10`, `1 3` at the restore; 190 ms later 16 then 17 in one frame; both in hand. |

## R4 - The cause

`Gear.Equip` and `RestoreSlots` judge a slot by `GetInventoryItemID` at the moment they run. Between a call and the
server's answer (R3 steps 2 to 4: 150 to 250 ms, longer with lag) the slot still holds the old item:

- **B1** (step 3): the restore after a fresh entry finds the old weapon in slot 16, not the pole, decides "the player
  changed this slot by hand" and drops the record; the off hand's record (`equipped = false`) is dropped too, as the
  shield is still there. The pole swap lands afterwards, and no record is left.
- **B2** (step 7): the entry after a fresh exit finds the pole still in slot 16 and asks for nothing; its records are
  kept (the `restoring` flags cleared), the restore lands, the mode is on with the weapon.
- **B3** (step 5): not a timing issue; the game refuses the pole when the off hand has nowhere to go.

How a player meets B1: two presses of the toggle key, an exit during a lag spike, or "Leave fishing mode when
attacked" with a mob that attacks right after entering.

## R5 - Rejected ways

| Way | Why not |
|---|---|
| Equip the off hand after the main hand's answer (the second player's idea) | The same-frame swap works (step 2); it would not touch B1 |
| `IsInventoryItemLocked` on the slot as "on its way" | Stays false while the swap is on its way (step 4) |
| The lock of the source bag slot | Tells which bag slot, not which equipment slot; other bag actions lock slots too |
| Retry counters and a "could not put back" warning | The failures seen are timing, not refusals; waiting for the answer covers them, and a refused swap changes nothing to put back |
| Off hand first at a fight's start | Today both weapons are back in the fight (step 8) |
| `C_EquipmentSet` | Changes the player's own sets (R2) |

## R6 - Decisions for the plan

**D1 - What counts as waiting.** Decision: a slot is waiting from the add-on's `C_Item.EquipItemByName` for it, or
from its move of the slot's item to the bags (`UnequipToBags`, a slot that was empty before fishing), until
`PLAYER_EQUIPMENT_CHANGED` for that slot; when a two-handed pole goes on and the off hand holds an item, slot 17
waits too (the game empties it in the same answer, R3 step 2). Rationale: the event is the game's own answer, per
slot, and the only one a swap brings (R3). Alternatives: `IsInventoryItemLocked` (false, step 4); `ITEM_UNLOCKED` of
the bag slot (names a bag slot, not the equipment slot).

**D2 - The end of a wait without an answer.** Decision: 5 seconds after the call the slot stops waiting. Rationale: a
refused swap sends no `PLAYER_EQUIPMENT_CHANGED` (step 5); 5 s is twenty times the answers seen, and a wait cut short
only brings back today's behaviour. Alternatives: `UI_ERROR_MESSAGE` (its text names no slot and other actions send
the same type); no limit (a refusal would block the gear for good).

**D3 - What waits.** Decision: `Gear.Equip`, `Gear.Restore` and `Gear.RestoreWeapons` neither judge nor call while a
slot they judge waits (`Gear.Equip` and the full restore: any slot; the weapons' restore: a weapon slot, so a hat the
game refused does not keep the weapons in the bags as a fight starts; code review, round 3); they queue themselves
and return. Rationale: B1 and B2 are both a judgement in the window. The combat
check stays first in `RestoreSlots` (a restore asked in the lockdown still sets `restoreAfterCombat`), the cast check
stays after the wait (it runs when the queued restore runs). Alternatives: wait only on exit (leaves B2).

**D4 - One queued action, the last one asked for.** Decision: one slot in memory: `equip` or `restore` with its scope.
An equip replaces anything; a restore replaces an equip; a restore asked while a restore is queued widens the scope
(all slots win over the weapons only). Rationale: the player's last press is what they want; the widening keeps a
full exit from shrinking to the weapons when a fight starts during the wait (`RestoreWeapons` at
`PLAYER_REGEN_DISABLED` while the mode is still on). Alternatives: run every request in order (enter, leave, enter
would swap three times).

**D5 - When the queued action runs.** Decision: on the frame after the last waiting slot is answered (`C_Timer.After(0)`)
or after the 5 s limit, and only if still wanted: an equip only while fishing mode is on and not leaving, a restore
only while it is off or leaving (the rule `OnCastEnd` already uses). Rationale: the answer for 16 arrives before the
one for 17 in the same frame (step 2); judging inside the first event would see 17 not yet changed. The check of the
mode covers a `/reload` or an exit that changed the wish.

**D6 - The room check on entry.** Decision: `Gear.HasRoomForPole()` is false only when the gear setting is on, the pole
`Gear.GetPole()` gives is two-handed (`INVTYPE_2HWEAPON`) and not in the main hand, the off hand holds an item and
the regular bags (`bagType == 0`, bags 0 to `NUM_BAG_SLOTS`) have no free slot. `Mode.Enter` asks it before
`Action.Enable`, prints the reason with the off-hand item's link and returns; nothing is enabled, equipped or
recorded. Rationale: step 5 (0 free: refused) and step 6 (1 free: works); a profession bag cannot take a shield.
Alternatives: enter and let the game refuse (B3, today); enter without the gear swap (a fishing mode without a pole).

**D7 - The text.** Decision: one new key, `"Fishing mode needs a free bag slot for %s."`, `%s` the off-hand item's
link (color outside the string, as the link brings its own). Nine translations in the same change.

**D8 - The debug line.** Decision: the Gear section of `/okf debug` gets one line, `swap in flight: <slots or none>,
queued: <equip | restore all | restore weapons | none>`, through `Gear.DebugState()`. Rationale: the checklist and a
future bug report see the wait. Not localized (the debug report never is).

No open question is left: no `NEEDS CLARIFICATION` in the plan.
