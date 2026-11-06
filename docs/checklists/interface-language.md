# In-game checklist: interface languages

**Feature**: the addon's interface in ten languages and the Language setting (`specs/001-interface-language`;
rules in `docs/languages.md`).
**Closes**: no `VERIFY` markers; the font results go into `specs/001-interface-language/research.md` R6 and
`docs/forever-api.md`.
**Needs**: one client (any language) on a character that has learned Fishing, has a fishing pole and has the
fishing keys bound.

## Setup

1. Install the build (`npm run install-addon`), or link the working folder once (`npm run link`).
2. Restart the game completely: the translation files are new in the TOC, so `/reload` is not enough.
3. Log in on the character.

## 1. Fonts on this client

Type in the chat (one line):

```
/run for _,f in ipairs({"2002","ARKai_T","ARHei","blei00d","bKAI00M","FRIZQT___CYR"}) do print(f,UIParent:CreateFontString():SetFont("Fonts\\"..f..".ttf",12,"")) end
```

Each line should end with `true` (the client has that font). Write down every `false`.

- [x] `2002` (Korean): true
- [x] `ARKai_T` (Simplified Chinese): true
- [x] `ARHei` (Simplified Chinese, bold): **false**
- [x] `blei00d` (Traditional Chinese): **false**
- [x] `bKAI00M` (Traditional Chinese): true
- [x] `FRIZQT___CYR` (Cyrillic): true

Optional, how the chat draws the names:

```
/run print("한국어 繁體中文 简体中文 Українська")
```

## 2. Default: the client language

- [x] Settings -> AddOns -> OneKeyFishing: the **Language** button in the top right shows "Game client language".
- [x] On an English client the whole addon is in English, as before. (Checked on a Russian client with the setting
  on "Game client language", 2026-11-05: all English, only the client's YES / NO in popups.)
- [x] Hovering the Language button shows the tooltip: Korean and Chinese may show as squares; pick English to get a
  readable interface back.

## 3. Switching to Ukrainian

- [x] Clicking the Language button opens a menu: "Game client language", then English, Deutsch, Español (EU),
  Español (AL), Français, Українська, 한국어, Português, 繁體中文, 简体中文; the current one is marked.
- [x] Picking Українська shows a popup with "Reload now" and "Later".
- [x] "Later" closes the popup; the addon stays in English until the next reload.
- [x] Picking again and choosing "Reload now" reloads the interface.

After the reload, everything below is in Ukrainian:

- [x] Settings, main page (keys, features, camera, actions) and the Fishing gear page.
- [ ] Action indicator (Cast / Hook! / Apply lure / Open, "No bobber", the drag tooltip). In game 2026-11-05:
  all but Open (no clam yet).
- [x] Statistics window (`/okf stats`): titles, rows, row tooltips, buttons, reset popups.
- [x] Catch notifications.
- [x] Minimap button tooltip and right-click menu.
- [x] Item tooltip line (fishing gear / Alt+Click hint).
- [x] Chat messages (for example `/okf toggle` twice: fishing mode on / off).
- [ ] `/okf` help: command names and descriptions stay in English (they are not translated on purpose).
- [x] Options -> Keybindings -> AddOns -> OneKeyFishing: both binding names.

## 4. The choice is kept

- [x] `/reload`: still Ukrainian.
- [ ] Log out and in on another character of the same account: still Ukrainian.

## 5. Long texts and other scripts

Pick each language below, reload, and look at the settings pages and the statistics window.

- [x] Deutsch: nothing is cut off or overlaps (buttons grow with their text, checkbox labels wrap, long statistics
  labels end before the first column and show in full in the tooltip).
- [x] Español (EU), Español (AL), Français, Português: same.
- [x] 한국어: readable, or squares (as the tooltip warns); the menu still shows "English" readably.
- [x] 繁體中文: same.
- [x] 简体中文: same.

## 6. Back to the client language

- [x] Pick "Game client language", reload: English again.

## 7. The addon list and the language hint

On a client in German (or another language with a translation), on the character screen -> AddOns:

- [x] OneKeyFishing is under the category in the client's language ("Berufe" in German).
- [x] The tooltip of OneKeyFishing shows the description in the client's language, special letters intact
  (ä, ö, ü, ß in German).
- [x] In game, no chat line "Your game client has no translation..." appears (the client has a translation). That the
  line shows once on a client without one (Russian) is covered by `tests/core/locale_hint_test.lua`. In game
  2026-11-05: none on an English client; on a Russian client the line shows once after the hint state was reset,
  and not again after `/reload`.
- [x] Statistics window, "Catches per hour": the decimal separator is the client's (a comma on a German client),
  whatever the interface language. Gold of 1000g or more shows the client's thousands separator instead (a point
  on a German client: "1.234g" next to "2,5" is correct).

