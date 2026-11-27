---

description: "Task list for spec 030: fishing gear waits for the game's swap"
---

# Tasks: Fishing Gear Waits for the Game's Swap

**Input**: `specs/030-gear-in-flight/` (spec, plan, research R1-R6 with decisions D1-D8, data-model,
contracts/gear.md, quickstart)

**Tests**: included (CLAUDE.md, Principle V; spec SC-005: the tests for B1 and B2 fail on the code of 1.7.1). Tests
run in fengari (Lua 5.3); the addon stays free of 5.1/5.3 differences.

**Paths**: addon files under `OneKeyFishing/`, tests under `tests/<area>/`, documents in the repository root.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: can run in parallel (different files, no dependency on an unfinished task)
- **[Story]**: US1 leaving right after entering keeps the weapons (B1), US2 entering right after leaving equips the
  pole (B2), US3 no fishing mode without room for the off hand (B3)

## Architecture rules for this change (CLAUDE.md, constitution III and VI)

- **One module**: the wait lives in `Fishing/Gear.lua` (layer 1) as locals; `Fishing/Mode.lua` asks
  `Gear.HasRoomForPole()`; `Core/Debug.lua` reads `Gear.DebugState()`. No message, no frame, no setting, no
  `<Module>.private`.
- **Saved data unchanged**: `charDB.gearSwap` keeps its fields and writers; the waiting slots and the queued action
  are memory only (data-model.md). No `DB_SCHEMA` bump.
- **Order inside `RestoreSlots`** (D3): the combat lockdown check first (it still sets `restoreAfterCombat`), then the
  wait, then the cast (`deferredSlots`), then the slots. The existing behaviour with no slot waiting stays byte for
  byte the same (FR-007).
- **Runtime only**: `GetTime`, `C_Timer.After`, `GetInventoryItemID`, `C_Container` are called at runtime, never
  while the files load. No new API global (all are in `.luacheckrc` already; check with `npm run check`).
- **Text**: one key, `L["Fishing mode needs a free bag slot for %s."]`, `%s` the off-hand item's link (no color
  code in the string), in `Locales/enUS.lua` and the nine translations in the same change; no `L[...]` while the
  files load.
- **One VERIFY marker** (added in code review, round 2): `VERIFY(V83)` in `Gear.HasRoomForPole`, the room rule with
  an empty main hand, which the spike did not see (`verification.md`; checked in game on 2026-11-27, the rule kept,
  the marker removed); every other game fact the code relies on was
  seen in game on 2026-11-27 (research R3); the behaviour of the fix is checked by the new checklist (SC-001 to
  SC-004).
- **Style**: the file headers and comments of the neighbouring code (what and why, spec number); Lua 5.1; lines of at
  most 120 characters; ASCII outside the translations.

---

## Phase 1: Setup

- [X] T001 Read `OneKeyFishing/Fishing/Gear.lua` (`Gear.Equip`, `RestoreSlots`, the `PLAYER_EQUIPMENT_CHANGED`
  handler, `OnCastEnd`, the `PLAYER_REGEN_ENABLED` handler), `OneKeyFishing/Fishing/Mode.lua` (`Enter`, `Mode.Exit`,
  the `PLAYER_REGEN_DISABLED` handler), the Gear section of `OneKeyFishing/Core/Debug.lua`,
  `tests/fishing/gear_combat_test.lua`, `tests/fishing/gear_pole_test.lua` and the stubs of `tests/wow.lua`
  (`equip_calls`, `inventory`, `C_Timer`, `advance`, `fire`, `owe_gear`, `C_Container`); run `npm test` and note
  that it passes before any change.

---

## Phase 2: Foundational (the wait for the game's answer)

**Purpose**: the waiting slots and the queued action of data-model.md, which US1 and US2 both use.

- [X] T002 Create `tests/fishing/gear_in_flight_test.lua` with its fixtures only: a one-handed weapon (ID 3269) in
  `inventory[16]`, a shield (2212) in `inventory[17]`, the two-handed Fishing Pole (6256) in bag 0 (override
  `C_Item.GetItemInfoInstant` to give 6256 `"INVTYPE_2HWEAPON"` and the Fishing Pole class, as
  `tests/fishing/gear_pole_test.lua` does; `GetInventoryItemLink` returning `"item:<id>"` for the inventory;
  `C_Container.GetContainerNumFreeSlots` returning a test-set `free_slots` with bag type 0, `free_slots = 2` by
  default and reset before each test); `fishing_ready()` (the
  harness helper that lets `Action.Enable` pass) and `settings.gear = true`;
  helpers `land(slot, itemID)` (sets `inventory[slot]` and fires `PLAYER_EQUIPMENT_CHANGED(slot, itemID == nil)`)
  and `land_pole()` (16 = pole, then 17 = nil, both in one call, as the game answered in research R3 step 2).
