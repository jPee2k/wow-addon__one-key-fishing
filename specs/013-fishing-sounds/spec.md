# Feature Specification: Fishing Sounds

**Feature Branch**: `013-fishing-sounds`

**Created**: 2026-11-16

**Status**: Draft

**Input**: User description: "Custom fishing sounds. A separate 'Sound effects' page in the addon settings with: a
checkbox (on/off), off by default; a checkbox for fishing sound in the background (off by default); a volume control
for the custom fishing sounds (when they are on). I prepared 3 sounds (a bite, the hook (pulling the fish), a rare
item caught and in the loot). The sounds are in static/audio; they are my own sounds, so no rights are infringed."
(Translated from Ukrainian.) Research input: [docs/history/sounds-plan.md](../../docs/history/sounds-plan.md).

## Clarifications

### Quiz on the gameplay, 2026-11-16

- Q: The game tells an addon nothing when a fish bites: the splash exists only as the game's own sound, and the
  example addon (ForeverFishing) does not play a sound of its own at the bite either. What replaces the "bite"
  sound? → A: Both: (1) a **splash focus** while fishing: the game's music, ambience and dialog are silenced and
  the effects raised, so the game's own splash stands out, everything put back afterwards; (2) the **bell** plays
  when the bobber lands on the water (the line is out: wait for the bite).
- Q: When does the "hook" sound play? → A: When the player presses the fishing key to hook, while the line is out,
  whether a fish is caught or not. (Planning: the addon runs no code on that press, so the sound follows the
  press's result, one server round trip later; research R1, FR-007.)
- Q: What is a "rare item" in the loot? → A: Quality Uncommon (green) or better.
- Q: The background sound option (one game setting for all game sound; there is none for the addon alone)? → A: Only
  while fishing mode is on; the player's own setting comes back when the mode ends.
- Q: Which file plays for which event? → A: `bell_dark_01` when the bobber lands, `retrive_dark_01` on the hook key,
  `notification_dark_01` for a rare item.
- Q: The hook sound already played; a rare item is in the same loot: does the rare sound play too? → A: Yes, in
  addition.

### Session 2026-11-16

- Author's direction: the feature follows the project's style and architecture like the other features (a settings
  page like the existing ones, its rules in a module of the game layer, the page in the UI layer, joined by
  messages), is translated into every language of the addon, and reacts to combat.
- Q: What happens to the sounds when a fight starts while fishing? → A: A pause for the fight: at the start of a
  fight the addon's sounds stop and stay silent, and the splash focus is lifted at once (music, ambience and dialog
  come back). After the fight, if fishing mode is still on, the focus and the sounds come back. The background
  sound option is not touched by a fight.
- Q: Is there a quick way to the sounds outside the settings page? → A: Both: a slash command `/okf sound` that
  opens the "Sound effects" page, and an on/off entry for the fishing sounds in the minimap button's menu.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Hear the fishing sounds (Priority: P1)

A player turns on the addon's fishing sounds on the new "Sound effects" settings page. From then on, while fishing
mode is on, a bell rings when the bobber lands on the water, a short sound plays when they press the fishing key to
hook, and a distinct notification plays when the loot holds an Uncommon or better item.

**Why this priority**: the sounds are the feature; everything else tunes them.

**Independent Test**: turn the sounds on, enter fishing mode, cast, hook, and loot a green item: three different
sounds are heard at the three moments. Turn them off: none plays.

**Acceptance Scenarios**:

1. **Given** the sounds are on and fishing mode is on, **When** the bobber lands on the water, **Then** the bell
   plays once.
2. **Given** the sounds are on and the line is out, **When** the player presses the fishing key to hook, **Then**
   the hook sound plays on the press's result (the loot, or the game's "fish got away" / "no fish hooked"
   line) within half a second, whether a fish is caught, got away, or none had bitten.
3. **Given** the sounds are on, **When** the fishing loot holds one or more Uncommon or better items, **Then** the
   rare sound plays once for that loot, in addition to the hook sound.
