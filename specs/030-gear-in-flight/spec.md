# Fix Specification: Fishing Gear Waits for the Game's Swap

**Feature Branch**: `030-gear-in-flight` (off `develop`)

**Created**: 2026-11-27

**Status**: Draft; the cause reproduced in game on 2026-11-27 (spike below)

**Input**: A player's report on 1.6.1: "It just deleted my weapon when swapping back out of fishing mode. I had plenty
of bag space open too." A second player read `Fishing/Gear.lua` and suspected the off hand: the restore equips the
main hand and the off hand in the same moment without waiting for the first swap. The author's spike did not confirm
that, and found the real cause: a swap still on its way to the server.

A short spec: no message on the bus, no saved field, one translated text. Released alone as 1.7.2.

## What is known (spike of 2026-11-27)

The author's checks in game, build 1.60.1.71139, a level 10 paladin with a one-handed mace and a shield, the
two-handed Fishing Pole in the bags, an event logger on `ITEM_LOCK_CHANGED`, `ITEM_UNLOCKED`,
`PLAYER_EQUIPMENT_CHANGED` and `UI_ERROR_MESSAGE`:

| Step | What was done | What happened |
|---|---|---|
| 2 | Enter, wait for the pole, leave | Both back in hand; the server confirmed the main hand and the off hand in one frame, in order. The off hand is **not** refused |
| 3 | Enter and leave 0.1 s apart (`/run OneKeyFishing_ToggleMode()C_Timer.After(0.1,OneKeyFishing_ToggleMode)`) | **Bug B1**: chat "ON" then "OFF"; the pole swap landed afterwards; pole in hand, mace and shield in the bags, `/okf debug` "pending restore: none". Nothing would ever put them back |
| 4 | Check the slot locks right after entering | `IsInventoryItemLocked(16)` and `(17)` stay false while the swap is on its way; only the pole's bag slot is locked |
| 5 | Enter with 0 free bag slots | **B3**: the game refused the whole swap ("Inventory is full.", `UI_ERROR_MESSAGE` type 3, the bag slot unlocked, no `PLAYER_EQUIPMENT_CHANGED`); fishing mode on without the pole; the records dropped safely on exit, nothing lost |
| 6 | Enter with 1 free bag slot | Works: the mace takes the pole's place, the shield the free slot; both back on exit |
| 7 | Leave and enter 0.1 s apart | **B2**: fishing mode on with the mace in hand, no pole; the records still pending; dropped safely on the next exit, nothing lost |
| 8 | Fight with "Leave fishing mode when attacked" on | Works: both weapons back at the fight's start, the mode off after it |
| 9 | Leave while the line is out | Works: both back when the channel ends |

The server answers a swap 150 to 250 ms after the call. `PLAYER_EQUIPMENT_CHANGED`'s second value is true when the
slot became empty (step 2: the off hand pushed out by the two-handed pole).

**The cause.** Fishing mode judges a slot by what the game shows in it right now. Between the call and the server's
answer the slot still shows the old item, so a restore taken in that window decides "the player changed this slot by
hand" and forgets the record (B1), and an equip taken in that window decides "the pole is already there" (B2).

## Decisions of the author, 2026-11-27

1. **Wait for the game's answer.** While a swap the addon asked for has not been answered, the gear is neither judged
   nor changed; the last action asked for runs once the answers are in.
2. **Do not enter fishing mode without room** for the off hand a two-handed pole pushes out (B3), and say why.
3. **Keep it small**: no new saved field, no retry counters, no "could not put back" message, no change to the fight
   and cast paths that work today, no new order of the hands at a fight's start.
4. **Release alone as 1.7.2**, before spec 028.

## User Scenarios & Testing

### User Story 1 - Leaving right after entering keeps the weapons (Priority: P1)

A player enters fishing mode and leaves it again before the pole is in hand: a double press of the key, a lag spike,
or a mob that attacks at once with "Leave fishing mode when attacked" on. Today the pole stays in hand and the
weapons stay in the bags for good. After the fix the player's weapons come back.