- [X] T003 In `OneKeyFishing/Fishing/Gear.lua` add the locals of data-model.md: `SWAP_WAIT = 5` (seconds, D2),
  `waiting = {}` (`slot -> GetTime() at which the wait ends`), `queued` (`nil | { kind = "equip" } |
  { kind = "restore", slots = nil or set }`), and `Ask(itemID, slot)`: `waiting[slot] = GetTime() + SWAP_WAIT`, then
  `C_Item.EquipItemByName(itemID, slot)`, then `C_Timer.After(SWAP_WAIT, Settle)` (D1, D2).
- [X] T004 In `OneKeyFishing/Fishing/Gear.lua` add `IsWaiting()`: drops every `waiting` entry whose time has passed,
  returns whether one is left; and `Settle()`: when `queued` is set and `IsWaiting()` is false, schedules
  `C_Timer.After(0, RunQueued)` once (a flag, so two answers in one frame schedule one run; D5).
- [X] T005 In `OneKeyFishing/Fishing/Gear.lua` add `RunQueued()`: returns if `IsWaiting()`; takes `queued` and sets it
  `nil`; an `equip` runs `Gear.Equip()` only while `ns.Mode.IsActive() and not ns.Mode.IsExiting()`; a `restore` runs
  `RestoreSlots(scope)` only while `not ns.Mode.IsActive() or ns.Mode.IsExiting()` (the rule of `OnCastEnd`, D5).
- [X] T006 In `OneKeyFishing/Fishing/Gear.lua` extend the `PLAYER_EQUIPMENT_CHANGED` handler: after its existing
  `restoring` logic (unchanged), `waiting[slot] = nil`, then `Settle()`.
- [X] T007 In `OneKeyFishing/Fishing/Gear.lua` add `Queue(kind, slots)` with the table of data-model.md ("The queued
  action"): `equip` replaces anything; `restore` all replaces anything; `restore` weapons keeps a queued `restore`
  all, else replaces (D4).

**Checkpoint**: `npm test` still passes (nothing calls the new code yet).

---

## Phase 3: User Story 1 - Leaving right after entering keeps the weapons (Priority: P1) MVP

**Goal**: B1 is gone: a restore asked while the pole swap is on its way keeps the records and runs after the answer.

**Independent test**: research R3 step 3 in game; `tests/fishing/gear_in_flight_test.lua` below.

### Tests for User Story 1 (write first; they fail on 1.7.1)

- [X] T008 [US1] In `tests/fishing/gear_in_flight_test.lua` test "leaving before the pole's answer keeps the gear":
  `ns.Mode.Enter()`, `ns.Mode.Exit()` with no answer yet: `ns.charDB.gearSwap[16]` and `[17]` still recorded, no
  equip call for 3269 or 2212 yet; `land_pole()`, `advance(0)`: one equip call for 16 with `"item:3269"` and one for
  17 with `"item:2212"`; `land(16, 3269)`, `land(17, 2212)`: `gearSwap` is `nil`.
- [X] T009 [US1] Test "two answers in one frame run the restore once, on the next frame": as T008 but count the equip
  calls right after `land_pole()` (none) and after `advance(0)` (exactly two, 16 and 17).
- [X] T010 [US1] Test "a refused swap ends the wait after 5 seconds": enter, exit, no answer; `advance(4.9)`: no
  restore call; `advance(0.2)`: the restore runs with today's rules (16 still holds 3269, so the records are dropped
  as "not ours", no equip call).
- [X] T011 [US1] Test "a fight during the wait": enter, exit, set `in_combat = true`, `land_pole()`, `advance(0)`: no
  equip call; `in_combat = false`, `fire("PLAYER_REGEN_ENABLED")`: the weapon and the shield are asked for.
- [X] T012 [US1] Test "a weapons-only restore keeps a full one queued": record a head slot too (`gearSwap[1]`), enter,
  exit, then `ns.Gear.RestoreWeapons()` before the answer; after `land_pole()` and `advance(0)` the head is asked for
  as well.

### Implementation for User Story 1

- [X] T013 [US1] In `OneKeyFishing/Fishing/Gear.lua` `RestoreSlots(onlySlots)`: after the combat lockdown block, the
  "full restore settles the wait" line and `if not swap then return end`, and before the cast check,
  `if IsWaiting() then Queue("restore", onlySlots) return end`; a run that goes ahead clears a queued restore
  (`queued = nil` when it is a restore).