4. **Given** the loot holds only Poor or Common items, **When** it opens, **Then** no rare sound plays.
5. **Given** the sounds are off (the default), **When** the player fishes, **Then** the addon plays none of its
   sounds.
6. **Given** the sounds are on and fishing mode is off, **When** the player fishes by other means, **Then** the
   addon plays none of its sounds.
7. **Given** any state, **When** the player picks the fishing sounds entry in the minimap button's menu, **Then**
   the sounds switch on or off, and the settings page shows the same state; `/okf sound` opens that page.

---

### User Story 2 - Set the volume of the addon's sounds (Priority: P2)

On the same page a volume control sets how loud the addon's three sounds are, without touching any game volume.

**Why this priority**: the files have one loudness; players' setups differ, and a sound that is too loud or too
quiet is soon turned off.

**Independent Test**: set the volume to 30 %, hear the sample; set it to 100 %, hear it louder; the game's own
volume settings are unchanged in Options.

**Acceptance Scenarios**:

1. **Given** the sounds are on, **When** the player moves the volume control, **Then** a sample plays at the chosen
   volume and the next fishing sounds use it.
2. **Given** the sounds are off, **When** the page is shown, **Then** the volume control is greyed out and cannot be
   changed.
3. **Given** the volume is 0 %, **When** a fishing event happens, **Then** no addon sound plays.
4. **Given** any volume, **When** the player opens the game's audio options, **Then** every game volume is what it
   was before.

---

### User Story 3 - Hear fishing with the game in the background (Priority: P2)

A player who fishes while another window is in front turns on "Fishing sound in the background". While fishing mode
is on, the game keeps its sound (the game's splash and the addon's sounds) when its window is not in focus. When
fishing mode ends, the game's own background sound setting is what it was before.

**Why this priority**: the splash is the cue to hook; without background sound a player who alt-tabs hears nothing.

**Independent Test**: turn the option on, enter fishing mode, switch to another window: the splash and the addon's
sounds are heard. Leave fishing mode: the game's "Sound in Background" option is back to its old value.

**Acceptance Scenarios**:

1. **Given** the option is on and the game's own background sound is off, **When** fishing mode starts, **Then**
   game sound continues while the window is in the background.
2. **Given** the same, **When** fishing mode ends (by the key, a fight, logout, `/reload`, or the next login after a
   crash), **Then** the game's background sound setting is back to off.
3. **Given** the player changed the game's background sound setting by hand while fishing, **When** fishing mode
   ends, **Then** the player's new choice is kept.
4. **Given** the option is off (the default), **When** fishing mode starts, **Then** the game's background sound
   setting is not touched.
5. The option works whether the addon's own sounds are on or off.

---

### User Story 4 - Make the game's splash stand out (Priority: P3)

A player turns on "Splash focus while fishing". While fishing mode is on, the game's music, ambience and dialog are
silent and the sound effects are on and loud enough, so the bobber's splash is easy to hear. When fishing mode ends,
the game's audio is as it was.

**Why this priority**: it is the only way to help with the bite itself, which the addon cannot see; it changes the
game's audio, so it is a separate choice.

**Independent Test**: with music playing, turn the option on and enter fishing mode: music and ambience stop, the
splash is clear. Leave fishing mode: music and ambience come back at their old volume.

**Acceptance Scenarios**:

1. **Given** the option is on, **When** fishing mode starts, **Then** music, ambience and dialog are silenced and
   sound effects are on at a volume of at least 90 %.
2. **Given** the same, **When** fishing mode ends in any way (as in Story 3), **Then** every audio setting the
   focus changed is back to its old value.
3. **Given** the player changed one of those settings by hand while fishing, **When** fishing mode ends, **Then**
   that setting keeps the player's new value; the others are put back.
4. **Given** the option is off (the default), **When** fishing mode starts, **Then** no game audio setting changes.
5. **Given** the option is turned on or off while fishing mode is on, **When** it changes, **Then** the focus starts
   or ends at once.

---

### Edge Cases

- The game's master sound or all sound is off: the addon's sounds follow it and stay silent; the addon does not turn
  game sound on (only the splash focus turns sound effects on, and only while fishing).
