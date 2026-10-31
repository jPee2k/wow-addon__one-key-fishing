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

## In game

The in-game steps live in [interface-language.md](../../docs/checklists/interface-language.md); the order of everything is
`docs/release-plan.md`.

## User Story 3: the next Fishing rank

Automated: `tests/skill_test.lua` covers the thresholds (50 / 125 / 225 with level 10 / 20 / 35), the level wait
and `PLAYER_LEVEL_UP`, once-per-session notices, the raid warning only the first time, the chat-only repeat on
mode entry, no line at 300, the setting turning notices off, and every name fallback (game, table, English).
`tests/mappin_test.lua` covers the map choice from candidates, the game rule, no pin in an instance and the
replace popup.

The in-game steps are section 10 ("Next rank") of the same checklist.