- [X] T014 [US1] In `OneKeyFishing/Fishing/Gear.lua` `RestoreSlots`: replace its `C_Item.EquipItemByName(entry.previous,
  slot)` with `Ask(entry.previous, slot)`; in `UnequipToBags(slot, reserved)`, after `PickupInventoryItem(slot)` and
  the put into a bag, set `waiting[slot] = GetTime() + SWAP_WAIT` and `C_Timer.After(SWAP_WAIT, Settle)` (data-model:
  an entry entering right after such an exit must not see the item still in the slot).
- [X] T015 [US1] Run `npm test`: T008 to T012 pass, `tests/fishing/gear_combat_test.lua` passes unchanged. Check
  that T008 and T009 fail when T013 is reverted (SC-005).

**Checkpoint**: B1 fixed and tested; the exit paths of spike steps 2, 8 and 9 unchanged.

---

## Phase 4: User Story 2 - Entering right after leaving equips the pole (Priority: P2)

**Goal**: B2 is gone: an equip asked while the restore is on its way runs after the answer; only the last wish runs.

**Independent test**: research R3 step 7 in game; the tests below.

### Tests for User Story 2 (write first; they fail on 1.7.1)

- [X] T016 [US2] In `tests/fishing/gear_in_flight_test.lua` test "entering before the restore's answer equips the
  pole": enter, `land_pole()`, exit (the restore asks for 3269 and 2212), enter again before their answer: no equip
  call for 6256 yet; `land(16, 3269)`, `land(17, 2212)`, `advance(0)`: one equip call for 6256 in 16, and
  `gearSwap[16].previous` is the weapon's link.
- [X] T017 [US2] Test "enter, leave, enter before any answer: the pole once": the last wish wins; after `land_pole()`
  and `advance(0)` no restore call and no second pole call; the records are those of the first entry. A second case
  with an extra fishing item (a hat: in `ns.charDB.gear.items`, `bag_items[hat] = 1`, `INVTYPE_HEAD` from the
  `GetItemInfoInstant` override, slot 1 empty before fishing): enter, `land_pole()` and `land(1, hat)` (the entry
  answered), leave (the hat is moved to the bags by `UnequipToBags`, slot 1 waits), enter again before that answer:
  no equip call for the hat yet; `land(1, nil)`, `advance(0)`: the hat is asked for once.

### Implementation for User Story 2

- [X] T018 [US2] In `OneKeyFishing/Fishing/Gear.lua` `Gear.Equip()`: at its start `if IsWaiting() then Queue("equip")
  return end`, else clear a queued action (`queued = nil`); replace its `C_Item.EquipItemByName(itemID, slot)` with
  `Ask(itemID, slot)`; where a two-handed pole goes on over an off-hand item (the `swap[OFFHAND_SLOT] = { ... equipped
  = false }` branch), also set `waiting[OFFHAND_SLOT]` to the same time (D1).
- [X] T019 [US2] Run `npm test`: T016 and T017 pass; `tests/fishing/gear_pole_test.lua` and every other test pass.
  Check that T016 and T017 fail when T018 is reverted (SC-005).

**Checkpoint**: B2 fixed and tested.

---

## Phase 5: User Story 3 - No fishing mode without room for the off hand (Priority: P3)

**Goal**: B3 is gone: with full bags and an off-hand item, fishing mode stays off and says why.

**Independent test**: research R3 step 5 in game; the tests below.

### Tests for User Story 3 (write first)

- [X] T020 [US3] In `tests/fishing/gear_in_flight_test.lua` test "full bags keep fishing mode off": `free_slots = 0`,
  `ns.Mode.Enter()`: `ns.Mode.IsActive()` false, no equip call, no `gearSwap`, the chat line with the shield's link
  once (`chat_count`).
- [X] T021 [US3] Test "the mode enters as before": with `free_slots = 1`; with the pole already in 16 and 0 free;
  with `settings.gear = false` and 0 free; with nothing in 17 and 0 free: the mode is on each time. And the resume
  after `/reload` with 0 free (`charDB.resumeMode = true`, `PLAYER_ENTERING_WORLD` with `isReloadingUi`, the resume
  delay): the mode stays off, the chat line once, and the login restore runs as before.

### Implementation for User Story 3

