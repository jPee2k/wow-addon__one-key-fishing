# Quickstart: Pin and Combat Fixes

How to see that the fixes work: first the automated tests, then the in-game steps for the author. The rules being
checked are in [contracts/map-pin.md](contracts/map-pin.md) and [contracts/combat.md](contracts/combat.md). The state
and the stubs are in [data-model.md](data-model.md).

## Automated

```sh
npm run check
npm test
```

Each test below must fail when its fix is reverted (spec FR-012, SC-006).

| Test file | Proves | Fails without |
|---|---|---|
| `tests/core/pin_set_test.lua` (extended) | P4: no `OpenWorldMap` call, in or out of a fight, also after Replace; the toast is the new text with the place | removing the `OpenWorldMap` block; the toast key change |
| `tests/fishing/gear_combat_test.lua` | C1: no `equip_calls` in the lockdown for `RestoreWeapons`, `Restore` and the cast-end retry. C2: after `PLAYER_REGEN_ENABLED` with the mode off, every owed slot is equipped once. C4: `RestoreWeapons` outside the lockdown still equips the weapons | the lockdown guard in `RestoreSlots`; Gear's `PLAYER_REGEN_ENABLED` handler |
| `tests/fishing/mode_combat_test.lua` | C5: `Mode.Exit` in the lockdown gives one line and no equip, and the exit finishes on `PLAYER_REGEN_ENABLED`. C6: the attack line once with the setting on, none with it off or the mode off. C7: `OneKeyFishing_ActionKeyIdle` within 5 s prints nothing more. C8: a login in a fight with gear owed equips nothing until the fight ends | the `RestoreWeapons` removal from `Mode.Exit`; the attack print; `lastHint`; the login path |
| `tests/fishing/key_combat_test.lua` | C9: the `_onstate-combat` snippet of `OneKeyFishingBindingOwner`, run with `newstate = 1` (a number, as the driver sends it), clears the overrides; with `0` it leaves them | `tonumber(newstate) == 1` (the old `== "1"` fails) |

`npm run check` lists `VERIFY(R14)` and `VERIFY(V45)` as open until the author confirms them.

## In game (handed to the author after the implementation)

The author's order: implement and fix first, then the game. The steps cover only what spec 009 changes. Phase `c`
of the author's 1.2.0 test page (tasks T027) lists the same steps.

**Already confirmed in game, not repeated** (cited in the checklists):
- the pin and the minimap arrow on Heming, and the replace question with buttons in the addon's language
  (2026-11-06, `interface-language.md` section 10);
- the chat map link with no blocked action after it (2026-11-06);
- with "Leave fishing mode when attacked" on: the weapons back at once on an attack, the rest of the gear and the
  mode off after the fight (2026-11-06, `fishing-mode.md` section 1);
- fishing going on after a fight with the setting off (2026-11-06);
- no on-screen arrow, `showInGameNavigation` = 0 (V31, 2026-11-07).

The key check comes first, because it confirms the cause (R1):

1. **The fishing key's binding in a fight** (`docs/checklists/fishing-mode.md` section 1, sub-step 1). With fishing
   mode on, "Leave fishing mode when attacked" off, and a fight under way:
   - `/run print(GetBindingAction("<key>", true))` prints `ONEKEYFISHING_ACTION`;
   - the fishing key gives "The fishing key is paused in combat.", not the game's "can't do that in combat".
   Closes V45. If it prints `CLICK OneKeyFishingButton:LeftButton`, see verification.md V45 "If it turns out wrong".
2. **The attack line** (sub-step 2). With the setting on, an attack gives "Leaving fishing mode after combat."
   exactly once.
3. **The toggle key in a fight** (sub-step 3). With the setting off, run `/console taintLog 1`, then press the
   toggle key in a fight. Expect:
   - that line once;
   - no "Interface action failed";
   - `Logs/taint.log` without `EquipItemByName`;
   - after the fight, the mode off and the gear back.
4. **Map pin** (`docs/checklists/interface-language.md` section 10, "Map pin"). Press Pin in the statistics window
   or the minimap menu. Expect:
   - the map stays closed;
   - the notification above the indicator names the place and says to open the map;
   - open the map: the pin is there;
   - a fight, then the map opened with M: no "Interface action failed because of an AddOn".
   One pin path is enough: the catalog's pin buttons go through the same `MapPin.Set`, and the tests cover them.
   Closes R14.
5. **The manual**: read the pin and "Safe in combat" parts against what steps 2 to 4 showed.

After the steps pass:
- the markers go;
- the R14 and V45 rows are ticked;
- the facts go into `docs/forever-api.md`;
- the 1.2.0 test page's phase `c` is marked.

**Result** (2026-11-07): steps 1 to 4 passed in game (enUS client, ukUA addon); R14 and V45 closed, their markers
removed; the 1.2.0 test page phase `c` is marked.