## 8. Debug report

- [x] `/okf debug`: the report is in English, with a line `Language: <setting> (in use: <language>)` under the line
  with the client locale.

## 9. Fishing works the same in another language

With the addon in Ukrainian (or any other non-English language):

- [ ] (re-run after spec 008) Toggle fishing mode on and off; settings and gear are restored.
- [x] Cast, hook and loot with the fishing key.
- [ ] (re-run after spec 008) A lure is applied when the pole has none.
- [ ] A fished clam or container is opened.
- [x] The statistics count casts, catches and value.

## 10. Next rank (User Story 3)

Closes the VERIFY marks of `GameData/FishingRanks.lua`, `GameData/NpcNames.lua` and `Core/MapPin.lua` (research R11,
R12, R14; [verification.md](../../specs/001-interface-language/verification.md)).
A low character helps for the first steps; the book and the quest need a trip to Booty Bay and Dustwallow Marsh.

**Places and IDs** (write down what differs):

- [ ] Old Man Heming in Booty Bay sells "Expert Fishing - The Bass and You" (skill 125, level 20), and it teaches
  Expert Fishing: he sells it (item 16083, 2026-11-06); that it teaches Expert from skill 125 and level 20: ____
- [ ] Nat Pagle in Dustwallow Marsh gives "Nat Pagle, Angler Extreme" (skill 225, level 35): ____
- [ ] (re-run after spec 008) Journeyman is taught by fishing trainers from skill 50, level 10: learned at a trainer at
  level 10 (2026-11-06); the skill 50 threshold itself needs a character with skill 50-74 at level 10 (open)
- [ ] Next to Heming and next to Nat Pagle, with the NPC targeted, paste the map ID, the point and the GUID (the
  NPC ID is the second last number) of each:
  `/run local m=C_Map.GetBestMapForUnit("player") local p=C_Map.GetPlayerMapPosition(m,"player") print(m,UnitGUID("target"),p:GetXY())`
  Heming (2026-11-06, release 1.1.0): map 1434, 0.2745 / 0.7719, `Creature-0-6865-0-8-2626-52F4FE9F06` (NPC 2626)
  Nat Pagle: ____
- [x] With Heming's merchant window open, the book is item 16083:
  `/run for i=1,GetMerchantNumItems() do print(i,GetMerchantItemID(i),GetMerchantItemLink(i)) end`: 1 6256 Fishing
  Pole, 2 6529 Shiny Bauble, 3 6530 Nightcrawlers, 4 6532 Bright Baubles, 5 273636 Chef's Knife, 6 16083 Expert
  Fishing - The Bass and You (2026-11-06)
- [ ] With Nat Pagle's quest dialog open, the quest ID on Forever and the title of 6607:
  `/run print(GetQuestID(), C_QuestLog.GetTitleForQuestID(6607))`: ____
- [ ] `/okf debug` right after learning Journeyman and again after Expert: "next rank names" and "next rank pin"
  for the book and the quest: after Journeyman (2026-11-06, enUS client, skill 103/150, level 10)
  `next rank names: item game, npc game, area game, zone game`, `next rank pin: map 1434 at 0.274, 0.770`;
  after Expert: ____

**Names from the game** (on an English client, then on another client language if you can):

- [x] `/run print(C_Map.GetAreaInfo(35), C_Map.GetAreaInfo(33), C_Map.GetAreaInfo(517), C_Map.GetAreaInfo(15))`
  prints Booty Bay, Stranglethorn Vale, Tidefury Cove, Dustwallow Marsh in the client's language: as expected
  (ruRU client, 2026-11-05)
