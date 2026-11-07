# Verification debt: Pin and Combat Fixes

Claude cannot run the game. The fishing key's fix is built on the assumption below, read from the client's own code
but not seen in game. The ID continues the V series of specs 002 to 008 (V1 to V44). The code carries
`-- VERIFY(V45): ...`; `npm run check` lists it, and `npm run build` refuses to package while it is open.

The map pin's assumption keeps its ID R14 (`specs/001-interface-language/verification.md`). Its row is rewritten for
the new code (the map stays closed) and closed by `docs/checklists/interface-language.md` section 10.

To close an item:
1. Run its step in game.
2. Record the answer in `docs/forever-api.md`.
3. Adjust the code if the game differs.
4. Remove the marker and tick the item here.

| ID | Assumption we build on | Evidence before the change | If it turns out wrong | How to verify | Status |
| --- | --- | --- | --- | --- | --- |
| V45 | The `[combat]` state driver delivers `newstate` as the number `1`, so `tonumber(newstate) == 1` clears the overrides in a fight, and the fishing key then runs its own binding (`OneKeyFishing_ActionKeyIdle`) | `SecureStateDriver.lua` `resolveDriver` (`tonumber(newValue) or newValue`), `SecureHandlers.lua` `SecureHandler_StateOnAttributeChanged` (passes the value unchanged), `RestrictedFrames.lua` `HANDLE:ClearBindings` (`ClearOverrideBindings(frame)`), export build 70685; in game 2026-11-06: the key still clicked the cast button in a fight | If the binding is still the click after the fix, a rebind between the state driver and the lockdown is the next suspect (research R1, alternatives): guard `BindCast` / `BindInteract` with the owner's `state-combat` | `docs/checklists/fishing-mode.md` section 1: in a fight, `/run print(GetBindingAction("<key>", true))` after the fix prints `ONEKEYFISHING_ACTION` (a build from before the fix would print `CLICK OneKeyFishingButton:LeftButton`; optional, not planned); the key prints "The fishing key is paused in combat." | **Confirmed** 2026-11-07 (enUS client, ukUA addon): in a fight `GetBindingAction` gives `ONEKEYFISHING_ACTION`, the key prints its paused line, the indicator shows the paused label; marker removed |
