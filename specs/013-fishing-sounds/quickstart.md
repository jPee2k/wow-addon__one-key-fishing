# Quickstart: Fishing Sounds

How to prove the feature works: what the automated tests prove, then what only the game can show.

## Prerequisites

- Node.js 18+, `npm install` once.
- ffmpeg on `PATH` only to re-render the volume steps (`npm run sounds`); the rendered files are committed.
- In game: a character with Fishing, a key bound to "Fishing action", water nearby. A game **restart** after
  installing (new files).

## Automated

```text
npm run check   # TOC, media files (every master has its nine steps), locales complete, manual lists /okf sound
npm test        # tests/fishing/sound_*_test.lua, cvar_sync_test.lua, cvar_list_test.lua, tests/catch, tests/ui
```

What the tests prove (research R11):

| Spec | Proven by |
|---|---|
| FR-005 to FR-008, US1 | sound_events_test: bell once per cast; hook on loot or a fish error line, once per cast, not on a movement stop; rare once per loot with an Uncommon or better item, after the hook; nothing with the sounds or the mode off |
| FR-010, FR-011, US2 | sound_volume_test: the file per step, nothing at 0 %, the previous handle stopped |
| FR-013 to FR-016, US3, US4 | cvar_sync_test: both options on enter and restored on exit, applied at once when switched while fishing, the player's change kept, effects at `max(old, 0.9)`, a crash record restored at login |
| FR-018 | sound_combat_test, cvar_sync_test: silence and the focus lifted in a fight, both back after it, the background kept |
| FR-017 | cvar_list_test: ten CVars in the debug report |
| FR-004a, FR-019 | sound_page_test: greyed slider, the minimap entry and the page agree; check: all languages, `/okf sound` in the manual |

## In game (the author; `docs/checklists/sounds.md`, closes V46 to V49)

1. `/okf sound` opens "Sound effects"; every option is off; the slider is greyed. Turn the sounds on: the slider
   wakes; moving it plays the hook sound louder or quieter.
2. Fishing mode on, cast: the bell when the bobber lands. Hook at the splash: the hook sound within half a second.
   Hook too early: the hook sound too ("No fish are hooked."). Walk away while the line is out: no hook sound. (V46, V47)
3. Loot a green item: the hook sound, then the notification. A white fish: no notification.
4. Background on, fishing, alt-tab: the splash and the sounds are still heard; leave the mode: Options -> Audio ->
   "Sound in Background" is back to its old value. (V49)
5. Splash focus on with music playing: music, ambience, dialog stop; leave the mode: they come back at their old
   volumes. Change the music volume by hand while fishing: it keeps that value after leaving. (V48)
6. A fight while fishing ("Leave fishing mode when attacked" off): no addon sound, music back at once; after the
   fight the focus returns. With it on: after the fight the mode ends and the settings are back.
7. `/reload` while fishing, and a forced quit while fishing then login: the audio settings are back.
8. Minimap menu: "Fishing sounds" switches them; the open page follows.
9. Another interface language: the page is translated.
