# Sounds plan

A finished plan, kept as a record: built by spec `specs/013-fishing-sounds/` (the "Sound effects" page). It records
how an addon plays sound in WoW Forever (what the client offers, what another Forever addon does, what the rules
allow) and how the page fits into OneKeyFishing. The spec's research, plan and the code are the current truth where
they differ from the design below (the bell, hook and rare sounds, the hook heard on its result, the splash focus
built after all).

## 1. How sound works in the WoW client

### The calls (Forever build 1.60.1)

Checked against the local client export (`Blizzard_APIDocumentationGenerated/SoundDocumentation.lua`,
`Blizzard_SharedXML/Mainline/Sound.lua`) and Ketho's Forever `GlobalAPI.lua`; none of them is protected, so they
work in combat and from tainted code.

| Call | What it does | Volume |
|---|---|---|
| `PlaySoundFile(pathOrFileID [, channel])` -> `willPlay, handle` | plays an `.ogg` or `.mp3` shipped in the addon folder (`"Interface\\AddOns\\OneKeyFishing\\Media\\Sounds\\x.ogg"`) or a game file by FileDataID | **no volume argument**: the channel's volume CVar times `Sound_MasterVolume` |
| `PlaySound(soundKitID [, channel, noDup, finishCallback, priority, volumeOverride])` = `C_Sound.PlaySound` | plays a Blizzard sound kit (an ID from the game, e.g. `SOUNDKIT.MAP_PING`) | `volumeOverride` (0-1) exists in the Forever signature |
| `C_Sound.PlaySoundWithOptions({ soundKitID, uiSoundSubType, volumeOverride, ... })` | the same with a table; Blizzard's own combat audio alerts use it with `uiSoundSubType = "Voice"` and `volumeOverride` | as above, sound kits only |
| `StopSound(handle [, fadeoutMs])`, `C_Sound.IsPlaying(handle)` | stop a sound we started, ask if it still plays | - |
| `MuteSoundFile` / `UnmuteSoundFile` | silence a game file; **not used** (it changes the game's sound, not ours) | - |
| `C_CVar.GetCVar` / `C_CVar.SetCVar` | read and write sound CVars; the global `SetCVar` / `GetCVar` are not in Forever's global list, so use `C_CVar` (as `Fishing/Mode.lua` already does) | - |

Channels for `PlaySoundFile`: `"Master"`, `"SFX"` (the default), `"Music"`, `"Ambience"`, `"Dialog"`. Each has a
volume CVar (`Sound_MasterVolume`, `Sound_SFXVolume`, ...) and an on/off CVar (`Sound_EnableAllSound`,
`Sound_EnableSFX`, ...). A sound on a switched-off channel does not play (`willPlay` is false).

Other facts:

- A sound file added to the addon folder is found only after a **game restart** (the client indexes files at
  start), like any new file (CLAUDE.md, Workflow).
- `PlaySoundFile` cannot change the volume of one sound. The only per-sound volume is `volumeOverride`, and only
  for Blizzard sound kits.
- **Sound in the background**: one game CVar, `Sound_EnableSoundWhenGameIsInBG` ("Sound in Background" in
  Options -> Audio, `Blizzard_SettingsDefinitions_Shared/Audio.lua`). It is all or nothing: there is no flag that
  lets only the addon's sound through while the window has lost focus. Sound CVars live in `Config.wtf`, so the
  value is shared by every character on the computer.
- Events keep firing while the window is in the background, so a sound started by `FISH_CAUGHT` plays there too;
  only the frame rate drops (`maxFPSBk`), which slows `OnUpdate`, not the events.

## 2. How ForeverFishing does it (the example)

`static/examples/ForeverFishing` (version 0.9.165, "All Rights Reserved": **we read it, we copy neither its code nor
its sound files**). Its sound lives in `Audio.lua`, `AudioCompatibility.lua`, the "focus" part of `Core.lua` and the
"Notification Sounds" page of `Settings.lua`.

### Alert sounds (`Audio.lua`)

- **Choices**: a list `rangeSoundChoices` with Off, four Blizzard sound kits (`UI_BNET_TOAST`, `MAP_PING`,
  `ALARM_CLOCK_WARNING_3`, `RAID_WARNING`, each with a numeric fallback ID) and voice packs (male, female).
- **Events**: one setting per event: out of range / cursor reminder, idle recast reminder, catch confirmed, fish
  escaped (`ERR_FISH_ESCAPED`, `ERR_FISH_NOT_HOOKED`), cooking done, bags full. Each event has a cue name, and a
  voice file is `<voice>_<cue>.ogg`.
- **Playing**: kits through `PlaySound(kit, "Master")`, files through `PlaySoundFile(path, "Master")`, both in
  `pcall`; the handle is kept per event and `StopSound(handle, 120)` stops the previous one before a new one.
- **Volume of its own files**: since `PlaySoundFile` has no volume, every clip is shipped **ten times**,
  pre-rendered at 10 % steps (`Media/Voices/VolumeNN/`, about 2 MB). The slider (0-100, step 10, default 50) picks
  the folder; 0 plays nothing. The built-in kit sounds are not scaled by that slider.
- **Repeats and reminders**: `C_Timer.NewTimer` with a token per event, so a cancelled timer never plays; a
  "repeat" option and a repeat interval (1-15 s).
- **Off switch**: `enableAlertSounds`; leaving the fishing bar, loading screens and reset stop every sound and
  timer.

### Sound in background

A toggle on its sound page writes `Sound_EnableSoundWhenGameIsInBG` directly and reads it back. It is treated as the
**player's game setting**: not saved, not restored, the same as Blizzard's checkbox. Its manual says: turn it on to
keep hearing the real bobber splash with the game in the background.

### Focus splash sound (the large part)

While its fishing bar is open it changes the game mix so the native splash stands out: `Sound_EnableAllSound` and
`Sound_EnableSFX` on, master and effects raised to at least 60 % / 90 %, music, ambience and dialog at 0, and
sliders for master, ambience and music that change only this temporary mix. Every changed CVar is stored first
(`soundRestore`: old value, applied value, a pending target) and restored when the bar closes, at logout and at the
next login; a value the player changed in the meantime is kept, not overwritten; `CVAR_UPDATE` follows outside
changes, and a retry loop (0.15, 0.4, 1 s) handles writes the client acknowledges late. `AudioCompatibility.lua`
then wraps functions of two other fishing addons (TheFishingLog, FishFry) to stop them fighting over the music
volume. About 600 lines in all.

### What we take from it

| Idea | Take | Why |
|---|---|---|
| A list of choices with ids, Off first | yes | simple, saves an id, survives a renamed label |
| `PlaySoundFile(..., "Master")` in `pcall`, keep the handle, `StopSound` before the next | yes | the robust minimum |
| Volume by pre-rendered files in 10 % steps | yes, for our own files | the only way to scale an addon file |
| `volumeOverride` for Blizzard kits | yes, if it works for addons (`VERIFY`) | a real per-sound volume, no extra files |
| Background toggle | yes, but scoped to fishing mode (below) | our Principle III |
| Focus mix (changing master, music, ambience) | **no**, maybe a later spec | changes the player's whole mix; a large restore machine; the player can set the mix in Options |
| Hooking other addons' functions | **no** | fragile, not our business |
| Its voice clips | **no** | not licensed to us |

## 3. Rules

- **Blizzard UI Add-On Development Policy** (free of charge, code not hidden or obfuscated, no harm to realms or
  other players, no advertisements, no offensive material, follow the Terms of Use): a sound played on our own
  machine breaks none of them. The project rule that matters more: **the sound is only a notice**. It never casts,
  hooks or loots, and nothing reacts to the bobber by itself (CLAUDE.md, Hard rules). The splash itself has no
  event; the game plays its own splash sound, and the background setting is what lets the player hear it.
- **CurseForge**: content from other authors only under its license or with permission. Our files must be our own
  or under a license that allows redistribution in an MIT project (CC0 preferred, CC-BY with the credit), listed
  in an `ATTRIBUTION.txt` beside them and in the manual. Blizzard sounds are referenced by sound kit ID and never
  copied into the package.
- **By ID, never by name**: kits by numeric ID (the `SOUNDKIT` table may miss a name, so keep the ID as fallback);
  our files by fixed path.
- **Every visible text through `ns.L`** with nine translations: page title, labels, choice names.
- **Principle III**: a CVar fishing mode changes is stored in the character DB before the change and restored on
  exit, logout, `/reload` and after a crash.

## 4. The design for OneKeyFishing

### What the page holds

A new subcategory **Sounds** under OneKeyFishing in the game's Settings, next to "Fishing gear" and "Shared
database":

1. **Play the addon's sound** (checkbox, off by default) with a **sound** dropdown and a **Play** button (preview).
2. **Volume of the addon's sound** (slider 0-100 %, step 10, default 60). Changes only our sound, never a game CVar.
3. **Keep the game's sound while WoW is in the background, while fishing** (checkbox, off by default). It turns on
   `Sound_EnableSoundWhenGameIsInBG` for the time of fishing mode and puts the old value back on exit. The text
   under it says it applies to all game sound (the splash included), not only to the addon's.

### Which events sound

To settle in the spec (open question 1). Candidates already on the message bus:

| Message | Sound for |
|---|---|
| `FISH_CAUGHT` | a catch (the main candidate) |
| `FISH_MISSED` | the fish got away |
| `LURE_READY` | a lure can be applied again |
| `SKILL_WARNING` (loud) | the Fishing rank cap |

One sound for all chosen events in the first version, or one choice per event as ForeverFishing does. Recommended:
start with catch and missed, one dropdown each; more later without a data change.

### Where the code goes (layers)

| Piece | Place | Layer |
|---|---|---|
| Blizzard sound kit IDs offered as choices | `GameData/Sounds.lua` (`ns.GameData.Sounds`, data only, by ID) | 0 |
| Our sound files and `ATTRIBUTION.txt` | `OneKeyFishing/Media/Sounds/<name>.ogg` and `Media/Sounds/VolumeNN/<name>.ogg` | - |
| `ns.Sound`: the choices, `Sound.Play(event)`, `Sound.Preview(id)`, the volume pick (file step or `volumeOverride`), the stop of the previous handle, `ns.On("FISH_CAUGHT" / "FISH_MISSED", ...)` | `Fishing/Sound.lua` (fishing-mode area, after `Fishing/Mode.lua` in the TOC) | 1 |
| The background CVar | one more row of `CVARS` in `Fishing/Mode.lua`: `{ name = "Sound_EnableSoundWhenGameIsInBG", value = "1", setting = "backgroundSound" }` | 1 |
| The Sounds page | `UI/Settings.lua`, `CreateSoundPage()`, `Settings.RegisterCanvasLayoutSubcategory(mainCategory, soundPage, L["Sounds"])` | 3 |
| A test command (optional) | `/okf sound` in `Core/Commands.lua`, plays the chosen sound | 0 |
| Debug lines | `Core/Debug.lua`: sound on/off, choice, volume, the background CVar (already listed through `Mode.CVAR_NAMES`) | 0 |

No new message: the page writes `ns.db.settings` and fires `SETTINGS_CHANGED` (the key) like the other settings.
`Sound.lua` needs no frame (`C_Timer` only), so `tools/addon.mjs` needs no `CreateFrame` exception.

### Saved fields (`OneKeyFishingDB.settings`, new keys, no `DB_SCHEMA` bump: `ApplyDefaults` adds them)

| Key | Default | Meaning |
|---|---|---|
| `sound` | `false` | play the addon's sound |
| `soundCatch`, `soundMissed` | a sound id / `"off"` | the choice per event (ids, not labels) |
| `soundVolume` | `60` | 0-100, step 10 |
| `backgroundSound` | `false` | the background CVar while fishing |

`OneKeyFishingCharDB.savedCVars` already keeps what `Mode` changed; the background CVar joins it with no new field.

### Volume

- **Our files**: one master file, rendered at 10 % steps into `Media/Sounds/Volume10` ... `Volume90`; 100 % plays
  the master, 0 % plays nothing. A small tool (`tools/sounds.mjs`, ffmpeg) renders the steps so the files stay
  reproducible; the packaged size stays small for short clips (ForeverFishing: 16 clips times 10 is about 2 MB).
- **Blizzard kits**: `C_Sound.PlaySoundWithOptions({ soundKitID = id, uiSoundSubType = "Master",
  volumeOverride = volume / 100 })`. If the check in game shows the override is ignored for addons, kits play at
  full channel volume and the slider tells so.
- Channel `"Master"` for both, so the sound is heard with effects switched off; the game's master volume still
  scales it, and `Sound_EnableAllSound` off silences it (the player's choice; we do not override it).
- The slider never writes a game CVar. That keeps the restore machine of section 2 out of the addon.

### Sound in the background

- Scoped to **fishing mode**: applied on enter through the `CVARS` table, stored in `savedCVars` first, restored on
  exit, logout, `/reload` and the next login after a crash. Outside fishing the player's own setting stands.
- If the player already has it on, nothing changes for them.
- Improvement worth taking from ForeverFishing for this CVar (and the others in `CVARS`): on restore, put the old
  value back **only if the CVar still holds the value we applied**; a value the player changed in Options while
  fishing is theirs. Today `RestoreCVars` writes the old value unconditionally (to note in
  [tech-debt.md](../tech-debt.md) if not fixed in the spec).
- Not done: a separate "mirror Blizzard's checkbox" toggle. The game's own Options already does that.

### Stopping

`Sound.StopAll()` on `MODE_CHANGED` (off), when the setting goes off, and before a preview; one handle per event,
stopped with a short fade before the next sound of the same event.

## 5. Questions only the game can answer (future `VERIFY` ids)

| Id | Question | If wrong |
|---|---|---|
| SND-1 | `PlaySoundFile` plays an addon `.ogg` by path on Forever and returns a handle | addon files have no FileDataID, so the feature falls back to Blizzard kits only |
| SND-2 | `volumeOverride` of `C_Sound.PlaySoundWithOptions` changes the volume when called from an addon | kits play at channel volume; the slider applies to our files only |
| SND-3 | `C_CVar.SetCVar("Sound_EnableSoundWhenGameIsInBG", "1")` takes effect at once and is allowed in and out of combat | apply only out of combat (fishing mode is entered out of combat anyway) |
| SND-4 | with the CVar on and WoW in the background, `FISH_CAUGHT` still fires and the sound plays | document that the background option covers the splash only |
| SND-5 | the chosen kit IDs exist in Forever's `SOUNDKIT` table | keep the numeric fallback IDs |

## 6. Open questions for the author

1. Which events sound in the first version (catch, missed, lure, rank cap)? One dropdown per event or one sound for
   all?
2. Our own sound files: where do they come from (made by the author, CC0 library)? Without them the first version
   offers Blizzard kits only.
3. The background option: only while fishing (recommended, restored on exit) or a permanent switch of the game
   setting like ForeverFishing?
4. A focus mix (louder splash, quieter music) as a later spec, or never?

## 7. Definition of done for the feature

Spec `013-fishing-sounds` with `verification.md` for the ids above; `CHANGELOG.md` `[Unreleased]` and the manual
`OneKeyFishing/README.md` (the Sounds page, `/okf sound` if added); the new texts in `Locales/enUS.lua` and the nine
translations; `docs/architecture/fishing-mode.md` (the `Sound` module, the CVar), `docs/architecture/ui.md` (the
page), `docs/architecture/core.md` (the saved keys); CLAUDE.md's module table; tests in `tests/fishing-mode/` for the
volume step, the file path, the event gating and the CVar row; `.luacheckrc` `read_globals` for `PlaySoundFile`,
`StopSound`, `C_Sound`; an in-game checklist `docs/checklists/sounds.md`; this plan moves to `docs/history/` when the
feature ships.

## Sources

- Client export, build 1.60.1.70685: `Blizzard_APIDocumentationGenerated/SoundDocumentation.lua`,
  `Blizzard_SharedXML/Mainline/Sound.lua`, `Blizzard_SettingsDefinitions_Shared/Audio.lua`,
  `Blizzard_CombatAudioAlerts/Blizzard_CombatAudioAlertManager.lua`.
- [Ketho, BlizzardInterfaceResources, `forever` branch, GlobalAPI.lua](https://github.com/Ketho/BlizzardInterfaceResources/blob/forever/Resources/GlobalAPI.lua):
  `PlaySoundFile`, `PlaySound`, `StopSound` present; global `SetCVar` / `GetCVar` absent.
- [warcraft.wiki.gg: API PlaySoundFile](https://warcraft.wiki.gg/wiki/API_PlaySoundFile): channels, formats, no
  volume argument, new files need a restart.
- [Blizzard: UI Add-On Development Policy](https://us.forums.blizzard.com/en/wow/t/ui-add-on-development-policy/24534).
- [CurseForge support: project moderation and copyright](https://support.curseforge.com/en/support/solutions/articles/9000197279).
- `static/examples/ForeverFishing` 0.9.165: `Audio.lua`, `AudioCompatibility.lua`, `Core.lua` (focus mix,
  `SetBackgroundSoundEnabled`), `Settings.lua` (the Notification Sounds page), `README.md`.
