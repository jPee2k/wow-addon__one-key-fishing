---

description: "Task list for spec 009, pin and combat fixes"
---

# Tasks: Pin and Combat Fixes

**Input**: Design documents from `specs/009-pin-combat-fixes/`

**Prerequisites**:
- [plan.md](plan.md), [spec.md](spec.md), [research.md](research.md), [data-model.md](data-model.md)
- [contracts/map-pin.md](contracts/map-pin.md), [contracts/combat.md](contracts/combat.md)
- [verification.md](verification.md), [quickstart.md](quickstart.md)

**Tests**: required. Spec FR-012 and constitution Principle V ask for a test of every logic change. The test is
written first and must fail without its fix (run it before the fix and note the failure).

**Organization**: grouped by the user stories of spec.md (US1 to US5). Work in the current branch `002-shared-db`;
commit only when the author asks.

**Rules for every task** (CLAUDE.md):
- `npm run check` and `npm test` pass after it. A test written before its fix is the only allowed red, until the
  fix that follows.
- Addon Lua stays ASCII outside `Locales/<code>.lua`, Lua 5.1/5.3 neutral, at most 120 characters a line.
- No Cyrillic in any Markdown file.
- The layers hold.
- No new addon file and no TOC change, so `/reload` is enough in game. New test files need no registration
  (`tests/run.mjs` finds every `*_test.lua`).

## Format: `[ID] [P?] [Story] Description`

- **[P]**: can run in parallel (different files, no dependency on an unfinished task)
- **[Story]**: the user story of spec.md (US1 to US5)

---

## Phase 1: Setup

**Purpose**: a baseline to compare against at the end.

- [X] T001 Run `npm run check` and `npm test` from the repository root. Note the open VERIFY marker count (51) and
  the test result in the hand-over notes (not in a file).

---

## Phase 2: Foundational (test stubs)

**Purpose**: the stubs the tests of US2, US3 and US4 need (data-model.md "Test stubs"). US1 needs none and can start
right after T001.

- [X] T002 In `tests/wow.lua`, add these stubs, each documented in the file's header list (the block of "Game data a
  test can set"):
  - `equip_calls = {}` (read): `C_Item.EquipItemByName(item, slot)` appends `{ item = item, slot = slot }`. Add the
    function to the existing `C_Item` table.
  - `inventory = {}`: `GetInventoryItemID(unit, slot)` returns `inventory[slot]` for `"player"`. Add it only if the
    file does not define `GetInventoryItemID` yet.
  - Frame attributes: `Frame:SetAttribute(name, value)` / `Frame:GetAttribute(name)` stored per frame, if `NewFrame`
    (`tests/wow.lua:547`) has none.
  - `override_bindings = {}` (read): `override_bindings[owner][key] = action`.
    - `SetOverrideBinding(owner, isPriority, key, action)` stores `action`, or clears the key when `action` is nil.
    - `SetOverrideBindingClick(owner, isPriority, key, buttonName, mouseButton)` stores
      `"CLICK " .. buttonName .. ":" .. (mouseButton or "LeftButton")`.
    - `ClearOverrideBindings(owner)` empties the owner's table.
  - `channel_info`: when set to a table, `UnitChannelInfo("player")` returns its values unpacked in the game's order
    (name, text, texture, startMS, endMS, isTradeSkill, notInterruptible, spellID). Keep today's empty stub when
    nil; replace `function UnitChannelInfo() end` at `tests/wow.lua:1679`.
  - `known_spells = {}`: `IsSpellKnown(spellID)` returns `known_spells[spellID] == true`. Today `IsSpellKnown` is a
    permissive stub returning nil, so `ns.GetFishingSpellID()` (`Core/Data.lua:262`) answers nil and
    `Mode.Enter` stops at "You have not learned Fishing.". A test sets `known_spells[7620] = true` to enter the mode.
  - A helper `enter_fishing_mode()` for the new tests: sets `known_spells[7620] = true`,
    `bindings["ONEKEYFISHING_ACTION"] = { "`" }`, `ns.db.settings.gear = false` (so `Mode.Enter` equips nothing),
    calls `ns.Mode.Enter()` with `in_combat = false`, asserts `ns.Mode.IsActive()`, then resets `equip_calls = {}`
    and `chat = {}`. Document it in the header's helper list.
  - A helper `owe_gear()` that fills `ns.charDB.gearSwap` with two weapon entries and one other slot, each
    `{ previous = <id>, equipped = <id> }`, using the slot IDs of `ns.GameData.EquipSlots`: `mainHand` (16) and `offHand` (17) for
    the weapons, and `byEquipLoc.INVTYPE_HEAD[1]` (1) for the head (there is no `head` key). It also sets `inventory[slot]` to the `equipped` item, so `RestoreSlots` sees each slot as still the
    addon's. It returns the slot list.
  - A helper `chat_count(text)`: the number of `chat` lines that contain `text` (plain find, as `chat_contains` at
    `tests/wow.lua:310`). `ns.Print` puts the addon's `CHAT_PREFIX` before every line (`Core/Core.lua:65`), so a
    line never equals the bare text. Document it with `chat_contains`.
  Run `npm test`: every existing test still passes (the new stubs only record).

