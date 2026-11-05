# Feature Specification: Interface Language

**Feature Branch**: `001-interface-language`

**Created**: 2026-10-24

**Status**: Draft

**Input**: User description: "OneKeyFishing addon localization. Add the possibility to change language in the
addon's options. The addon is taken automatically the game client language. If in the game the language is
not present, english by default."

## Clarifications

### Session 2026-10-24

- Q: When the player picks another language, does it apply at once or after a UI reload? → A: After a
  reload: a "Reload now / Later" prompt appears; the new language shows everywhere after the reload.
- Q: Are Korean and Chinese offered on clients of another language, whose fonts may lack those characters?
  → A: Yes, every language is offered on every client, named in its own language; a tooltip on the language
  setting warns that Korean and Chinese may show as squares on a client in another language and that
  English can be picked to return.

### Session 2026-11-03 (User Story 3: the next Fishing rank)

Research behind these answers: [research.md](research.md) R11-R16.

- Q: Where do the names in "where to learn the next rank" come from? → A: From the game, by ID, in the client's
  language (zone, sub-zone, book, quest, rank names), so they match the map and the quest log; the addon's own
  English names are only the fallback.
- Q: NPC names (Old Man Heming, Nat Pagle), which the game has no API for? → A: From the game when a tooltip
  can read them, else from a table of the official names per client language, else English.
- Q: How are the sentences built? → A: One complete sentence per way of learning (trainer, book, quest) in
  every language; game names only fill placeholders.
- Q: When does the reminder come? → A: A quiet notice (chat line and toast) as soon as the next rank can be
  learned (skill 50, 125, 225 and character level 10, 20, 35), and a loud one at the cap (75, 150, 225). The
  old "5 points before the cap" warning goes.
- Q: What if the character level is too low? → A: Wait for it: no "can learn" notice until the level is
  reached (also checked on level-up); the rank line shows the level needed.
- Q: The raid warning at the cap shows on every entry into fishing mode. → A: Only the first time per
  session; later entries print a chat line.
- Q: How does the advice stay findable after the toast fades? → A: A permanent "Next rank" line in the
  statistics window with a map pin button, the same in the minimap tooltip and menu, and a clickable map link
  in the chat notice. There is no separate journal.
- Q: Which places get a pin? → A: The book seller and the quest giver. The trainer rank gets text only (any
  fishing trainer; the minimap can track trainers); a pin on the nearest trainer goes to the roadmap.
- Q: Where does the static game data go? → A: A data-only file under `GameData/`; moving the older tables there
  is technical debt for 1.2.0.
- Q: Where is it built? → A: On this branch, in this release (1.1.0), as User Story 3 of this spec; the map pin
  logic becomes a shared module that the catch catalog of 1.2.0 later reuses.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - The addon speaks the client's language (Priority: P1)

A player installs OneKeyFishing on a game client set to a language the addon has a translation for. Without
touching any setting, every text the addon shows (settings, indicator, statistics window, notifications,
minimap menu and tooltips, chat messages, key binding names) appears in that language. On a client whose
language the addon has no translation for, everything appears in English, as it does today.

**Why this priority**: most players never open the options; the automatic choice is what nearly everyone
will see, and the English fallback guarantees nobody gets a broken or empty interface.

**Independent Test**: start the game with a client language that has a translation, check that the addon's
texts are translated; start it with a language that has none, check that they are in English.

**Acceptance Scenarios**:

1. **Given** a fresh install and a client language with a translation, **When** the player logs in, **Then**
   the addon's interface is in that language.
2. **Given** a fresh install and a client language without a translation (for example Russian), **When** the
   player logs in, **Then** the addon's interface is in English.
3. **Given** a translation that lacks some texts, **When** one of those texts is shown, **Then** it appears in
   English instead of being empty or showing an internal key.

---

### User Story 2 - Pick another language in the options (Priority: P2)

A player wants the addon in a language other than the client's, for example a Ukrainian player on an
English or Russian client (the game has no Ukrainian client language). In the addon's options they open a
language list, pick a language, and the addon's interface switches to it. The choice is kept across sessions
and characters on the account. Picking "Game client language" returns to the automatic behaviour of
Story 1.

**Why this priority**: it is the only way to reach Ukrainian, and it serves players whose client language
differs from the language they prefer to read; it builds on the translations of Story 1.

**Independent Test**: on any client, pick a language in the options, confirm the interface switches to it
and is still in that language after logging out and in again, on another character too; pick "Game client
language" and confirm Story 1 behaviour returns.

**Acceptance Scenarios**:

1. **Given** the options are open, **When** the player opens the language list, **Then** it shows "Game
   client language" (selected by default) and every available language, each written in its own language.
