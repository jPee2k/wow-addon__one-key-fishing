# Research: Fishing Sounds

Input: [spec.md](spec.md), [docs/history/sounds-plan.md](../../docs/history/sounds-plan.md) (the sound API of WoW Forever and how
ForeverFishing uses it). Sources checked on 2026-11-16: the local client export (build 1.60.1.70685), Ketho's
Forever `GlobalAPI.lua`, `CVars.lua` and `GlobalStrings/enUS.lua`.

## R1. When the hook sound plays (FR-007)

**Decision**: the hook sound plays on the **result of the hook press**, the first of:

- fishing loot for the current cast (`LOOT_READY` through `FISH_CAUGHT`), or
- the game's error line `ERR_FISH_ESCAPED` ("Your fish got away!") or `ERR_FISH_NOT_HOOKED` ("No fish are hooked.")
  in `UI_ERROR_MESSAGE` while the line is out or within 1 s after the channel stopped (Catch.lua's `LOOT_GRACE`;
  review 2 moved this to Catch.lua as the message `FISH_ESCAPED`, which Sound.lua only listens to).

Once per cast (keyed by `ns.GetFishingCastID()`). A channel that ends by moving, jumping or running out gives
neither, so no hook sound plays for it, which is right: no hook was pressed.

**Rationale**: while the line is out, the fishing key is an override binding to the game's `INTERACTTARGET`
(`Fishing/Action.lua`); no addon code runs on that press. The results above follow the press after one server round
trip (well under the 0.5 s of SC-001). Nothing in the key's secure path changes. The error lines are compared with
the client's own global strings (`ERR_FISH_ESCAPED`, `ERR_FISH_NOT_HOOKED`), so any client language works
(Principle II: the needle comes from the client's own localized data). A right-click on the bobber is a hook too and
sounds the same.

**Alternatives considered**:
- Bind the key, while channeling, to a second secure button whose click we can see: changes the hook path that the
  author tested and kept (memory "hook with a target": interact-button variants were rejected). Rejected.
- A keyboard-enabled frame with `SetPropagateKeyboardInput(true)` that sees the key press: misses mouse buttons and
  the mouse wheel as fishing keys, can swallow keys if the propagation fails, and the call is restricted in combat.
  Rejected.
- `FISHING_CAST_STOP` before the channel's end time: also fires for movement. Rejected.

`VERIFY(V47)`: the loot and the two error lines arrive within 0.5 s of the press; the error's second argument equals
the global string.

## R2. Rare loot (FR-008)

**Decision**: `Catch/Catch.lua` adds the loot slot's quality to each item of `FISH_CAUGHT`
(`{ link, itemID, quantity, quality }`), read from `GetLootSlotInfo(i)` (5th return: `texture, item, quantity,
currencyID, quality, ...`, as Blizzard's `LootFrame.lua` and `EventImplementation.lua` in the export read it). Rare
is `quality >= Enum.ItemQuality.Uncommon` (2). When the slot has no quality, `C_Item.GetItemQualityByID(itemID)`;
when neither knows it, the item is not rare.

**Rationale**: the loot slot knows the quality even for an item the client has not cached yet (items hidden until
found, memory "hidden items"), and it is game data by ID (Principle II). The message is the one place every catch
passes through; one more field costs nothing to the other listeners.

**Alternatives considered**: the colour code of the link (fragile text parsing); `GetItemQualityByID` only (nil for
uncached items). Rejected.

## R3. The bell (FR-006)

**Decision**: on `FISHING_CAST_START` (the fishing channel started, so the bobber is on the water), once per cast.

**Rationale**: the message exists, fires once per cast, also for a cast running across a `/reload` (Action.Enable).

## R4. Playing a file (FR-009, FR-011)

**Decision**: `PlaySoundFile(path, "Master")` in `pcall`; the handle is kept per event (`bell`, `hook`, `rare`) and
`StopSound(handle, FADE_MS)` stops the previous sound of the same event and every sound on `StopAll`. When a catch
brings both the hook and the rare sound, the rare one starts `RARE_DELAY` (0.4 s) later so the two are heard apart;
a token cancels it when the sounds stop in between.

**Rationale**: `PlaySoundFile`, `StopSound` exist in Forever's global list; `"Master"` plays with sound effects off
and still follows the master volume and the "all sound" switch (spec Edge Cases). Same pattern as ForeverFishing's
`Audio.lua`, written anew (its code is not licensed to us).

`VERIFY(V46)`: an addon `.ogg` plays by path on Forever and returns a handle that `StopSound` stops.

## R5. Volume (FR-010) and the sound files

**Decision**: each sound ships at 100 % (`Media/Sounds/<name>.ogg`) and pre-rendered at 10 % steps
(`Media/Sounds/Volume10/<name>.ogg` ... `Volume90/`). The setting picks the folder; 0 plays nothing. A new tool
`tools/sounds.mjs` (`npm run sounds`) renders the steps from the masters with ffmpeg (amplitude `step / 100`,
libvorbis), so the files stay reproducible; `npm run check` reports a master without its nine steps. The masters are
the author's three files from `static/audio`, renamed to their event: `bell.ogg` (`bell_dark_01`), `hook.ogg`
(`retrive_dark_01`), `rare.ogg` (`notification_dark_01`); about 30 files, under 1 MB.

**Rationale**: `PlaySoundFile` has no volume argument; `volumeOverride` exists only for Blizzard sound kits. Changing
a game volume CVar would change the whole game mix (rejected in docs/history/sounds-plan.md). The steps match the spec's
10 % steps.

**Packaging**: today a packaged addon file must be listed in the TOC (`tools/addon.mjs` `packageEntries`,
`npm run check`); sound files cannot be. `tools/addon.mjs` gains `ADDON_MEDIA`: every `.ogg` under
`OneKeyFishing/Media/`, packaged and accepted by the check (any other file type there is a problem). The
constitution's "Technical Constraints" ("exactly the TOC, the files it lists, `Bindings.xml` and `README.md`") needs
a PATCH amendment through `/speckit-constitution`: "... and the sound files under `Media/`". The BigWigs packager
already copies the whole folder.

**Alternatives considered**: Blizzard sound kits with `volumeOverride` (not the author's sounds); one file and the
SFX channel volume (changes the game). Rejected.

## R6. Game audio settings for fishing mode (FR-013 to FR-016)

**Decision**: the background option and the splash focus become rows of `Fishing/Mode.lua`'s `CVARS` table, the
existing mechanism that records a CVar in `charDB.savedCVars` before changing it and restores it on exit, logout,
`/reload` and the next login:

| CVar | Value | Setting | In a fight |
|---|---|---|---|
| `Sound_EnableSoundWhenGameIsInBG` | `1` | `backgroundSound` | kept |
| `Sound_MusicVolume`, `Sound_AmbienceVolume`, `Sound_DialogVolume` | `0` | `splashFocus` | lifted |
| `Sound_EnableSFX` | `1` | `splashFocus` | lifted |
| `Sound_SFXVolume` | `max(old, 0.9)` | `splashFocus` | lifted |

Two changes to Mode, both inside its module:

1. **Reconcile instead of apply-all**: `SyncCVars()` compares what each row wants now (mode on, its setting on, not
   lifted by a fight) with `savedCVars`: a wanted row not saved is saved and set; a saved row no longer wanted is
   restored and dropped. Enter, exit, a fight's start and end, and a change of `backgroundSound` / `splashFocus`
   (rows marked `live`) call it. The other rows keep their "next time you enter" behaviour.
2. **Restore only what still holds our value** (Principle III, FR-015): a row's applied value is derived from its
   saved old value (`value` or `value(old)`), so `savedCVars` keeps its shape (`name -> old`): no `DB_SCHEMA` bump.
   On restore, a CVar whose current value differs from the applied one is the player's choice and is only dropped
   from the record. A saved CVar with no row (an older build's) is restored as today.

**Rationale**: one mechanism for every changed CVar, already tested for crash and `/reload`; the sound CVars are
neither account nor character CVars and not secure (`CVars.lua`: category 7, `secure = false`), so they can be set
at `PLAYER_REGEN_DISABLED` and in a fight. Point 2 closes a gap of the existing rows too (Principle III already says
"only while it still holds what the addon put there").

**Alternatives considered**: ForeverFishing's separate sound snapshot with pending targets and a retry loop (about
600 lines); a permanent switch of the background setting (rejected by the author). Rejected.

`VERIFY(V48)`: `C_CVar.SetCVar` on these CVars takes effect at once, also at `PLAYER_REGEN_DISABLED`.
`VERIFY(V49)`: with the background CVar on, the game's splash and the addon's sounds are heard with the window
unfocused.

## R7. Combat (FR-018)

**Decision**:
- `Sound.lua`: `PLAYER_REGEN_DISABLED` stops every sound and pauses; `PLAYER_REGEN_ENABLED` resumes. A paused module
  plays nothing.
- `Mode.lua`: the focus rows carry `combat = "lift"`; `PLAYER_REGEN_DISABLED` calls `SyncCVars()` (the rows are no
  longer wanted, so they are restored at once); `PLAYER_REGEN_ENABLED` calls it again when the mode stays on (after
  `Action.Rebind`), or `Exit` restores everything when a pending exit ends the mode. The background row is not
  lifted.

**Rationale**: the same events Mode and Action already use; `PLAYER_REGEN_DISABLED` runs before the lockdown.

## R8. Settings page, minimap menu, command (FR-001 to FR-004a, FR-019)

**Decision**:
- `UI/Settings.lua`: `CreateSoundPage()`, a canvas subcategory "Sound effects" registered after "Shared database",
  built from the file's own helpers (`CreateText`, `CreateCheckbox`, `PADDING`) like the other pages. The volume
  uses Blizzard's `MinimalSliderWithSteppersTemplate` (the Settings panel's own slider, `Blizzard_SharedXML/Shared/
  Slider/MinimalSlider.xml`) with steps of 10 and a "%" label; it is disabled and its label greyed while the sounds
  are off. Releasing it plays `Sound.Preview()`.
- `SettingsUI.OpenSounds()` opens the page; `/okf sound` in `Core/Commands.lua` calls it.
- `UI/Minimap.lua`: the menu gets `root:CreateCheckbox(L["Fishing sounds"], Sound.IsEnabled, toggle)`.
- The sounds switch only through `Sound.SetEnabled(value)`, which writes `settings.fishingSounds`, stops the sounds
  when off and fires `SETTINGS_CHANGED("fishingSounds")`; the page listens and updates (a cross-module rule in
  CLAUDE.md, like `Share.SetEnabled`).

## R9. Texts

New keys in `Locales/enUS.lua` and the nine translations: "Sound effects", "Play fishing sounds", its explanation
(a bell when the bobber lands, a sound on the hook, a notification for an Uncommon or better item), "Volume", "%d%%",
"Fishing sound in the background", its explanation (all game sound keeps playing in the background while fishing
mode is on), "Splash focus while fishing", its explanation (music, ambience and dialog silenced, effects raised while
fishing; restored afterwards and in a fight), "Fishing sounds" (the minimap entry). No text is looked up while the
files load.

## R10. Debug report (FR-017)

The "Settings" section shows `fishingSounds`, `soundVolume`, `backgroundSound`, `splashFocus`; the "Game settings"
section already lists every row of `Mode.CVAR_NAMES`, which now includes the six sound CVars.

## R11. Tests (Principle V)

In `tests/fishing/` (the area of `Sound.lua` and `Mode.lua`), with stubs in `tests/wow.lua` (`PlaySoundFile`
recording calls and returning a handle, `StopSound`, `UI_ERROR_MESSAGE`, `ERR_FISH_*` globals, the 5th return of
`GetLootSlotInfo`, `Enum.ItemQuality`):

- `sound_events_test.lua`: bell once per cast; hook on loot, on each error line, once per cast, not on a movement
  stop; rare once per loot with a green item, after the hook, not for white/grey; nothing with the sounds off or the
  mode off.
- `sound_volume_test.lua`: the path per step, 100 % the master, 0 % no call; stop of the previous handle.
- `sound_combat_test.lua`: no sound in a fight, sounds again after it.
- `cvar_restore_test.lua`: the restore rule for the existing rows: a value still ours is set back, a value the
  player changed while fishing is kept and only dropped from the record, a saved name without a row is set back.
- `cvar_sync_test.lua`: background and focus on enter, restore on exit, live toggle while on, a player's change kept
  on restore, `max(old, 0.9)`, the focus lifted at `PLAYER_REGEN_DISABLED` and back at `PLAYER_REGEN_ENABLED`, the
  background kept in a fight, a crash's record restored at login.
- `cvar_list_test.lua` extended (ten names); `tests/catch/` extended for the quality field; `tests/ui/`
  `sound_page_test.lua` (greyed slider, the minimap checkbox and the page agree); `tests/tools/` for the media check.

## R12. Documents

`CHANGELOG.md` `[Unreleased]`, `OneKeyFishing/README.md` (the page, `/okf sound`, the credit for the author's own
sounds), `CLAUDE.md` (module table: `Fishing/Sound.lua`; `FISH_CAUGHT` item fields; the `Sound.SetEnabled` rule;
the Media folder), `docs/architecture/fishing-mode.md` (Sound, the CVar rows and the reconcile), `ui.md`, `core.md`
(the settings keys), `docs/development.md` (`npm run sounds`, ffmpeg, `Media/`), `docs/forever-api.md` (the facts
once confirmed), `.luacheckrc` (`PlaySoundFile`, `StopSound`, `ERR_FISH_ESCAPED`, `ERR_FISH_NOT_HOOKED`,
`MinimalSliderWithSteppersMixin` if used), `verification.md` (V46 to V49), `docs/checklists/sounds.md`, the
constitution PATCH (R5), `docs/ROADMAP.md` (the item leaves when built), `docs/sounds-plan.md` to `docs/history/`.
