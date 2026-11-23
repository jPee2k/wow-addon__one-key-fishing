# Forever API

What is known about the WoW Forever API (Interface `16001`, build 1.60.1, `WOW_PROJECT_ID = 18`), and how to check
a call. The Forever client runs the modern (Mainline) API, not the Classic one. Facts confirmed in game go into
"Verified in game" below (constitution, Principle IV), including the answers to the `VERIFY` items of the
`verification.md` files of `specs/002-local-catch-db`, `specs/003-guild-group-sync`,
`specs/004-public-channel-sync` and `specs/005-catch-catalog`, which [docs/checklists/spike.md](checklists/spike.md)
collects in one game session. The questions that still wait for the game are in "Open questions" at the end.

## Checking a signature without the game

Signatures (not behaviour) can be checked without the game, in this order:

1. **The live client's own export.** Start the client with `-console` (Battle.net: game settings, additional
   command line arguments). On the login or character screen, open the console (`` ` ``) and run
   `exportInterfaceFiles code`. The code lands in `<WoW folder>/_forever_/BlizzardInterfaceCode/Interface/AddOns/`:
   - `Blizzard_APIDocumentationGenerated/*.lua` holds signatures, enums and events;
   - FrameXML shows how Blizzard itself uses an API (`Blizzard_FriendsFrame/Camelot/` is the Forever version of a
     frame);
   - the client build is in `<WoW folder>/.build.info` (product `wowf`).

   This works without entering the world, so it is available before launch. Re-export after every client patch.
2. **Public dumps** (slightly older builds):
   - the `forever` branch of [Gethe/wow-ui-source](https://github.com/Gethe/wow-ui-source/tree/forever)
     (`Blizzard_APIDocumentationGenerated`);
   - the global list in
     [Ketho/BlizzardInterfaceResources](https://github.com/Ketho/BlizzardInterfaceResources/blob/forever/Resources/GlobalAPI.lua);
   - the [1.60.1 API notes](https://warcraft.wiki.gg/wiki/Patch_1.60.1/API_changes/notes).

## Reading the dumps

- **Undocumented globals.** Old globals such as `GetLootSourceInfo` and `BNGetNumFriends` are not in the generated
  docs. For those, check Ketho's GlobalAPI list or a use in FrameXML.
- **Deprecated globals.** Files in `Blizzard_Deprecated*` (`BNSendGameData`, `ChatFrame_AddMessageEventFilter`,
  ...) load only with the `loadDeprecationFallbacks` CVar. Use the namespaced functions instead
  (`C_BattleNet.SendGameData`, `ChatFrameUtil.AddMessageEventFilter`).
- **Checked against build 1.60.1.70685 (2026-10-29).** The live export has every API the catch database relies on
  (`specs/002-local-catch-db/research.md` R11, `specs/003-guild-group-sync/research.md`), including
  `C_EncodingUtil`, `Enum.SendAddonMessageResult`, `Enum.AddOnRestrictionType` and `PanelTabButtonTemplate`.

## Finding what the game blocked

The game's yellow chat line "Interface action failed because of an AddOn" (`INTERFACE_ACTION_BLOCKED`) names no
addon and no function, shows once per session, and has two kinds of cause, which the usual tools tell apart only
in part (found 2026-11-18, fixes of the statistics, debug and minimap windows):

- **A protected call refused.** The game fires `ADDON_ACTION_BLOCKED` or `ADDON_ACTION_FORBIDDEN` with the addon
  and the function, and the taint log records it.
- **A check in Blizzard's Lua** that refuses addon code in combat (`InCombatLockdown() and not issecure()`) and calls
  `DisplayInterfaceActionBlockedMessage` itself: `HideUIPanel` / `ShowUIPanel`
  (`UIParentPanelManager.lua`), and in build 70959 the secure value that the menu's title, divider and spacer set
  for gamepad navigation. No event fires, and the taint log (even at level 2) records nothing.

Steps, one at a time, each handed to the author as an in-game check:

1. **Reproduce and note the step.** Out of combat `/reload` (the line shows again only in a new session), then the
   action in combat; note which press or click brings the line.
2. **The events.** Before the action:
   `/run local f=CreateFrame("Frame") f:RegisterEvent("ADDON_ACTION_BLOCKED") f:RegisterEvent("ADDON_ACTION_FORBIDDEN") f:SetScript("OnEvent",function(_,e,a,fn) print(e,a,fn) end)`.
   A line `ADDON_ACTION_BLOCKED <addon> <function>` names the protected call; no line means the second kind.
3. **The stack (the decisive step for the second kind).** Before the action:
   `/run hooksecurefunc("DisplayInterfaceActionBlockedMessage",function() print("OKF-TRACE", debugstack(2,10,0)) end)`.
   The hook runs on every refusal, also after the chat line stopped showing, and prints the Blizzard file and
   function that refused and the addon call that led there; a screenshot of the chat is enough.
4. **The taint log, for taint.** `/console taintLog 2` (1 records blocked protected calls, 2 also every global
   read that addon code tainted), `/reload`, the action, `/reload` again so the file is written; the log is
   `<WoW folder>/_forever_/Logs/taint.log` and Claude can read it directly. Lines "Execution tainted by
   OneKeyFishing while reading global BINDING_NAME_ONEKEYFISHING_*" come from the key bindings page and are
   harmless. Turn it off after (`/console taintLog 0`): at level 2 the file grows by megabytes.
5. **The code.** Read the function the stack names in the client export; when the file is missing there, the
   export is older than the client (compare `.build.info`) and the author re-exports.

## From the client export

Facts read from the export of build 1.60.1.70685 for the public channel (`specs/004-public-channel-sync`, research
R2-R4, R9). They say what exists and how Blizzard's own code uses it, not how it behaves; the spike checks that.

- A player may be in `Constants.ChatFrameConstants.MaxChatChannels` (20) chat channels; `ChatFrameUtil.CanAddChannel`
  checks it.
- Joining a locked channel fires `CHANNEL_PASSWORD_REQUEST`, and Blizzard answers it with
  `StaticPopup_Show("CHAT_CHANNEL_PASSWORD", ...)` (`EventRouting.lua`, `EventImplementation.lua`).
- A chat window drops the lines of channels that are not in its own list (`ChatFrameOverrides.lua`), and
  `ChatFrameMixin:RemoveChannel` takes one out of it (`ChatFrame_RemoveChannel` is deprecated). The Chat Channels
  window and Chat Settings > Channels list every channel the player is in, with no filter.
- Chat filters and event handlers must skip secret values (`issecretvalue`): under chat lockdown the message
  arguments can be secret, and reading them errors.
- `SetChannelPassword(name, password)` is what `/password` and the password popup call. There is no call that turns
  channel moderation off (only `ChannelModerator` / `ChannelUnmoderator` for one player).
- The `bit` library (`band`, `bor`, `bxor`, `bnot`, `lshift`, `rshift`) is called over 300 times in
  Blizzard's code; whether its results are signed is not documented.

Facts read from the same export for the catch catalog (`specs/005-catch-catalog`, research R4, R6-R8):

- Map pins: `C_Map.CanSetUserWaypointOnMap`, `SetUserWaypoint(UiMapPoint)`, `HasUserWaypoint`, `GetUserWaypoint`,
  `ClearUserWaypoint`, `C_SuperTrack.SetSuperTrackedUserWaypoint` and `UiMapPoint.CreateFromCoordinates` carry no
  restriction flag beyond the default; Blizzard's `/mappin` uses this sequence (`WaypointLocationDataProvider.lua`).
  `Enum.GameRule.WorldMapTrackingPinDisabled` gates the pin UI through `C_GameRules.IsGameRuleActive`.
- `C_Map.OpenWorldMap` is `HasRestrictions`; the global `OpenWorldMap(mapID)` is plain FrameXML
  (`Blizzard_WorldMap.lua`), gated only by `Enum.GameRule.WorldMapDisabled`, but called from addon code it taints
  the map ("Verified in game").
- A state driver's value reaches the `_onstate-<name>` snippet as a number when it reads as one:
  `SecureStateDriver.lua` `resolveDriver` applies `tonumber`, and `SecureHandler_StateOnAttributeChanged` passes it
  unchanged, so `"[combat] 1; 0"` gives `1`, never `"1"`. `HANDLE:ClearBindings()` is
  `ClearOverrideBindings(frame)` (`RestrictedFrames.lua`), so it also clears overrides the insecure code set with
  that owner (spec 009 research R1). Seen in game 2026-11-07 (V45): with `tonumber(newstate) == 1` the key's
  binding in a fight is `ONEKEYFISHING_ACTION`.
- Forever hides the "Show In-Game Navigation" checkbox (CVar `showInGameNavigation`, `Camelot/InterfaceOverrides.lua`).
- `C_Map.GetWorldPosFromMapPos` and `C_Map.GetMapPosFromWorldPos(continentID, pos, overrideMapID)` convert a point
  between maps.
- `C_MapExplorationInfo.GetExploredAreaIDsAtPosition(uiMapID, vector2)` returns explored areas only;
  `C_Map.GetAreaInfo(areaID)` names an area; there is no call that names an unexplored position. The addon takes
  the subzone of a cast from the explored areas at the player's own position matched against `GetSubZoneText()`
  (both folded, so letter case never matters).
- `CaseAccentInsensitiveParse(text)` (`LocalizationDocumentation.lua`) and `strcmputf8i(a, b)` (used by
  `AddonList.lua`) exist.
- `WowScrollBoxList`, `CreateScrollBoxListLinearView`, `ScrollUtil.InitScrollBoxListWithScrollBar`,
  `MinimalScrollBar`, `CreateDataProvider` and `SearchBoxTemplate` load in Forever (`Blizzard_SharedXML.toc`, no
  game-type limit); Forever's friends list uses the scroll list.

## Verified in game

- Closing a window in combat (2026-11-18): `HideUIPanel` returns at once for addon code in combat
  (`UIParentPanelManager.lua`, `CheckProtectedFunctionsAllowed`: `InCombatLockdown() and not issecure()`), with
  no error and no `ADDON_ACTION_BLOCKED` event; the chat line "Interface action failed because of an AddOn" shows
  once per session. The close button of `BasicFrameTemplateWithInset` (`UIPanelCloseButton_OnClick`) hides its
  parent that way, so it did nothing on the debug report window in a fight; on the statistics window, built from
  the same template, it did close the window, for a reason not found. Escape through `UISpecialFrames` closes
  an addon window in combat and leaves the game menu closed. The addon's windows give the close button their own
  script (`frame:Hide()`, `ns.SetupWindow`).
- Stacking (from the export, 2026-11-18): the game's popups (`StaticPopupBaseTemplate`) are `DIALOG` and top-level,
  and `StaticPopup_Show` raises them; menus open in `FULLSCREEN_DIALOG`; the Settings panel is `HIGH` and
  top-level. A top-level addon window in `DIALOG` would rise over a popup when clicked, so the addon's windows are
  `HIGH`.
- Menus in combat (2026-11-18, build 70959): a `MenuUtil` menu built by addon code opens in combat, but its
  title, divider and spacer elements call `SmartNavigation_MarkFrameIgnored`, which in this build sets a secure
  value (`Blizzard_GamepadSmartNavigation/SecureHelper.lua`, `SetSecureValue`; not in the 70685 export) and is
  refused in combat with the "Interface action failed because of an AddOn" line and no `ADDON_ACTION_BLOCKED`
  event (found by a `hooksecurefunc` on `DisplayInterfaceActionBlockedMessage` printing `debugstack`; the taint
  log at level 2 recorded nothing). Buttons, checkboxes and radios do not. The minimap menu leaves its title out
  in combat; the addon's other menus have none of the three.
- The fishing sounds' settings page (spec 013, 2026-11-16, enUS): `MinimalSliderWithSteppersTemplate` in a canvas
  settings page works as in the export (`Init(value, min, max, steps, formatters)`, the `Label.Right` formatter,
  `RegisterCallback(Event.OnValueChanged)`, the value on the child `.Slider`) (V50). An addon `.ogg` played with
  `PlaySoundFile(path, "Master")` is heard, and the pre-rendered volume steps sound quieter (V46); switching
  the sounds off mid-sound stops it (`StopSound(handle, fade)`). `PlaySoundFile` has no volume argument.
  The sound CVars (`Sound_MusicVolume`, `Sound_AmbienceVolume`, `Sound_DialogVolume`) set by `C_CVar.SetCVar` show
  at once in Options -> Audio (V48, entry side). The fish line "No fish are hooked." (`ERR_FISH_NOT_HOOKED`) comes
  as `UI_INFO_MESSAGE` (messageType 417, the text as 2nd argument), not as `UI_ERROR_MESSAGE`, and a too-early
  press ends the fishing channel; the loot of a hook comes at once (V47). `Sound_EnableSoundWhenGameIsInBG` set by
  `C_CVar.SetCVar` keeps all game sound, the addon's `PlaySoundFile` included, with the window unfocused (V49).
  The sound CVars can be set at `PLAYER_REGEN_DISABLED` and take effect at once: the music comes back as the fight
  starts (V48).
- The addon list (character screen -> AddOns) reads `## Notes-<code>` and `## Category-<code>` from the TOC in the
  client's language, UTF-8 included (checked on a German client, 2026-11-03).
- Client answers on launch day (EU realm, ruRU client, game 1.60.1 build 70790, 2026-11-05):
  - `C_Map.GetAreaInfo(35 / 33 / 517 / 15)` gives Booty Bay, Stranglethorn Vale, Tidefury Cove, Dustwallow Marsh
    in the client's language.
  - `C_Item.GetItemNameByID(16083)` gives "Expert Fishing - The Bass and You"; `C_QuestLog.GetTitleForQuestID(6607)`
    gives **nil**, also 5 s after `C_QuestLog.RequestLoadQuestByID(6607)`, and `C_QuestLog.GetQuestInfo(6607)` is nil
    (open: another quest ID on Forever, or no data for a quest this character cannot see; check at Nat Pagle).
  - `C_Spell.GetSpellSubtext(7620 / 7731 / 7732 / 18248)` gives Apprentice / Journeyman / Expert / Artisan in the
    client's language: the rank names can be read from the client.
  - Font files (`SetFont` test from `/run`): `2002`, `ARKai_T`, `bKAI00M`, `FRIZQT___CYR` exist; `ARHei` and
    `blei00d` do not. The language menu still shows Korean and both Chinese names readably.
  - The game reorders a binding's two keys on `/reload` (a key set in the left column can come back in the right
    one, in the Keybindings window too). `GetBindingKey` returns them in that current order, so the addon shows the
    keys in the order of the Keybindings columns, not in the order the player set them.
  - Lua 5.1 in the game raises an error for `tostring()` with no value (a function that returns nothing);
    the tests did not catch it (`Debug.lua:84`), so wrap such calls as `tostring((f()))`.
  - `YES`, `NO` and `CANCEL` are the client's language, not the addon's.
- Release 1.1.0 at level 10 (EU realm, enUS client, 2026-11-06):
  - Forever uses the Classic uiMapIDs: `C_Map.GetMapInfo(1434)` (Stranglethorn Vale) answers and
    `C_Map.CanSetUserWaypointOnMap(1434)` is true, so the pin for Booty Bay goes on map 1434, not on 224.
  - `C_Map.SetUserWaypoint(UiMapPoint.CreateFromCoordinates(...))` from addon code sets the pin, and
    `C_SuperTrack.SetSuperTrackedUserWaypoint(true)` tracks it: the minimap's edge arrow (the arrow on screen
    needs the hidden CVar `showInGameNavigation`, which reads `0`; V31, below).
  - The global `OpenWorldMap(mapID)` called from addon code opens the map but taints it: the field
    `targetScrollY` of the map canvas (`MapCanvas_ScrollContainerMixin.lua:445`) counts as the addon's, and in a
    later fight the map's quest pins are blocked (`Button:SetPassThroughButtons()`, "Interface action failed
    because of an AddOn", `Logs/taint.log` with `/console taintLog 1`). The addon no longer calls it (spec 009); a
    pin leaves the map closed, and the map works in a later fight (R14, seen 2026-11-07).
  - `C_TooltipInfo.GetHyperlink("unit:Creature-0-0-0-0-2626-0000000000")` gives Old Man Heming's name in line 1.
  - Journeyman Fishing is learned at a trainer at character level 10.
  - Old Man Heming (NPC 2626) stands in Booty Bay at 0.2745 / 0.7719 of map 1434 and sells item 16083, "Expert
    Fishing - The Bass and You" (also 6256 Fishing Pole, 6529, 6530, 6532 lures and 273636 Chef's Knife).
  - A chat link `|Hworldmap:<mapID>:<x*10000>:<y*10000>|h[...]|h` built by an addon works: a click sets the pin and
    opens the map through the game's own handler, with no taint (a fight afterwards is clean).
  - Nightcrawlers (6530) and Shiny Bauble (6529) have no item cooldown: right after a 6530 was applied,
    `C_Container.GetItemCooldown` gives 0 for both (the other lures are not checked yet).
  - `C_Item.IsUsableItem` is true for a lure that needs more Fishing skill than the character has: the game
    refuses it only when it is applied.
  - `C_Item.EquipItemByName` from addon code is blocked in combat ("An action was blocked in combat because of
    taint from OneKeyFishing - EquipItemByName()", `taint.log`), also for weapons; in the `PLAYER_REGEN_DISABLED`
    handler, before the lockdown, it still swaps them.
  - The game refuses a lure above the Fishing skill with "Cannot apply ..." (since spec 008 the addon does not
    offer one: `GameData/Lures.lua`, V43 / V44). The lures' tooltips give the original requirements: Nightcrawlers and
    Aquadynamic Fish Lens 50, Bright Baubles, Flesh Eating Worm and Aquadynamic Fish Attractor 100, Shiny Bauble none
    (2026-11-11, V43).
  - The Fishing channel lasts 30 s (`UnitChannelInfo("player")` end minus start, 2026-11-11, V26).
  - `GetBuildInfo()` gives "1.60.1" and the build "70790" (closes V7).
  - The bobber's GUID is `GameObject-...-35591-...`: object ID 35591, read from the `softinteract` unit (V3, the
    bobber side; the cast, hook and "No bobber" steps pass on it).
  - In Booty Bay `C_Map.GetBestMapForUnit("player")` is 1434 (the town has no map of its own) and
    `C_Map.GetPlayerMapPosition(1434, "player")` gives the position (V1 / V2 in part).
  - `C_Map.HasUserWaypoint` and `C_Map.GetUserWaypoint` see a pin the player set by hand, so the replace question
    works; the game rule `WorldMapTrackingPinDisabled` is not active in the open world (V30 in part).
  - The auction scan: commodity search result 1 has `unitPrice`, item search result 1 has `buyoutAmount`, and both
    give prices (V4 / V5 in part).
  - The `TooltipDataProcessor` item post call adds lines to bag item tooltips (V38 in part).
  - The Addon Compartment exists (the addon's entry shows and works).
  - A settings page frame that is created shown gets no `OnShow` on its first view in a session (spec 007): create
    it hidden.
- The shared catch database build (`002-shared-db`, EU realm, enUS client, 2026-11-06), the quick run before the
  spike:
  - `PanelTabButtonTemplate` with `PanelTemplates_SetNumTabs` / `PanelTemplates_SetTab` / `PanelTemplates_TabResize`
    draws the statistics window's three tabs in the game's tab look (closes V6).
  - `JoinTemporaryChannel` called from addon code at login, with no key press, joins the hidden channel
    `OneKeyFishingShare` (`/okf share`: "Public channel: in use"; V19 in part, the messages are not seen yet).
- The first spike report (`/okf spike`, Thunder Bluff, out of combat, not fishing, 2026-11-06):
  - Thunder Bluff has its own map 1456 of type 3 (Zone), parent Kalimdor 1414, and `GetPlayerMapPosition` gives a
    position there; `CanSetUserWaypointOnMap` is true for 1456 and 1414. At the pond no explored area is at the
    position and `GetSubZoneText()` is empty (V1, V2, V30, V34 in part).
  - An open-water catch has the loot source `GameObject-...-35591-...` (the bobber), `ns.IsPoolLoot()` false (V3 in
    part).
  - `RegisterAddonMessagePrefix` gives 0; `SendAddonMessage` `WHISPER` to self and to a made-up name both give `0`
    (Success, not `TargetOffline`), and the made-up one prints "No player named '<name>' is currently playing."
    (V12 in part).
  - `BNET_CLIENT_WOW` is `WoW`, `WOW_PROJECT_ID` 18; Battle.net game accounts of Forever friends have
    `clientProgram` WoW and `wowProjectID` 18; `C_BattleNet.SendGameData` returns 0. 2026-11-10: with a Battle.net
    friend in Forever running the addon (no guild, group or character friend in common), `/okf share` counted one
    player heard on Battle.net and one exchange; 22 sends returned 0: `BN_CHAT_MSG_ADDON` brings the messages
    (closes V13).
  - Out of combat in a capital no `C_RestrictedActions` restriction is active, `InChatMessagingLockdown()` is
    false, `AreOutgoingAddonChatMessagesRestricted()` true (V14 in part).
  - `C_EncodingUtil` CBOR, Deflate and Base64 round-trip a record (closes V15).
  - `MaxChatChannels` is 20; the limit text is "You can only be in 20 channels at a time." (V23 in part).
  - `bit` exists with unsigned results (`bnot(0)` = `band(-1, 4294967295)` = 4294967295); `ns.SHA256("abc")` is the
    known digest; 64 proof steps took 19.8 ms (V26 in part).
  - `CaseAccentInsensitiveParse` on an enUS client folds letter case (Latin and Cyrillic) but keeps accents
    ("Ab", E acute, Cyrillic capital Shcha -> "ab", e acute, small shcha); `strcmputf8i("b", "A")` is 1 (V36 in part).
  - `WowScrollBoxList`, `MinimalScrollBar` and `SearchBoxTemplate` can be created, `CreateScrollBoxListLinearView`,
    `ScrollUtil.InitScrollBoxListWithScrollBar`, `CreateDataProvider` and the atlas `Waypoint-MapPin-Untracked`
    exist (V37, the API side).
  - The CVar `showInGameNavigation` reads `0`, although the arrow showed for the 1.1.0 pin (V31).
- The second spike report (Mulgore at Stonebull Lake, 2026-11-06):
  - Mulgore is map 1412 of type 3 with a position. `GetSubZoneText()` is "Stonebull Lake", yet
    `C_MapExplorationInfo.GetExploredAreaIDsAtPosition(1412, position)` returns nothing (V34 fails in part).
  - 64 proof steps took 19.0 ms again: a SHA-256 step costs about 0.3 ms in the game (V26).
  - The error path of `ns.Safe`: the `scriptErrors` popup shows the error once with the failing function as its
    first Lua line, and the error log keeps the same stack and count (closes V42).
  - A whisper (`SendAddonMessage` `WHISPER`) to `UnitName("player")` gives `0` but prints "No player named
    '<first name>' is currently playing." and never echoes: `UnitName` gives the first name and the last name as two
    values, so the target was the first name alone (V11).
- The third spike report (Stonebull Lake, the bobber out, 2026-11-06):
  - `C_Map.GetPlayerMapPosition` gives a position while Fishing is channeled (`UnitChannelInfo` spell 7731) (V1).
  - `GetExploredAreaIDsAtPosition(1412, position)` gives area 222 "Bloodhoof Village" where `GetSubZoneText()` is
    "Stonebull Lake": the exploration areas are the map's overlay regions, not the subzone (V34).
  - The test channel, from the previous report's checks: `NOT_ALLOWED_IN_CHANNEL` (argument the channel name) after
    the addon message to it, no echo of that message; `CHANNEL_OWNER` names the player (who joined first);
    `PASSWORD_CHANGED` once for setting and once for clearing a password, with the player's name; one `YOU_LEFT`
    for the leave; the channel numbers after the leave equal those before the join (V19, V22, V24, V41).
- Pool loot (Ratchet, 2026-11-06): a catch from an Oily Blackmouth School, with the bobber in the pool, has the
  loot source `GameObject-...-35591-...`: the bobber, as in open water, so `GetLootSourceInfo` does not tell a
  pool catch apart (V3 fails).
- In a group, `SendAddonMessage` `PARTY` returns 0 and echoes, with the sender "First Last" (no realm) (V10, V11).
- In a guild, `SendAddonMessage` `GUILD` returns 0 and echoes, the sender shaped the same way; a guildmate running
  the addon is heard and exchanged with (2026-11-11, V10).
- In the cave before Wailing Caverns (subzone "Wailing Caverns", 2026-11-06) `C_Map.GetBestMapForUnit("player")`
  is the continent Kalimdor 1414 (type 2), with a position on it; no cave map; `GetExploredAreaIDsAtPosition`
  gives nothing (V2, V33, V34).
- `TooltipDataProcessor` item post calls fire for item tooltips in bags, the auction house list, a chat link's
  `ItemRefTooltip` and an addon's own rows (`GameTooltip:SetItemByID`) (V38, 2026-11-07).
- The navigation arrow (2026-11-07): with `showInGameNavigation` at `0`, `C_SuperTrack.SetSuperTrackedUserWaypoint(true)`
  after a pin gives the minimap's edge arrow but no arrow on screen (V31).
- Items (spike with a synthetic seed, 2026-11-06): of item IDs 6000-6899, 36 are unknown to
  `C_Item.GetItemInfoInstant` while `C_Item.DoesItemExistByID` reports every one as existing;
  `C_Item.RequestLoadItemDataByID` of such an item brings `ITEM_DATA_LOAD_RESULT` with `false`, and it stays without
  a name, quality or instant info (V27, V35). `GetChannelName(name)` gives the number, the name, 0 and false for a
  channel the player is in, 0 otherwise; `IsDisplayChannelOwner()` is true for a channel the player created.
- Channel commands in one macro (2026-11-06): only the first `/join` or `/leave` of a channel takes effect; a
  `/leave X` then `/join X` gives one `YOU_LEFT` and the player stays out, a `/join X`, `/leave X`, `/join X` while
  out gives one `YOU_CHANGED`. A join, typed or from addon code, always brings `YOU_CHANGED` ("Changed Channel:"),
  never `YOU_JOINED` (V41).
- The auction house (Orgrimmar, 2026-11-06): a commodity search (Raw Brilliant Smallfish, 6291) gives 31 results
  with `unitPrice` and `quantity` in ascending price order, `GetCommoditySearchResultsQuantity` 1592 (later 1662, as the auction house list shows) and
  `HasFullCommoditySearchResults` true (V4); an item search (Spiked Club of Power, 4564) gives results with
  `buyoutAmount` and `quantity` 1 (V5 in part). An item with no listing gives 0 results. An item result row is a
  group of equal auctions of one piece each: `buyoutAmount` is the price of one piece, `quantity` the number of
  them (V5, 2026-11-18: 53 Pound Yellowtail 13878, rows of 1, 7, 1, 3 and 2 pieces at 56s 80c to 61s; the row of 7
  had `buyoutAmount` 5685). Never divide it by the quantity.
  A poor quality (grey) item can be listed: `C_AuctionHouse.IsSellItemValid` is true for one in the bags
  (Snapped Spider Limb, 2026-11-18).
- The auction house's request system (Thunder Bluff, 2026-11-17, `/run` with an event listener):
  - A healthy request is `AUCTION_HOUSE_THROTTLED_MESSAGE_SENT`, `..._RESPONSE_RECEIVED` about 0.2 s later, the
    result event, then `AUCTION_HOUSE_THROTTLED_SYSTEM_READY` about 0.5 s after the send. The addon's scan of 40
    items with every item key cached took 28 s: 40 requests, 0.7 s each, no extra page; that is the server's pace.
  - A request the server never answers jams the client's auction house: `IsThrottledMessageSystemReady()` stays
    false, every later request is `..._QUEUED` and drops the one queued before it (`..._DROPPED`), the window shows
    nothing. Closing the window, reopening it and `/reload` do not help; logging the character out and in does.
  - The server never answers `C_AuctionHouse.SearchForItemKeys` (one listed item key, a price sort, the system
    ready): it jams the auction house. Do not call it.
  - The server never answers `SendSearchQuery` for an item the client knows but the game does not have yet (Winter
    Squid 13755, Plated Armorfish 13890: `C_Item.DoesItemExistByID` true, the item key info cached, a price
    sort): it jams the auction house too. An item that exists and has no listing is answered (8 of the scan's 40).
    Not a rule of the item: on 2026-11-18 the rebuilt scan (spec 018) searched Winter Squid among 68 items and got
    its price (68 items in 41 s, 54 prices, no jam). What made the two searches of 2026-11-17 unanswered is not
    known; Plated Armorfish was answered too, later the same day (V58).
  - The rebuilt scan (spec 018, 2026-11-18): `GetItemKeyInfo` for a whole list of 68 to 72 items at its start, then
    one `SendSearchQuery` every 0.6 s: every request answered, none without its item key info, 41 to 47 s a scan,
    also right after another scan (V56, V57). Commodity results come cheapest first over the whole list (Raw
    Spotted Yellowtail: 4750 pieces in 48 rows from 40c to 3s 12c), so the price of the first pages equals the
    price of all (V55).
  - `C_AuctionHouse.GetItemKeyInfo` is nil for an item key the client has not cached;
    `ITEM_KEY_ITEM_INFO_RECEIVED` (itemID) follows within 0.01 s, and the cache survives a relog. A scan that
    sends its searches without waiting for the key info is slow and loses prices: the same 40 items with 25 keys
    not cached took 162 s (53 requests, 13 of them extra pages) and found 31 prices, then 28 s and 32 prices.
  - Auctionator 347 works: its summary scan (`SendBrowseQuery` with an empty search, then
    `RequestMoreBrowseResults`) read the whole house, 6765 items, in 32 s. `Auctionator.API.v1` is there:
    `GetAuctionPriceByItemID` gives the cheapest unit price in copper (87 for item 6291, as the house shows),
    `GetAuctionAgeByItemID` the days since (0), `RegisterForDBUpdate` calls back after one of its searches and
    once at the end of a scan (also during the addon's own scan). It keeps its prices per game mode
    (`Auctionator.State.CurrentRealm` is `PvP`). Its tooltip lines ("Vendor", "Auction") show on the addon's own
    row tooltips (`GameTooltip:SetItemByID`), so the addon leaves out its own price line for an item Auctionator
    prices (V59, 2026-11-18). A character with Auctionator disabled has neither API function.
- Inside the Wailing Caverns instance (2026-11-06): `C_Map.GetBestMapForUnit("player")` is nil, no position,
  `C_RestrictedActions.GetAddOnRestrictionState(Enum.AddOnRestrictionType.Map)` is 2 and the `Map` restriction is
  active (the others are not); `C_Map.CanSetUserWaypointOnMap(nil)` raises a usage error (V1, V14, V30).
- In a dungeon (2026-11-11): `UnitGUID("softinteract")` on the bobber is a secret value; splitting it raises
  "attempt to perform string conversion on a secret string value"; since spec 012 the addon checks `issecretvalue`
  first (`ns.IsSecret`) and treats the bobber as unknown there. During a boss fight
  the `Chat`, `Combat`, `Encounter` and `Map` restrictions are active, `InChatMessagingLockdown()` is true, and
  `SendAddonMessage` (`GUILD`, `WHISPER`) and `C_BattleNet.SendGameData` return 11.
- At Ratchet (The Barrens 1413, 2026-11-06) `GetExploredAreaIDsAtPosition` gives area 392 "Ratchet", the same as
  `GetSubZoneText()` (V34 works there).
- Places by `/run` (2026-11-08, before spec 011):
  - In the cave before Wailing Caverns the reported map is Kalimdor 1414 with the position (0.519, 0.551), and
    `C_Map.GetMapInfoAtPosition(1414, x, y)` gives 1413 "The Barrens", `mapType` 3 (Zone): the zone under a point
    of the continent is found (V2, V33). `C_Map.GetPlayerMapPosition(1413, "player")` gives a position there too
    (x 0.461).
  - `C_Map.GetAreaInfo(id)` over the IDs 1 to 20000, compared with `GetSubZoneText()`, finds exactly one area at
    Ratchet (392) and at Stonebull Lake (223, where the explored regions gave nothing or 222); at the Thunder
    Bluff pond `GetSubZoneText()` is empty. The walk costs 4.3 to 4.7 ms; the highest area ID with a name is 17853
    (V34).
- Addon messages in a custom channel (`/run` tests, 2026-11-06, full account, level 11): typed text in a temporary
  channel shows, but `C_ChatInfo.SendAddonMessage(prefix, text, "CHANNEL", n)` returns `0` (Success) and the server
  then sends `CHAT_MSG_CHANNEL_NOTICE` `NOT_ALLOWED_IN_CHANNEL` with the channel name (`CHAT_NOT_ALLOWED_IN_CHANNEL_NOTICE`
  "[%s] That operation is not permitted in this channel."); no `CHAT_MSG_ADDON` echo comes back. The same for a
  channel the player owns and for `OneKeyFishingShare` (V19 fails). A send to channel number 0 returns 7
  (`InvalidChannel`). The addon's channel is off (spec 010). Passes again since 2026-11-16 (below).
- Addon messages in a custom channel, again (`/run` test, 2026-11-16, Drog Earthshaker): `JoinTemporaryChannel("OkfTest42")`
  gives `YOU_CHANGED` on channel 5; `C_ChatInfo.SendAddonMessage("OKFT", "ping", "CHANNEL", 5)` returns `0`, **no**
  `NOT_ALLOWED_IN_CHANNEL` comes, and the sender's own `CHAT_MSG_ADDON` (`OKFT`, `ping`, `CHANNEL`, "Drog
  Earthshaker") comes back; `LeaveChannelByName` gives `YOU_LEFT`. The refusal of 2026-11-06 no longer shows for
  this character: a server change, not a limit by character level (a level 4 character sends too, below).
- Addon messages between two players in a custom channel (`/run` test, 2026-11-16, Drog Earthshaker level 31 and
  Fowik Che level 27, client 1.60.1.70938; the `CHANNEL` path does not depend on guild, group or friends): in `OkfTest42` each one's
  `SendAddonMessage(..., "CHANNEL", n)` returns `0`, the other receives `CHAT_MSG_ADDON` (`OKFT`, text, `CHANNEL`,
  "First Last") and the sender its own echo; ten messages sent in one frame all arrive, in order; a 255-byte message
  arrives whole; no `NOT_ALLOWED_IN_CHANNEL`. The same in `OneKeyFishingShare` (V19 passes, V20 in part). The
  addon must be disabled for that test: 1.2.0 leaves a channel of its own names that it did not join
  (`Exchange/Channel.lua`, `OnNotice`), so a `/run` join of `OneKeyFishingShare` gets `YOU_LEFT` within a second.
  That leave also shows that `CHAT_MSG_CHANNEL_NOTICE` names the channel in argument 9 (its base name, matched by
  `OnNotice` and the chat filters), and argument 4 is "<number>. <name>" (the `/run` listener printed it).
- Addon messages in a custom channel, argument by argument (`/run` test, 2026-11-17, Green Neerg level 1 and Plague
  Corvus level 8, not friends in game or on Battle.net): `CHAT_MSG_ADDON` gives prefix, text, `CHANNEL`, the sender
  "First Last", argument 5 (`target`) "8. OkfTest42" and argument 8 (`name`) "OkfTest42", the base name (V53). A
  level 1 character sends and receives. A client that has not registered the prefix gets nothing, its own echo
  included, though its sends arrive (`C_ChatInfo.RegisterAddonMessagePrefix`).
- Chat channel limit (2026-11-17, dev build): `C_ChatInfo.GetNumActiveChannels()` counts temporary channels too (it
  equals the entries of `GetChannelList()`). With 20 channels taken, `JoinTemporaryChannel(name)` returns nothing and
  the chat shows "You can only be in 20 channels at a time." (`ERR_TOO_MANY_CHAT_CHANNELS`); below the limit it
  returns `0` (V23).
- Chat channel numbers (2026-11-22, Drog Earthshaker, client 1.60.1.71037, Stranglethorn Vale; found after the
  addon's channel was seen on number 1 with General on 7):
  - A join gets the lowest free number. The game keeps the numbers of its own channels the client knows while they
    are not active (Trade 2, Services 4, TradeLocal 5, the city's OOC 6 outside a city: listed greyed in Chat
    Settings > Channels, `GetChannelName(number)` gives 0 for them). It does **not** keep General's number once the
    player leaves General: after `/leave 1` a join of `OneKeyFishingShare` got number 1, and `/join General` then put
    General on 7, behind every channel. Nothing puts it back by itself.
  - "Chat Defaults" in the chat settings (`ChatConfig_ResetChatSettings`, which calls
    `C_ChatInfo.ResetDefaultZoneChannels()`) puts the game's channels back on their numbers and a custom channel
    behind them (General 1 ... OOC 6, `OneKeyFishingShare` 7).
  - `/run C_ChatInfo.SwapChatChannelsByChannelIndex(1,7)` (what a drag of a row in Chat Settings > Channels calls)
    traded the two numbers with no error and no "Interface action failed": General on 1, the addon's channel on 7.
    Typed, so with a key press. From `C_Timer.After`, with no key press, it works the same (V70, the same day:
    General on 6 and the channel on 1 traded places, the numbers were there at once), and the addon's own swap ran
    with no "Interface action failed", also around a fight. The chat edit box keeps its channel as a number (its
    `channelTarget` attribute): left on General's old number, it opened the hidden channel after the swap. The box
    sends with `C_ChatInfo.SendChatMessage`, which has restrictions and takes secret arguments only untainted, so
    addon code does not write that attribute (`docs/tech-debt.md`).
  - `C_ChatInfo.GetGeneralChannelLocalID()` gives General's number (`1`; `6` with General put behind) and nothing
    ("empty result") while the player is not in General (V71).
  - `C_ChatInfo.GetChannelInfoFromIdentifier("General")` gives `zoneChannelID=1`, `channelType=1`, `localID` (the
    chat number), `name="General - Stranglethorn Vale"`, `shortcut="General"`; for a custom channel `zoneChannelID=0`,
    `channelType=0`. `GetChannelList()` gives triples of number, short name ("General", "Trade") and `true` for a
    number that is only kept; `GetChannelName(number)` gives the long name ("General - Stranglethorn Vale") (V72).
  - A channel of the game joined again takes the lowest free number: LocalDefense, left and joined with the addon's
    channel on its number 3, came on 6. A `/reload` lists every channel and kept number as before it (V73).
  - After a login the client does not know the city's OOC yet: the addon's channel joined on 6, and "Chat Defaults"
    then listed OOC on 6 and the channel on 7.
  - A `/reload` keeps every number. A logout and login does not bring the addon's temporary channel back (it was not
    in the list right after the login); the addon joins it again after its delay.
  - A layer change by a group invite (the LayerSwap addon) changes no number.
  - The checkbox of the channel's row in Chat Settings > Channels, ticked by hand, shows it in that window; the addon
    takes it out again (`ChatFrame1:ContainsChannel("OneKeyFishingShare")` was false afterwards).
- Channel moderation by players (2026-11-17, the owner of `OneKeyFishingShare`, no addon): `/ckick <channel> <name>`,
  `/owner <channel>`, `/run ChannelKick(channel, "First Last")` and `/run DisplayChannelOwner(channel)` print nothing
  and change nothing; the kicked player stays in the channel. `/password <channel> x` works (V24). `/chatlist` prints
  nothing either; `GetChannelList()` lists the channels (number, name, disabled). A level 4 character
  (Showtime Holyhell) sends and receives in `OkfTest42` the same way: no limit by level (V19 closed). Both
  players were of one faction (one faction per account on a PvE realm): the other faction is not checked (V20).
- Channel password and owner (`/run` test, 2026-11-16, two players in `OkfTest42`): the first to join owns it.
  `/password OkfTest42 x` by the owner gives every member `CHAT_MSG_CHANNEL_NOTICE_USER` `PASSWORD_CHANGED` with
  the owner's "First Last". A join without the password fires `CHANNEL_PASSWORD_REQUEST` (the channel name), then
  the notice `WRONG_PASSWORD`; `GetChannelName` gives 0, and Blizzard's popup "Please enter a password for
  '<name>'." stays on screen until closed. `JoinTemporaryChannel(name, "x")` with the password joins, and addon
  messages pass. When the owner leaves, the leaver gets `SET_MODERATOR` with the new owner's first name only
  ("Drog"), then `OWNER_CHANGED` ("First Last") and `YOU_LEFT`; the one who stays gets `OWNER_CHANGED` with its own
  "First Last" and may then clear the password (`/password OkfTest42`: `PASSWORD_CHANGED` with its name); a join
  without a password works again (V24, V21 in part). Once the second player's chat showed "Interface action failed
  because of an AddOn" near these notices; its source is not known.
- Character names (`/run` tests, 2026-11-06): a Forever character has a first and a last name, written with a space
  ("Drog Earthshaker"); players whisper with `/w First Last`, and chat shows "[First Last]". `UnitName("player")`
  returns two values, the first name and the last name ("Drog", "Earthshaker"; the second is not a realm), so
  `print(UnitName(...))` looks like the full name and a call that passes `UnitName(...)` as its last argument sends
  the first name alone. `UnitFullName` does the same (two values, no realm). `GetUnitName(unit, true)` gives one
  string, "First Last" (also for a target: "Cadiee Druid"). `GetNormalizedRealmName()` gives an internal name
  (`CAMWOWEU4Realm4PvP`). The addon keeps names as the game gives them; its own name is `GetUnitName("player", true)`
  (spec 010).
- Forever's friends window lists Battle.net friends with their Forever character ("Showtime Stormbringer, Lvl 10");
  with no character friend added, `C_FriendList.GetNumFriends()` is 0 (2026-11-06). `SendAddonMessage` `WHISPER` to "First Last" arrives, and `CHAT_MSG_ADDON` names the
  sender "First Last" (no realm); to "First Last-Realm" or "First-Realm" it returns `0` but the game prints "No
  player named ..." (showing "First-Realm" as "First Realm") and nothing arrives (V11 fails, V12 in part).
  - Joining a temporary channel from addon code brings the notice `YOU_CHANGED` only (no `YOU_JOINED`), no chat
    window lists the channel, and `SendAddonMessage` to it gives `0` (V19, V21 in part).
- `INTERACTTARGET` exists. The bobber is readable as unit `softinteract` (name and GUID), but it has **no
  nameplate** and `UnitExists` is false, so nothing can be anchored to it.
- Fishing rank spells are 7620 / 7731 / 7732 / 18248. The skill comes from `GetProfessions()` →
  `GetProfessionInfo` (skillLine 356); `GetSkillLineInfo` does not exist.
- These are missing: `GetSpellInfo`, `GetItemInfo`, `EquipItemByName` and the classic auction API. Use `C_Spell`,
  `C_Item`, `C_Item.EquipItemByName` and `C_AuctionHouse` instead.
- `C_Item.EquipItemByName` fails silently while casting or channeling, so a gear swap entry is only cleared on
  `PLAYER_EQUIPMENT_CHANGED`, and a restore during a cast waits for the cast to end.
- Bags cannot be opened while the Settings panel is open, so items are added through Alt+Click in bags, not from
  the panel.
- Key bindings on punctuation keys (`'` `;` `[` ...) are named by the character the current Windows keyboard
  language types, so they break when the language is switched; letters, numbers, F-keys and mouse buttons do not.
  There is no API for physical keys; the settings and README tell players to bind such keys once per language
  (two slots per binding).
- Player auras and the camp's fishing buff (2026-11-19, build 70959; the whole session is in
  [fishing-investigation.md](fishing-investigation.md), "Checked in game"):
  - `C_UnitAuras.GetPlayerAuraBySpellID(1280341)` ("Uncommon Fishing", the Fishing Rack's aura) returns nothing
    without the buff and an `AuraData` table with it (`spellId`, `name`, `duration = 3600`, `expirationTime`,
    `auraInstanceID`, `sourceUnit = "player"`, `isHelpful`).
  - `C_Secrets.GetSpellAuraSecrecy(1280341)` and `(1280342)` give 2; `C_Secrets.ShouldAurasBeSecret()` is false
    out of combat and true in a fight with an ordinary mob, where `GetPlayerAuraBySpellID` returns nothing for an
    aura that is up. The table is back after the fight: an empty answer in a fight means "unknown".
  - In a fight the `UNIT_AURA` payload is secret (`addedAuras` and `updatedAuraInstanceIDs` secret tables,
    `isFullUpdate` a secret boolean); `ipairs` over one raises "bad argument #1 to 'ipairs' (table expected, got
    secret)". Check `issecretvalue` first.
  - The aura is added one second after the placing cast (`UNIT_SPELLCAST_SUCCEEDED` 1307247), outlives the placed
    object and a logout to the character screen; its `auraInstanceID` changes over a relog.
  - Under the aura the Fishing cast (18248), the bobber (35591) and the loot source are unchanged; `LOOT_READY`
    fires two or three times per catch. The aura's bonus is a second loot slot of the same catch (slot 1 Bloated
    Mithril Head Trout, slot 2 Raw Mithril Head Trout), both with the bobber's GUID as the source. The loot of an opened Bloated fish has the
    source `Item-...` (the item's GUID).
  - A lure from the camp (Camper's Lure, item 291005) is a weapon enchant like the others:
    `GetWeaponEnchantInfo()` gives true, the time left in ms and the enchant ID 8773 (+60, 5 minutes).
  - A placed Fishing Rack is opened like a container (spell 6247 "Opening"); its loot source is
    `GameObject-...-612090-...`.
  - `C_VignetteInfo.GetVignettes()` returns an empty table there.

## Open questions

Answered only by the game; the spike ([docs/checklists/spike.md](checklists/spike.md)) asks them, and the answers
move to "Verified in game":

- Does a sender from another realm come as "First Last-Realm", and what do `C_FriendList` names look like (V11)?
  Accepted without a check for 1.2.0 (2026-11-12): the same "First Last" rule as the senders seen.
- Does the catch depend on the Fishing skill at all? Checked on the gathered data after the launch; if not, the
  skill ranges of the place key can go.
- Does a crash write saved variables, or keep a CVar set during the session (spec 015 review 4)? WoW writes
  saved variables only at a logout, a `/reload` or the exit; if a crash in fishing mode with the splash focus on
  leaves music, ambience and dialog at 0 on the next start, reopen the dropped item of `docs/tech-debt.md`
  ("History", 2026-11-16).
- Does `GetLootSlotInfo(i)` give the item quality as its 5th value for fishing loot, also for an item the client has
  not cached (the rare sound of spec 013, V51, `docs/checklists/sounds.md` step 3)?
- Is the auction house in Forever per game mode, per faction or shared? This decides whether auction prices can
  ever be shared between players (`docs/ROADMAP.md`).

Answered on 2026-11-16 (`/run`, see "Verified in game"): addon messages in a custom channel pass again between
players, also in `OneKeyFishingShare` and from a level 4 character (V19). The channel comes back in its own feature
(`Channel.AVAILABLE = true`, the checks of [checklists/public-channel.md](checklists/public-channel.md), a review of
`Exchange/Channel.lua`).
Answered on 2026-11-10: `C_BattleNet.SendGameData` reaches another Forever client with the addon (V13).
Answered on 2026-11-08 (`/run`, see "Verified in game"): the subzone's area ID is found by `GetSubZoneText()`
among the `C_Map.GetAreaInfo` names (V34), and a cave's continent map gives the zone under the point (V2, V33).
Answered on 2026-11-06/07 (see "Verified in game"): pool loot is not told apart (V3); one `YOU_LEFT` per leave, and
in one macro only the first `/join` or `/leave` of a channel takes effect (V41).

- `C_Map.GetMapLevels(uiMapID)` gives `0 0 0 0` for every zone in Forever (seen 2026-11-23 with a `/run` on Elwynn,
  Westfall, Durotar, the Barrens, Ashenvale, Stranglethorn); the client has no zone levels (`UiMap.ContentTuningID` and
  `AreaTable.ExplorationLevel` are 0 in build 1.60.1.71037). The addon keeps its own table (`GameData/ZoneLevels.lua`).
