---

description: "Task list for spec 013, fishing sounds"
---

# Tasks: Fishing Sounds

**Input**: Design documents from `specs/013-fishing-sounds/`

**Prerequisites**:
- [plan.md](plan.md), [spec.md](spec.md), [research.md](research.md), [data-model.md](data-model.md)
- [contracts/module-api.md](contracts/module-api.md), [quickstart.md](quickstart.md)
- Research input: [docs/history/sounds-plan.md](../../docs/history/sounds-plan.md); constitution 1.5.4 (sound files under `Media/`)

**Tests**: required (constitution Principle V). Each test is written first and seen failing before its code.

**Organization**: grouped by the user stories of spec.md (US1 to US4). Work on `013-fishing-sounds`; commit only
when the author asks.

**Rules for every task** (CLAUDE.md):
- `npm run check` and `npm test` pass after it; a test written before its code is the only allowed red.
- Addon Lua: ASCII outside `Locales/`, 120-character lines, Lua 5.1/5.3 neutral, every handler through the bus.
- No Cyrillic in Markdown.
- Write files with LF line endings (`.gitattributes` `eol=lf`). In Python, open with `newline=''` or write bytes.
- A new visible text: a literal English key in `Locales/enUS.lua` and its translation in each of the nine other
  locale files (`deDE`, `esES`, `esMX`, `frFR`, `ukUA`, `koKR`, `ptBR`, `zhTW`, `zhCN`) in the same task; color
  codes outside the strings; no `L[...]` lookup while the files load.
- A new WoW API global goes into `.luacheckrc` `read_globals` in the task that first uses it.
- New files and a TOC change: the author restarts the game (not only `/reload`).
- Code built on an assumption only the game can confirm carries `-- VERIFY(Vnn): <what>` (verification.md).

## Format: `[ID] [P?] [Story] Description`

- **[P]**: can run in parallel (different files, no dependency on an unfinished task)
- **[Story]**: the user story of spec.md (US1 to US4)

---

## Phase 1: Setup (files, tools, stubs)

**Purpose**: the sound files packaged and checked, the test stubs; no addon behaviour yet. T002 to T005 form one
step for `npm run check`: the copied `.ogg` files are accepted only once T003 packages them and T004 rendered their
steps, so run the check after T005 (the one allowed exception to "after every task").

- [X] T001 Run `npm run check` and `npm test` from the repository root on `013-fishing-sounds`; note the test count
  (758) and the VERIFY marker count for the hand-over.
- [X] T002 Copy the author's files from `static/audio/` into `OneKeyFishing/Media/Sounds/` under event names:
  `bell_dark_01.ogg` -> `bell.ogg`, `retrive_dark_01.ogg` -> `hook.ogg`, `notification_dark_01.ogg` -> `rare.ogg`
  (byte copies; `static/` stays untouched and git-ignored).
- [X] T003 In `tools/addon.mjs`: export `ADDON_MEDIA_DIR = "Media"` and a function `mediaFiles()` returning every
  file under `OneKeyFishing/Media/` (forward-slash paths relative to the addon folder, sorted); `packageEntries`
  adds each `.ogg` of it (`{ from: "OneKeyFishing/<path>", to: "<path>" }`). Check `tools/build.mjs` copies binary
  files unchanged (it must not read them as text) and fix it if not.