**Checkpoint**: the stubs are in place; US2, US3 and US4 can start.

---

## Phase 3: User Story 1 - A map pin never breaks the map in a later fight (Priority: P1) 🎯 MVP

**Goal**: no pin of the addon opens the world map, and the toast names the place and says to open the map
(contracts/map-pin.md P1-P4, research R5).

**Independent Test**: `tests/core/pin_set_test.lua` and `tests/ui/catalog_pending_test.lua` pass; in game,
quickstart.md step 4.

### Tests for User Story 1

- [X] T003 [US1] Extend `tests/core/pin_set_test.lua`:
  - In the first test ("no waypoint ..."), replace `eq(world_maps_opened[#world_maps_opened], 1415, "the map
    opened")` with `eq(#world_maps_opened, 0, "the map stays closed")`, and reset `world_maps_opened = {}` at its
    start.
  - Change the toast expectation to `(L["Map pin: %s. Open the world map to see it."]):format(...)`.
  - Rename the test to say the map stays closed.
  - In the Replace test ("a pin the player set ..."), after the accepted popup, assert
    `eq(#world_maps_opened, 0, "no map after Replace")`.
  - Update the file's header comment (P4: no world map, research R5).
  Run it: it fails on the map assertion. The toast key also fails until T005.

### Implementation for User Story 1

- [X] T004 [US1] In `OneKeyFishing/Core/MapPin.lua` `MapPin.Set`, delete the block that calls
  `OpenWorldMap(target.mapID)` (the `-- VERIFY(R14)` comment, the `InCombatLockdown()` test and the call).
  - Put `-- VERIFY(R14): a pin set without opening the map leaves the map untainted for a later fight` on the
    `C_Map.SetUserWaypoint` line's block.
  - Update the function's comment: "Sets the game's map pin at target ... with the game's tracking (the minimap's
    arrow) and a toast; the world map stays closed (research R5 of spec 009)".
  - Update the file header: "with the navigation arrow" becomes "with the game's tracking (the minimap's arrow)".
  - Fix the `MapPin.Link` comment if it still compares itself with a map that the addon opens.
- [X] T005 [P] [US1] Replace the key `"Map pin: %s"` with `"Map pin: %s. Open the world map to see it."` in
  `OneKeyFishing/Locales/enUS.lua`, and in each translation remove the old key and add the new one. Each
  translation keeps its file's existing word for the pin and the form of address its `"Open the auction house
  first."` uses. Suggested texts:
  - `OneKeyFishing/Locales/deDE.lua`: `"Kartenmarkierung: %s. Öffne die Weltkarte, um sie zu sehen."`
  - `OneKeyFishing/Locales/esES.lua` and `OneKeyFishing/Locales/esMX.lua`:
    `"Marcador de mapa: %s. Abre el mapa del mundo para verlo."`
  - `OneKeyFishing/Locales/frFR.lua`: `"Repère sur la carte : %s. Ouvrez la carte du monde pour le voir."`
  - `OneKeyFishing/Locales/koKR.lua`: `"지도 핀: %s. 세계 지도를 열어 확인하세요."`
  - `OneKeyFishing/Locales/ptBR.lua`: `"Marcador no mapa: %s. Abra o mapa-múndi para vê-lo."`
  - `OneKeyFishing/Locales/zhCN.lua`: `"地图标记：%s。请打开世界地图查看。"`
  - `OneKeyFishing/Locales/zhTW.lua`: `"地圖標記：%s。請開啟世界地圖查看。"`
  - `OneKeyFishing/Locales/ukUA.lua`: the existing pin word of its old line, then "Open the world map to see it" in
    the formal form its `"Open the auction house first."` line uses (feminine object pronoun for the pin).