- [ ] `/run print(C_Item.GetItemNameByID(16083), C_QuestLog.GetTitleForQuestID(6607))` prints the book and the quest
  (run it twice: the first call may still be empty): the book `Expert Fishing - The Bass and You`, the quest
  **nil** (2026-11-05; open). Also nil 5 s after `C_QuestLog.RequestLoadQuestByID(6607)`;
  `C_QuestLog.GetQuestInfo(6607)` nil, `IsQuestFlaggedCompleted(6607)` false (level 1 character)
- [ ] (re-run after spec 008) `/run for _,s in ipairs({7620,7731,7732,18248}) do print(s, C_Spell.GetSpellSubtext(s))
  end` prints the rank names (Apprentice ... Artisan): Apprentice, Journeyman, Expert, Artisan
- [ ] (re-run after spec 008) `/okf debug`, section Fishing: the lines "next rank", "next rank names" (game / table /
  english for each name) and "next rank pin": paste them (2026-11-05, skill 52/75, level 6): `next rank: <Journeyman in
  the client's language> (game), state level, from skill 50 and level 10, reminders true`, `next rank names: trainer (no
  game names)`, `next rank pin: none (trainer, no usable map, or pins disabled)`; at 75/75, level 6: `state cap`, the
  rest the same

**Notices and the line:**

- [ ] (re-run after spec 008) At skill 50 (125, 225) with the level: one chat line and a notification "You can learn ...
  now." with the where sentence; not again until the next login: at skill 50+ on reaching level 10 (2026-11-06); 125 /
  225 later
- [ ] (re-run after spec 008) Below the level: no notice; the statistics window says "from character level N" (before
  the skill threshold: "from skill X and character level N"); after the level-up the notice comes (the level-up part
  waits for level 10).
- [ ] (re-run after spec 008) With "Show catch notifications" off, the rank notices still show their notification above
  the indicator (2026-11-06).
- [ ] (re-run after spec 008) At the cap: a large on-screen message once; entering fishing mode again prints a chat line
  only.
- [ ] (re-run after spec 008) The statistics window shows the "Next rank" line under the prices line; the minimap
  tooltip shows it too.

**Map pin** (Expert or Artisan advice):

- [ ] (re-run after spec 008) The **Pin** button in the statistics window and "Pin: next Fishing rank" in the minimap
  menu set the game's pin and the navigation arrow on Heming or Nat Pagle and open the map: on Heming, map 1434
  (2026-11-06). The map opened by the addon then failed in a fight ("Interface action failed because of an AddOn", taint
  of `OpenWorldMap`; without a pin no such line). Fix waits in `docs/tech-debt.md`; then re-check: Pin, a fight, the map
  opened by hand (M): no such line: ____
- [ ] (re-run after spec 008) With a pin of your own on the map, a popup asks first; Cancel keeps your pin. The buttons
  are in the addon's language (2026-11-06).
