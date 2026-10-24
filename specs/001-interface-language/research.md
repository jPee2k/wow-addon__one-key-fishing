# Research: Interface Language

Decisions taken for the plan, each with the reason and the alternatives that were rejected.

## R1. When the language can be chosen (load order)

- **Decision**: The language is resolved in Core's `ADDON_LOADED` handler, right after the saved variables
  are migrated and filled with defaults, and before any other code looks up a text. No `L["..."]` lookup may
  run while the addon files load. Every current load-time lookup moves to runtime:
  - `Core.lua`: `BINDING_NAME_ONEKEYFISHING_*` are set in `ADDON_LOADED` (the Keybindings panel reads the
    globals when it is opened).
  - `ns.RegisterCommand(name, description, fn)` takes the description as a function returning the text
    (`function() return L["..."] end`), called when the help is printed. Five commands: scan, debug, toggle,
    config, stats.
  - `UI/Settings.lua` `TOGGLES`, `UI/StatsFrame.lua` `ROWS`, `UI/Indicator.lua` `LABELS`, `Skill.lua`
    `RANK_NAMES` / `NEXT_RANK`: built by a function on first use instead of at file load.
- **Rationale**: WoW loads saved variables after all addon files have run, just before `ADDON_LOADED`, so the
  preference does not exist at file load. A text looked up at load time would be stuck in the client
  language. Keys stay literal (`L["text"]`), so the key sync of `npm run check` keeps working.
- **Guard**: `ns.L` records every lookup made before the language is set; a test loads the addon and asserts
  that list is empty, so a new load-time lookup fails `npm test`.
- **Alternatives rejected**: a custom CVar read at load time (persistence of addon-registered CVars is
  unverified on Forever); a load-on-demand child addon (two addons for one setting); proxy objects that
  translate late (every `SetText` and `format` would need to handle them).

## R2. Translation file format and registry

- **Decision**: A new first file `Localization.lua` owns `ns.L`, the registry and the language list. Each
  translation is `Locales/<code>.lua`:

  ```lua
  local _, ns = ...
  ns.AddTranslation("deDE", "Deutsch", function(L)
      L["Cast"] = "Auswerfen"
  end)
  ```

  The function body runs only for the language that is picked, so the other eight cost no memory beyond their
  code. `Locales/enUS.lua` keeps the English list (`L[key] = true`) and registers "English".
- **Rationale**: the native name lives in the translation file, which is the one place allowed to hold
  non-ASCII text; a language without a file simply does not appear in the list (FR-012). Literal
  `L["..."] = "..."` lines keep the existing key check.
- **Alternatives rejected**: `if GetLocale() == ... then` blocks (cannot follow a preference); one big table
  of all languages in one file (unreadable diffs, all languages in memory).

## R3. Resolving the effective language

- **Decision**: `ns.ResolveLanguage(preference, clientLocale)`:
  1. preference is a registered code → that code;
  2. otherwise (`"auto"`, or a code no longer shipped) → `clientLocale` if registered;
  3. otherwise → `"enUS"`.
  Ukrainian has no client locale, so it can only come from step 1. `ruRU` is not registered and falls to
  English. Lookups go: chosen translation → English key.
- **Rationale**: one pure function, unit-testable without reloading the addon; covers FR-002, FR-004, FR-005,
  FR-007 and the "language removed in a later version" edge case.

## R4. The language control in the settings

- **Decision**: On the main settings page, next to the title: a "Language:" label and a button showing the
  current choice. Clicking it opens a menu (`MenuUtil.CreateContextMenu`, already used by the minimap button)
  with radio entries: "Game client language" (translated) and each registered language by its native name, in
  the order of `docs/languages.md`. Hovering the button shows the tooltip of FR-013. `MenuUtil` is verified on
  Forever, so it has no fallback (dropped in code review).
- **Rationale**: `MenuUtil` is verified on Forever by the minimap menu; `root:CreateRadio` belongs to the same
  menu API but is not verified yet, so the code falls back to `root:CreateButton` with a check mark in the
  text if `CreateRadio` is missing. The settings pages are plain canvas widgets (project rule), not the
  Settings setting-type API.
- **Alternatives rejected**: `WowStyle1DropdownTemplate` (not verified on Forever); a row of ten radio
  buttons (no room on the page, which fits without scrolling).

## R5. Applying a change (reload prompt)

- **Decision**: Choosing a different value saves it in `OneKeyFishingDB.settings.language` and shows a
  `StaticPopup` "The language changes after reloading the interface." with "Reload now" (`ReloadUI()`) and
  "Later". Nothing reloads without that click.
- **Rationale**: matches the clarification (Q1) and Principle I: the reload is the player's click.
  `ReloadUI` is not protected; it runs from the popup's button handler.

## R6. Fonts

- **Decision**: All addon text keeps using the game's font objects (`GameFontNormal`, `GameFontHighlight`,
  `GameFontDisableSmall`, ...) and Blizzard's tooltips and menus; no font file is set by path. These font
  objects pick a per-alphabet font (Korean, Chinese, Cyrillic) when the text needs it. `npm run check`
  reports any `SetFont` call in the addon.
- **Findings**: on the author's English Forever client the font cache holds `frizqt__.ttf` (Latin) and
  `bkai00m.ttf` (Traditional Chinese, so the client draws it); Cyrillic `frizqt___cyr.ttf` is cached on the
  retail and era clients. Korean `2002.ttf` and Simplified Chinese `arkai_t.ttf` are not cached yet, which
  only means nothing drew with them; the in-game check in `quickstart.md` settles it.
- **Alternatives rejected**: shipping CJK font files (several MB each, against the small package); hiding
  Korean and Chinese on other clients (rejected in clarification Q2).

## R7. Longer texts (SC-006)

- **Decision**: `ns.CreateButton` widens a button to its text when the text is wider than the given width;
  checkbox labels and hint lines get an explicit width with word wrap; the statistics row labels keep their
  column and are checked in game per language. The in-game checklist covers every window in German (usually
  the longest) and Korean / Chinese.
- **Rationale**: fixed widths (140-190 px buttons, 300 px columns) fit English only; growing to fit is cheaper
  than per-language layouts.

## R8. Placeholders and line length in translations

- **Decision**: A test compares, for every translated string, the sequence of `%` format specifiers with the
  English key (Lua 5.1 has no positional arguments, so the order must match) and the `|` escape sequences.
  Translation lines keep the 120-character limit: a long entry is written as
  `L["English"] =\n    "translation"`, split with `..` if still too long.
- **Rationale**: a mismatched specifier makes `string.format` raise an error in game; this catches it in CI.
  `npm run check` measures characters, not bytes, so CJK lines are not penalised.

## R9. Completeness

- **Decision**: A test asserts that every shipped translation has every key of `enUS.lua` (FR-011). A new
  English text therefore needs its nine translations in the same change. The English fallback (FR-007) still
  protects players if a gap slips through in a future volunteer contribution.
- **Alternative rejected**: completeness as a release-time warning only (would let releases ship partial
  translations, against FR-011).

## R10. Out of scope (confirmed)

- Localized TOC fields (`## Notes-deDE:`): they follow the client, not the setting, and the TOC must stay
  ASCII.
- Game names (items, zones, spells): always from the client.
- The debug report and slash command names: stay English (FR-009); the report gains three lines: the
  preference, the effective language and the client locale.
