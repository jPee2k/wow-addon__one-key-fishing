# In-game checklist: the fishing sounds

**Feature**: the "Sound effects" settings page: the fishing sounds, their volume, game sound in the background while
fishing, the splash focus, the pause in fights (`specs/013-fishing-sounds`).
**Closes**: V46, V47, V48, V49, V50, V51 of `specs/013-fishing-sounds/verification.md`, and SC-005 of the spec.
**Needs**: one character that has learned Fishing, a key bound to "Fishing action", water nearby, a place with a
mob to start a fight; a second window (a browser) to put in front for step 4; a second interface language for step 9.

## Setup

1. Install the build (`npm run install-addon`), or link the working folder once (`npm run link`); restart the game
   completely (new files: `Fishing/Sound.lua` in the TOC and the sounds under `Media/Sounds/`).
2. Log in on the fishing character. In Options -> Audio note "Sound in Background": ____, and the volumes: music
   ____, ambience ____, dialog ____, effects ____ (with "Enable Sound Effects": ____).
   2026-11-16 (enUS client, addon linked): master 60 %, music 25 %, effects 90 %, ambience 70 %, dialog 90 %; Enable
   Sound, Music, Sound Effects, Dialog and Ambient Sounds on. "Sound in Background": not noted yet.
3. Turn music on in Options -> Audio if it is off, so step 5 can hear it stop.

## Steps

1. [x] **The page** (V50, SC-005, FR-001, FR-002, FR-010): time yourself from Esc to a working setup. Open Options ->
   AddOns -> OneKeyFishing -> "Sound effects" (or `/okf sound`). Expected: the four options in this order, every one
   off, the volume slider greyed. Turn on "Play fishing sounds": the slider wakes; move it to 30 %, then 100 %: the
   hook sound plays each time, quieter at 30 %. Time taken: ____ (under a minute). The game's volumes in Options ->
   Audio are unchanged.
   In game 2026-11-16 (enUS, linked): the four options in order, the slider greyed while off and usable when on,
   "100%" next to it, the sample plays at every step and is quieter at 30 %; set up in a few seconds; no Lua error;
   the texts do not overlap (screenshot). V50 confirmed; V46 playback side seen (the stop is checked in step 2).
2. [x] **The bell and the hook** (V46, V47, FR-006, FR-007): fishing mode on, cast. Expected: the bell as the line goes
   out. Hook at the splash: the hook sound within half a second, then the loot. Cast again and press the key
   before any splash: "No fish are hooked." and the hook sound. Cast again, let a fish bite and wait until it gets
   away, then press: the hook sound with "Your fish got away!" if the game says so. Cast again and walk away: no
   hook sound. Turn "Play fishing sounds" off mid-sound: it stops.
   Partly 2026-11-16 (enUS, linked): the bell on the cast, the hook sound with the loot, no hook sound when walking
   away, the stop mid-sound: as expected, no Lua error. "No fish are hooked." played no hook sound: the addon read
   only `UI_ERROR_MESSAGE`; it now reads `UI_INFO_MESSAGE` too. Checked again after `/reload`: the hook sound plays,
   the line was `UI_INFO_MESSAGE 417 No fish are hooked.`, and the too-early press ends the line. V46, V47 confirmed.
3. [ ] **The rare sound** (V51, FR-008): fish until a green (Uncommon) or better item comes (or a fished container of
   that quality). Expected: the hook sound, then the notification a moment later. A white fish: no notification.
   Skipped 2026-11-16: no green item caught yet; the author reports back when one comes. While fishing, note too
   whether "Your fish got away!" ever shows without a press (a bite left alone): it would play a hook sound then.
4. [x] **In the background** (V49, US3): turn on "Fishing sound in the background", enter fishing mode, cast and put
   the browser in front of the game. Expected: the splash and the addon's sounds are heard. Options -> Audio shows
   "Sound in Background" on. Leave fishing mode: it is back to the value of setup step 2. Turn the option off and
   on again while fishing: the game setting follows at once.
   In game 2026-11-16 (enUS): all as expected; V49 confirmed.
5. [x] **The splash focus** (V48, US4): turn on "Splash focus while fishing", enter fishing mode. Expected: music,
   ambience and dialog stop, effects are on and at least 90 % (Options -> Audio). Leave the mode: every value of
   setup step 2 is back. Enter again, change the music volume by hand in Options -> Audio, leave the mode: the music
   keeps your new value, the rest comes back.
   Partly 2026-11-16 (enUS): with the focus on, entering fishing mode set music, ambience and dialog to 0 %; effects
   stayed at 90 % (already at the floor), master 60 % untouched; seen at once in Options -> Audio (V48: the entry
   side). The author reports the audio settings change with the mode, and no Lua error since login. Then: music set
   to 40 % by hand while fishing stayed 40 % after leaving the mode; ambience, dialog and effects came back to their
   values of setup step 2 (FR-015). Open: a fight (step 6).
6. [x] **A fight** (V48, FR-018): with "Leave fishing mode when attacked" off, the sounds and the focus on, fishing,
   attack a mob. Expected: no addon sound in the fight, music comes back at once; after the fight the focus returns
   (music stops again) and the next cast rings the bell. With "Leave fishing mode when attacked" on: after the fight
   the mode ends and every audio setting is back.
   In game 2026-11-16 (enUS): both cases as expected; V48 confirmed.
7. [x] **`/reload` and a crash** (FR-014): fishing with both game options on, `/reload`. Expected: the mode resumes
   with the options applied. Then quit the game from the task manager while fishing and log in: the chat says the
   game settings were restored, and Options -> Audio shows the values of setup step 2.
   In game 2026-11-16 (enUS): after `/reload` the mode resumed with the focus and the background sound; after a
   forced quit the login line came and every value was back.
8. [x] **The minimap menu** (FR-004a): right-click the minimap button. Expected: a text entry "Turn fishing sounds
   off" while they are on, "Turn fishing sounds on" while off (no checkbox); clicking it switches the sounds, the
   next menu shows the other text, and the open "Sound effects" page follows.
   In game 2026-11-16 (enUS): as expected.
9. [x] **Another language** (FR-004): switch the interface language (the language setting, then reload). Expected:
   the page, its explanations and the minimap entry are translated; nothing in English but `/okf sound`.
   In game 2026-11-16 (ukUA interface on an enUS client): the page, the four options and their explanations are in
   Ukrainian, nothing overlaps (screenshot).

## Results

- Date, build, client language: 2026-11-16, game 1.60.1, enUS client (ukUA interface for step 9), `013-fishing-sounds`
  linked.
- Problems found: "No fish are hooked." comes as `UI_INFO_MESSAGE`, so the first build played no hook sound for it
  (fixed the same day, checked again); the minimap entry was made a text button at the author's request. V46 to V50
  confirmed. Open: step 3 (no green item caught yet).

What happens next is in [release-plan.md](../release-plan.md).
