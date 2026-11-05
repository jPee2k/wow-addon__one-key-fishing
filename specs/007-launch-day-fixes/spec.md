# Feature Specification: Launch Day Fixes

**Feature Branch**: `001-interface-language` (spec 007 is built on the 1.1.0 branch)

**Created**: 2026-11-05

**Status**: Draft

**Input**: User description: "Fixes found in the first in-game test of 1.1.0 (2026-11-05, game 1.60.1 build 70790,
EU realm, Russian client), to be shipped in 1.1.0: (1) the Fishing gear settings page shows 14 empty rows with
Remove buttons on its first view in a session, and hovering one raises a Lua error; (2) `/okf debug` aborts its
Gear section when no lure is in the bags; (3) the addon's popups show their buttons in the client's language
instead of the addon's; (4) the minimap tooltip, the settings key line and the indicator show only one of the two
keys a player bound to an action; (5) in the statistics window, a Scan button that does not fit moves to its own
row at the right edge instead of wrapping to the left; (6) with Korean or Chinese, the last line of the minimap
tooltip reaches past the tooltip's bottom edge. Out of scope: the quest title of the Artisan quest is not given by
the client (checked later at Nat Pagle)."

## Context

WoW Forever opened on 2026-11-04. The first in-game run of the 1.1.0 checklists
([interface-language.md](../../docs/checklists/interface-language.md),
[fishing-mode.md](../../docs/checklists/fishing-mode.md)) on a level 1 character found the problems below; their
details are in the Results of `interface-language.md`. Release 1.1.0 (interface languages) waits for these fixes
(`docs/release-plan.md`). The work is built on `001-interface-language` itself, so 1.1.0 ships the languages and
the fixes together.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - The Fishing gear page works on its first view (Priority: P1)

A player opens the addon's settings and goes to the Fishing gear page for the first time in a session. They see
only the items they added (or "No items yet."), never rows without an item, and moving the mouse over the page
never produces an error.

**Why this priority**: today the page shows 14 empty rows with Remove buttons on its first view and hovering one
raises a Lua error. Every player who opens the page meets it; it looks broken and the error window interrupts play.

**Independent Test**: on a character with no extra gear, `/reload`, open the settings, open Fishing gear and move
the mouse over the whole list area.

**Acceptance Scenarios**:

1. **Given** a character with no extra fishing gear and a fresh session, **When** the player opens the Fishing gear
   page for the first time, **Then** the list shows "No items yet." and no row or Remove button.
2. **Given** a character with two extra items, **When** the page is opened for the first time in the session,
   **Then** exactly two rows show, each with its item, slot and Remove button.
3. **Given** the page is open, **When** the player hovers anywhere in the list area, including where no row is
   shown, **Then** no error appears; hovering a shown row shows that item's tooltip.
4. **Given** the page is open, **When** an item is added or removed through Alt+Click, **Then** the list updates
   without switching pages.

---

### User Story 2 - The debug report is complete without a lure (Priority: P1)

A player writes a bug report and runs `/okf debug`. The report contains every section in full, whether or not a
lure is in the bags.

**Why this priority**: the debug report is the tool for every bug report; today its Gear section stops with an
error line for every player without a lure, and that hides the best pole, the chosen pole and the pending gear
restore, the facts most often needed.

**Independent Test**: with no lure in the bags, run `/okf debug` and read the Gear section.

**Acceptance Scenarios**:

1. **Given** no lure in the bags, **When** the player runs `/okf debug`, **Then** the Gear section lists the main
   hand, the lure state, the lure setting with "next lure: none" (or an equivalent plain value), the best and chosen
   pole and the pending restore, with no "failed" line.
2. **Given** a usable lure in the bags, **When** the report is made, **Then** the next lure is named as before.
3. **Given** any other section whose value can be missing (no Fishing skill, no pole, no next rank), **When** the
   report is made, **Then** that section also completes, showing the missing value plainly.

---

### User Story 3 - Popups speak the addon's language (Priority: P1)

A player who uses the addon in Ukrainian on a Russian client resets the statistics. The question and both buttons
are in Ukrainian.

**Why this priority**: 1.1.0 is the languages release; a popup with Ukrainian text and Russian buttons (the Russian
Yes / No) is the most visible break of it, and it hits exactly the players the Language setting exists for.

**Independent Test**: set the addon to a language other than the client's, open each addon popup and read the
buttons.

**Acceptance Scenarios**:

1. **Given** the addon in Ukrainian on a Russian client, **When** the player presses Reset session or Reset all in
   the statistics window, **Then** the popup's accept and cancel buttons are in Ukrainian.
2. **Given** the same setup, **When** the addon asks before replacing the player's own map pin, **Then** both
   buttons are in Ukrainian.