2. **Given** the player picks a language, **When** a prompt offers "Reload now" and "Later" and the player
   chooses "Reload now", **Then** after the reload all of the addon's texts are in the picked language.
3. **Given** the player picks a language and chooses "Later", **When** they keep playing, **Then** the
   interface stays in the current language until the next reload or login, which then uses the picked one.
4. **Given** a language was picked, **When** the player logs in again, on this or another character of the
   account, **Then** the addon's interface is still in the picked language.
5. **Given** a language was picked, **When** the player picks "Game client language", **Then** the addon
   follows the client language again, with the English fallback.

---

### User Story 3 - The next Fishing rank, in the client's language and on the map (Priority: P3)

A player levels Fishing. When the next rank can be learned, the addon tells them once, in a short notice,
what the rank is, where to learn it and which character level it needs. The names in that advice (zone,
town, book, quest, the seller or quest giver, the rank) are exactly the ones the player's game client shows
on its map, in its tooltips and in its quest log, whatever language the addon's interface is in. At the cap
the addon says so loudly once. The advice stays in the statistics window and the minimap tooltip, so it is
not lost when the notice fades, and for the book and the quest one click puts the game's own map pin and
navigation arrow on the place.

**Why this priority**: it fixes texts that this feature translated by hand and that do not match what the
player sees on the map (worst for Ukrainian, which has no client), and it turns a 3-second toast into advice
the player can act on. It builds on the translations of Story 1.

**Independent Test**: on an English and on a non-English client, with the addon in another language, raise
Fishing to 50, 75, 125, 150 and 225 (or set a character at those points): check the notices, the names in
them against the map and tooltips, the "Next rank" line, the level wait, and the pin for the book and the
quest.

**Acceptance Scenarios**:

1. **Given** Fishing 49/75 and character level 10 or more, **When** the skill reaches 50, **Then** one quiet
   notice (chat line and toast) says Journeyman Fishing can be learned from any fishing trainer, with the
   hint that capitals and towns have one and the minimap can track trainers.
2. **Given** Fishing 125/150 and character level 15, **When** the notice would come, **Then** no "can learn"
   notice is shown and the "Next rank" line says level 20 is needed; **When** the character reaches level 20,
   **Then** the quiet notice comes.
3. **Given** Fishing reaches 150/150, **When** it happens the first time in a session, **Then** a chat line, a
   toast and a raid-warning style message say the cap is reached and where to learn Expert Fishing; **When**
   the player enters fishing mode again in that session, **Then** only a chat line repeats it.
4. **Given** an English client and the addon in Ukrainian, **When** the Expert advice is shown, **Then** the
   sentence is Ukrainian while the book, the seller, the town and the zone read exactly as the English
   client names them (for example the book "Expert Fishing - The Bass and You", Booty Bay, Stranglethorn
   Vale).
5. **Given** a German client, **When** the Artisan advice is shown, **Then** the quest, Nat Pagle and the
   zone carry the German client's names.
6. **Given** the Expert or Artisan advice, **When** the player clicks the pin button in the statistics
   window or the minimap menu entry, **Then** the game's map pin and navigation arrow point at the seller or
   the quest giver; if the player had set a pin of their own, the addon asks before replacing it. **When**
   the player clicks the map link in the chat notice instead, **Then** the game itself sets the pin on the
   same place and opens the map, as for any map link.
7. **Given** Fishing 300/300, **When** the statistics window or the minimap tooltip is shown, **Then** no
   "Next rank" line appears.
8. **Given** the rank reminder setting is off, **When** a threshold or the cap is reached, **Then** no notice
   is shown; the "Next rank" line stays.

---

### Edge Cases

- A language was picked, and a later addon version no longer offers it: the addon falls back to "Game client
  language" and keeps working.
- The player changes the client's language while "Game client language" is selected: the next session follows
  the new client language.
- Names that come from the game itself (items, zones, spells, quests, NPCs, rank names) stay in the client's
  language whatever the addon's language is; the addon does not translate them. The sentences around them
  (how and where to learn a rank) are the addon's own texts and are translated (User Story 3).
- The client has not loaded the book's or the quest's name yet: the advice uses the English name until the
  game delivers it, then shows the client's name.
- The NPC name cannot be read from the game and the client language has no entry in the addon's table: the
  English name is shown.
- The game does not allow a map pin (an instance, a game rule that turns pins off, a map the addon cannot
  match): no pin button, no map link; the text advice still shows.
- Forever teaches a rank differently from the original game (another source, other requirements): the data
  file is corrected after the in-game check; until then the advice may be wrong, which the checklist covers.
- The diagnostic report used in bug reports stays in English whatever language is chosen, so the author can
  read every report.
