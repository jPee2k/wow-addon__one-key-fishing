# Quickstart: Fishing Gear Waits for the Game's Swap

## Automated

```sh
npm run check
npm test
```

`tests/fishing/gear_in_flight_test.lua` (new). The stub `C_Item.EquipItemByName` records calls and changes nothing;
the test lands a swap by setting `inventory[slot]` and firing `PLAYER_EQUIPMENT_CHANGED(slot, empty)`, the way the
game answered in the spike ([research.md](research.md) R3). A one-handed weapon in 16, a shield in 17, a
two-handed pole in the bags.

| Test | Proves | Fails on 1.7.1 |
|---|---|---|
| Enter, leave before the answer, then the answer | B1: the records are kept; after the answer the weapon and the shield are asked for (16 and 17) | yes |
| Leave, enter before the answer, then the answer | B2: after the answer the pole is asked for | yes |
| Enter, leave, enter before any answer | only the last wish runs: the pole, once | yes |
| Two answers in one frame (16, then 17) | the queued restore runs on the next frame, once, and sees 17 empty | yes |
| No answer (refused swap) | after 5 s the queued action runs with today's rules; nothing before | yes |
| A fight starts while a restore is queued | the lockdown wins: nothing in the fight, the restore after it | yes |
| `RestoreWeapons` while a full restore is queued | the full restore stays full | yes |
| Leave (a hat goes back to the bags), enter before that answer | the hat is asked for once after the answer | yes |
| Full bags, off-hand item, two-handed pole in the bags | `Mode.Enter` leaves the mode off, no equip call, the chat line once | yes |
| The resume after `/reload` with full bags | the mode stays off, the chat line once, the login restore runs | yes |
| 1 free slot; pole already in hand; gear setting off; no off-hand item | the mode enters as before | no |
| No slot waiting | every existing gear path asks the same calls as before | no (`gear_combat_test.lua`, `gear_pole_test.lua` unchanged) |

## In game

New checklist `docs/checklists/gear-swap.md`, built on the spike (research R3), with the event logger `C1` and the
item check `C4` of R3. Needs: a character with a one-handed weapon and an off-hand item, a two-handed Fishing Pole in
the bags, a mob, bags that can be filled.

| Step | Spike step | Expected after the fix |
|---|---|---|
| Enter and leave 0.1 s apart, 3 times | 3 | weapon and off hand in hand each time (SC-001); debug "swap in flight: none, queued: none" |
| Leave and enter 0.1 s apart | 7 | pole in hand; the next exit brings the gear back (SC-002) |
| Full bags, enter | 5 | mode off, the chat line names the off-hand item, nothing equipped (SC-003) |
| Enter, wait, leave | 2 | as on 2026-11-27 (SC-004) |
| 1 free slot | 6 | as on 2026-11-27 |
| A fight in fishing mode | 8 | as on 2026-11-27 |
| Leave while the line is out | 9 | as on 2026-11-27 |
| `/reload` 0.1 s after entering, then leave | new | the gear comes back (the records survive the reload) |
