# Checklist: the gear swap waits for the game's answer

**Feature**: fishing mode's gear swap waits for the game to answer a swap before it judges or changes a slot again,
and fishing mode does not turn on without room for the off-hand item
([specs/030-gear-in-flight](../../specs/030-gear-in-flight/spec.md)).

**Closes**: SC-001 (enter and leave 0.1 s apart keeps the gear), SC-002 (leave and enter 0.1 s apart equips the pole),
SC-003 (full bags keep the mode off), SC-004 (the paths that worked on 2026-11-27 still do), FR-007 in game, and
V83 ([verification](../../specs/030-gear-in-flight/verification.md)); the other game facts were seen in the spike of
2026-11-27 ([research](../../specs/030-gear-in-flight/research.md), R3).

**Needs**: one character with a one-handed weapon and an off-hand item (a shield or a second weapon), the two-handed
Fishing Pole in the bags, at least 2 free bag slots and things to fill them, a mob to fight, water.

## Setup

- [ ] `npm run install-addon` (or `npm run link` once), then `/reload` (no file was added to the TOC).
- [ ] Log in on the character, out of combat, fishing mode off, the weapon and the off-hand item in hand.
- [ ] The chat commands (each at most 255 characters, counted):

```
C0  /run OKM,OKO=GetInventoryItemID("player",16),GetInventoryItemID("player",17)print(OKM,OKO)
C1  /run local f=CreateFrame("Frame")OKFL=f f:SetScript("OnEvent",function(_,e,...)print(format("%.3f",GetTime()),e,...)end)for _,e in ipairs{"ITEM_LOCK_CHANGED","ITEM_UNLOCKED","PLAYER_EQUIPMENT_CHANGED","UI_ERROR_MESSAGE"}do f:RegisterEvent(e)end
C2  /run OKFL:UnregisterAllEvents()
C3  /run local n=0 for b=0,4 do local f,t=C_Container.GetContainerNumFreeSlots(b)if t==0 then n=n+f end end print("free",n)
C4  /run for _,id in ipairs{OKM,OKO}do print(id,C_Item.GetItemCount(id),C_Item.IsEquippedItem(id))end
C5  /run OneKeyFishing_ToggleMode()C_Timer.After(0.1,OneKeyFishing_ToggleMode)
C6  /run OneKeyFishing_ToggleMode()ReloadUI()
```

`ReloadUI` works only from a key press: called from a `C_Timer.After` callback the game blocks it ("Interface action
failed because of an AddOn"), so C6 reloads in the same frame as the entry, before the game answers.

- [ ] C0 in the normal gear prints two item IDs (the second not `nil`), then C1 (the event logger). After a `/reload`
  run C0 (in the normal gear) and C1 again.

## Steps

1. **Enter and leave 0.1 s apart** (SC-001; spike step 3, B1)
   - [ ] Fishing mode off: C5. Chat "ON" then "OFF"; a moment later C4 prints `true` for both items (in hand).
   - [ ] `/okf debug`, Gear section: "pending restore: none" and "swap in flight: none, queued: none".
   - [ ] C5 twice more: both items in hand each time.
2. **Leave and enter 0.1 s apart** (SC-002; spike step 7, B2)
   - [ ] Enter with `/okf toggle`, wait for the pole. C5: "OFF" then "ON"; a moment later the pole is in hand
     (`/okf debug`: "fishing pole: true").
   - [ ] `/okf toggle`: C4 prints `true` for both items.
3. **Full bags** (SC-003; spike step 5, B3)
   - [ ] Fill the bags until C3 prints `free 0` (the pole in a bag). `/okf toggle`: fishing mode stays off, the chat
     says "Fishing mode needs a free bag slot for [item]" with the off-hand item, no "Inventory is full.", nothing
     changes in hand, the logger prints nothing.
   - [ ] The main hand empty (the weapon left at the bank), the off-hand item worn, the bags still full (`free 0`):
     `/okf toggle` keeps the mode off with the same line. Then put the pole on by hand (drag it onto the main hand):
     does the game take it, with the off-hand item landing in the pole's freed bag slot, or refuse with "Inventory is
     full."? (V83, 2026-11-27: the game takes it; the room rule stays stricter there on purpose, see
     [verification](../../specs/030-gear-in-flight/verification.md))
4. **One free slot** (SC-004; spike step 6)
   - [ ] C3 prints `free 1`. `/okf toggle`: the pole in hand. `/okf toggle`: C4 prints `true` for both items.
5. **Enter, wait, leave** (SC-004; spike step 2)
   - [ ] `/okf toggle`, wait for the pole, `/okf toggle`: both items in hand, no red text.
   - [ ] Start summoning a mount (or another spell with a cast time) and press the toggle key during the cast: the
     mode turns on, and the pole goes on when the cast ends (code review, round 5: an equip asked during a cast was
     dropped by the game before).
6. **A fight** (SC-004; spike step 8; "Leave fishing mode when attacked" on)
   - [ ] In fishing mode, pull a mob: in the fight C4 prints `true` for both items; after it "Fishing mode OFF" and both
     still in hand.
   - [ ] A hat the game refuses (above the character's level) added to the fishing gear (Alt+Click): enter, wait for
     the pole, leave, and pull a mob within 5 seconds: the weapon and the off-hand item are back at the fight's start
     (code review, round 4: the hat's unanswered swap must not hold the weapons).
7. **Leave while the line is out** (SC-004; spike step 9)
   - [ ] In fishing mode, cast, `/okf toggle` while the bobber is out; when the channel ends both items are in hand.
8. **A `/reload` right after entering** (spec edge case)
   - [ ] Fishing mode off, not fishing: C6. After the reload the mode is back on with the pole (it was on at the logout);
     `/okf toggle`: both items in hand.
9. **Clean up**
   - [ ] C2.

## Results

- Date: 2026-11-27, client language: enUS with the Ukrainian interface, build 1.60.1 (71139); the working folder of
  `030-gear-in-flight`, a level 10 paladin with Carpenter's Mallet 1415, Cracked Buckler 2212 and the Fishing Pole.
- Every step passed:
  - Step 1: the restore was asked one frame after the pole's answer, and both items were back.
  - Step 2: the pole was asked again one frame after the restore's answer.
  - Step 3: no "Inventory is full." and no swap.
  - Step 5: the pole went on after the cast.
  - Step 6: the weapons came back at the fight's start; in the second box shoulders above the character's level
    were used, not a hat. The level refusal is `UI_ERROR_MESSAGE` 5, and the weapons came back at the fight's start
    while the wait for the shoulders still ran.
  - Step 7: the restore came after the channel's end.
  - Step 8: the mode resumed with the pole and both records.
  - The first box of step 5 is the same as step 4 and was not repeated.
- Problems found: none in the addon. The first C6 (`C_Timer.After(0.1,ReloadUI)`) was blocked by the game and is
  replaced. A `/reload` made while fishing left the resumed mode's equip waiting for the channel's end
  (`/okf debug` "queued: equip"), as designed.

What the checklist confirms is in `docs/forever-api.md`; V83 is closed in
[verification.md](../../specs/030-gear-in-flight/verification.md) and its marker removed from `Fishing/Gear.lua`.