- Translated text is longer than the English one: buttons, columns and labels still show it without cutting
  off meaning or overlapping other elements.
- The player picks Korean or Chinese on a client whose fonts lack those characters: the addon's texts may
  show as squares, but the language list stays usable, because "English" and every other language name are
  written in their own script; picking English restores a readable interface.
- Slash commands keep their English names in every language, so instructions shared between players work for
  everyone.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The addon MUST show every text it writes itself in the effective language: settings,
  indicator, statistics window, notifications, minimap button menu and tooltips, item tooltip lines, chat
  messages, and the names of its key bindings.
- **FR-002**: The default setting MUST be "Game client language": the effective language is the client's
  language when the addon has a translation for it, and English otherwise.
- **FR-003**: The options MUST offer a language setting listing "Game client language" and every available
  language, each language named in its own language.
- **FR-004**: The supported languages are the ones the game client offers, with Ukrainian in place of Russian:
  English, Deutsch, Español (EU), Español (AL), Français, Українська, 한국어, Português, 繁體中文, 简体中文.
  Each language is always named in its own language. There is no Russian translation; a Russian client gets
  English unless another language is picked.
- **FR-005**: Ukrainian MUST be reachable only by picking it in the options, since no client reports it.
- **FR-006**: The chosen language MUST be kept for the whole account and survive logout, reload and game
  restarts.
- **FR-007**: Any text missing from a translation MUST appear in English.
- **FR-008**: A language change MUST take effect through a UI reload, never instantly: right after the
  change, a prompt with "Reload now" and "Later" appears. "Reload now" reloads the UI; "Later" keeps the
  current language until the next reload or login. The addon never reloads without the player's click.
- **FR-009**: The diagnostic report MUST stay in English, and slash command names MUST stay the same in every
  language.
- **FR-010**: Choosing a language MUST NOT change any game data matching: the addon keeps working the same on
  every client language and with every interface language.
- **FR-011**: This feature MUST ship a complete translation for every supported language: Ukrainian and the
  eight other non-English languages of FR-004.
- **FR-012**: The list in the options MUST show only languages that have a translation in the installed
  version, plus "Game client language" (this matters for future partial or added translations).
- **FR-013**: Every language MUST be offered on every client language. The language setting MUST carry a
  tooltip warning that Korean and Chinese text may show as squares on a client in another language, and that
  picking English brings the readable interface back.
- **FR-014**: The addon's texts MUST be drawn with the game's own fonts wherever the game can pick the right
  font for the script, so that Korean and Chinese have the best chance to show on a client in another
  language.

#### Added during implementation (User Stories 1 and 2)

- **FR-026**: On a client language without a translation, with the setting left on "Game client language", the
  addon MUST say once per account, in English, that other languages (naming Ukrainian) can be picked in the
  settings; it switches nothing by itself. Picking a language in the menu counts as having seen the hint
  (`settings.languageHintShown`).
- **FR-027**: The TOC MUST carry `## Notes-<code>` and `## Category-<code>` for every translation with a client
  locale (all but Ukrainian), so the game's addon list shows the description and the category (Professions) in
  the client's language; these lines follow the client, not the addon's language setting.
- **FR-028**: Decimal numbers in the statistics MUST use the game client's decimal separator (`DECIMAL_SEPERATOR`),
  as gold amounts do, whatever the interface language.

#### User Story 3: the next Fishing rank

- **FR-015**: In the next-rank advice, the zone, the sub-zone, the book, the quest and the rank names MUST be
  read from the game client by ID, in the client's language. Until the client delivers a name, the addon's
  English name is used, and the advice is refreshed when the name arrives.
- **FR-016**: NPC names in the advice MUST come from the game client when it can provide them, else from the
  addon's table of official names for the client's language, else in English. They follow the client's
  language, never the addon's interface language.
- **FR-017**: Each way of learning a rank (trainer, book, quest) MUST have its own complete sentence in every
  language; game names only fill placeholders, so each language can build correct grammar.
- **FR-018**: A quiet notice (chat line and toast) MUST appear once per session per rank when the next rank
  can be learned: skill 50 and level 10 for Journeyman, skill 125 and level 20 for Expert, skill 225 and
  level 35 for Artisan. It replaces the warning 5 points before the cap. "Once per session" means it comes
  again after each login or reload until the rank is learned.
- **FR-019**: While the character level is below the rank's requirement, the "can learn" notice MUST wait;
  it comes once the level is reached (including right after a level-up) if the skill is still enough.
- **FR-020**: At the cap (75, 150, 225) the addon MUST show a chat line, a toast and a raid-warning style
  message the first time in a session; on later entries into fishing mode in that session, only a chat line.
  When the level is still too low, the cap message names the level needed. When the skill reaches the
  cap and the "can learn" threshold at once (Artisan: both 225), only the cap message is shown.
