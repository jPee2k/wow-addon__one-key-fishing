# Verification debt: Error Log

The game opens on 2026-11-04, so this is built on the assumption below and checked afterwards. The ID continues
the shared series (`specs/005-catch-catalog/verification.md` ends at V40, `specs/004-public-channel-sync` holds V41).
The code carries `-- VERIFY(V42): ...`; `npm run build` refuses to package while it is open.

Closing it: run the step in game, record the answer in `docs/forever-api.md`, adjust the code if needed, remove the
marker and tick it here.

| ID | Assumption we build on | Evidence before launch | If it turns out wrong | How to verify | Status |
| --- | --- | --- | --- | --- | --- |
| V42 | Inside an `xpcall` message handler, the first Lua line of `debugstack(2, 10, 0)` (after the game's `error` itself) is the failing function; with the error stack height set as Blizzard's `CallErrorHandler` does (`SetErrorCallstackHeight(GetCallstackHeight() - 1)` around the call), `geterrorhandler()(err)` makes the `scriptErrors` popup and BugSack show the error with the failing code's stack, once | `geterrorhandler`, `debugstack`, `GetCallstackHeight` and `SetErrorCallstackHeight` in the 1.60.1 export (`FrameScriptDocumentation.lua`); `HandleLuaError` reads the stack level from `GetErrorCallstackHeight()` (`Blizzard_ScriptErrors.lua:48-60`), and `CallErrorHandler` and `assertsafe` set it the same way (`ErrorUtil.lua:1-6, 16-25`) | Change the offset of `GetCallstackHeight() - 1` or the `debugstack` level | `docs/checklists/spike.md`, step "Error log" | Built, waiting for launch |
