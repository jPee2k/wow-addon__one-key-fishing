# Data Model: Fishing Sounds

No saved field changes shape: four new keys get defaults, `savedCVars` keeps `name -> old value`. No `DB_SCHEMA`
bump, no migration.

## Saved: `OneKeyFishingDB.settings` (account-wide, new keys)

| Key | Type | Default | Rule |
|---|---|---|---|
| `fishingSounds` | boolean | `false` | written only by `Sound.SetEnabled` |
| `soundVolume` | integer | `100` | 0-100, a multiple of 10; a saved value out of range or off the grid is clamped and rounded on read (`Sound.Volume()`) |
| `backgroundSound` | boolean | `false` | a `Mode` CVar row setting (live) |
| `splashFocus` | boolean | `false` | a `Mode` CVar row setting (live, lifted in a fight) |

`ApplyDefaults` adds them to existing installs: every new option starts off (spec Assumptions).

## Saved: `OneKeyFishingCharDB.savedCVars` (per character, existing)

`name -> old value` (string), written before a CVar is set, removed when restored. New names may appear:
`Sound_EnableSoundWhenGameIsInBG`, `Sound_MusicVolume`, `Sound_AmbienceVolume`, `Sound_DialogVolume`,
`Sound_EnableSFX`, `Sound_SFXVolume`. The applied value is derived from the row and the old value, not stored.

## Mode CVar row (code, `Fishing/Mode.lua`)

| Field | Meaning |
|---|---|
| `name` | the CVar |
| `value` | a string, or a function `old -> string` (`Sound_SFXVolume`: `max(old, 0.9)`) |
| `setting` | the `settings` key that asks for the row (none: always) |
| `live` | a change of `setting` while the mode is on applies or restores the row at once |
| `combat` | `"lift"`: not wanted while in a fight |

A row is **wanted** when the mode is on, its setting is on (or it has none), and it is not lifted by a fight.

State of one row:

```text
not saved --(wanted)--> saved: old recorded, then value set
saved --(not wanted: exit, setting off, fight start, logout)--> restore:
        current == applied(old) -> set old, drop record
        current != applied(old) -> drop record (the player's value stays)
saved at login (crash) --> restore as above (no row: set old)
```

`Sound_EnableSoundWhenGameIsInBG` is never lifted; the focus rows return at `PLAYER_REGEN_ENABLED` when the mode is
still on.

## Message payload: `FISH_CAUGHT` (changed, compatible)

`items`: list of `{ link, itemID, quantity, quality }`; `quality` is the loot slot's item quality (number, may be
nil). Existing listeners ignore the new field.

## Sound module state (runtime, not saved)

The fight is not kept here: `Mode.InFight()` (Fishing/Mode.lua) tells it.

| Field | Meaning |
|---|---|
| `handles[event]` | the handle of the last sound per event (`bell`, `hook`, `rare`) |
| `hookCast` | the cast ID that already played its hook sound (every `FISHING_CAST_START` is a new cast, so the bell needs none) |
| `token` | increases on every stop; a delayed rare sound plays only with the token it was scheduled under |

## Sound files (packaged)

| Event | Master | Steps | From the author's file |
|---|---|---|---|
| `bell` | `Media/Sounds/bell.ogg` | `Media/Sounds/Volume10/bell.ogg` ... `Volume90/bell.ogg` | `bell_dark_01.ogg` |
| `hook` | `Media/Sounds/hook.ogg` | as above | `retrive_dark_01.ogg` |
| `rare` | `Media/Sounds/rare.ogg` | as above | `notification_dark_01.ogg` |

Paths are under `Interface\AddOns\OneKeyFishing\`. A new or renamed file needs a game restart.
