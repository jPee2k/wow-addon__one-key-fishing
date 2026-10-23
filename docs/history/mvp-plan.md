# OneKeyFishing: MVP plan (historical)

This is the original plan the addon was built from (versions 0.1 to 0.2), translated to English.
It is kept for reference; the code is the source of truth. Things that changed later:

- **Gear**: the first version saved a whole "fishing set" (`/okf saveset`). It was replaced by the
  current model: the best (or chosen) pole plus a list of extra items, restoring only the slots that changed.
- **Icon over the bobber**: dropped. The bobber has no nameplate, so nothing can be anchored to it;
  the indicator shows "No bobber" instead when the interact key would miss it.
- **Debug report**: the stage 0 API check became a short report for bug reports (`/okf debug`).

## Context

One-key fishing for WoW Forever without the mouse and without any bot behavior: every action is a key
press by the player. The client is build 1.60.1 and runs the modern (Mainline) API. The UI is in English.

## API spike results (stage 0, build 1.60.1.70450)

- Interface `16001` confirmed, `WOW_PROJECT_ID = 18`. The client may run in any language, so game data
  is always matched by ID, never by name.
- `INTERACTTARGET` exists. The CVars `SoftTargetInteract`, `SoftTargetIconGameObject`,
  `SoftTargetIconInteract` and `autoLootDefault` exist.
- Fishing rank spells are 7620 / 7731 / 7732 / 18248. The skill comes from `GetProfessions` +
  `GetProfessionInfo` (skillLine 356); `GetSkillLineInfo` does not exist. The rank cap shows as `maxRank`
  (for example 74/150 at Journeyman).
- Fishing pole: `classID 2`, `subclassID 20` (`Enum.ItemWeaponSubclass.Fishingpole`). Lures show up in
  `GetWeaponEnchantInfo`.
- Missing: `GetSpellInfo`, `GetItemInfo`, `EquipItemByName` and the classic auction API. Use `C_Spell.*`,
  `C_Item.GetItemInfo`, `C_Item.EquipItemByName` and `C_AuctionHouse.*`. Present: `C_EquipmentSet`,
  `MenuUtil`, `Settings`, `AddonCompartmentFrame` and all the needed secure templates.

## Stack

- Plain Lua 5.1, XML only for `Bindings.xml`. **No libraries** (no Ace3, no LibDBIcon): the addon is small.
- The native Settings API (Esc -> Options -> AddOns).
- `luacheck` with `.luacheckrc` (WoW API globals), `.gitignore`.
- SavedVariables: `OneKeyFishingDB` (settings, statistics, prices) and `OneKeyFishingCharDB` (per-character gear).

## Structure

```
OneKeyFishing/
  OneKeyFishing.toc      Interface 16001, SavedVariables, AddonCompartmentFunc
  Bindings.xml           two actions: Fishing action, Toggle fishing mode
  Core.lua               namespace, events, DB defaults, /okf
  Mode.lua               entering and leaving the mode, saving and restoring CVars
  Action.lua             secure button + secure handler for the key, action priorities
  Bags.lua               finding lures, clams and containers
  Gear.lua               remembering the current gear, equipping fishing gear, putting it back
  Camera.lua             zoom while fishing and restore
  Stats.lua              casts, catches, misses, zones, fish per hour
  Skill.lua              Fishing skill, rank cap, "learn the next rank" warning
  Prices.lua             vendor price + auction scan for fish
  UI/Indicator.lua       action icon near the center + cast timer (draggable)
  UI/Toast.lua           catch notifications above the indicator
  UI/StatsFrame.lua      statistics window
  UI/Minimap.lua         minimap button + tooltip
  UI/Settings.lua        settings panel
```

## Key mechanisms

- **Keys.** `Bindings.xml` adds two actions to the Key Bindings menu. Outside the mode the action key does
  nothing (it is a dedicated key). In the mode the addon reads `GetBindingKey(...)` and sets override
  bindings on those keys.