- Two events close together (the hook sound and the rare sound of the same catch): both are heard; a new sound of the
  same event stops the previous one of that event.
- A loot with several green items: the rare sound plays once.
- An item the game client does not know yet (items hidden until found in WoW Forever): its quality is read by its ID
  when the client has it, else from the loot link; if neither tells the quality, no rare sound plays for it.
- The player presses the fishing key twice quickly while the line is out: one hook sound per cast.
- The bobber does not land (no water, too far, interrupted cast): no bell.
- A fight starts while fishing (FR-018): the addon's sounds stop and none plays during the fight; the splash focus
  is lifted at once. When the fight ends and fishing mode is still on, the focus is applied again and the sounds
  play again. When the fight ends fishing mode ("Leave fishing mode when attacked"), the background setting is put
  back with the other settings of fishing mode and the focus stays lifted.
- The splash focus option is turned on during a fight: it takes effect when the fight ends.
- The player turns the sounds off while one plays: it stops.
- The game crashes or the computer turns off while fishing: the next login puts back the audio settings the focus
  and the background option changed, like the other settings of fishing mode.
- Game audio settings are shared by every character on the computer: the restore at the next login happens when the
  character who fished logs in.

## Requirements *(mandatory)*

### Functional Requirements

**The settings page**

- **FR-001**: The addon's settings MUST have a separate page "Sound effects", next to the existing pages.
- **FR-002**: The page MUST hold, in this order: "Play fishing sounds" (off by default); the volume of the addon's
  sounds (greyed out while the sounds are off); "Fishing sound in the background" (off by default); "Splash focus
  while fishing" (off by default). Each option has a short explanation under it; the background and focus texts say
  that they change game audio settings for the time of fishing mode only.
- **FR-003**: Every option MUST be saved per account and survive `/reload` and logout.
- **FR-004**: Every text on the page MUST be translated into all of the addon's languages.
- **FR-004a**: The slash command `/okf sound` MUST open the "Sound effects" page (listed in `/okf` help and in the
  manual), and the minimap button's menu MUST have an entry that turns the fishing sounds on or off and shows their
  current state; both change the same saved option as the page's checkbox, and an open page shows the change.

**The addon's sounds**

- **FR-005**: The addon MUST play its sounds only while the sounds are on and fishing mode is on, except the
  volume sample the player asks for by moving the volume control (FR-010).
- **FR-006**: The bell MUST play once when the line is cast (the fishing channel starts, the bobber flies out;
  review 3 of 2026-11-16: the player-facing texts say "when you cast").
- **FR-007**: The hook sound MUST play on the result of the player's hook press while the line is out (the fishing
  loot, or the game's "fish got away" or "no fish hooked" line), within half a second of the press, once per cast,
  whatever the result; a line that ends without a press (moving, the channel running out) plays no hook sound.
- **FR-008**: The rare sound MUST play once per fishing loot that holds at least one item of quality Uncommon or
  better, recognized by the item's ID; it plays in addition to the hook sound.
- **FR-009**: The addon's sounds MUST be the three files the author supplied, shipped with the addon, played on the
  game's master channel, so they are heard with sound effects off but follow the game's master volume and its "all
  sound" switch.
- **FR-010**: The volume control MUST range 0-100 % in steps of 10 %, default 100 %, and MUST change only the
  addon's sounds; 0 % plays nothing. Moving it MUST play a sample at the new volume.
- **FR-011**: A new sound of an event MUST stop the previous sound of the same event; turning the sounds off and
  leaving fishing mode MUST stop every sound the addon started.
- **FR-012**: The sounds are notices only: no sound, and nothing in this feature, MAY cast, hook, loot or act in the
  game for the player.

**Game audio settings changed for fishing mode**

- **FR-013**: With "Fishing sound in the background" on, entering fishing mode MUST turn on the game's background
  sound setting; with "Splash focus while fishing" on, it MUST silence music, ambience and dialog and make sound
  effects on and at least 90 %.
