# Research: Launch Day Fixes

Findings come from the in-game run of 2026-11-05 (game 1.60.1 build 70790, EU realm, ruRU client, addon
`1.0.0-dev+1dbac37`), recorded in the Results of [interface-language.md](../../docs/checklists/interface-language.md),
and from reading the code at commit `72c3c44`.

## R1. Fishing gear page: empty rows on the first view

- **Finding**: `CreateGearPage` (`UI/Settings.lua:312`) builds `MAX_GEAR_ROWS` (14) row frames, which start shown
  like every new frame. Only `Refresh()` hides the rows without an item, and it runs from the page's `OnShow`, on
  `GEAR_LIST_CHANGED`, `GET_ITEM_INFO_RECEIVED` and `BAG_UPDATE_DELAYED`. In game, the first view of the page in a
  session shows all 14 rows with Remove buttons; after switching to the main page and back, or reopening the
  panel, they are gone. So `OnShow` does not come on the first view: the page was created at `PLAYER_LOGIN`
  without a parent, so it counts as shown from the start, and the Settings panel's first `Show` changes nothing.
  The main page's key line is filled on its first view (it is the category the panel opens), so only the
  subcategory page is affected in practice; the fix makes both independent of that event.
- **Error**: hovering an empty row calls `ShowItemTooltip(self, self.itemID)` with `itemID == nil`;
  `GameTooltip:SetItemByID(nil)` raises the `C_TooltipInfo.GetItemByID` usage error (`UI/Settings.lua:285`).
- **Root cause (Forever export, `Blizzard_Settings_Shared/Blizzard_SettingsPanel.lua`)**: `DisplayLayout` shows a
  canvas page with `frame:SetParent(settingsCanvas)` and `frame:Show()`; `ClearCurrentCategoryCanvas` hides it when
  another category is picked. A frame is created shown, so the first `Show` changes nothing and sends no `OnShow`;
  the main page escaped only because the canvas itself was still hidden on the panel's first display.
- **Decision**: both pages are hidden right after creation, so the panel's `Show` always sends `OnShow`; the gear
  page's `Refresh` runs only while the page is visible (`IsVisible`, not `IsShown`: a page in the closed panel is
  still shown, and it searched the bags for the best pole on every bag update); rows start hidden and
  `ShowItemTooltip` returns without an item, as a second guard. Found in the code review of round 1.
- **Alternatives rejected**: a `Refresh()` when the page is built (the first version: it worked, but kept the
  page refreshing off screen and left the main page on the same root cause); a `C_Timer` refresh (racy).

## R2. Debug report stops in the Gear section

- **Finding**: `Debug.lua:84` calls `tostring(ns.Bags.FindLure())`. `Bags.FindLure` ends without a `return` when
  no lure is usable, so the call passes no argument at all, and Lua 5.1 raises
  `bad argument #1 to 'tostring' (value expected)`. The section's `pcall` catches it and prints `!! failed`, so the
  rest of the Gear section (best pole, chosen pole, extra items, pending restore) is lost. fengari behaves the same,
  but no test made a report.
- **Decision**: one local helper in `Debug.lua`, `Value(...)`, returns `tostring((...))`: the parentheses keep the
  first value, or nil when there is none. Every function result the report prints goes through it. `FindLure`
  stays as it is (its callers test it for truth). A new `tests/debug_test.lua` makes the report on a character
  without a lure, without a pole and without the Fishing skill and checks there is no `!! failed` line; it fails on
  the current code.
- **Alternatives rejected**: `return nil` at the end of `FindLure` only (fixes this call, leaves the next one);
  removing the `pcall` per section (one error would lose the whole report).

## R3. Popup buttons in the client's language

- **Finding**: `ns.ShowPopup` (`Core.lua:43`) uses `YES` and `NO` when no button text is given; the statistics
  reset popups give none. The map pin popup passes `CANCEL`. These are the game's globals in the client's language
  (verified: Russian buttons with the addon in Ukrainian). The language reload popup already passes
  `L["Reload now"]` / `L["Later"]`.
