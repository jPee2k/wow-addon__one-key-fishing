# Architecture: fishing mode

The fishing key, entering and leaving the mode, gear, camera, lures and containers, and the skill. Principle III
of the constitution says what must be restored when.

## Fishing/Action.lua

The single fishing key.

- Keys bound to `ONEKEYFISHING_ACTION` (Bindings.xml) are overridden only while the mode is on.
- When the player is not channeling, the key clicks `OneKeyFishingButton` (SecureActionButtonTemplate). Its
  `PreClick` resolves the action by priority: apply lure, then open a fished container, then cast Fishing.
- While channeling Fishing, the key is bound to `INTERACTTARGET` (soft-target interact hooks the bobber).
- The overrides are owned by a `SecureHandlerStateTemplate` frame whose `[combat]` state driver clears them inside
  combat. The driver passes the state as a number, so the handler compares `tonumber(newstate) == 1` (spec 009,
  research R1; V45). The hook (`INTERACTTARGET`) goes too, so a bobber still out cannot be hooked in a fight.
  `Action.IsPaused()` is true from `PLAYER_REGEN_DISABLED` to `PLAYER_REGEN_ENABLED` while the key is enabled, and
  the start fires `ACTION_STATE("paused")` for the indicator.
- `Action.Enable` picks up a Fishing channel that is already running (`UnitChannelInfo`), because no
  `CHANNEL_START` comes for a cast begun before a `/reload` or before the mode was switched on.
- The keys are re-read on `UPDATE_BINDINGS` and after combat; our own overrides fire that event too, so it rebinds
  only when the keys changed.

## Fishing/Mode.lua

Enter and exit fishing mode.

- Every changed CVar, the gear swap and the camera zoom are stored in the character DB *before* changing anything.
  As a result, exit, logout, `/reload` (which also fires `PLAYER_LOGOUT`) and crashes restore the CVars
  (`PLAYER_LOGIN` restores any left over) and the gear.
- The saved zoom (Camera.lua) survives a `/reload` but is dropped on a real login (`isInitialLogin`), so after a
  logout, crash or disconnect in fishing mode the previous zoom is not restored.
- `PLAYER_LOGOUT` with the mode on restores the CVars and sets `resumeMode`; `PLAYER_ENTERING_WORLD` resumes only
  when `isReloadingUi` is true too, after a 1 second delay, because bindings and the spellbook are not ready then.
  If it cannot resume (combat), the camera comes back at once and the gear after combat.
- Leaving in combat only sets a pending exit and says "Leaving fishing mode after combat." once; nothing is equipped
  in the lockdown, and the whole exit (gear, camera, CVars) runs on `PLAYER_REGEN_ENABLED`.
- An attack with "Leave fishing mode when attacked" on (`PLAYER_REGEN_DISABLED`, before the lockdown) swaps the
  weapons back, sets the pending exit and prints the same line once; the key hint waits 5 s before repeating it.
- While the mode is on, the plain binding body of the action key only runs when combat dropped the overrides, so
  `OneKeyFishing_ActionKeyIdle` says why the key does nothing.

## Fishing/Gear.lua

- Equips the chosen pole (or the best pole by fishing bonus) plus user-picked extra items. The best pole passes
  over a pole whose `GameData.FishingPoles[id].skill` is above the Fishing skill (an unknown skill, or a pole not
  listed, holds nothing back; the pole already in the main hand is usable, so it is never passed over); a pole
  chosen by hand is kept.
- It records only the slots it changed (`charDB.gearSwap`). On exit a slot is restored only if it still holds
  what the addon put there.
- The fishing bonus is parsed from tooltip lines that contain the client's localized Fishing spell name minus its
  first UTF-8 character (tooltips may lowercase it, and `string.lower` only handles ASCII).
- Weapons return only before the combat lockdown (`PLAYER_REGEN_DISABLED`); a restore asked for in the lockdown
  waits for `PLAYER_REGEN_ENABLED` (Gear's `restoreAfterCombat`: only a restore the lockdown refused, done there when fishing mode is off; Mode's exit
  does it otherwise). An attack during a cast defers the swap past that moment, so the weapons come back after the
  fight: the game's limit, not covered by constitution III's "weapons at once".
