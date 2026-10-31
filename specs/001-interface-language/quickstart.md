# Quickstart: Validating Interface Language

## Automated (every change)

```bash
npm run check   # key sync of every translation, ASCII rule, line length, TOC lists the files,
                # no SetFont call
npm test        # includes tests/core/locale_test.lua
```

`tests/core/locale_test.lua` is expected to cover:

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