- [X] T006 [US1] In `OneKeyFishing/UI/Toast.lua`, the `MAP_PIN_SET` handler with a place name shows
  `(L["Map pin: %s. Open the world map to see it."]):format(placeName)` (colour and loud flag unchanged).
- [X] T007 [P] [US1] In `tests/ui/catalog_pending_test.lua` lines 81-82, use the new key.
- [X] T008 [P] [US1] Remove `"OpenWorldMap"` from `read_globals` in `.luacheckrc` (line 41). Keep the
  `OpenWorldMap` stub and `world_maps_opened` in `tests/wow.lua`, because the pin test and `tests/ui/spike_test.lua`
  assert on them. Run `npm run check` and `npm test`: T003 now passes.

**Checkpoint**: US1 is done; its in-game step waits for the whole spec (the author's order).

---

## Phase 4: User Story 2 - Leaving fishing mode in a fight raises no error (Priority: P1)

**Goal**: no equip or unequip call in the lockdown on any path; the gear comes back when the fight ends
(contracts/combat.md C1-C5, C8; research R2, R3).

**Independent Test**: `tests/fishing/gear_combat_test.lua` and the exit part of `tests/fishing/mode_combat_test.lua`
pass; in game, quickstart.md step 3 (setting off, toggle key in a fight).

### Tests for User Story 2

- [X] T009 [P] [US2] Create `tests/fishing/gear_combat_test.lua`. Header: what it proves (contracts/combat.md C1-C4,
  spec 009 US2). Fishing mode stays off in this file (no `enter_fishing_mode()`), so Gear's own
  `PLAYER_REGEN_ENABLED` handler owns the end of the fight. Each case starts with `owe_gear()` and
  `equip_calls = {}`. Cases, in this order:
  - **Lockdown**: `in_combat = true`. Call `ns.Gear.RestoreWeapons()` and `ns.Gear.Restore()`. Expect no
    `equip_calls`, and `ns.charDB.gearSwap` keeps all three entries.
  - **After the fight**: `in_combat = false`, `fire("PLAYER_REGEN_ENABLED")`. Expect every owed slot in
    `equip_calls` exactly once, each with its `previous` item.
  - **The cast ends in the lockdown**:
    1. `in_combat = false` (the moment before the lockdown) and `channel_info` set to a Fishing channel
       (spellID 7620). Call `ns.Gear.RestoreWeapons()`: nothing is equipped, because the cast defers it
       (`deferredSlots`).
    2. Set `in_combat = true` and `channel_info = nil`, then `fire("UNIT_SPELLCAST_CHANNEL_STOP", "player")`.
    3. `advance(0.2)` (`tests/wow.lua:338`; the retry in `OnCastEnd`). Expect no `equip_calls`.
    4. `in_combat = false`, `fire("PLAYER_REGEN_ENABLED")`. Every owed slot is equipped once.
  - **Before the lockdown** (C4): `in_combat = false`, `channel_info = nil`, `ns.Gear.RestoreWeapons()`. Only the
    two weapon slots are equipped; the head slot is not.
  Run it: the lockdown case and the cast case fail today (equips in the lockdown), and the cast case's step 4 fails
  too (nobody finishes the restore after the fight).
- [X] T010 [P] [US2] Create `tests/fishing/mode_combat_test.lua` with the exit cases (header: contracts/combat.md
  C5, C8, spec 009 US2). Count lines with `chat_count(text)` from T002 (the lines carry the addon's prefix).
  - **The toggle key in a fight**:
    1. `ns.db.settings.exitOnCombat = false`, `enter_fishing_mode()`, `owe_gear()`.
    2. `in_combat = true`, call `OneKeyFishing_ToggleMode()` twice.
    3. Expect `chat_count(L["Leaving fishing mode after combat."]) == 1`, no `equip_calls`,
       `ns.Mode.IsActive()` still true and `ns.Mode.IsExiting()` true.
  - **The end of that fight**: `in_combat = false`, `fire("PLAYER_REGEN_ENABLED")`. Expect:
    - `ns.Mode.IsActive()` false;
    - every owed slot equipped exactly once (Gear's handler skipped, because the mode was still active when it
      ran, and `Mode.Exit` restored);
    - `chat_count((L["Fishing mode %s."]):format("|cffff3333" .. L["OFF"] .. "|r")) == 1`.
  - **The login path** (C8):
    1. The mode off, `owe_gear()`, `equip_calls = {}`, `in_combat = true`.
    2. `enter_world(true, false)`, then `advance(1)` (the resume delay). Expect no `equip_calls`.
    3. `in_combat = false`, `fire("PLAYER_REGEN_ENABLED")`. Every owed slot is equipped once.
  Run it: the toggle case fails today (weapons equipped in the lockdown), and the login case fails too.

### Implementation for User Story 2

- [X] T011 [US2] In `OneKeyFishing/Fishing/Gear.lua`:
  - Add a file-local `restoreAfterCombat = false` next to `deferredSlots`.
  - In `RestoreSlots`, right after the `swap` nil check and before the `IsCasting()` check, return when
    `InCombatLockdown()` is true. Set `restoreAfterCombat = true` first, and add the comment "equipping is protected
    in combat, weapons too (constitution III)". The function's later `inCombat` local and its `not inCombat` test of
    the unequip then always pass; remove them.
  - `Gear.Restore()` becomes a plain `RestoreSlots(nil)`.
  - At the start of every full restore outside the lockdown (`RestoreSlots(nil)` reached past the guard), clear
    `restoreAfterCombat`.
  - In `OnCastEnd`'s timer, replace the `InCombatLockdown()` branch with a plain
    `RestoreSlots(slots ~= true and slots or nil)`. The guard covers the lockdown.
  - Register `PLAYER_REGEN_ENABLED`: if `restoreAfterCombat` and not `ns.Mode.IsActive()`, call `RestoreSlots(nil)`.
    The mode's own handler owns an active or exiting mode (research R3; `Gear.lua` loads before `Mode.lua`).
  - Update the comments that say weapons are swapped in combat.
- [X] T012 [US2] In `OneKeyFishing/Fishing/Mode.lua`:
  - In `Mode.Exit`'s `InCombatLockdown()` branch, remove `ns.Gear.RestoreWeapons()`. It keeps setting
    `pendingExit` and printing the line once.
  - Remove the file-local `restoreAfterCombat` and its branch in the `PLAYER_REGEN_ENABLED` handler.
  - In the `PLAYER_ENTERING_WORLD` timer, replace the `InCombatLockdown()` split with `ns.Gear.Restore()` (Gear
    defers it, C8).
  - Fix the comment of the `PLAYER_REGEN_DISABLED` handler: "Weapons can be swapped here, before the combat
    lockdown; the rest of the gear waits until combat ends".
  Run `npm test`: T009 and T010 pass.

**Checkpoint**: US2 is done.

---

## Phase 5: User Story 3 - An attack says that fishing mode ends (Priority: P2)

**Goal**: one line on an attack with "Leave fishing mode when attacked" on; the key hint does not repeat it within
5 s (contracts/combat.md C6, C7; research R4).

**Independent Test**: the attack cases of `tests/fishing/mode_combat_test.lua` pass; in game, quickstart.md step 2
(setting on).

### Tests for User Story 3

- [X] T013 [US3] Add to `tests/fishing/mode_combat_test.lua`, after the T010 cases (same file). Each case starts
  from fishing mode off; finish a running exit first with `in_combat = false` and `fire("PLAYER_REGEN_ENABLED")`.
  - **The attack**:
    1. `ns.db.settings.exitOnCombat = true`, `enter_fishing_mode()`, `owe_gear()`.
    2. `in_combat = false` (the handler runs before the lockdown), `fire("PLAYER_REGEN_DISABLED")`.
    3. Expect `chat_count(L["Leaving fishing mode after combat."]) == 1`, and only the two weapon slots in
       `equip_calls`.
  - **The 5-second pause**: right after, `in_combat = true` without advancing the stub clock. Call
    `OneKeyFishing_ActionKeyIdle()` and `OneKeyFishing_ToggleMode()`. Still
    `chat_count(L["Leaving fishing mode after combat."]) == 1`.
  - **The setting off**: `exitOnCombat = false`, `enter_fishing_mode()`, `fire("PLAYER_REGEN_DISABLED")`. `chat_count` of the
    line is 0, no `equip_calls`, and the mode is still on and not exiting.
  - **The mode off**: `fire("PLAYER_REGEN_DISABLED")` prints nothing.
  Run it: the attack case fails today (no line), and so does the pause case.

### Implementation for User Story 3

- [X] T014 [US3] In `OneKeyFishing/Fishing/Mode.lua`:
  - Move `local lastHint = 0` up to the file-local state at the top, next to `pendingExit`.
  - In the `PLAYER_REGEN_DISABLED` handler's attack branch, after `ns.Gear.RestoreWeapons()`, print
    `L["Leaving fishing mode after combat."]` and set `lastHint = GetTime()`.
  - In `Mode.Exit`'s lockdown branch, also set `lastHint = GetTime()` when it prints.
  No new locale key. Run `npm test`: T013 passes.

**Checkpoint**: US3 is done.

---

## Phase 6: User Story 4 - The fishing key explains itself in a fight (Priority: P3)

**Goal**: the combat state handler clears the key's overrides for the state the game really sends (contracts/combat.md
C9, C10; research R1; verification.md V45).

**Independent Test**: `tests/fishing/key_combat_test.lua` passes; in game, quickstart.md step 1.

### Tests for User Story 4

- [X] T015 [P] [US4] Create `tests/fishing/key_combat_test.lua`. Header: contracts/combat.md C9, research R1, and
  that the game's state driver delivers the number `1`.
  - After `load_addon()`, `enter_fishing_mode()`, so that `override_bindings[OneKeyFishingBindingOwner]["`"]` holds
    `"CLICK OneKeyFishingButton:LeftButton"`. Assert that first, so the test fails loudly if the stub is not wired.
  - Read the snippet `OneKeyFishingBindingOwner:GetAttribute("_onstate-combat")` and compile it with
    `loadstring("local self, stateid, newstate = ...; " .. snippet, "=snippet", "t", env)`. In the stubs
    `loadstring` is Lua 5.3's `load`, which takes the environment as its fourth argument (fengari has no
    `setfenv`). This is a test-only route; the addon is not touched. `env` holds `tonumber`; pass a `self` whose
    `ClearBindings` calls `ClearOverrideBindings(OneKeyFishingBindingOwner)`.
  - Run it with `newstate = 1` (number): the owner's bindings are empty.
  - Re-enter the bindings, run it with `0`: they stay.
  - Run it with the string `"1"`: they are cleared, so the snippet tolerates either form.
  Run it: the number case fails today.