- [ ] (re-run after spec 008) The map link at the end of the chat notice sets the pin and opens the map (without a
  question): at the cap 150/150, level 10 (2026-11-06); a fight afterwards with the map opened by hand gave no blocked
  action (the game's own link handler opens the map, not the addon).

**Languages:**

- [x] With the addon in Ukrainian on an English client: the sentences are Ukrainian, the book, quest, places and
  ranks read exactly as the English client names them (2026-11-06; the quest still waits for Nat Pagle).

## 11. Launch day fixes (spec 007)

Re-runs the steps that failed on 2026-11-05 ([quickstart](../../specs/007-launch-day-fixes/quickstart.md)), on a
build after the code review (`1.0.0-dev+09cfb6b` or later; the minimap tooltip shows the version).

- [x] **US1, settings pages, first view.** `/reload`, `/okf config`: the main page shows both keys of each action,
  the Language button the current choice, the checkboxes as set. Open Fishing gear first thing and hover the whole
  list: only your items (or "No items yet."), no Remove button without an item, no Lua error; switch pages a few
  times; close the panel, Alt+Click an item in the bags, reopen: the item is listed; remove it the same way.
- [ ] (re-run after spec 008) **US2, debug.** With no lure in the bags, `/okf debug`: the Gear section is complete
  ("next lure: nil", best pole, chosen pole, pending restore), no `!! failed` line.
- [x] **US3, popups.** Addon in Ukrainian on a non-English client: Reset session / Reset all in the statistics (then
  cancel) show both buttons in Ukrainian. The map pin replace popup waits for a rank advice with a place (level 10,
  section 10).
- [x] **US4, keys.** Two keys bound to each action: the minimap tooltip and the settings key line show both, in the
  order of the Keybindings columns (the game may swap the two on a reload); Deutsch: the key line wraps inside the
  page.
- [x] **US4, indicator** (fishing mode): one key per line in the icon's top right corner; one key in full.
- [x] **US5, statistics buttons.** Deutsch: the three reset/refresh buttons on the first row, "Auktionspreise
  scannen" at the left of the second row; Français, Español (EU), Português: buttons read left to right, top to
  bottom, nothing overlaps; English: all four in one row, Scan at the right edge.
- [ ] **US6, Korean and Chinese on another client** (deferred, no such client): the Language tooltip no longer falls
  below its frame; glyphs past the right edge and white text on every second minimap hover wait for an issue
  (Results, spec 007 research R9).

## Results

- Date, build, client language: 2026-11-05, game 1.60.1 (70790), EU realm, client ruRU, addon
  1.0.0-dev+1dbac37, then 1.0.0-dev+212927b; Fishing learned at level 5, skill 52/75 at level 6 (run in
  progress: the rank steps from level 10, Heming, Nat Pagle and the containers are open).
- 2026-11-06, release 1.1.0, an English client (also with the addon in Ukrainian): level 10, Journeyman learned
  at a trainer, skill 103/150. The "can learn" notice (also with catch notifications off), the Expert advice with
  every name from the game (the book, Heming through his creature tooltip, Booty Bay, Stranglethorn Vale), the pin
  on map 1434 with the navigation arrow and the replace popup work. Open: the chat map link (skill 125 at level
  20, or the cap 150), Heming's merchant list and point, Nat Pagle and the quest ID, the debug report after Expert,
  the German Heming name. Found: the map that the pin opened (`OpenWorldMap`) was blocked in a later fight
  ("Interface action failed because of an AddOn"); the fix is in `docs/tech-debt.md`.
- Fonts missing: `ARHei.ttf` and `blei00d.ttf`; the language menu still draws every language name readably.
- Next rank: map IDs and points, names, what differs from the original game: area, book and rank names come in
  the client's language; the quest title of 6607 stays nil, also after `RequestLoadQuestByID` (open: check at
  Nat Pagle whether Forever uses another quest ID; until then the English fallback name shows).
- Spec 007 fixed the problems below (re-run in section 11, 2026-11-05) except two left on purpose: with the
  addon in Korean or Chinese on a client in another language, the Language tooltip's glyphs reach a little past its
  right edge, and the minimap tooltip turns white on every second hover. No Korean or Chinese client to test with;
  they wait for an issue from players (spec 007 research R9).
- Problems found on the first run:
  - the Fishing gear page shows 14 empty rows with "Remove" buttons; hovering one raises a Lua error in
    `GameTooltip:SetItemByID` (nil item ID, `UI/Settings.lua:285`). Only on the first view of the page in a
    session: after switching to the main page and back, or reopening the panel, the rows are gone. The rows are
    created shown and only `Refresh` from the page's `OnShow` hides them, so `OnShow` does not come on the first
    view. The main page's key line is filled on the first view;
  - `/okf debug` stops the Gear section with `Debug.lua:84: bad argument #1 to 'tostring' (value expected)`
    when no lure is in the bags;
  - the addon's popups use the client's `YES` / `NO` (Russian yes / no on a Russian client with the addon in
    Ukrainian);
  - the minimap tooltip shows only the first key of each binding, and the game's order of the two keys is not
    the order of the Keybindings columns;
  - statistics window: when the three left buttons are too wide (German), the Scan button moves to a row of its
    own at the right edge (`UI/StatsFrame.lua:263`); the author expects it to wrap to the left, like a line of
    text;
  - minimap tooltip with Korean or Chinese: some glyphs of the last line reach about half a line below the
    tooltip's bottom edge. The language menu is fine.