- **Decision**: three new texts `L["Yes"]`, `L["No"]`, `L["Cancel"]` with nine translations; `ns.ShowPopup`
  defaults to the first two (looked up at call time, never at load); `UI/MapPin.lua` passes `L["Cancel"]`. A test
  shows each popup with the addon in Ukrainian and checks the two button texts of `StaticPopupDialogs[key]`.
- **Translations** (standard UI words): deDE Ja / Nein / Abbrechen; esES and esMX Sí / No / Cancelar; frFR Oui /
  Non / Annuler; ukUA the standard Ukrainian yes / no / cancel words; koKR 예 / 아니요 / 취소; ptBR Sim / Não / Cancelar; zhTW 是 / 否 / 取消;
  zhCN 是 / 否 / 取消.
- **Alternatives rejected**: keeping the globals (the bug); per-popup texts everywhere (more strings, same result).

## R4. Two bound keys

- **Finding**: three copies of the key text (`UI/Minimap.lua:36`, `UI/Settings.lua:67`, `UI/Indicator.lua:140`)
  take only the first return of `GetBindingKey`. Verified in game: the game reorders a binding's two keys on a reload, in its
  Keybindings window too (debug: action `', ``, toggle ``SHIFT-`, SHIFT-'``), so the first key alone was the
  English-layout key for one action and the Ukrainian one for the other.
- **Decision**: `ns.KeyText(binding, short)` in `Core.lua` collects every key of `GetBindingKey(binding)`, drops
  duplicates, turns each into `GetBindingText(key, short)` and joins them with `" / "` (no translation needed).
  No key: the red "not bound" text as today (the indicator, which shows nothing when unbound, passes its own empty
  default; see the contract). Order: the game's order, the same in all three places (FR-010); in game it matches the
  Keybindings columns, which the game itself may swap on a reload (checked 2026-11-05). The indicator puts two keys on two lines (separator `"\n"`) and keeps no width limit, so one key
  shows in full as before (FR-011) and a pair is never cut to its first key (FR-012). A first version capped the
  width at the icon and cut one long key (code review round 2).
- **Alternatives rejected**: guessing the layout from the current Windows language (no API); showing only the key
  that works in the current layout (no API either).

## R5. Statistics buttons wrap like text

- **Finding**: `UI/StatsFrame.lua:257` widens the window for the three left buttons; when Scan does not fit beside
  them, the window grows by one row (28) and Scan moves to `BOTTOMRIGHT -14, 40`, above the left row at the right
  edge. Nothing overlaps, but the reading order is wrong.
- **Decision**: same widths and the same extra row; only the positions change when Scan wraps: the three left
  buttons move up to `y = 40` (first row) and Scan goes to `BOTTOMLEFT 14, 12` (second row, left). When everything
  fits, nothing changes (Scan stays at the right edge of the single row). The choice is a small pure function
  `StatsFrame.ButtonRows(leftWidth, scanWidth, minWidth)` (returns whether Scan wraps and the window width), so a
  test checks English (one row) and a long language (two rows). The stub's `SetWidth` / `GetWidth` remember widths
  so the test can also check the whole window.
- **Alternatives rejected**: a general flow layout for any number of buttons (one window, four buttons: more code
  than the need, Principle VI).

## R6. Korean and Chinese glyphs below the minimap tooltip

- **Finding**: the tooltip's height is the sum of its line heights, measured with the tooltip font; the Korean and
  Chinese fonts the game falls back to draw taller glyphs, so the last line reaches about half a line below the
  frame (seen in game). The language menu is not affected.
- **Decision**: when the addon's language is `koKR`, `zhCN` or `zhTW` and the client is not one of them (a Korean
  or Chinese client measures with its own font), the minimap tooltip ends with `GameTooltip:AddLine(" ")` before
  `Show()`. A test builds the tooltip in each language on a non-CJK and on a Korean client.