### Implementation for User Story 4

- [X] T016 [US4] In `OneKeyFishing/Fishing/Action.lua`:
  - Change the snippet to `if tonumber(newstate) == 1 then self:ClearBindings() end`.
  - Above it, add `-- VERIFY(V45): the state driver sends the number 1 (SecureStateDriver resolveDriver); clearing
    drops the overrides so the key runs its own binding in a fight`.
  - Keep the file header line on the dropped overrides; it is now true.
  Run `npm test`: T015 passes. `npm run check` lists V45.

**Checkpoint**: US4 is done (waiting for the in-game step).

---

## Phase 7: User Story 5 - The manual promises only what the pin shows (Priority: P3), and the documents

**Goal**: the manual, the changelog, the specs, the architecture pages, the API facts, the tech-debt list and the
checklists match the new behaviour (spec FR-006, FR-013, FR-014; research R6).

**Independent Test**: read the changed parts against contracts/map-pin.md and contracts/combat.md; `npm run check`
passes (slash commands, no Cyrillic).

- [X] T017 [P] [US5] `OneKeyFishing/README.md`:
  - Line 64 ("Safe in combat") becomes: "when attacked with 'Leave fishing mode when attacked' on, the weapons come
    back at once and fishing mode ends after the fight; in a fight the fishing key pauses."
  - Where the manual describes the setting or leaving the mode in a fight, add two sentences:
    - "The game lets an addon swap weapons only as the fight starts. If the attack comes while you are casting, or
      you leave the mode during the fight, the weapons come back with the rest of the gear when the fight ends."
    - "The pole stays in your hands until then."
  - Lines 151-152 (catalog "Map pin"): drop "and opens the world map at that zone (not in combat)"; say the pin
    shows on the world map and the minimap (with the minimap's arrow) and the message says to open the map.
  - Lines 219-221 (next rank): replace "the game's map pin and navigation arrow point at the seller or the quest
    giver" with "the game's map pin marks the seller or the quest giver on the world map and the minimap (with the
    minimap's arrow); open the world map to see it". Add that the arrow on screen depends on the game's navigation
    setting.
  - Check the troubleshooting entry "The fishing key is paused in combat" (line ~307) still reads right.
- [X] T018 [P] [US5] `CHANGELOG.md` `[Unreleased]`, `### Fixed` (exists, line ~56 of the section), add:
  - "After setting a map pin, the world map no longer fails in a fight ('Interface action failed because of an
    AddOn'); the pin no longer opens the map, and its message says to open it."
  - "Leaving fishing mode in a fight no longer raises 'Interface action failed'; the gear comes back when the fight
    ends."
  - "In a fight the fishing key now pauses and says so, instead of trying to cast."
  - "An attack in fishing mode (with 'Leave fishing mode when attacked' on) now says that the mode ends after the
    fight."
  - "The manual no longer promises a navigation arrow on screen for the next-rank pin."
  The released 1.1.0 entry stays as it is.
- [X] T019 [P] [US5] Specs:
  - `specs/001-interface-language/spec.md` FR-022 (line 255): "the game's own map pin with the navigation arrow"
    becomes "the game's own map pin, tracked (the minimap's arrow), without opening the world map".
  - `specs/005-catch-catalog/spec.md` FR-011 (line 282): drop "turn on the game's navigation to it" in favour of
    "track it (the minimap's arrow)". Replace "and open the world map at that zone. In combat the world map MUST NOT
    open; ..." with "The world map MUST NOT open; the toast says to open it".
  - Add a line "(changed by spec 009)" to each.
- [X] T020 [P] [US5] Verification rows:
  - `specs/001-interface-language/verification.md` R14: the assumption becomes "the pin and its tracking set from
    addon code, without opening the map, leave the map untainted for a later fight". The status becomes "Fallback
    built (spec 009), waiting for `interface-language.md` section 10".
  - `specs/005-catch-catalog/verification.md` V31: add "the manual corrected (spec 009)".
  - The V32 row: add a pointer that the fallback is built (spec 009) under R14.
- [X] T021 [P] [US5] `docs/forever-api.md`:
  - Lines 108-111: replace "The pins still call it: `docs/tech-debt.md`" with "The addon no longer calls it (spec
    009); a pin leaves the map closed".
  - Add a line under the facts read from the client export (or "how to check a call"): the state driver passes
    `tonumber` of the state, so a `_onstate-<name>` snippet compares numbers (V45, open).
