# Implementation Plan: Fishing Sounds

**Branch**: `013-fishing-sounds` | **Date**: 2026-11-16 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `specs/013-fishing-sounds/spec.md`; research input
[docs/history/sounds-plan.md](../../docs/history/sounds-plan.md)

## Summary

A "Sound effects" settings page with the author's three sounds, their volume, game sound in the background while
fishing, and a splash focus; a pause in fights.

- **Sounds (R1-R4)**: a new layer 1 module `Fishing/Sound.lua` (`ns.Sound`) plays `bell` on `FISHING_CAST_START`,
  `hook` on the result of the hook press (fishing loot, or the game's "fish got away" / "no fish hooked" line), and
  `rare` for loot with an Uncommon or better item (the quality comes with `FISH_CAUGHT` from the loot slot). Files
  through `PlaySoundFile(path, "Master")`, one handle per event. The secure hook path is not touched.
- **Volume (R5)**: the files are pre-rendered at 10 % steps under `OneKeyFishing/Media/Sounds/` (`npm run sounds`,
  ffmpeg); the tools package `.ogg` files under `Media/`, as constitution 1.5.4 allows.
- **Background and focus (R6, R7)**: six sound CVars become rows of Mode's existing CVar table, saved before they
  change and restored on every end of fishing mode. Mode reconciles rows instead of applying all on entry, so a
  setting switched while fishing and a fight (the focus is lifted, then returns) apply at once; a restore puts a value
  back only while it is still ours (Principle III, FR-015).
- **UI (R8, R9)**: a canvas subcategory, a minimap menu checkbox, `/okf sound`; nine translations.

## Technical Context

**Language/Version**: Lua 5.1 (the WoW Forever client, Interface 16001), tests in fengari (Lua 5.3); Node.js 18+ for
the tools

**Primary Dependencies**: the WoW Mainline API as shipped in Forever 1.60.1 (`PlaySoundFile`, `StopSound`,
`C_CVar`, `GetLootSlotInfo`, `UI_ERROR_MESSAGE`, `MinimalSliderWithSteppersTemplate`, `MenuUtil`); ffmpeg for the
volume render (development only)

**Storage**: four new `settings` keys with defaults; `charDB.savedCVars` keeps its shape: no `DB_SCHEMA` bump

**Testing**: `npm test`, `npm run check`; new stubs in `tests/wow.lua`: `PlaySoundFile` / `StopSound` recording
calls, `ERR_FISH_ESCAPED`, `ERR_FISH_NOT_HOOKED`, the loot slot's quality, `Enum.ItemQuality`, sound CVar defaults

**Target Platform**: WoW Forever client (Windows / macOS)

**Project Type**: game addon (single package `OneKeyFishing/`) with Node tooling

**Performance Goals**: a sound within 0.5 s of its event (SC-001); no `OnUpdate`, no polling: events and one
`C_Timer.After` for the delayed rare sound

**Constraints**:
- Blizzard's Add-On Policy (Principle I): the sounds are notices; nothing casts, hooks or loots; the bite is not
  detected; the fishing key's secure binding is unchanged.
- Principle II: rarity by the loot slot's quality, the fish error lines by the client's own global strings.
- Principle III: every audio CVar recorded before it changes; restored on exit, fight-driven exit, logout, `/reload`,
  next login; only while it holds our value.
- Layers: `Sound.lua` (1) uses Core (0), `Mode`/`Action`/`Catch` (1) messages; the UI (3) calls `ns.Sound`; Commands
  opens the page.
- About 12 new visible texts, each with nine translations; ASCII outside the locales; 120-character lines.
- Package size: about 30 short `.ogg` files, under 1 MB.

**Scale/Scope**:
- Addon: new `Fishing/Sound.lua`, `Media/Sounds/` (3 masters + 27 steps); changed `Fishing/Mode.lua`,
  `Catch/Catch.lua`, `Core/Core.lua` (defaults), `Core/Debug.lua`, `Core/Commands.lua`, `UI/Settings.lua`,
  `UI/Minimap.lua`, `OneKeyFishing.toc`, `Locales/*.lua` (10).
- Tools: `tools/addon.mjs`, `tools/check.mjs`, new `tools/sounds.mjs`, `package.json` (`sounds` script).
- Tests: five new files in `tests/fishing/` (`cvar_restore_test.lua` among them), one in `tests/ui/`, one in
  `tests/tools/`; extended `cvar_list_test.lua` and `tests/catch/`; `tests/wow.lua`.
- Documents: research R12.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Check | Result |
|---|---|---|
| I. Blizzard Policy | Sounds react to game events but replace no player decision; no automatic hook, no sound monitoring (the bite is not detected; the splash focus only changes the mix); the hook binding is untouched (R1) | Pass |
| II. Language-Independent Game Data | Quality by loot slot / item ID; fish errors by the client's own `ERR_FISH_*` strings; every text through `ns.L` with nine translations; `/okf sound` English | Pass |
| III. Safe, Restorable State | The six sound CVars use Mode's record-before-change mechanism; restore on every path incl. crash; the new restore rule implements "only while it still holds what the addon put there" (R6); no saved field reshaped | Pass |
| IV. Verified Forever API | Every call is in Forever's global list or the client export; behaviour only the game shows carries `VERIFY(V46-V49)` and a checklist; calls in `pcall`, nothing errors at load; new globals in `.luacheckrc` | Pass |
| V. Checked and Tested Changes | Tests per research R11, each failing without its change; `npm run check`, `npm test` | Pass |
| VI. Simple Module Boundaries | One new module in its area (`Fishing/`), frames only in `UI/`, no new message, the command in `Commands.lua`, the switch through `Sound.SetEnabled` | Pass |
| Technical Constraints | "Shipped files are exactly the TOC, the files it lists, `Bindings.xml` and `README.md`": the `.ogg` files under `Media/` are none of these | Pass: amended in constitution 1.5.4 (2026-11-16), which allows `.ogg` files under `Media/` |

Re-check after Phase 1: the contracts add one module, one field to `FISH_CAUGHT` items, two row fields in Mode and a
packaged media folder; every layer rule holds; the shipped-file rule is met by constitution 1.5.4. Pass.

## Project Structure

### Documentation (this feature)

```text
specs/013-fishing-sounds/
├── plan.md              # This file
├── research.md          # Phase 0
├── data-model.md        # Phase 1
├── quickstart.md        # Phase 1
├── contracts/
│   └── module-api.md    # Phase 1
├── checklists/
│   └── requirements.md
├── verification.md      # V46-V49 (with the tasks)
└── tasks.md             # /speckit-tasks
```

### Source Code (repository root)

```text
OneKeyFishing/
├── OneKeyFishing.toc            # Fishing\Sound.lua after Catch\Catch.lua
├── Media/Sounds/                # bell.ogg, hook.ogg, rare.ogg + Volume10..Volume90/
├── Fishing/Sound.lua            # new: ns.Sound (R1-R5, R7)
├── Fishing/Mode.lua             # sound CVar rows, SyncCVars, restore rule (R6, R7)
├── Catch/Catch.lua              # FISH_CAUGHT item quality (R2)
├── Core/Core.lua                # four settings defaults
├── Core/Debug.lua               # the sound settings (R10)
├── Core/Commands.lua            # /okf sound
├── UI/Settings.lua              # the "Sound effects" page, SettingsUI.OpenSounds (R8)
├── UI/Minimap.lua               # the menu checkbox
└── Locales/*.lua                # the new keys, nine translations
tools/
├── addon.mjs                    # ADDON_MEDIA in packageEntries
├── check.mjs                    # media rules
└── sounds.mjs                   # new: npm run sounds
tests/
├── wow.lua                      # sound, loot quality, error-line stubs
├── fishing/                     # sound_events, sound_volume, sound_combat, cvar_sync, cvar_restore (new); cvar_list
├── catch/                       # the quality field
├── ui/                          # sound_page_test.lua (new)
└── tools/                       # media check
```

**Structure Decision**: the existing layout. The sounds belong to the fishing-mode area (they live and stop with
fishing mode, and Mode owns the CVars), so `Sound.lua` goes into `Fishing/` and is documented in
`docs/architecture/fishing-mode.md`; no new area. `Media/` holds assets only, no code.

## Complexity Tracking

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| Packaged `.ogg` files outside the TOC (Technical Constraints) | The author's own sounds are the feature, and the game plays an addon file only from the addon folder; a TOC cannot list sound files | Blizzard sound kits only: not the author's sounds, which the spec requires |
| 27 pre-rendered volume copies | `PlaySoundFile` has no volume argument; per-sound volume exists only for Blizzard kits | Changing a game volume CVar changes the whole game mix, which FR-010 forbids |