**Why this priority**: the only case where the player loses the use of their gear; the reported bug.

**Independent Test**: spike step 3 in game; in the tests, a swap that lands later than the exit.

**Acceptance Scenarios**:

1. **Given** a one-handed weapon and a shield in hand and the pole in the bags, **When** the player enters and leaves
   fishing mode 0.1 s apart, **Then** a moment later the weapon and the shield are in hand and the pole in the bags.
2. **Given** the same, **When** the player enters and a fight starts before the pole is in hand, with "Leave fishing
   mode when attacked" on, **Then** the weapons are back in hand when the fight ends (the combat lockdown starts in
   the same frame, before the game's answer), and nothing stays in the bags afterwards.
3. **Given** the same, **When** the player enters, leaves and enters again within a second, **Then** fishing mode ends
   on with the pole in hand, and leaving later brings back the weapon and the shield.

---

### User Story 2 - Entering right after leaving equips the pole (Priority: P2)

A player leaves fishing mode and enters it again before the weapons are back in hand. Today the mode is on with the
weapon in hand. After the fix the pole goes on once the restore is answered.

**Why this priority**: no loss, but fishing without a pole is a broken mode.

**Independent Test**: spike step 7 in game; in the tests, a restore that lands later than the next entry.

**Acceptance Scenarios**:

1. **Given** fishing mode on with the pole in hand, **When** the player leaves and enters 0.1 s apart, **Then** a
   moment later the pole is in hand, and leaving later brings back the weapon and the shield.

---

### User Story 3 - No fishing mode without room for the off hand (Priority: P3)

A player with an off-hand item and full bags enters fishing mode. Today the game refuses the swap and the mode is on
without the pole. After the fix the mode stays off and the chat says that a free bag slot is needed for the off-hand
item.

**Why this priority**: no loss; the player learns why instead of fishing without a pole.

**Independent Test**: spike step 5 in game; in the tests, full bags with an off-hand item.

**Acceptance Scenarios**:

1. **Given** an off-hand item in hand, the pole in the bags and 0 free regular bag slots, **When** the player enters
   fishing mode, **Then** the mode stays off, nothing is equipped and the chat names the reason.
2. **Given** the same with 1 free slot, **When** the player enters, **Then** the mode turns on with the pole in hand
   (step 6).
3. **Given** the pole already in hand and full bags, **When** the player enters, **Then** the mode turns on as before.
4. **Given** the gear setting off, **When** the player enters with full bags, **Then** the mode turns on as before.

### Edge Cases

- **The game refuses a swap** (no answer comes): the wait ends after 5 seconds, and the gear is judged as today. A
  refused swap changed nothing, so the record is dropped as "not ours" (spike step 5).
- **A `/reload` or logout while a swap is on its way**: the wait is not saved; the records are, and the login's restore
  runs later than the answer, as today.
- **The player swaps an item by hand during the wait**: after the answer the slot is judged as today: what the player
  put there stays.
- **A fight starts during the wait**: equipping is protected in the lockdown, so the waiting restore runs when the
  fight ends (the existing rule of constitution III).
- **The line is out when the wait ends**: the existing wait for the cast's end follows.
- **Several slots** (the pole and extra fishing items): the action runs once, after the last answer.
- **Enter and leave pressed several times**: only the last request runs.
- **The off hand with special bags only free** (a bag for herbs, for example): it does not count as room; the game
  puts the off hand only into a regular bag.

## Requirements

### Functional Requirements

- **FR-001**: Each slot the addon asks the game to swap or to empty into the bags, and the off-hand slot a two-handed
  pole empties, MUST count as waiting until the game reports a change of that slot, or for 5 seconds at most.