- [X] T022 [P] [US5] `CLAUDE.md`:
  - Line 33: "features 001 to 006 and 008 have one" becomes "001 to 006, 008 and 009".
  - Line 99 (the `Core/MapPin.lua` row): "the game's map pin with the navigation arrow" becomes "the game's map pin
    with its tracking (the minimap's arrow; the map stays closed)".
  - Lines 169-170 (Forever API): "a map pin follows Blizzard's `/mappin`" stays, and "the addon never opens the
    world map" is added.
  - Add one Forever API bullet: "A state driver's value reaches `_onstate-*` as a number (`[combat] 1; 0` gives
    `1`)".
  - The equip bullet already states the lockdown rule.
- [X] T023 [P] [US5] Architecture pages:
  - `docs/architecture/core.md` lines 88-96 (MapPin): no navigation arrow on screen promised; no world map opened.
  - `docs/architecture/ui.md` line 68: drop "and out of combat the map"; the toast text says to open the map.
  - `docs/architecture/fishing-mode.md`:
    - lines 14-15: the `[combat]` handler compares `tonumber(newstate) == 1`;
    - lines 32-36: leaving in combat sets a pending exit only, nothing is equipped in the lockdown, the attack line;
    - line 45: "Weapons return only before the combat lockdown (`PLAYER_REGEN_DISABLED`); a restore asked for in the
      lockdown waits for `PLAYER_REGEN_ENABLED` (Gear's `restoreAfterCombat`)". Add: "An attack during a cast defers
      the swap past that moment, so the weapons come back after the fight: the game's limit, not covered by
      constitution III's 'weapons at once'".
  - Add the three new test files to `docs/development.md`'s `fishing/` row only if that row lists every file (it lists
    examples; leave it otherwise).