- **FR-021**: The statistics window MUST show a permanent "Next rank" line under the skill line (rank, how
  and where to learn it, the level needed while it is not reached), and the minimap button tooltip MUST
  show the same advice. Nothing is shown when there is no next rank (300) or Fishing is not learned.
- **FR-022**: For the book and the quest, the player MUST be able to set the game's own map pin with the
  navigation arrow on the seller or the quest giver: a pin button next to the "Next rank" line, a minimap
  menu entry and a clickable map link in the chat notice. Through the pin button and the menu entry, a pin
  the player set themselves is replaced only after a confirmation, and the navigation arrow is turned on.
  The chat link is the game's standard map link and behaves like any other: the game sets the pin and opens
  the map at once, without the addon's confirmation or arrow. Where the game allows no pin, the pin controls are hidden. The trainer rank has no
  pin; its sentence points to capitals and towns and to the minimap's trainer tracking.
- **FR-023**: The existing setting "Warn when the Fishing rank is capped" becomes the switch for all rank
  notices and is renamed "Remind me about the next Fishing rank" (the saved key `skillCapWarning` stays);
  the "Next rank" line is always shown.
- **FR-024**: The static data of the advice (ranks, skill and level requirements, item, quest, area, NPC and
  map IDs, coordinates, NPC names per client language, English fallback names) MUST live in a data-only file
  under `GameData/`, separate from the logic.
- **FR-025**: The diagnostic report MUST show the next-rank state, where each name came from (game, table or
  English) and the pin target; it stays in English (FR-009).

### Key Entities

- **Language**: one entry of the supported list; has a native name shown to the player and either matches a
  game client language or (Ukrainian) does not.
- **Language preference**: the account-wide choice, either "Game client language" or one specific language.
- **Translation**: the set of the addon's texts in one language; may be incomplete, gaps are filled from
  English.
- **Rank step**: what follows a rank cap: the next rank, the skill and level from which it can be learned, and
  its learning source.
- **Learning source**: a trainer (any), a book (item, seller, place) or a quest (quest, giver, place); a place
  has a sub-zone, a zone, candidate map IDs and coordinates.
- **Map pin target**: a map and a point where the game's own pin can be set; absent where the game allows no
  pin.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: On a client language that has a translation, 100% of the addon's own visible texts appear in
  that language with no setting changed.
- **SC-002**: On a client language without a translation, 100% of the addon's texts appear in English; no
  empty labels or internal keys appear in any language.
- **SC-003**: A player can switch the addon to another language in under 30 seconds from opening the options.
- **SC-004**: A chosen language persists across 100% of logouts, reloads and character switches on the
  account.
- **SC-005**: Every core action (fishing key, gear swap, lures, statistics, auction scan) behaves the same in
  every interface language and on every client language.
- **SC-006**: In every shipped language, no text in the addon's windows is cut off or overlaps another element.
- **SC-007**: On every client language, 100% of the game names in the next-rank advice (zone, sub-zone, book,
  quest) read exactly as the client shows them on its map, in tooltips and in the quest log; rank names do
  too when the client provides them as spell subtext (research R12), otherwise they are the addon's
  translation.
- **SC-008**: From the statistics window, a player sets the map pin on the book seller or the quest giver with
  one click (two when a pin of their own has to be replaced).
- **SC-009**: The rank notices never repeat the raid-warning style message more than once per session per
  rank.

## Assumptions

- Translations are written as normal text in their own language, following `docs/languages.md`. The author
  reviews the Ukrainian one; the other eight are prepared without a native-speaker review in this release, so
  they use plain, consistent wording and game terms as the client names them, and volunteers (CurseForge
  localization tool or pull requests) may correct them later.
- Latin with accents and Cyrillic show on every client (Ukrainian uses the Cyrillic the game already
  supports for Russian). Korean and Chinese show on clients in those languages; on other clients it depends
  on the game's fonts (FR-013, FR-014). On the author's English Forever client the font cache already holds
  the Latin font and the Traditional Chinese font (`bkai00m.ttf`); the Korean and Simplified Chinese fonts are
  to be confirmed in game.
- Game-provided names (items, zones, spells, quests, NPCs) are never translated by the addon: they come from
  the client (User Story 3 reads them by ID).
- WoW Forever teaches Fishing ranks as the original game does (research R11): Journeyman from any trainer,
  Expert from the book sold in Booty Bay, Artisan from Nat Pagle's quest in Dustwallow Marsh, nothing
  faction-bound. The IDs, maps and coordinates come from Wowhead Classic and are confirmed in game after the
  launch (2026-11-04).
- Existing saved settings remain valid; players upgrading get "Game client language" by default.