- [X] T022 [US3] In `OneKeyFishing/Fishing/Gear.lua` add `Gear.HasRoomForPole()` per data-model.md ("The room
  check"): returns `false, GetInventoryItemLink("player", OFFHAND_SLOT)` only when `ns.db.settings.gear`, `Gear.GetPole()`
  gives a pole, its equip location is `"INVTYPE_2HWEAPON"`, `GetInventoryItemID("player", MAINHAND_SLOT)` is not it,
  slot 17 holds an item, and the free slots of bags 0 to `NUM_BAG_SLOTS` with bag type 0 sum to 0; else `true`.
- [X] T023 [US3] In `OneKeyFishing/Fishing/Mode.lua` `Enter(owned)`: after the combat check and before
  `ns.Action.Enable()`, `local room, offhand = ns.Gear.HasRoomForPole()`; on `false`
  `ns.Print(L["Fishing mode needs a free bag slot for %s."], offhand)` and return.
- [X] T024 [P] [US3] Add the key `L["Fishing mode needs a free bag slot for %s."] = true` to
  `OneKeyFishing/Locales/enUS.lua` next to `"No fishing pole found in your bags."`, and its translation to
  `deDE.lua`, `esES.lua`, `esMX.lua`, `frFR.lua`, `koKR.lua`, `ptBR.lua`, `ukUA.lua`, `zhCN.lua`, `zhTW.lua` in
  `OneKeyFishing/Locales/` (the `%s` kept; the terms of each file's existing gear lines, docs/languages.md).
- [X] T025 [US3] Run `npm run check` (every key in all ten files) and `npm test`: T020 and T021 pass.

**Checkpoint**: B3 fixed and tested.

---

## Phase 6: Polish & Cross-Cutting Concerns

- [X] T026 Add `Gear.DebugState()` to `OneKeyFishing/Fishing/Gear.lua` (the waiting slots, sorted, and the queued
  action as `"equip"`, `"restore all"`, `"restore weapons"` or `nil`; contracts/gear.md) and the line
  `swap in flight: <slots or none>, queued: <action or none>` after the "pending restore" lines in the Gear section
  of `OneKeyFishing/Core/Debug.lua` (not localized; D8); a test of the line in
  `tests/fishing/gear_in_flight_test.lua` (waiting and idle).
- [X] T027 [P] Update `docs/architecture/fishing-mode.md`, section `Fishing/Gear.lua`: the wait for the game's answer
  (waiting slots, 5 s, the queued action and its rule, the next frame), `HasRoomForPole` and the room rule of
  `Mode.Enter`, `DebugState`; link research.md.
- [X] T028 [P] Update `CHANGELOG.md` under `[Unreleased]` (Fixed: leaving fishing mode right after entering it left
  the pole in hand and the weapons in the bags; entering right after leaving left the pole out; fishing mode no
  longer turns on without the pole when the bags have no room for the off-hand item) and the manual
  `OneKeyFishing/README.md` (the gear swap part: one free bag slot is needed for an off-hand item when the pole is
  two-handed).
- [X] T029 [P] Create `docs/checklists/gear-swap.md` from quickstart.md "In game" with the template of
  `docs/checklists/README.md` (header, setup, steps with the logger `C1` and the check `C4` of research R3, results),
  and its row in the table of `docs/checklists/README.md`; every chat command counted (at most 255 characters).
- [X] T030 Run `npm run check` and `npm test`; read the whole diff for a stray `C_Item.EquipItemByName` outside `Ask`
  in `OneKeyFishing/Fishing/Gear.lua`, a line over 120 characters, a non-ASCII character outside the translations.
- [X] T031 Hand the checklist `docs/checklists/gear-swap.md` to the author with `npm run install-addon`; record the
  results in the checklist and in `docs/forever-api.md` if a new fact shows up; fix with a test what fails.

---

## Dependencies & Execution Order

- **Phase 1 -> Phase 2 -> US1 -> US2**: US2's `Gear.Equip` wait uses the same machinery and is tested against the
  restore of US1 (T016 needs T013-T014).
- **US3** depends only on Phase 1: `HasRoomForPole` and the Mode check touch no code of the wait; it may be built
  before or after US1/US2.
- **Phase 6** after the stories it describes: T026 after T013 and T018; T027-T029 after all three stories; T030 last
  before T031.

### Parallel opportunities

- T024 (ten locale files) beside T022-T023.
- T027, T028, T029 (three different documents) together.

### Parallel example: User Story 3

```text
T022 Gear.HasRoomForPole in Fishing/Gear.lua   |  T024 the text in the ten Locales/*.lua
T023 the check in Fishing/Mode.lua (after T022)
```

## Implementation Strategy

1. **MVP = US1** (Phases 1-3): the only case with a loss; it can ship alone.
2. **US2** next: same machinery, small.
3. **US3**: independent, one text.
4. **Polish**: debug line, documents, checklist; then the author's checks in game; release 1.7.2 per
   `docs/publishing.md` after the checklist passes (not part of these tasks).