- [X] T024 [P] [US5] `docs/tech-debt.md`:
  - Remove the open items "The map pin opens the world map, and the map then fails in a fight", "The manual
    promises a navigation arrow on screen", "Leaving fishing mode in a fight raises 'Interface action failed'",
    "The fishing key keeps its cast in a fight" and "No chat line when an attack ends fishing mode".
  - Remove "Batch 3" and "Batch 4" from "Fix batches". Keep the other batch numbers (1, 2, 5) as they are: other
    documents and notes cite them by number.
  - In the heading of batch 1, "next spec 009" becomes "next spec 010". Add one line under "Fix batches": "Batches 3
    and 4 were fixed by spec 009 on `002-shared-db` (release 1.2.0)".
  - Add a "History" line: "2026-11-07, spec 009: batches 3 and 4 fixed with tests; R14 and V45 wait for the game".
- [X] T025 [P] [US5] `docs/release-plan.md` step 1 (line ~42):
  - "batches 1 and 2 are built here (next spec 009)" becomes "(next spec 010)".
  - "batches 3 and 4 go to `develop` as a 1.1.x patch" becomes "batches 3 and 4 are built here by spec 009 and ship
    in 1.2.0 (no 1.1.x patch)".
  - Check the rest of the file for the same 1.1.x-patch plan and the spec number.
