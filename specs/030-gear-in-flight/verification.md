# Verification: Fishing Gear Waits for the Game's Swap

The code built on assumptions only the game can confirm carries `-- VERIFY(<id>): <what>`; the IDs continue the V
series (V82 was spec 029's; this spec has V83). A marker is removed after the author confirms the behaviour in game,
or when the author accepts the assumption without a check (the row then says "Accepted" and what happens if it is
wrong).

Already seen in game, no marker (the spike of 2026-11-27, [research.md](research.md) R3): the answer of a swap
150 to 250 ms after the call; the main hand and the off hand asked in one frame are both done and answered in one
frame; `PLAYER_EQUIPMENT_CHANGED`'s second value; the equipment slots not locked while a swap is on its way; a
refused swap ("Inventory is full.") sends no `PLAYER_EQUIPMENT_CHANGED`; one free bag slot is enough with a filled
main hand.

To close an item: run its check, record the answer in `docs/forever-api.md`, adjust the code if the game differs (with
a test), remove the marker.

| ID | What is assumed | Where | If wrong | Check | Status |
|---|---|---|---|---|---|
| V83 | With the main hand empty, an off-hand item worn and 0 free regular bag slots, the game still refuses the two-handed pole (the off-hand item does not take the pole's freed bag slot) | `Fishing/Gear.lua` (`Gear.HasRoomForPole`) | Fishing mode stays off in a case where the swap would work (no item at risk); then the room rule counts the pole's own bag slot when the main hand is empty | [docs/checklists/gear-swap.md](../../docs/checklists/gear-swap.md), step 3, second box: the main hand empty, the bags full, the pole put on by hand | **Checked, the assumption is wrong; the rule is kept** 2026-11-27 (build 71139, Carpenter's Mallet 1415 in a bag, Cracked Buckler 2212 worn, `free 0`): `/okf toggle` kept the mode off with the line; the pole dragged onto the main hand by hand was taken, the shield went into the pole's freed bag slot (`PLAYER_EQUIPMENT_CHANGED 16 false`, `17 true`). The author kept the stricter rule: the case is rare, nothing is lost, the player frees one slot; relaxing it would make the exit's restore (slots in ascending order) look for a bag slot for the pole first and print a needless "No free bag space" line, and the drag by hand is not the `C_Item.EquipItemByName` call the addon makes; marker removed |
