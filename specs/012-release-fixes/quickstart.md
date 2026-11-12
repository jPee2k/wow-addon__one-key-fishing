# Quickstart: Release Fixes for 1.2.0

The rules being checked are in [contracts/module-api.md](contracts/module-api.md); the state is in
[data-model.md](data-model.md).

## Automated

```sh
npm run check
npm test
```

Each test fails without its fix (spec FR-014):

| Test | Proves | Fails without |
|---|---|---|
| `tests/ui/indicator_secret_test.lua` (new) | S1, G1, B1, I1: a secret soft-target GUID while channeling gives no error and "Hook!", not "No bobber"; I2: a readable other target still warns | the `IsSecret` guard in `GameObjectID`; the `known` answer in `ShowNoBobber` |
| `tests/fishing/fished_loot_test.lua` (extended) | L1: a secret loot source raises no error and the timing fallback counts the loot | the guard in `IsFromLastOpen` |
| `tests/fishing/lure_skill_test.lua` (extended) | L2, L3: a lure refused while the skill was unknown comes back once the skill reaches its requirement; one refused at its requirement stays skipped after a skill-up | the skill-event handler and the stored skill |
| `tests/ui/here_page_test.lua` (extended) | H1-H3: the hint with another player's catches here (with and without own catches), at another place, and with sharing off | `view.others` and the second hint |
| `tests/exchange/share/game_test.lua` (extended) | T1, T2: "1 player" and "2 players" | the singular key |
| `tests/ui/minimap_tooltip_test.lua` (extended) | M1, M2: lines cleared first, every coloured line carries its code | `ClearLines` and `Colored` |
| `tests/tools/private_check_test.mjs` (extended) | P1-P3: alias, bracket and string with `--` reported; own folder silent | the luaparse walk |

The test stubs: `tests/wow.lua` gets `strsplit` raising on a value in `secret_values` (as the game does), a
settable soft-target GUID for `UnitGUID("softinteract")`, and `GameTooltip:ClearLines` recorded.

## In game (after the implementation)

1. **The dungeon** (batch 10): ten casts at water in a dungeon (the one of 2026-11-11). No error window; the
   indicator shows "Hook!" while the bobber is out; catches are looted; `/okf debug` Errors has no new entry.
2. **The open world** (I2, regression): a cast while looking away from the bobber still shows "No bobber" after the
   grace time.
3. **Status texts** (batch 9): with one exchange partner, "Exchange: 1 player, ... ago" on "What can be caught
   here", the settings page and in `/okf share`; on the tab, the hint reads "No bundled data in this version."
   without "only your own catches".
4. **The minimap tooltip** (batch 7): over a session, hover item rows of the statistics window, then the minimap
   button, many times: the gold, grey and green lines keep their colours. Seen over time, not in one hover.
5. **The lure** (batch 5): not reproducible on purpose (V43 confirmed the requirements); the tests cover it.
