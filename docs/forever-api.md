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
  `buyoutAmount` and `quantity` 1 (V5 in part). An item with no listing gives 0 results.
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
  (`InvalidChannel`). The addon's channel is off (spec 010).
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

## Open questions

Answered only by the game; the spike ([docs/checklists/spike.md](checklists/spike.md)) asks them, and the answers
move to "Verified in game":

- Does a sender from another realm come as "First Last-Realm", and what do `C_FriendList` names look like (V11)?
  Accepted without a check for 1.2.0 (2026-11-12): the same "First Last" rule as the senders seen.
- Does the catch depend on the Fishing skill at all? Checked on the gathered data after the launch; if not, the
  skill ranges of the place key can go.
- Is the auction house in Forever per game mode, per faction or shared? This decides whether auction prices can
  ever be shared between players (`docs/ROADMAP.md`).

Answered on 2026-11-10: `C_BattleNet.SendGameData` reaches another Forever client with the addon (V13).
Answered on 2026-11-08 (`/run`, see "Verified in game"): the subzone's area ID is found by `GetSubZoneText()`
among the `C_Map.GetAreaInfo` names (V34), and a cave's continent map gives the zone under the point (V2, V33).
Answered on 2026-11-06/07 (see "Verified in game"): pool loot is not told apart (V3); one `YOU_LEFT` per leave, and
in one macro only the first `/join` or `/leave` of a channel takes effect (V41).
