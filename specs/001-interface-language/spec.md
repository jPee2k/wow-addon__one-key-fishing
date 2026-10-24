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

### Edge Cases

- A language was picked, and a later addon version no longer offers it: the addon falls back to "Game client
  language" and keeps working.
- The player changes the client's language while "Game client language" is selected: the next session follows
  the new client language.
- Names that come from the game itself (items, zones, spells) stay in the client's language whatever the
  addon's language is; the addon does not translate them. Fishing rank names and where to learn a rank are
  the addon's own texts and are translated.
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

### Key Entities

- **Language**: one entry of the supported list; has a native name shown to the player and either matches a
  game client language or (Ukrainian) does not.
- **Language preference**: the account-wide choice, either "Game client language" or one specific language.
- **Translation**: the set of the addon's texts in one language; may be incomplete, gaps are filled from
  English.

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
- Game-provided names (items, zones, spells) are out of scope: they always come from the client.
- Existing saved settings remain valid; players upgrading get "Game client language" by default.
