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
  combat.
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
  If it cannot resume (combat), the camera and the weapons come back at once and the rest of the gear after
  combat.
- Leaving in combat only sets a pending exit (weapons back at once, the rest after combat).
- While the mode is on, the plain binding body of the action key only runs when combat dropped the overrides, so
  `OneKeyFishing_ActionKeyIdle` says why the key does nothing.

## Fishing/Gear.lua

- Equips the chosen pole (or the best pole by fishing bonus) plus user-picked extra items.
- It records only the slots it changed (`charDB.gearSwap`). On exit a slot is restored only if it still holds
  what the addon put there.
- The fishing bonus is parsed from tooltip lines that contain the client's localized Fishing spell name minus its
  first UTF-8 character (tooltips may lowercase it, and `string.lower` only handles ASCII).
- Weapons return immediately in combat; the rest waits until combat ends.
- `C_Item.EquipItemByName` fails silently while casting or channeling ([forever-api.md](../forever-api.md)).

## Fishing/Camera.lua

- Zooms to `settings.cameraDistance` on entering fishing mode and back on exit.
- The previous zoom is kept in `charDB.savedCameraZoom`, so it survives a `/reload`; `Camera.Forget` drops it on
  a real login (Mode.lua).
- A zoom is animated, so for 1.5 s after one the target, not `GetCameraZoom()`, is the starting point.

## Fishing/Bags.lua

Lures and fished containers.

- `FindLure` takes the best lure in the bags (`LURES`, best first) that is usable and not on its own cooldown
  (`C_Container.GetItemCooldown`, the global cooldown does not count); for lures passed over because of a cooldown
  it fires `LURE_READY` when the soonest one is ready.
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

## GameData/FishingRanks.lua

Data only, no logic, no `L`: `ns.FishingRanks[cap]` (the next rank's spell, the skill and level it can be learned
from, and where: trainer, book or quest with item / quest / NPC / area IDs, candidate uiMapIDs and the point,
English fallback names), `ns.FishingRankSpells` (rank spell per cap) and `ns.NpcNames[npcID][clientLocale]`. Game
data tables that are plain data belong in `GameData/`; the older ones (lures, containers, pole bonuses, spell and
bobber IDs) move there in 1.2.0 (`docs/release-plan.md`).

## Fishing/Skill.lua

- The Fishing skill (`Skill.Get`), rank names (`Skill.GetRankName`: the rank spell's subtext in the client's
  language, else `L`), and the next-rank advice `Skill.GetNextRank()` (state `later` / `now` / `level` / `cap`,
  the where sentence, the pin target, where each name came from). It stores the session's starting rank.
- Every game name is read by ID in the client's language (`C_Map.GetAreaInfo`, `C_Item.GetItemNameByID`,
  `C_QuestLog.GetTitleForQuestID`; the book and quest are requested at login), NPC names from a creature tooltip
  (kept once the client gave it), then `ns.NpcNames`, then English.
- Notices: "can learn" once per session per rank (chat and toast, waits for the character level), the cap with a
  raid warning the first time per session and a chat line on later fishing mode entries; the chat line carries a
  `worldmap:` link when a pin is possible (`Core/MapPin.lua`). Chat and the raid warning are here; the toast goes
  through `SKILL_WARNING`, shown by `UI/Toast.lua`. It checks on skill events, a level-up, after login and on
  entering fishing mode.
- `Skill.DescribeNextRank` is the line of the statistics window and the minimap tooltip.
