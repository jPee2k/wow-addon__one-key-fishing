# Quickstart: Validating Interface Language

## Automated (every change)

```bash
npm run check   # key sync of every translation, ASCII rule, line length, TOC lists the files,
                # no SetFont call
npm test        # includes tests/locale_test.lua
```

`tests/locale_test.lua` is expected to cover:

- `ResolveLanguage`: auto + client with translation → that language; auto + `ruRU` → `enUS`; picked `ukUA` on
  any client → `ukUA`; unknown stored code → as auto.
- No text lookup before the language is set while the addon loads (`ns.earlyLookups` is empty).
- Every translation: registered under its file name, has a native name, has every English key, keeps the
  `%` specifiers and `|` escapes of each key.
- A missing key falls back to English.
- Choosing a language saves the preference and shows the reload popup; accepting it calls `ReloadUI`.

## In game (handed to the author)

The checklist to tick in the game is [docs/checklists/interface-language.md](../../docs/checklists/interface-language.md);
the steps below summarize it.

Prerequisites: `npm run install-addon` (or `npm run link`), restart the game (new files in the TOC).

1. **Fonts on the English client** (once):
   `/run for _,f in ipairs({"2002","ARKai_T","ARHei","blei00d","bKAI00M","FRIZQT___CYR"}) do print(f,UIParent:CreateFontString():SetFont("Fonts\\"..f..".ttf",12,"")) end`
   Expect `true` for each; note any `false` in the plan's findings.
2. **Auto**: with the setting on "Game client language", the English client shows English.
3. **Pick Ukrainian**: Settings → OneKeyFishing → Language → Українська. The popup appears; "Later" keeps
   English; "Reload now" shows Ukrainian in: settings (both pages), indicator, statistics window and its
   tooltips, catch notifications, minimap tooltip and menu, item tooltip line, chat messages, Keybindings →
   AddOns → OneKeyFishing.
4. **Persistence**: log out, log in on another character: still Ukrainian.
5. **Each other language** (Deutsch first, then 한국어, 繁體中文, 简体中文, the rest): nothing cut off or
   overlapping in the settings pages and the statistics window; Korean and Chinese readable (or squares, as the
   tooltip warns), and the language button still lets you pick English.
6. **Back to auto**: pick "Game client language", reload: English again.
7. **`/okf debug`**: report in English, with the preference, effective language and client locale lines.
8. **Fishing works** in Ukrainian: cast, hook, lure, container, statistics count (SC-005).

## User Story 3: the next Fishing rank

Automated: `tests/skill_test.lua` covers the thresholds (50 / 125 / 225 with level 10 / 20 / 35), the level wait
and `PLAYER_LEVEL_UP`, once-per-session notices, the raid warning only the first time, the chat-only repeat on
mode entry, no line at 300, the setting turning notices off, and every name fallback (game, table, English).
`tests/mappin_test.lua` covers the map choice from candidates, the game rule, no pin in an instance and the
replace popup.

In game (the checklist gets a "Next rank" section), on an English client and, if possible, another one:

1. **IDs and places (VERIFY)**: the Expert book is sold by Old Man Heming in Booty Bay and teaches Expert
   Fishing; Nat Pagle in Dustwallow Marsh gives "Nat Pagle, Angler Extreme"; the level requirements are 10 /
   20 / 35. Next to each NPC: `/run local m=C_Map.GetBestMapForUnit("player") local p=C_Map.GetPlayerMapPosition(m,"player") print(m,p:GetXY())`
   and write down the map ID and point.
2. **Names from the game**: `/run print(C_Map.GetAreaInfo(35), C_Map.GetAreaInfo(33), C_Item.GetItemNameByID(16083), C_QuestLog.GetTitleForQuestID(6607), C_Spell.GetSpellSubtext(7732))`
   prints the client's names; the `/okf debug` report shows where each advice name came from.
3. **Notices**: at skill 50 / 125 a quiet notice; at the cap one raid-warning message, then only chat lines on
   entering fishing mode; with a low level the line shows the level needed.
4. **Line and pin**: the statistics window and the minimap tooltip show the "Next rank" line; the pin button
   and the minimap menu entry set the game's pin and arrow on Heming or Nat Pagle, and with a pin of your own
   on the map a popup asks first; the chat map link sets the pin and opens the map at once, like any map link.
5. **Ukrainian on an English client**: the sentence is Ukrainian, the game names are the English client's.