- [X] T026 [P] [US5] Checklists. They ask only for what spec 009 changes (spec FR-014; the author's rule: no step
  that was already checked). These are confirmed in game and only cited, as "(confirmed 2026-11-06)":
  - the pin and the minimap arrow on Heming, and the replace question with buttons in the addon's language
    (`interface-language.md` section 10);
  - the chat map link with no blocked action after it;
  - with the setting on, the weapons back at once on an attack, and the rest of the gear plus the mode off after
    the fight;
  - fishing going on after a fight with the setting off (`fishing-mode.md` section 1 findings).
  Edits:
  - `docs/checklists/fishing-mode.md` section 1, "Out of combat only": mark "(re-run after spec 009)" and replace
    the expectation with three sub-steps, in this order:
    1. The binding in a fight, with the setting off: `/run print(GetBindingAction("<key>", true))` prints
       `ONEKEYFISHING_ACTION` (V45). The fishing key gives "The fishing key is paused in combat.", not the game's
       "can't do that in combat".
    2. The setting on, an attack: "Leaving fishing mode after combat." exactly once (the new part).
    3. The setting off, the toggle key in a fight: that line once, and no "Interface action failed" (with
       `/console taintLog 1`, `Logs/taint.log` has no `EquipItemByName`). After the fight the mode is off and the
       gear is back.
    Keep the 2026-11-06 findings under the step as its history.
  - `docs/checklists/interface-language.md` section 10, "Map pin", first step: replace the open re-check text
    ("then re-check: ...: ____") with "(re-run after spec 009) Pin: the map stays closed; the notification names the
    place and says to open the map; open the map (the pin is there); a fight; the map opened with M gives no
    'Interface action failed because of an AddOn'. Closes R14: ____".
  - `docs/checklists/catch-catalog.md` step 3 (ticked): add one line "Since spec 009 the pin no longer opens the map;
    checked through the next-rank pin (`interface-language.md` section 10), the same `MapPin.Set`". Do not untick
    it.
