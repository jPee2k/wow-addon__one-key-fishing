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

- [ ] Settings, main page (keys, features, camera, actions) and the Fishing gear page.
- [ ] Action indicator (Cast / Hook! / Apply lure / Open, "No bobber", the drag tooltip).
- [ ] Statistics window (`/okf stats`): titles, rows, row tooltips, buttons, reset popups.
- [ ] Catch notifications.
- [x] Minimap button tooltip and right-click menu.
- [ ] Item tooltip line (fishing gear / Alt+Click hint).
- [x] Chat messages (for example `/okf toggle` twice: fishing mode on / off).
- [x] `/okf` help: the command names stay in English (not translated on purpose); their descriptions are in
  Ukrainian.
- [x] Options -> Keybindings -> AddOns -> OneKeyFishing: both binding names.

## 4. The choice is kept

- [x] `/reload`: still Ukrainian.
- [ ] Log out and in on another character of the same account: still Ukrainian.

## 5. Long texts and other scripts

Pick each language below, reload, and look at the settings pages and the statistics window.

- [ ] Deutsch: nothing is cut off or overlaps (buttons grow with their text, checkbox labels wrap, long statistics
  labels end before the first column and show in full in the tooltip).
- [ ] Español (EU), Español (AL), Français, Português: same.
- [ ] 한국어: readable, or squares (as the tooltip warns); the menu still shows "English" readably.
- [ ] 繁體中文: same.
- [ ] 简体中文: same.

## 6. Back to the client language

- [x] Pick "Game client language", reload: English again.

## 7. The addon list and the language hint

On a client in German (or another language with a translation), on the character screen -> AddOns:

- [x] OneKeyFishing is under the category in the client's language ("Berufe" in German).
- [x] The tooltip of OneKeyFishing shows the description in the client's language, special letters intact
  (ä, ö, ü, ß in German).
- [x] In game, no chat line "Your game client has no translation..." appears (the client has a translation). That the
  line shows once on a client without one (Russian) is covered by `tests/locale_hint_test.lua`. In game
  2026-11-05: none on an English client; on a Russian client the line shows once after the hint state was reset,
  and not again after `/reload`.
- [ ] Statistics window, "Catches per hour": the decimal separator is the client's (a comma on a German client),
  whatever the interface language. Gold of 1000g or more shows the client's thousands separator instead (a point
  on a German client: "1.234g" next to "2,5" is correct).

## 8. Debug report

- [x] `/okf debug`: the report is in English, with a line `Language: <setting> (in use: <language>)` under the line
  with the client locale.

## 9. Fishing works the same in another language

With the addon in Ukrainian (or any other non-English language):

- [ ] Toggle fishing mode on and off; settings and gear are restored.
- [ ] Cast, hook and loot with the fishing key.
- [ ] A lure is applied when the pole has none.
- [ ] A fished clam or container is opened.
- [ ] The statistics count casts, catches and value.

## 10. Next rank (User Story 3)

Closes the VERIFY marks of `GameData/FishingRanks.lua`, `Skill.lua` and `UI/MapPin.lua` (research R11, R12, R14).
A low character helps for the first steps; the book and the quest need a trip to Booty Bay and Dustwallow Marsh.

**Places and IDs** (write down what differs):

- [ ] Old Man Heming in Booty Bay sells "Expert Fishing - The Bass and You" (skill 125, level 20), and it teaches
  Expert Fishing: ____
- [ ] Nat Pagle in Dustwallow Marsh gives "Nat Pagle, Angler Extreme" (skill 225, level 35): ____
- [ ] Journeyman is taught by fishing trainers from skill 50, level 10: ____
- [ ] Next to Heming and next to Nat Pagle, paste the map ID and point of each:
  `/run local m=C_Map.GetBestMapForUnit("player") local p=C_Map.GetPlayerMapPosition(m,"player") print(m,p:GetXY())`
  Heming: ____ Nat Pagle: ____

**Names from the game** (on an English client, then on another client language if you can):

- [x] `/run print(C_Map.GetAreaInfo(35), C_Map.GetAreaInfo(33), C_Map.GetAreaInfo(517), C_Map.GetAreaInfo(15))`
  prints Booty Bay, Stranglethorn Vale, Tidefury Cove, Dustwallow Marsh in the client's language: as expected
  (ruRU client, 2026-11-05)
