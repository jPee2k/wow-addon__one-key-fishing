# Languages

The languages of the addon's own interface: what is supported, how a language is chosen, and what a
translation has to follow.

Two things are separate here:

- **The game client language.** OneKeyFishing works with a client in any language, because game data
  (spells, items, skill lines, game objects) is matched by ID, never by name. Item, zone and spell names that
  the addon shows come from the client, so they are always in the client's language.
- **The addon interface language.** Every text the addon writes itself (settings, indicator, statistics,
  messages) goes through `ns.L`. This page is about this language.

## Supported languages

The list follows the languages the game client offers. Ukrainian takes the place of Russian: there is no
Russian translation. Every language is named in its own language, as the language setting shows it.

| Language | Code | Client locale | Status |
|---|---|---|---|
| English | `enUS` | yes | Base language |
| Deutsch | `deDE` | yes | Done |
| Español (EU) | `esES` | yes | Done |
| Español (AL) | `esMX` | yes | Done |
| Français | `frFR` | yes | Done |
| Українська | `ukUA` | no | Done (the author reviews it) |
| 한국어 | `koKR` | yes | Done |
| Português | `ptBR` | yes | Done |
| 繁體中文 | `zhTW` | yes | Done |
| 简体中文 | `zhCN` | yes | Done |

The translations other than Ukrainian have not been reviewed by native speakers yet; corrections are welcome.

## Choosing the language

- Settings -> OneKeyFishing -> **Language** (top right): **Game client language** (the default) or any language
  from the table, each named in its own language.
  - **Game client language** uses the translation that matches the client (`GetLocale()`), and English when
    there is none (also for `ruRU`).
  - Ukrainian is available only by picking it: the game has no Ukrainian client locale.
- The tooltip of the button warns that Korean and Chinese may show as squares on a client in another
  language; the menu always shows "English" in Latin letters, so the way back stays readable.
- A change asks "Reload now" / "Later": the interface builds its texts while it loads, so the new language
  shows after a reload. Nothing reloads without that click.
- The setting is account-wide (`OneKeyFishingDB.settings.language`, `"auto"` or a code). A stored code that a
  later version no longer ships counts as "Game client language".
- A text that a translation does not have falls back to English.
- Not translated on purpose: the debug report (`/okf debug`, it goes into bug reports), slash command names,
  the addon name and the language names. Item, zone and spell names come from the game client in its language.

## Translation files

- One file per language: `OneKeyFishing/Locales/<code>.lua`, listed in the TOC after `Locales/enUS.lua` and
  before `Core.lua`. The exact format and rules are in
  [the translation file contract](../specs/001-interface-language/contracts/translation-file.md):

  ```lua
  local _, ns = ...

  ns.AddTranslation("deDE", "Deutsch", function(L)
      L["Cast"] = "Auswerfen"
  end)
  ```

- The translation is plain text in its own language, in UTF-8. These are the only Lua files where
  `npm run check` allows non-ASCII text; every other Lua, TOC and XML file is ASCII, and the rest of the
  project is written in English.
- Every key of `enUS.lua`, nothing else: `npm run check` reports unknown keys, `npm test` reports missing
  ones. A new English text therefore needs its translations in the same change.
- Keep the `%s` / `%d` placeholders in the same order as in the English text (Lua 5.1 has no positional
  arguments, so rephrase the sentence instead of moving them; `npm test` compares them). No color codes.
- Lines up to 120 characters: break after `=` and join long texts with `..`.
- Game terms (rank names, places, menu paths) follow the client's own wording in that language. Ukrainian keeps
  the game's menu paths in English, since no client is in Ukrainian.
- The addon draws text only with the game's font objects (`npm run check` rejects any `SetFont` call), which pick a Korean, Chinese or Cyrillic font when the text needs it.
- Translations can come from volunteers through the CurseForge localization tool or as pull requests.