- [X] T027 [P] [US5] The author's 1.2.0 test page (claude.ai artifact
  `https://claude.ai/artifact/8bqDcm6BKLMFQgkMgySQpy`, the "1.2.0" test page; its text is in Ukrainian).
  - Read it first: the Artifact tool (`action: "read"`), and its database collection `steps` with `ArtifactData`.
    On 2026-11-07 the collection was empty. Keep every mark it holds at the time of the change.
  - Republish to the same URL with these changes:
    - Phase `b` (batches 1 and 2): its title names spec 010 instead of spec 009.
    - Phase `c` (today "after the 1.1.x patch, batches 3-4"): rename it to "after spec 009: the pin and the fight",
      keep the tag that blocks the release. Its intro says the fix is on `002-shared-db` (no 1.1.x patch, no
      rebase).
  - The steps of phase `c` mirror T026:
    - `c-key`: the binding in a fight;
    - `c-attack`: the attack line;
    - `c-combat`: the toggle key in a fight;
    - `c-pin`: the pin with the map closed, then a fight and M.
    Keep the ids `c-pin` and `c-combat` so any marks stay attached. Cite what was already confirmed, as in T026.
    The page's Ukrainian text follows the page's existing style.
  - Leave the other phases unchanged.

**Checkpoint**: every document matches; the in-game steps are ready.

---

## Phase 8: Polish & Cross-Cutting Concerns

- [X] T028 Run `npm run check` and `npm test`. Both pass. The VERIFY count is the T001 count plus V45; R14 stays
  one marker. Grep the addon for `OpenWorldMap` (none outside comments) and for `"Map pin: %s"` (none).
- [X] T029 Revert check (quickstart.md "Automated"): for each fix, revert only that hunk locally, run its test file
  and see it fail, then restore it. The fixes are T004 (map), T011 (lockdown guard and Gear's
  `PLAYER_REGEN_ENABLED`), T012 (`Mode.Exit`), T014 (attack line) and T016 (`tonumber`). Note the results in the
  hand-over.
- [X] T030 Hand-over to the author, after every task above (the author's order: implement and fix first, then the
  game):
  - the in-game steps: phase `c` of the 1.2.0 test page (T027), the same as quickstart.md "In game" (key check,
    combat, pin), with `/reload` (no restart needed);
  - the files changed;
  - that R14 and V45 stay open until confirmed;
  - no commit until the author asks.

---

## Dependencies & Execution Order

- **T001** first.
- **T002** (stubs) before US2, US3 and US4. US1 does not need it.
- **US1** (T003-T008): T003 before T004-T006. T005 and T006 together make T003's toast assertion pass. T007 and
  T008 are independent.
- **US2** (T009-T012): T009 and T010 before T011 and T012; T011 before T012 (Mode relies on Gear's deferral).
- **US3** (T013-T014): after US2, because the tests and the code share `tests/fishing/mode_combat_test.lua` and
  `Fishing/Mode.lua`.
- **US4** (T015-T016): only after T002; independent of US1-US3 (`Fishing/Action.lua`).
- **US5 and documents** (T017-T027): after the stories they describe. T017-T027 are different files and can run in
  parallel.
- **Polish** (T028-T030) last.

### Parallel opportunities

- After T001: US1 (T003-T008) alongside T002.
- After T002: US2's tests T009 and T010 together; US4 (T015-T016) alongside US2.
- Within US1: T005, T007 and T008 together once T003 is written.
- All of T017-T027 together.

### Parallel example: after T002

```text
Task: "T009 [US2] Create tests/fishing/gear_combat_test.lua"
Task: "T010 [US2] Create tests/fishing/mode_combat_test.lua (exit cases)"
Task: "T015 [US4] Create tests/fishing/key_combat_test.lua"
```

## Implementation Strategy

1. **MVP = US1** (T001, T003-T008): the map pin is the released bug that blocks a game window. It is built
   first, but the in-game check waits for the whole spec (the author's order).
2. **US2 + US3** (T002, T009-T014): the combat exit and the attack line, one in-game step (fishing-mode.md
   section 1).
3. **US4** (T015-T016): the one-line key fix, confirmed by the first sub-step of the same in-game section.
4. **Documents** (T017-T027), then **Polish** (T028-T030).