- **Alternatives rejected**: `GameTooltip:SetPadding(0, n)` (exists in the Forever export,
  `FrameAPITooltipDocumentation.lua`, but the padding stays on the shared `GameTooltip` for the next owner unless
  reset, and its arguments are marked secret-when-tainted; a blank line has neither problem); fixing every tooltip
  of the addon (only the minimap tooltip was seen to overflow; others can adopt the same line if the re-run shows
  them).

## R7. Release notes and docs

- **Decision**: `CHANGELOG.md` `[Unreleased]` gets a `### Fixed` list for what a 1.0.0 player can see: the Fishing
  gear page on its first view, `/okf debug` without a lure, both bound keys shown. The popups in the addon's
  language, the statistics buttons in long languages and the CJK tooltip fix 1.1.0 features, so they need no line
  (spec FR-019). The manual (`OneKeyFishing/README.md`) gets one sentence where it talks about binding a key per
  keyboard layout: the minimap tooltip and the settings show both keys. `docs/checklists/interface-language.md`
  and `fishing-mode.md` get the re-run steps of `quickstart.md`.

## R8. Code review (three rounds, 2026-11-05): findings left open

Fixed: round 1 (the settings pages' root cause, `IsVisible`, the two-key indicator, the CJK rule on CJK clients, the
key line width), round 2 (the indicator width cap that cut one long key, an impossible checklist step). Round 3 found
no defect. Checked and left open, low:

- Other addon tooltips (the Language button, statistics rows, the indicator) end with translated text too; only the
  minimap tooltip was seen to overflow in CJK. Quickstart step 10 now looks at them; extend the blank line (one
  shared helper) only if the re-run shows the same overflow.
- Three readers of `GetBindingKey` (`ns.KeyText`, `Action.lua` BoundKeys, the debug report's raw keys). They agree
  for the two key slots the game has; the debug report keeps raw English key names on purpose.
- `ns.KeyText` drops a key named twice, which the game does not return; kept for the spec's edge case, it costs
  nothing.
- A Scan button wider than the window minus its margins (over 550 px) would pass the right edge; no translation is
  near that.
- The `GetBindingText` stub ignores `short`, so no test pins the indicator's short names.
- `Yes`, `No`, `Cancel` sit under the `UI/Settings.lua` heading of the locale files, though Core and MapPin use them.

## R9. In-game re-run after the review (2026-11-05)

- The Language button's tooltip in zhCN on the ruRU client: its two wrapped sentences fell about two lines below
  the frame (the game counts wrapped lines with the client's font). Fixed with one shared rule, `ns.TallGlyphs()`
  (Core.lua): Korean or Chinese on another client do not wrap their tooltip lines and end with a blank line; the
  minimap tooltip uses it too. Test: `tests/minimap_tooltip_test.lua`.
- After the fix the Language tooltip's lines no longer fall below the frame, but a few glyphs reach past its right
  edge: the game measures the line width with the client's font too.
- The minimap tooltip shows all lines white instead of gold, green and grey on every second hover, only with the
  addon in Korean or Chinese (all three); English and Ukrainian keep their colours. The colours are passed on every
  show.
- **Decision (author, 2026-11-05)**: Korean and Chinese are not tested further. The author has no Korean or Chinese
  client (EU account only), real players of those languages run their own client, where the fonts match and
  `ns.TallGlyphs()` is off, and the two leftovers above are cosmetic. They wait for an issue from players.
- Code review of `ns.TallGlyphs()` (2026-11-05), deferred with the same case: the statistics row, indicator and item
  tooltip lines do not use the rule yet; the minimap next-rank line no longer wraps (it can reach past the right
  edge); no test pins that wrap flag; one shared tooltip helper would replace the two per-tooltip checks if Korean
  and Chinese on other clients are ever worked on.