- **One key.** The overrides belong to a `SecureHandlerStateTemplate` frame:
  - not channeling -> `CLICK OneKeyFishingButton`; `PreClick` (out of combat) picks the action by priority:
    **no lure** (`GetWeaponEnchantInfo`) -> `type=item, target-slot=16`; **clam or container in the bags**
    -> `type=item` (bag slot); otherwise -> `type=spell` Fishing;
  - `UNIT_SPELLCAST_CHANNEL_START` (Fishing) -> the key becomes `INTERACTTARGET`; `CHANNEL_STOP` -> back
    to the button;
  - a `[combat]` state driver drops the bindings inside combat (secure snippet); after
    `PLAYER_REGEN_ENABLED` the mode is left completely.
- **Mode** (toggle key, minimap, `/okf`): save and set the CVars (`autoLootDefault`, `SoftTargetInteract`,
  `SoftTargetIconGameObject` / `SoftTargetIconInteract`), equip the gear, zoom the camera; on exit restore
  everything exactly as it was.
- **Statistics.** `LOOT_READY` + `IsFishingLoot()` -> a catch; a channel without loot -> a miss. Zone key:
  `C_Map.GetBestMapForUnit` + subzone. Per session and per zone history, skill progress.
- **Fishing time.** Two counters: *time in the mode* (from entering to leaving) and *time casting* (the sum
  of the Fishing channels). Counted per session, per zone and in total; saved in the DB and kept across
  `/reload` and relog (the running segment is written on `PLAYER_LOGOUT`). Optional pause while AFK
  (`PLAYER_FLAGS_CHANGED` + `UnitIsAFK`). Fish per hour and gold per hour use the time in the mode. A live
  timer (`h:mm:ss`) is shown in the statistics window, the minimap tooltip and optionally under the indicator.
- **Prices.** `C_Item.GetItemInfo` -> sell price; at the auction house a "Scan fish" button looks up only
  the items from the statistics.
- **Minimap.** A custom button that can be dragged around the minimap. Left-click: mode, right-click: menu,
  Shift+left-click: statistics. The tooltip shows the state, the bound keys and short instructions.
  Plus an Addon Compartment entry.
- **Settings (everything can be turned on or off):** auto loot, bobber icon, lures, clams, gear, camera
  (+ distance), leaving the mode when attacked, indicator (+ lock), notifications, minimap button, rank cap
  warning, timer under the indicator, timer pause while AFK.
- **Every command is available from a menu, no chat needed.** Slash commands are only a fallback:
  - settings panel, *Actions* section: toggle fishing mode, open statistics, scan auction (enabled only
    while the auction house is open), debug report, reset indicator position;
  - right-click on the minimap button -> a context menu (`MenuUtil.CreateContextMenu`) with the same
    actions + Settings;
  - the statistics window has Reset session / Reset all / Scan auction buttons.
- **Rank cap warning.** `Skill.lua` reads the current and maximum Fishing skill on `SKILL_LINES_CHANGED` /
  `CHAT_MSG_SKILL`, at login and when entering the mode. When `rank == max` and `max` is below the overall
  cap it shows a large notification "Fishing skill capped (150/150): learn the next rank" with where to
  learn it (Apprentice 75 / Journeyman 150 / Expert 225 / Artisan 300: trainer / book / quest). A warning
  appears a few points before the cap. It is shown once per cap and repeated on entering the mode until the
  next rank is learned.

## Stages

0. **API spike**: `git init`, TOC, `/okf debug` printing the interface version, `INTERACTTARGET`, the
   soft-target CVars, the Fishing spell, `C_EquipmentSet`, `AddonCompartmentFrame`, `IsFishingLoot`,
   `GetWeaponEnchantInfo`, `C_AuctionHouse`, `MenuUtil` and the profession skill API. Check in game,
   adjust the plan.
1. Mode + one key (cast / hook) + auto loot + CVar restore + combat safety.
2. Indicator, timer, notifications, bobber icon.
3. Gear, lures, clams.
4. Statistics + fishing time + vendor price + statistics window + rank cap warning.
5. Auction scan.
6. Settings with an Actions section, minimap button with a context menu, camera, CLAUDE.md.

## Verification

- `luacheck .` without errors after every stage.
- A manual in-game checklist after every stage: `/reload` without Lua errors; entering and leaving the mode
  restores CVars, gear, camera and bindings; the full cast -> hook -> loot cycle works with one key; being
  attacked while fishing does not break the keys; statistics and the timer survive `/reload` and relog, the
  timer stops outside the mode and while AFK; every menu action (settings and minimap) works without a slash
  command; the rank cap warning appears at the cap and stops after the next rank is learned.
