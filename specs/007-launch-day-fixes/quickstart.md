# Quickstart: validating the launch day fixes

## Before the game

1. `npm run check` and `npm test` pass; the new tests (`debug_test`, `settings_gear_test`, `keys_test`,
   `popup_test`, the extended `stats_test`) are among them.
2. `npm run install-addon`, then restart the game (no file is added to the TOC by these fixes, so `/reload` is
   enough when the addon was already installed, but a restart is the safe default).
3. `/console scriptErrors 1`.

## In game (any character; a Russian or other non-English client shows the popup fix best)

Each step re-runs a step that failed on 2026-11-05 ([interface-language.md](../../docs/checklists/interface-language.md)
Results).

| # | Story | Do | Expected |
|---|---|---|---|
| 1 | US1 | `/reload`, `/okf config`, open **Fishing gear** first thing, hover the whole list area | "No items yet." (or exactly your items), no Remove button without an item, no Lua error |
| 2 | US1 | close the panel, Alt+Click an item in the bags (the bags cannot open while the panel is open), reopen Fishing gear; repeat to remove it | the row appears, then goes |
| 3 | US2 | with no lure in the bags: `/okf debug` | the Gear section is complete ("next lure: nil", best pole, chosen pole, pending restore); no `!! failed` line anywhere |
| 4 | US3 | addon in Ukrainian; `/okf stats` -> Reset session (then cancel) | question and both buttons in Ukrainian |
| 5 | US3 | set a map pin of your own, then the addon's Pin (when the next rank has a place) | both buttons in Ukrainian |
| 6 | US4 | bind two keys to each action (`` ` `` and `'`, `SHIFT-`` and `SHIFT-'`); hover the minimap button; open the main settings page; enter fishing mode | tooltip and key line show both keys of each action in the same order; the indicator shows both, one per line |
| 7 | US4 | unbind one key of an action | that action shows one key, as before |
| 8 | US5 | Language -> Deutsch, reload, `/okf stats`; then the same in Français, Español (EU) and Português | in German, first row: the three reset/refresh buttons; second row, at the left: Auktionspreise scannen; in every language the buttons read left to right, top to bottom, and nothing overlaps |
| 9 | US5 | Language -> English, reload, `/okf stats` | all four buttons in one row, Scan at the right edge (as before) |
| 10 | US6 | Language -> 한국어, 繁體中文, 简体中文 (reload each), hover the minimap button; also hover the Language button, a statistics row name and the indicator | every glyph inside the minimap tooltip, a small empty space at its bottom is expected; note any other tooltip whose last line reaches below its frame |

## Report back

Tick the matching steps in the checklists, note anything different, and paste the `/okf debug` report of step 3.