- `C_Item.EquipItemByName` fails silently while casting or channeling ([forever-api.md](../forever-api.md)).

## Fishing/Camera.lua

- Zooms to `settings.cameraDistance` on entering fishing mode and back on exit.
- The previous zoom is kept in `charDB.savedCameraZoom`, so it survives a `/reload`; `Camera.Forget` drops it on
  a real login (Mode.lua).
- A zoom is animated, so for 1.5 s after one the target, not `GetCameraZoom()`, is the starting point.

## Fishing/Bags.lua

Lures and fished containers.

- `FindLure` takes the best lure in the bags (`GameData.Lures` by `order`, best first) that is usable, not on its
  own cooldown (`C_Container.GetItemCooldown`, the global cooldown does not count) and not above the Fishing skill.
  It fires `LURE_READY` for lures passed over because of a cooldown, when the soonest one is ready.
- The skill rule: a lure whose `skill` is above `Skill.Get()` (the base rank, without bonuses: `VERIFY(V44)`) is
  never offered. Once the skill reaches it, the next `FindLure` offers it, in the same session. While the skill is
  unknown, nothing is held back. The values come from the original game (`VERIFY(V43)`,
  `specs/008-architecture-alignment/verification.md`). A lure not in `GameData.Lures` is never offered.
- An attempt counts as failed only when, 8 s later, the pole has no lure and the lure is not on cooldown; a failed
  lure is skipped until fishing mode is entered again.
- `Bags.DescribeLures` feeds the debug report.
- A container's loot window is matched to the open attempt by the item GUID (`GetLootSourceInfo`); nothing is
  opened over an open loot window; a container whose loot did not fit waits for free bag space, a locked one is
  skipped for the session.
- Everything looted from fishing goes into `fishedItems`, by the ID of its loot link (also an item the client does
  not know yet), so new Forever containers are opened without a list update. Bags reads the loot on its own
  `LOOT_READY`, where it also tracks the open loot window, not from `FISH_CAUGHT`, which comes only for the first
  loot of a counted cast.
- The bag iterator `ns.ForEachBagItem` is in Data.lua ([core.md](core.md)).

## Game data

The game data fishing mode reads is the model `ns.GameData` ([game-data.md](game-data.md)): the Fishing spells and
the rank steps with the NPC names (`Skill.lua`), the lures and fished containers (`Bags.lua`), the poles, the pole's
item class and the equipment slots (`Gear.lua`, `Action.lua`), the bobber (`Core/Data.lua`).

## Fishing/Skill.lua

- The Fishing skill (`Skill.Get`), rank names (`Skill.GetRankName`: the rank spell's subtext in the client's
  language, else `L`), and the next-rank advice `Skill.GetNextRank()` (state `later` / `now` / `level` / `cap`,
  the where sentence, the pin target, where each name came from). It stores the session's starting rank.
- Every game name is read by ID in the client's language (`C_Map.GetAreaInfo`, `C_Item.GetItemNameByID`,
  `C_QuestLog.GetTitleForQuestID`; the book and quest are requested at login), NPC names from a creature tooltip
  (kept once the client gave it), then `ns.GameData.NpcNames`, then English.
- Notices: "can learn" once per session per rank (chat and toast, waits for the character level), the cap with a
  raid warning the first time per session and a chat line on later fishing mode entries; the chat line carries a
  `worldmap:` link when a pin is possible (`Core/MapPin.lua`). Chat and the raid warning are here; the toast goes
  through `SKILL_WARNING`, shown by `UI/Toast.lua`. It checks on skill events, a level-up, after login, on
  entering fishing mode and at the end of a fight (`PLAYER_REGEN_ENABLED`). In a fight (`InCombatLockdown()`) the
  check does nothing: weapon skill-ups fire the skill events there, and a notice owed then comes after the fight.
- A name the game gives as a secret value (a creature tooltip line in an instance fight, seen 2026-11-08) counts
  as missing: the fallback name is used and nothing is cached.
- `Skill.DescribeNextRank` is the line of the statistics window and the minimap tooltip.
