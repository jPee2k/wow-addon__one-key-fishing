# Contracts: Fishing Sounds

The functions, messages and commands other files may use. Layers as in CLAUDE.md: `Fishing/` is layer 1, `UI/`
layer 3, `Core/Commands.lua` the entry that may open a window.

## C1. `ns.Sound` (`Fishing/Sound.lua`, new, after `Fishing/Mode.lua` and `Catch/Catch.lua` in the TOC)

| Function | Contract |
|---|---|
| `Sound.IsEnabled()` | `settings.fishingSounds == true` |
| `Sound.SetEnabled(value)` | writes `settings.fishingSounds`; off stops every sound (C1 `StopAll`); fires `SETTINGS_CHANGED("fishingSounds")`. The only writer of that key |
| `Sound.Volume()` | `settings.soundVolume` clamped to 0-100 and rounded to a multiple of 10 |
| `Sound.SetVolume(percent)` | stores the clamped, rounded value; fires `SETTINGS_CHANGED("soundVolume")` |
| `Sound.Path(event, volume)` | the file path for `"bell"`, `"hook"`, `"rare"` at a volume step, nil at 0 (pure, tested) |
| `Sound.Preview()` | plays the hook sound at the current volume, also outside fishing mode and with the sounds off (the page's slider is greyed then, so only the slider calls it); not in a fight |
| `Sound.StopAll()` | stops every handle with a short fade and cancels a pending rare sound |

Plays (all require: sounds on, fishing mode on, not paused, volume above 0):

| Event | Trigger | Once per |
|---|---|---|
| `bell` | `FISHING_CAST_START` | cast |
| `hook` | `FISH_CAUGHT` for the current cast, or `UI_ERROR_MESSAGE` whose message is `ERR_FISH_ESCAPED` or `ERR_FISH_NOT_HOOKED` while channeling or within `HOOK_GRACE` after `FISHING_CAST_STOP` | cast |
| `rare` | `FISH_CAUGHT` with an item of `quality >= Enum.ItemQuality.Uncommon`; `RARE_DELAY` after the hook sound | loot |

Stops: `MODE_CHANGED(false)`, `Sound.SetEnabled(false)`, `PLAYER_REGEN_DISABLED` (then paused until
`PLAYER_REGEN_ENABLED`). A new sound of an event stops that event's previous one.

`PlaySoundFile` and `StopSound` are called in `pcall`; a failure plays nothing and raises no error.

## C2. `Fishing/Mode.lua` (changed)

| Item | Contract |
|---|---|
| `CVARS` rows | gain `live` and `combat` (data-model.md); six sound rows added |
| `Mode.CVAR_NAMES` | every row's name (ten), for the debug report |
| `SyncCVars()` (local) | applies the wanted rows not yet saved, restores the saved rows no longer wanted (C3); called by `Enter`, `Exit`, `PLAYER_REGEN_DISABLED`, `PLAYER_REGEN_ENABLED` (mode still on), and `SETTINGS_CHANGED` of a `live` row's setting |
| Restore rule | a saved CVar is set back only when its current value equals the row's applied value for the saved old value (numbers compared as numbers); otherwise its record is dropped and the player's value stays. A saved name without a row is set back as before |
| `PLAYER_LOGOUT`, `PLAYER_LOGIN` | unchanged: restore every saved CVar (with the rule above) |

The existing rows (`SoftTargetInteract`, `autoLootDefault`, the two icons) are not `live`: their settings still apply
the next time the mode is entered.

## C3. `FISH_CAUGHT` (`Catch/Catch.lua`, changed)

`items[i].quality`: the 5th return of `GetLootSlotInfo(i)`, or `C_Item.GetItemQualityByID(itemID)`, or nil. Listed
in CLAUDE.md's messages.

## C4. Settings UI (`UI/Settings.lua`, changed)

- A canvas subcategory `L["Sound effects"]`, registered after "Shared database".
- Top to bottom: "Play fishing sounds" (`Sound.IsEnabled` / `Sound.SetEnabled`), the volume slider
  (`Sound.Volume` / `Sound.SetVolume`, 0-100 step 10, greyed while the sounds are off, `Sound.Preview()` when the
  value changes by the player), "Fishing sound in the background" (`settings.backgroundSound`), "Splash focus while
  fishing" (`settings.splashFocus`); each with its explanation. The two last write the setting and fire
  `SETTINGS_CHANGED(key)`, like the Features checkboxes.
- `SETTINGS_CHANGED("fishingSounds")` from elsewhere (the minimap menu) updates the checkbox and the slider's state.
- `SettingsUI.OpenSounds()` opens the page (refused in combat like `Open`).

## C5. Minimap menu (`UI/Minimap.lua`, changed)

A checkbox entry `L["Fishing sounds"]`: checked = `Sound.IsEnabled()`, click = `Sound.SetEnabled(not ...)`.

## C6. Command (`Core/Commands.lua`, changed)

`{ name = "sound", description = "open the sound effects settings", run = function() ns.SettingsUI.OpenSounds() end }`
English description; documented in `OneKeyFishing/README.md` (`npm run check`).

## C7. Tools (`tools/addon.mjs`, `tools/check.mjs`, new `tools/sounds.mjs`)

- `ADDON_MEDIA`: every `.ogg` file under `OneKeyFishing/Media/`, packaged by `packageEntries`; `npm run check`
  accepts them and reports any other file type under `Media/`, and a master in `Media/Sounds/` without its nine
  `VolumeNN` steps.
- `npm run sounds`: renders the steps from the masters with ffmpeg (fails with a clear message when ffmpeg is not on
  `PATH`).

## C8. Messages

No new message. `SETTINGS_CHANGED` carries the new keys `fishingSounds`, `soundVolume`, `backgroundSound`,
`splashFocus`.