- **FR-002**: While a slot it judges is waiting (any slot for putting on the fishing gear and for putting back all;
  a weapon slot for putting back only the weapons), putting back the player's gear and putting on the fishing gear
  MUST neither judge a slot nor ask for a swap, and MUST NOT drop or change a record of the gear swap. A waiting
  extra item (a hat the game refused) MUST NOT keep the weapons from coming back at a fight's start.
- **FR-003**: When no slot is waiting any more, the last action asked for (put on, put back all, or put back only the
  weapons) MUST run once, on the next frame, with the rules of today (the fight, the cast, "only while the slot still
  holds what the addon put there").
- **FR-004**: An action asked for while another waits MUST replace it: leaving cancels a waiting put-on, entering
  cancels a waiting put-back.
- **FR-005**: Entering fishing mode with the gear setting on MUST NOT turn the mode on when the pole to equip is
  two-handed and not in hand, an item is in the off hand and no regular bag slot is free. A put-on that waited
  (FR-003) asks again when it runs: without room it equips nothing and says why; the mode stays on (only a key press
  ends it). The chat MUST say why, in
  the interface language (one new text with its nine translations). Nothing is equipped or recorded.
- **FR-006**: The saved data MUST NOT change shape: no new field, no `DB_SCHEMA` change.
- **FR-007**: The paths that work today MUST behave as before when no swap is waiting: leaving at a fight's start
  (spike step 8), leaving while the line is out (step 9), leaving after the pole is in hand (step 2), the login's
  restore after a crash or logout.

### Key Entities

- **Gear swap record** (`charDB.gearSwap`, unchanged): per slot, the player's item before fishing and what the addon
  put there.
- **Waiting slot** (in memory only): a slot with a swap the game has not answered yet, and when the wait ends at the
  latest.
- **Pending action** (in memory only): the one gear action to run after the wait.

## Success Criteria

### Measurable Outcomes

- **SC-001**: Entering and leaving fishing mode 0.1 s apart leaves the player's weapon and off-hand item in hand,
  every time (spike step 3 repeated 3 times).
- **SC-002**: Leaving and entering 0.1 s apart ends with the pole in hand (step 7), and the next exit brings the
  player's gear back.
- **SC-003**: With an off-hand item and full bags, fishing mode stays off and the chat names the reason (step 5).
- **SC-004**: Spike steps 2, 6, 8 and 9 give the same result as on 2026-11-27.
- **SC-005**: `npm run check` and `npm test` pass; the tests for B1 and B2 fail on the code of 1.7.1; the existing
  gear tests pass unchanged.

## Assumptions

- The game answers every swap it accepts with `PLAYER_EQUIPMENT_CHANGED` for each slot that changed, an off hand
  emptied by a two-handed item included (seen in steps 2 to 9).
- A refused swap sends no `PLAYER_EQUIPMENT_CHANGED` (step 5); 5 seconds is far above the answers seen (150 to 250
  ms). With a lag longer than that, the behaviour is today's.
- A Fishing Pole is a two-handed item; one free regular bag slot is enough for it to push out an off-hand item (step 6).
- Constitution I (1.5.5, amended for this spec on 2026-11-27): fishing mode's gear swap starts and ends on a real key
  press or by Principle III, and may finish once the game answered an earlier swap (or the wait for that answer ran
  out); nothing else may start one. The
  waiting equip or restore is exactly that: it finishes the swap the player's press of the toggle started (or the
  exit a fight started), after the game's answer, and nothing else starts it. `C_Item.EquipItemByName` is not
  protected out of combat.

## Out of scope

Retry counters, a chat warning about gear that could not be put back, retries on entry, equipping the off hand first
at a fight's start, an equipment set of the game (`C_EquipmentSet`: it would change the player's own sets).

## In-game checks

A new checklist after the build (`docs/checklists/`): spike steps 3, 5 and 7 (now fixed) and 2, 6, 8 and 9
(unchanged), with the same logger. To see the wait in those steps, `/okf debug` shows the slots still waiting for the
game's answer and the queued action (not localized, as the whole report).
