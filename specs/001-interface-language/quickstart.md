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
