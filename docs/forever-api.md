# Forever API

What is known about the WoW Forever API (Interface `16001`, build 1.60.1, `WOW_PROJECT_ID = 18`), and how to check
a call. The Forever client runs the modern (Mainline) API, not the Classic one. Facts confirmed in game go into
"Verified in game" below (constitution, Principle IV), including the answers to the `VERIFY` items in
`specs/002-local-catch-db/verification.md` and `specs/003-guild-group-sync/verification.md`.

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
- `SetChannelPassword(name, password)` is what `/password` and the password popup call. There is no call that turns
  channel moderation off (only `ChannelModerator` / `ChannelUnmoderator` for one player).
- The `bit` library (`band`, `bor`, `bxor`, `bnot`, `lshift`, `rshift`) is called over 300 times in
  Blizzard's code; whether its results are signed is not documented.

## Verified in game

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