- [ ] `/run print(C_Item.GetItemNameByID(16083), C_QuestLog.GetTitleForQuestID(6607))` prints the book and the quest
  (run it twice: the first call may still be empty): the book `Expert Fishing - The Bass and You`, the quest
  **nil** (2026-11-05; open). Also nil 5 s after `C_QuestLog.RequestLoadQuestByID(6607)`;
  `C_QuestLog.GetQuestInfo(6607)` nil, `IsQuestFlaggedCompleted(6607)` false (level 1 character)
- [x] `/run for _,s in ipairs({7620,7731,7732,18248}) do print(s, C_Spell.GetSpellSubtext(s)) end` prints the rank
  names (Apprentice ... Artisan): Apprentice, Journeyman, Expert, Artisan
- [ ] `/okf debug`, section Fishing: the lines "next rank", "next rank names" (game / table / english for each
  name) and "next rank pin": paste them: ____

**Notices and the line:**

- [ ] At skill 50 (125, 225) with the level: one chat line and a notification "You can learn ... now." with the
  where sentence; not again until the next login.
- [ ] Below the level: no notice; the statistics window says "from character level N" (before the skill
  threshold: "from skill X and character level N"); after the level-up the notice comes.
- [ ] With "Show catch notifications" off, the rank notices still show their notification above the indicator.
- [ ] At the cap: a large on-screen message once; entering fishing mode again prints a chat line only.
- [ ] The statistics window shows the "Next rank" line under the prices line; the minimap tooltip shows it too.

**Map pin** (Expert or Artisan advice):

- [ ] The **Pin** button in the statistics window and "Pin: next Fishing rank" in the minimap menu set the game's
  pin and the navigation arrow on Heming or Nat Pagle and open the map.
- [ ] With a pin of your own on the map, a popup asks first; Cancel keeps your pin.
- [ ] The map link at the end of the chat notice sets the pin and opens the map (without a question).

**Languages:**

- [ ] With the addon in Ukrainian on an English client: the sentences are Ukrainian, the book, quest, places and
  ranks read exactly as the English client names them.

## 11. Launch day fixes (spec 007)

Re-runs the steps that failed on 2026-11-05 ([quickstart](../../specs/007-launch-day-fixes/quickstart.md)).

- [ ] **US1, gear page.** `/reload`, open Fishing gear first thing, hover the whole list: only your items (or "No
  items yet."), no Remove button without an item, no Lua error.
- [ ] **US2, debug.** With no lure in the bags, `/okf debug`: the Gear section is complete ("next lure: nil", best
  pole, chosen pole, pending restore), no `!! failed` line.
- [ ] **US3, popups.** Addon in Ukrainian on a non-English client: Reset session / Reset all in the statistics (then
  cancel) and the map pin replace popup show both buttons in Ukrainian.
- [ ] **US4, keys.** Two keys bound to each action: the minimap tooltip, the settings key line and the indicator
  show both, in the same order.
- [ ] **US5, statistics buttons.** Deutsch: the three reset/refresh buttons on the first row, "Auktionspreise
  scannen" at the left of the second row; Français, Español (EU), Português: buttons read left to right, top to
  bottom, nothing overlaps; English: all four in one row, Scan at the right edge.
- [ ] **US6, CJK tooltip.** 한국어, 繁體中文, 简体中文 (reload each): every glyph of the minimap tooltip inside its frame.

## Results

- Date, build, client language: 2026-11-05, game 1.60.1 (70790), EU realm, client ruRU, addon
  1.0.0-dev+1dbac37; level 1 character without Fishing (run in progress).
- Fonts missing: `ARHei.ttf` and `blei00d.ttf`; the language menu still draws every language name readably.
- Next rank: map IDs and points, names, what differs from the original game: area, book and rank names come in
  the client's language; the quest title of 6607 stays nil, also after `RequestLoadQuestByID` (open: check at
  Nat Pagle whether Forever uses another quest ID; until then the English fallback name shows).
- Problems found (open, to be fixed before 1.1.0):
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