- [X] T004 New `tools/sounds.mjs` and `package.json` script `"sounds": "node tools/sounds.mjs"`: for every master in
  `OneKeyFishing/Media/Sounds/*.ogg` and every step 10..90, run
  `ffmpeg -y -loglevel error -i <master> -filter:a volume=<step/100> -c:a libvorbis -q:a 4 <Volume<step>/name.ogg>`
  (creating the folders); if `ffmpeg` is not on `PATH`, fail with "ffmpeg is needed for npm run sounds" via
  `fail()`. Then run `npm run sounds` and commit nothing; if ffmpeg is missing on this machine, stop here and ask
  the author to install it or run the command (the 27 step files are needed before T005's check rules pass).
- [X] T005 In `tools/check.mjs`: the "not listed in the TOC" rule accepts `.ogg` files under `Media/`; any other
  file type under `Media/` is a problem ("only .ogg sound files belong in Media/"); a master
  `Media/Sounds/<name>.ogg` without `Media/Sounds/Volume10/<name>.ogg` ... `Volume90/<name>.ogg` is a problem
  ("missing volume steps: run npm run sounds"); a step file without its master is a problem. Write these rules as
  a pure function `mediaProblems(files)` in `tools/addon.mjs` (input: the forward-slash paths under the addon
  folder; output: `{ file, message }` problems) and call it from `tools/check.mjs`. Keep the root `static/` skip.
- [X] T006 New `tests/tools/media_check_test.mjs` (Node test, same style as `private_check_test.mjs`): the
  packaging includes `Media/Sounds/*.ogg` and the steps; a `.txt` under `Media/` and a master without steps are
  reported, by calling `mediaProblems(files)` from T005 with lists of paths (no file system).
- [X] T007 [P] In `tests/wow.lua` (and its header list of stubs): `PlaySoundFile(path, channel)` appends
  `{ path, channel }` to `sound_calls` and returns `true, <next handle number>` (`sound_play_result = false` makes it
  return false, nil); `StopSound(handle, fade)` appends to `sound_stops`; `ERR_FISH_ESCAPED = "Your fish got away!"`,
  `ERR_FISH_NOT_HOOKED = "No fish are hooked."`; `Enum.ItemQuality` (Poor 0, Common 1, Uncommon 2, Rare 3, Epic 4)
  if missing; `GetLootSlotInfo` returns a 5th value, the item's quality from `loot.items[slot][3]` (nil when not
  given); the sound CVars in the `C_CVar` stub default to the game's values (`Sound_EnableSoundWhenGameIsInBG` "0",
  `Sound_MusicVolume` "0.4", `Sound_AmbienceVolume` "0.6", `Sound_DialogVolume` "1.0", `Sound_EnableSFX` "1",
  `Sound_SFXVolume` "1.0"); `enter_fishing_mode()` and the test reset clear `sound_calls` / `sound_stops`.

**Checkpoint**: `npm run check` and `npm test` pass (758 plus the new tools test).

---

## Phase 2: Foundational (settings, catch quality, the module, Mode's CVar reconcile)

**Purpose**: what every story needs. Blocks Phases 3-6.

### Tests (write first, see them fail)

- [X] T008 [P] Extend `tests/catch/caught_test.lua`: a fishing loot whose items carry a quality
  (`loot.items = { { 6303, 1, 2 } }`) gives `FISH_CAUGHT` items with `quality == 2`; without a slot quality the
  item's `C_Item.GetItemQualityByID` is used; with neither the field is nil.