- **FR-014**: Every game audio setting changed by FR-013 MUST be recorded before it is changed and put back when
  fishing mode ends (exit, a fight, logout, `/reload`) and at the next login after a crash, the same way as the
  other settings fishing mode changes.
- **FR-015**: A setting the player changed by hand while fishing MUST keep the player's value on restore.
- **FR-016**: Switching either option while fishing mode is on MUST apply or restore its settings at once; neither
  option changes any game setting outside fishing mode.
- **FR-017**: The debug report (`/okf debug`) MUST show the three switches of the page, the volume and the game audio
  settings this feature changes.

**Combat**

- **FR-018**: At the start of a fight the addon MUST stop its sounds and play none until the fight ends, and MUST
  lift the splash focus at once (every audio setting it changed back to the value before fishing). When the fight
  ends and fishing mode is still on, it MUST apply the focus again (when that option is on) and play its sounds
  again. A fight MUST NOT change the background sound option, which follows fishing mode only.

**Style**

- **FR-019**: The "Sound effects" page MUST look and behave like the addon's other settings pages (the same
  widgets, layout, fonts and greyed-out state), and every text on it MUST come from the addon's translations,
  with all languages complete in the same change.

### Key Entities

- **Sound options** (account-wide): sounds on/off, volume (0-100, step 10), background sound on/off, splash focus
  on/off.
- **Fishing sound**: one of three events (bobber landed, hook key, rare loot) and its file.
- **Saved audio settings** (per character, existing record of fishing mode): the game audio settings fishing mode
  changed, with the value before the change and the value applied. The focus settings leave the record when a
  fight lifts the focus and enter it again when the focus comes back.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: With the sounds on, each of the three events is heard within half a second of happening, in 10 out of
  10 tries in game.
- **SC-002**: With every option of the page off (the default for a new and an updated install), a fishing session
  of any length plays no addon sound and changes no game audio setting.
- **SC-003**: After any end of fishing mode (exit, fight, logout, `/reload`, crash then login), 100 % of the game
  audio settings the feature changed are back to their old values, except those the player changed by hand.
- **SC-004**: At every volume step the heard loudness of the addon's sounds changes, and no game volume setting
  changes.
- **SC-005**: A player finds and sets up the "Sound effects" page in under one minute without the manual.
- **SC-006**: In a fight during fishing, 0 addon sounds play, and music, ambience and dialog are audible from the
  first moment of the fight to its end.

## Assumptions

- The three files in `static/audio` (`bell_dark_01.ogg`, `retrive_dark_01.ogg`, `notification_dark_01.ogg`) are the
  author's own work and ship under the addon's MIT license; the manual credits them.
- The bite itself cannot be detected: the game gives addons no event for it. The splash focus (Story 4) is the
  feature's answer, as in the example addon.
- "Bobber lands" is the start of the fishing channel; "hook" is the fishing key pressed during the channel, the key
  the addon already turns into the game's interact action. How the key press is observed without breaking the
  secure binding is a planning question (a `VERIFY` item if it needs the game).
- The splash focus values follow the example addon: music, ambience and dialog to 0 %, sound effects on and at least
  90 %, the master volume and the game's "all sound" switch untouched (a player who muted the game on purpose is not
  overruled).
- The volume steps of 10 % are a consequence of the game playing an addon's file at the channel's volume only; the
  files are prepared at each step (docs/history/sounds-plan.md, section 4).
- Rare means quality Uncommon (green), Rare, Epic or better; fished containers and junk are not rare unless their
  quality is.
- Existing installs get every new option off: nothing changes for a player until they choose it.
- The game lets an addon change its audio settings during a fight (they are not combat-protected), so the focus can
  be lifted at the first moment of the fight; if the game refuses, the focus is lifted as soon as it allows.
- The half second of SC-001 and FR-007 counts from the game's answer to the hook, one server round trip after the
  press: a player with a connection slower than that hears the sound later, never before the result.
- SC-005 is checked in game only (`docs/checklists/sounds.md`).
- The in-game behaviour (file playback by path, the background setting taking effect at once, the focus values
  being accepted) is confirmed by the author with an in-game checklist; until then the code carries `VERIFY`
  markers.