3. **Given** the same setup, **When** the player picks another language, **Then** the reload popup's buttons are
   in the language the addon uses now (the new language applies only after the reload).
4. **Given** the addon in English on an English client, **When** any popup shows, **Then** the buttons read as
   before (Yes / No / Cancel or the popup's own wording).

---

### User Story 4 - Both bound keys are shown (Priority: P2)

A player who types in two keyboard layouts binds two keys to each addon action (for example `` ` `` and `'`,
which is the same physical key in English and Ukrainian layouts), as the manual recommends. Everywhere the addon
names the keys, it shows both.

**Why this priority**: the addon tells players to bind punctuation keys once per layout, then shows one of the two
keys, picked in an order the player cannot see (the game's order, not the Keybindings columns). The player sees
one action with the English key and the other with the Ukrainian one and assumes something is wrong. It does not
break fishing, so it follows the P1 fixes.

**Independent Test**: bind two keys to each of the two actions, then read the minimap tooltip, the key line of the
settings page and the indicator.

**Acceptance Scenarios**:

1. **Given** two keys bound to Fishing action and two to Toggle fishing mode, **When** the player hovers the
   minimap button, **Then** each tooltip line names both keys of its action.
2. **Given** the same bindings, **When** the main settings page is opened, **Then** its key line names both keys
   of each action.
3. **Given** the same bindings, **When** the indicator shows the fishing key, **Then** it names both keys, or one
   key with no misleading order if space allows only one (see FR-012).
4. **Given** only one key bound to an action, **When** any of these places shows it, **Then** it shows that one
   key exactly as before.
5. **Given** no key bound, **When** any of these places shows it, **Then** it shows "not bound" as before.

---

### User Story 5 - Statistics buttons wrap like text (Priority: P3)

A player uses the addon in a language with long button texts (German). The bottom buttons of the statistics window
fill the first row from the left; a button that does not fit starts the next row at the left.

**Why this priority**: today nothing is cut off or overlaps (the window grows and the Scan button gets a row at the
right edge), so it works; the author expects the natural reading order instead. Layout polish only.

**Independent Test**: pick Deutsch, reload, open `/okf stats` and look at the bottom buttons; repeat in English.

**Acceptance Scenarios**:

1. **Given** the addon in English, **When** the statistics window opens, **Then** all four buttons stand in one
   row, as before.
2. **Given** the addon in German (the three left buttons plus Scan do not fit in one row), **When** the window
   opens, **Then** the Scan button stands at the left of a second row and the window grows by that row, with the
   zone list still clear of the buttons.
3. **Given** any language, **When** the window opens, **Then** no button overlaps another or the window's edge.

---

### User Story 6 - Korean and Chinese text stays inside the minimap tooltip (Priority: P3)

A player uses the addon in Korean or Chinese and hovers the minimap button. All text of the tooltip lies inside its
frame.

**Why this priority**: the glyphs of the last line reach about half a line below the frame; readable, but it looks
unfinished. It touches only the CJK languages, which the tooltip of the Language button already warns may not
render well.

**Independent Test**: pick 한국어, then 繁體中文 and 简体中文, reload each time, hover the minimap button.

**Acceptance Scenarios**:

1. **Given** the addon in Korean, Traditional Chinese or Simplified Chinese, **When** the player hovers the minimap
   button, **Then** every glyph of every line is inside the tooltip frame.
2. **Given** the addon in a Latin or Cyrillic language, **When** the tooltip shows, **Then** it looks as before
   (no extra empty space added).

---

### Edge Cases

- The gear page is opened from the minimap menu, from `/okf config` or from the game's Options; the first view is
  correct in each case.
- An item in the gear list whose data the client has not loaded yet: its row shows with a placeholder name and
  fills in when the data arrives; hovering it before then shows no error.
- Two keys bound to an action, one of them with a modifier (`SHIFT-'`): both are named with the modifier, in the
  game's readable form.
- The same key text twice (a player bound the same key in both slots): it is named once.
- A popup that already has its own button texts (the language reload popup, the pin replace popup) keeps its own
  accept text in the addon's language; only the generic Yes / No / Cancel come from the addon now.
- The statistics window in a language where even one left button is wider than the window: the window still
  widens to the first row, as today.
- The debug report while no Fishing skill is learned, with no pole and no next rank: every section completes.

## Requirements *(mandatory)*

### Functional Requirements

**Fishing gear page (User Story 1)**

- **FR-001**: The Fishing gear page MUST show, from its first view in a session, exactly one row per item in the
  player's extra gear list and no row without an item.
- **FR-002**: When the extra gear list is empty, the page MUST show "No items yet." and no row or Remove button.
- **FR-003**: Hovering any part of the page MUST NOT raise an error; an item tooltip is shown only for a row that
  holds an item.
- **FR-004**: The list MUST stay current while the page is open (an item added or removed, item data arriving).

**Debug report (User Story 2)**

- **FR-005**: Every value the debug report prints MUST print plainly when it is missing (no lure, no skill, no
  pole, no next rank), and no section may stop with an error because a value is missing.
- **FR-006**: An automated test MUST make the report with no lure in the bags and with no Fishing skill and
  check that every section completes; the test MUST fail on the current code.

**Popups (User Story 3)**

- **FR-007**: Every addon popup MUST show its accept and cancel buttons in the language the addon uses, not the
  client's language. This covers the statistics reset popups, the language reload popup and the map pin replace
  popup, and every future popup made through the shared popup helper.
- **FR-008**: The new button texts (at least Yes, No and Cancel) MUST be translated into all nine languages in the
  same change, like every other text.

**Bound keys (User Story 4)**

- **FR-009**: Where the addon names the keys of an action (the minimap tooltip, the key line of the main settings
  page, the indicator), it MUST name every key bound to that action (up to the two the game allows), in the
  game's readable key names.
- **FR-010**: Two keys MUST be shown in one fixed, documented order so that all three places show the same text for the
  same bindings.
- **FR-011**: One bound key and no bound key MUST look as they do today.
- **FR-012**: Where space is short (the indicator), both keys MUST still be named unless they do not fit; the
  indicator text MUST NOT grow wider than its frame.

**Statistics buttons (User Story 5)**

- **FR-013**: The bottom buttons of the statistics window MUST be laid out left to right in reading order; a button
  that does not fit in the current row MUST start the next row at the left edge.
- **FR-014**: The window MUST grow by each added row so that the buttons never overlap the zone list or each other.

**CJK tooltip (User Story 6)**

- **FR-015**: With the addon in Korean, Traditional Chinese or Simplified Chinese, the minimap tooltip MUST contain
  all of its text inside its frame.
- **FR-016**: The fix MUST NOT change the tooltip in the other seven languages.

**All stories**

- **FR-017**: Every fix with logic that runs without the game (gear list rows, the debug report, popup button
  texts, the key text, the button rows) MUST get an automated test that fails without the fix.
- **FR-018**: The in-game checklists MUST get the steps that confirm each fix in game (User Stories 1 to 6), and
  the steps already marked failed in `interface-language.md` MUST be run again after the fix.
- **FR-019**: The fixes MUST be listed in `CHANGELOG.md` only where they change something a 1.0.0 player can see
  (the gear page, the debug report, the key display); fixes of 1.1.0 features (popups in the addon's language, the
  statistics buttons for translations, the CJK tooltip) need no changelog line because 1.1.0 is not released.

### Key Entities

- **Extra gear list**: the player's chosen fishing items (per character), shown as rows on the Fishing gear page.
- **Key binding of an action**: up to two keys per addon action (Fishing action, Toggle fishing mode), in the
  game's order.
- **Addon popup**: a two-button question shown by the addon (statistics reset, language reload, map pin replace).

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: In the in-game re-run, opening the Fishing gear page and hovering its whole list area on the first
  view of a session produces 0 errors and 0 empty rows (was 14 empty rows and an error).
- **SC-002**: `/okf debug` produces a report with 0 "failed" lines on a character without a lure, without a pole
  and without the Fishing skill.
- **SC-003**: With the addon in Ukrainian on a Russian client, 100% of the buttons in the addon's popups (4 popups)
  are in Ukrainian.
- **SC-004**: With two keys bound to each action, the 3 places that name keys show both keys of each action.
- **SC-005**: In all ten languages the statistics buttons show in reading order with 0 overlaps.
- **SC-006**: In the three CJK languages, 0 glyphs of the minimap tooltip lie outside its frame.
- **SC-007**: All `interface-language.md` steps marked failed on 2026-11-05 pass in the re-run, and `npm run check`
  and `npm test` pass.

## Assumptions

- The fixes ship in 1.1.0 and are built on `001-interface-language`, before it is merged into `develop`.
- The Fishing gear page problem occurs only on the first view of a session (confirmed in game: after switching
  pages, or after reopening the panel, the rows are gone).
- The order of two keys shown is the game's order of the binding (the only order an addon can read); the spec only
  requires that it is the same everywhere. The player cannot see the Keybindings column order through any API.
- The "Scan auction prices" button remains the last button; it is the one that wraps first.
- The CJK overflow is a property of how the game measures tooltip lines with those fonts; a small extra space at
  the bottom of the tooltip for those three languages is acceptable.
- Out of scope: the Artisan quest title the client does not give (`C_QuestLog.GetTitleForQuestID(6607)` is nil,
  checked later at Nat Pagle); the fonts the client lacks (`ARHei`, `blei00d`), which change nothing visible.
- No saved field changes, so no saved variable migration is needed.