- [X] T009 [P] New `tests/fishing/cvar_restore_test.lua` (header: spec 013 R6, Principle III "only while it still
  holds what the addon put there"): with `autoLootDefault` "0" before, enter fishing mode (sets "1"), exit: back to
  "0"; enter again, set `autoLootDefault` to "0" by hand while fishing, exit: it stays "0" and `charDB.savedCVars`
  is empty; a saved name without a row (`savedCVars = { someOldCVar = "5" }` at `PLAYER_LOGIN`) is set back to "5".

### Implementation

- [X] T010 In `OneKeyFishing/Core/Core.lua` `DB_DEFAULTS.settings`, add with comments: `fishingSounds = false`
  ("Play fishing sounds", written only by `Sound.SetEnabled`), `soundVolume = 100` (0-100, step 10),
  `backgroundSound = false` (Mode CVar row, live), `splashFocus = false` (Mode CVar rows, live, lifted in a
  fight). No `DB_SCHEMA` bump (new keys only).
- [X] T011 In `OneKeyFishing/Catch/Catch.lua` `LOOT_READY`: read the 5th return of `GetLootSlotInfo(i)` as
  `quality`; when nil, `C_Item.GetItemQualityByID(itemID)` (guarded: the function may be missing); put it in the
  item table `{ link, itemID, quantity, quality }`. Update the file's header comment. (Makes T008 pass.)
- [X] T012 In `OneKeyFishing/Fishing/Mode.lua`, replace `ApplyCVars` / `RestoreCVars` with a reconcile:
  rows gain optional `live` (boolean) and `combat` (`"lift"`), and `value` may be a function `old -> string`;
  local `Applied(row, old)` returns the row's value for that old value; `Wanted(row)` = mode active and
  (no `setting` or `settings[setting]`) and not (`row.combat == "lift"` and `inFight`);
  `SyncCVars()` sets every wanted row not in `charDB.savedCVars` (record `old` first, skip when `GetCVar` is nil or
  already equals the applied value) and restores every saved row no longer wanted; `RestoreSaved(name, old)`: when
  a row exists and the current value differs from `Applied(row, old)` (numbers compared as numbers, strings
  otherwise), only drop the record; else `C_CVar.SetCVar(name, old)` and drop it; a name without a row is set
  back. `Enter` calls it right after `active = true` and `Exit` right after `active = false` (so `Wanted` sees the new
  state; exit: nothing wanted, so all restored); `PLAYER_LOGOUT` and `PLAYER_LOGIN`
  restore every saved row through `RestoreSaved`. Keep `charDB.savedCVars` as `name -> old` (no schema change).
  Track the fight with a local `inFight` set at `PLAYER_REGEN_DISABLED` and cleared at `PLAYER_REGEN_ENABLED`
  (the focus is lifted before the lockdown). (Makes T009 pass.)
- [X] T013 New `OneKeyFishing/Fishing/Sound.lua` (`ns.Sound`, header comment: what it plays and when, spec 013), in
  the TOC in a new group `# Sounds: the fishing sounds (Fishing/Sound.lua reads Catch.lua's messages)` right after
  the "# Catches and statistics" group (`Fishing\Sound.lua`): `Sound.IsEnabled()`; `Sound.SetEnabled(value)` writes
  `settings.fishingSounds = value == true`, calls `StopAll` when off, fires `SETTINGS_CHANGED("fishingSounds")`;
  `Sound.Volume()` clamps `settings.soundVolume` to 0-100 and rounds to a multiple of 10 (`math.floor(v / 10 +
  0.5) * 10`, non-numbers give 100); `Sound.SetVolume(percent)` stores that value and fires
  `SETTINGS_CHANGED("soundVolume")`; `Sound.Path(event, volume)` returns
  `"Interface\\AddOns\\OneKeyFishing\\Media\\Sounds\\" .. (volume < 100 and ("Volume" .. volume .. "\\") or "")
  .. event .. ".ogg"`, nil at 0; local `Play(event)` (pcall `PlaySoundFile(path, "Master")`, keep the handle per
  event, stop the event's previous handle first); `Sound.StopAll()` (pcall `StopSound(handle, FADE_MS)` for each,
  bump a token). Add `PlaySoundFile`, `StopSound` to `.luacheckrc` `read_globals`. Mark the playback
  `-- VERIFY(V46): an addon .ogg plays by path on the Master channel and StopSound stops it`.
- [X] T014 [P] New `specs/013-fishing-sounds/verification.md` in the format of
  `specs/009-pin-combat-fixes/verification.md`: V46 (file playback, R4), V47 (the hook results arrive within 0.5 s:
  loot, `ERR_FISH_ESCAPED`, `ERR_FISH_NOT_HOOKED` as the message of `UI_ERROR_MESSAGE`, R1), V48 (the sound CVars
  apply at once, also at `PLAYER_REGEN_DISABLED`, R6), V49 (the background CVar keeps the splash and the addon's
  sounds audible with the window unfocused, R6); each with evidence, what happens if wrong, how to verify
  (`docs/checklists/sounds.md` step), status "Open".

**Checkpoint**: `npm test` passes; fishing mode behaves as before (the existing Mode, combat and CVar tests).

---

## Phase 3: User Story 1 - Hear the fishing sounds (Priority: P1) 🎯 MVP

**Goal**: with "Play fishing sounds" on and fishing mode on: the bell when the bobber lands, the hook sound on the
hook's result, the rare sound for Uncommon or better loot; silence in a fight; the page, the minimap entry and
`/okf sound` (contract C1, C4-C6; FR-001 to FR-009, FR-011, FR-012, FR-018 for the sounds, FR-004a).

**Independent Test**: `tests/fishing/sound_events_test.lua`, `sound_combat_test.lua`, `tests/ui/sound_page_test.lua`.

### Tests (write first, see them fail)

- [X] T015 [P] [US1] New `tests/fishing/sound_events_test.lua`: with `Sound.SetEnabled(true)` and
  `enter_fishing_mode()`: `FISHING_CAST_START` plays `bell` once (path ends `bell.ogg`, channel "Master"), a second
  start of the same cast does not; `fish_cast` with a common item plays `hook` once and no `rare`; with an item of
  quality 2 plays `hook`, then `rare` after `advance(0.4)`; `UI_ERROR_MESSAGE` with `(0, ERR_FISH_ESCAPED)` and with
  `ERR_FISH_NOT_HOOKED` while channeling plays `hook`; a second error in the same cast does not; the same error 2 s
  after `FISHING_CAST_STOP` does not; a cast that stops with no loot and no error plays no `hook`; with the sounds
  off, or the mode off, nothing plays; `MODE_CHANGED(false)` and `Sound.SetEnabled(false)` stop the handles
  (`sound_stops`); `sound_play_result = false` raises no error.
- [X] T016 [P] [US1] New `tests/fishing/sound_combat_test.lua`: in fishing mode with the sounds on, `in_combat =
  true; fire("PLAYER_REGEN_DISABLED")` stops the handles and a cast start or a loot plays nothing; after
  `fire("PLAYER_REGEN_ENABLED")` (mode still on, `exitOnCombat` false) the next cast plays the bell; a rare sound
  scheduled just before the fight does not play.
- [X] T017 [P] [US1] New `tests/ui/sound_page_test.lua`: `settings_pages` holds the "Sound effects" page after
  `PLAYER_LOGIN`; showing it, the "Play fishing sounds" checkbox reflects `Sound.IsEnabled()`; clicking it calls
  through to the setting and fires `SETTINGS_CHANGED("fishingSounds")`; `Sound.SetEnabled(true)` from elsewhere
  checks it on the shown page; `/okf sound` (`ns.COMMANDS` entry `sound`) opens that page; the minimap menu has a
  "Fishing sounds" checkbox whose state follows `Sound.IsEnabled()` (stub `MenuUtil.CreateContextMenu` if needed).

### Implementation

- [X] T018 [US1] In `OneKeyFishing/Fishing/Sound.lua`: the plays of contract C1 behind one guard (sounds on,
  `ns.Mode.IsActive()`, not paused, `Sound.Volume() > 0`): `ns.On("FISHING_CAST_START")` -> `bell` once per
  `ns.GetFishingCastID()`; `ns.On("FISH_CAUGHT", items, castID)` -> `hook` once per cast, then, when any item has
  `quality >= Enum.ItemQuality.Uncommon` (fallback 2), `rare` after `RARE_DELAY = 0.4` via `C_Timer.After`,
  guarded by the stop token; `ns.RegisterEvent("UI_ERROR_MESSAGE", function(_, _, message)`: skip a secret value
  (`ns.IsSecret`), match `ERR_FISH_ESCAPED` / `ERR_FISH_NOT_HOOKED` while `ns.Action.IsChanneling()` or within
  `HOOK_GRACE = 1` s after `FISHING_CAST_STOP` -> `hook` once per cast; `MODE_CHANGED(false)` -> `StopAll`;
  `PLAYER_REGEN_DISABLED` -> `StopAll`, paused; `PLAYER_REGEN_ENABLED` -> not paused. Mark the hook triggers
  `-- VERIFY(V47): ...`. Add `ERR_FISH_ESCAPED`, `ERR_FISH_NOT_HOOKED` to `.luacheckrc`. (Makes T015, T016 pass.)
- [X] T019 [US1] In `OneKeyFishing/UI/Settings.lua`: `CreateSoundPage()` built like `CreateSharePage()` (title
  `L["Sound effects"]`, then the checkbox `L["Play fishing sounds"]` with `Sound.IsEnabled` / `Sound.SetEnabled`
  and the explanation text `L["A bell when the bobber lands on the water, a sound when you hook, and a notification when the loot holds an Uncommon or better item. Only while fishing mode is on."]`
  under it); `ns.On("SETTINGS_CHANGED")` for `fishingSounds` updates the shown checkbox; register it with
  `Settings.RegisterCanvasLayoutSubcategory(mainCategory, soundPage, L["Sound effects"])` after the share page
  (hidden at creation like the others), keep it in a `soundCategory`; `SettingsUI.OpenSounds()` opens it via
  `OpenCategory`. Add the three keys to `Locales/enUS.lua` and the nine translations.
- [X] T020 [P] [US1] In `OneKeyFishing/UI/Minimap.lua` `OpenMenu`: after "Settings", `root:CreateCheckbox(
  L["Fishing sounds"], function() return ns.Sound.IsEnabled() end, function() ns.Sound.SetEnabled(not
  ns.Sound.IsEnabled()) end)`. Add the key to `Locales/enUS.lua` and the nine translations.
- [X] T021 [P] [US1] In `OneKeyFishing/Core/Commands.lua`: `{ name = "sound", description = "open the sound effects
  settings", run = function() ns.SettingsUI.OpenSounds() end }` in name order; add `/okf sound` to the manual
  `OneKeyFishing/README.md` command list (`npm run check` requires it). (Makes T017 pass with T019, T020.)

**Checkpoint**: US1 tests pass; the sounds play in the tests with the default volume.

---

## Phase 4: User Story 2 - Set the volume (Priority: P2)

**Goal**: the volume slider, 0-100 % in steps of 10, default 100, greyed while the sounds are off, a sample when
moved (contract C1 `Volume`/`SetVolume`/`Path`/`Preview`, C4; FR-010).

**Independent Test**: `tests/fishing/sound_volume_test.lua`, the slider cases of `tests/ui/sound_page_test.lua`.

### Tests (write first, see them fail)

- [X] T022 [P] [US2] New `tests/fishing/sound_volume_test.lua`: `Sound.Path("hook", 100)` is the master path,
  `Sound.Path("hook", 30)` the `Volume30\hook.ogg` path, `Sound.Path("hook", 0)` nil; `settings.soundVolume` 37 reads
  as 40, -5 as 0, 250 as 100, "x" as 100; at 0 a cast plays nothing; at 50 the bell's path is the `Volume50` one;
  `Sound.Preview()` plays the hook sound at the current volume also with the sounds off and the mode off, and not
  in a fight.
- [X] T023 [P] [US2] Extend `tests/ui/sound_page_test.lua`: the slider exists, reads `Sound.Volume()`, is disabled
  while the sounds are off and enabled after `Sound.SetEnabled(true)`; a player change (call its value-changed
  callback with 70) stores 70 and plays one preview. Add slider stubs to `tests/wow.lua` if the template is missing
  there (`MinimalSliderWithSteppersMixin`, `CreateFrame(..., "MinimalSliderWithSteppersTemplate")` with `Init`,
  `SetEnabled`, `RegisterCallback`).

### Implementation

- [X] T024 [US2] In `OneKeyFishing/Fishing/Sound.lua`: `Sound.Preview()` (stop the previous preview, play `hook`
  at `Sound.Volume()`, not while paused); `Play` uses `Sound.Path(event, Sound.Volume())`. (Makes T022 pass.)
- [X] T025 [US2] In `OneKeyFishing/UI/Settings.lua` `CreateSoundPage()`: under the first checkbox, a label
  `L["Volume"]` and a `MinimalSliderWithSteppersTemplate` slider (min 0, max 100, step 10, label formatter
  `L["%d%%"]`), value from `Sound.Volume()` on show; on a player change `Sound.SetVolume(value)` then
  `Sound.Preview()` (only when the value differs from the stored one); enabled and the label's font
  `GameFontHighlight` while `Sound.IsEnabled()`, else disabled and `GameFontDisable` (updated on show and on
  `SETTINGS_CHANGED("fishingSounds")`). Guard: if the template is missing, fall back to a plain `Slider` with
  `SetMinMaxValues` / `SetValueStep` / `SetObeyStepOnDrag`. Add the keys to `Locales/enUS.lua` and the nine
  translations; add the mixin or template globals used to `.luacheckrc`. (Makes T023 pass.)

**Checkpoint**: US1 and US2 tests pass.

---

## Phase 5: User Story 3 - Fishing sound in the background (Priority: P2)

**Goal**: "Fishing sound in the background" turns on the game's background sound for the time of fishing mode, at
once when switched while fishing, restored on every end, the player's own change kept; untouched by a fight
(contract C2; FR-013 to FR-016 for the background row).

**Independent Test**: the background cases of `tests/fishing/cvar_sync_test.lua`; `cvar_list_test.lua`.

### Tests (write first, see them fail)

- [X] T026 [P] [US3] New `tests/fishing/cvar_sync_test.lua`, background part: with `backgroundSound` on and the CVar
  "0", `enter_fishing_mode()` sets it "1" and records "0"; exit restores "0"; with the option off nothing changes;
  turning it on while fishing (`settings.backgroundSound = true; ns.Fire("SETTINGS_CHANGED", "backgroundSound")`)
  sets "1" at once, turning it off restores at once; a hand change to "0" while fishing is kept at exit; with
  `exitOnCombat = false`, a fight (`PLAYER_REGEN_DISABLED` / `ENABLED`) leaves it "1"; with `exitOnCombat = true`
  the end of the fight ends the mode and restores it with the exit; `PLAYER_LOGOUT` with the mode on restores it, and the record
  left by a crash (`charDB.savedCVars = { Sound_EnableSoundWhenGameIsInBG = "0" }`, CVar "1") is restored at
  `PLAYER_LOGIN`.
- [X] T027 [P] [US3] Extend `tests/fishing/cvar_list_test.lua`: `Mode.CVAR_NAMES` has ten names, the six sound
  CVars among them, and each appears in the debug report's "Game settings"; the four new settings appear under
  "Addon settings".

### Implementation

- [X] T028 [US3] In `OneKeyFishing/Fishing/Mode.lua` `CVARS`: add `{ name = "Sound_EnableSoundWhenGameIsInBG",
  value = "1", setting = "backgroundSound", live = true }`; `ns.On("SETTINGS_CHANGED", key)` calls `SyncCVars()`
  when the mode is on and `key` is the setting of a `live` row. Mark the row
  `-- VERIFY(V49): the background CVar keeps the game's and the addon's sounds audible with the window unfocused`
  and the sync `-- VERIFY(V48): a sound CVar set through C_CVar takes effect at once`. (Makes T026 pass with T012.)
- [X] T029 [US3] In `OneKeyFishing/UI/Settings.lua` `CreateSoundPage()`: the checkbox
  `L["Fishing sound in the background"]` (`settings.backgroundSound`, write then
  `ns.Fire("SETTINGS_CHANGED", "backgroundSound")`, like the Features toggles) and its explanation
  `L["All game sound keeps playing while the game window is in the background, but only while fishing mode is on. Your own game setting comes back when the mode ends."]`;
  not greyed by the sounds checkbox (it works on its own). Add the keys to `Locales/enUS.lua` and the nine
  translations.

**Checkpoint**: US1-US3 tests pass.

---

## Phase 6: User Story 4 - Splash focus (Priority: P3)

**Goal**: music, ambience and dialog silenced and effects on at least 90 % while fishing; lifted at once in a fight
and back after it while the mode stays on; restored on every end (contract C2; FR-013 to FR-016, FR-018).

**Independent Test**: the focus cases of `tests/fishing/cvar_sync_test.lua`.

### Tests (write first, see them fail)

- [X] T030 [P] [US4] Extend `tests/fishing/cvar_sync_test.lua`, focus part: with `splashFocus` on, entering sets
  `Sound_MusicVolume`, `Sound_AmbienceVolume`, `Sound_DialogVolume` to "0", `Sound_EnableSFX` to "1" and
  `Sound_SFXVolume` "0.5" to "0.9" (but "1.0" stays and is not recorded); exit restores the old values; a hand
  change of the music to "0.3" while fishing is kept, the others restored; `PLAYER_REGEN_DISABLED` restores all
  focus CVars at once (records dropped) and `PLAYER_REGEN_ENABLED` with the mode on applies them again; with
  `exitOnCombat` on, the end of the fight ends the mode and leaves everything restored; switching the option on
  in a fight applies nothing until the fight ends; switching it off while fishing restores at once.

### Implementation

- [X] T031 [US4] In `OneKeyFishing/Fishing/Mode.lua` `CVARS`, rows with `setting = "splashFocus", live = true,
  combat = "lift"`: `Sound_MusicVolume` "0", `Sound_AmbienceVolume` "0", `Sound_DialogVolume` "0",
  `Sound_EnableSFX` "1", `Sound_SFXVolume` `value = function(old) return tostring(math.max(tonumber(old) or 0,
  0.9)) end`; `PLAYER_REGEN_DISABLED` (the existing handler) also calls `SyncCVars()` after setting `inFight`;
  `PLAYER_REGEN_ENABLED` clears `inFight` and, when the mode stays on, calls `SyncCVars()` after
  `ns.Action.Rebind()`. Comment why the focus is lifted (spec 013 FR-018). (Makes T030 pass.)
- [X] T032 [US4] In `OneKeyFishing/UI/Settings.lua` `CreateSoundPage()`: the checkbox
  `L["Splash focus while fishing"]` (`settings.splashFocus`, write then `SETTINGS_CHANGED`) and its explanation
  `L["While fishing mode is on, music, ambience and dialog are silenced and sound effects raised, so the bobber's splash stands out. Lifted in a fight; everything comes back when the mode ends."]`.
  Add the keys to `Locales/enUS.lua` and the nine translations.

**Checkpoint**: every story's tests pass.

---

## Phase 7: Polish and documents

- [X] T033 [P] `CHANGELOG.md` `[Unreleased]` "Added": the "Sound effects" page (sounds, volume, background,
  splash focus), the minimap entry, `/okf sound`; "Changed": fishing mode puts a game setting back only while it
  still holds the addon's value. `OneKeyFishing/README.md`: a "Sound effects" section (what each option does, the
  pause in fights, the bite cannot be detected so the focus helps hear the splash, the sounds are the author's own
  under the addon's MIT license) and `/okf sound`.
- [X] T034 [P] `CLAUDE.md`: module table row `Fishing/Sound.lua` (the fishing sounds) after `Catch/Catch.lua`;
  the `FISH_CAUGHT` message line with `quality`; cross-module rule "the fishing sounds are switched by
  `Sound.SetEnabled`, never by a direct write of `settings.fishingSounds`"; Workflow: `npm run sounds`; Forever API
  bullet: `PlaySoundFile` has no volume, the sound CVars are not secure (to be confirmed, V48).
- [X] T035 [P] Architecture: `docs/architecture/fishing-mode.md` (the Sound module, the CVar rows with `live` and
  `combat`, `SyncCVars`, the restore rule), `docs/architecture/ui.md` (the "Sound effects" page, the minimap
  entry), `docs/architecture/core.md` (the four settings keys in the saved-variables table, `/okf sound`),
  `docs/architecture/catch-and-stats.md` (the `quality` field).
- [X] T036 [P] `docs/development.md`: `npm run sounds` (ffmpeg, what it renders, when to run it) in the tools list
  and Packaging; `README.md` tools table: `npm run sounds`; `docs/forever-api.md`: open questions V46-V49 with the
  sources of research.md.
- [X] T037 [P] New `docs/checklists/sounds.md` from quickstart.md's in-game steps in the template of
  `docs/checklists/README.md` (header, setup with a game restart, numbered steps with the V ids, a step that times finding and setting up the page for SC-005, results); add its
  row to the table in `docs/checklists/README.md`.
- [X] T038 `docs/ROADMAP.md`: remove the "Sounds" idea (built); `git mv docs/sounds-plan.md
  docs/history/sounds-plan.md` and fix the links to it (`CLAUDE.md`, `docs/README.md`, the spec, plan and research
  of this feature); remove the Sync Impact Report comment from `.specify/memory/constitution.md`.
- [X] T039 Final run: `npm run check` and `npm test`; revert each new behaviour once (the restore rule, the hook
  triggers, the rare check, the focus lift) and see its test fail, then restore. Report the test count, the VERIFY
  markers (V46-V49 open) and that the author must restart the game and walk `docs/checklists/sounds.md`.

---

## Dependencies and execution order

- Phase 1 before everything; inside it T002, T003, T004 (render), T005 (check rules), T006 (their test) in order.
- Phase 2 before the stories: T010 (settings) and T013 (the module) for US1/US2; T011 (quality) for US1's rare
  sound; T012 (the reconcile) for US3/US4.
- US1 before US2 (the page and the module's play path); US3 before US4 (the live sync of T028 is reused by T031).
- `UI/Settings.lua` is touched by T019, T025, T029, T032 in that order; `Fishing/Mode.lua` by T012, T028, T031;
  `Fishing/Sound.lua` by T013, T018, T024.
- Phase 7 after the stories; T039 last.

## Parallel examples

- Phase 1: T007 alongside T003-T006.
- Phase 2: T008, T009 and T014 together.
- US1: T015, T016, T017 (tests) together; then T020 and T021 alongside T019.
- US2 tests T022, T023 together; US3 tests T026, T027 together.
- Phase 7: T033 to T037 together.

## Implementation strategy

- **MVP**: Phases 1-3 (US1): the three sounds with their page, minimap entry and command, silent in fights.
- Then US2 (volume), US3 (background), US4 (focus), each a working increment with its tests.
- One commit for the whole spec when the author asks; then the in-game checklist closes V46-V49.
