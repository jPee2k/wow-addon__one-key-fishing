std = "lua51"
max_line_length = 120
self = false
exclude_files = { ".git/" }

-- Unused arguments are common in WoW event callbacks.
unused_args = false

globals = {
    "OneKeyFishingDB",
    "OneKeyFishingCharDB",
    "SLASH_ONEKEYFISHING1",
    "SLASH_ONEKEYFISHING2",
    "SlashCmdList",
    "UISpecialFrames",
    "BINDING_HEADER_ONEKEYFISHING",
    "BINDING_NAME_ONEKEYFISHING_ACTION",
    "BINDING_NAME_ONEKEYFISHING_TOGGLE",
    "OneKeyFishing_ToggleMode",
    "OneKeyFishing_ActionKeyIdle",
    "OneKeyFishing_OnAddonCompartmentClick",
    "OneKeyFishing_OnAddonCompartmentEnter",
    "OneKeyFishing_OnAddonCompartmentLeave",
}

read_globals = {
    -- Lua extensions provided by the client
    "strsplit", "strtrim", "wipe", "unpack", "time", "date", "bit",

    -- Frames and UI
    "CreateFrame", "UIParent", "DEFAULT_CHAT_FRAME", "ChatFontNormal", "GameTooltip", "Minimap",
    "AddonCompartmentFrame", "AuctionHouseFrame", "RaidWarningFrame", "Settings", "MenuUtil", "Enum",
    "StaticPopupDialogs", "StaticPopup_Show", "StaticPopup_Hide", "ReloadUI", "RaidNotice_AddMessage",
    "ChatTypeInfo", "ChatFrameUtil",
    "TooltipDataProcessor", "ItemLocation", "ItemRefTooltip",
    "PanelTemplates_SetTab", "PanelTemplates_SetNumTabs", "PanelTemplates_TabResize",
    "CreateScrollBoxListLinearView", "ScrollUtil", "CreateDataProvider", "CreateVector2D",

    -- Namespaced APIs
    "C_AddOns", "C_CVar", "C_Spell", "C_SpellBook", "C_Item", "C_Container", "C_AuctionHouse", "C_Map",
    "C_Timer", "C_TooltipInfo", "C_QuestLog", "C_SuperTrack", "C_GameRules", "UiMapPoint", "OpenWorldMap",
    "C_RestrictedActions",
    "C_ChatInfo", "C_BattleNet", "C_FriendList", "C_EncodingUtil", "C_MapExplorationInfo",
    "C_Texture",

    -- Global API
    "GetAddOnMetadata", "GetBuildInfo", "GetLocale", "InCombatLockdown", "IsPlayerSpell",
    "GetProfessions", "GetProfessionInfo", "GetTime", "GetMoneyString",
    "GetBindingKey", "GetBindingText", "SetOverrideBinding", "SetOverrideBindingClick", "ClearOverrideBindings",
    "RegisterStateDriver", "hooksecurefunc", "HandleModifiedItemClick",
    "IsAltKeyDown", "IsShiftKeyDown", "IsControlKeyDown", "GetCursorPosition",
    "GetInventoryItemID", "GetInventoryItemLink", "GetWeaponEnchantInfo", "GetItemCount", "GetItemCooldown",
    "PickupInventoryItem", "PutItemInBackpack", "PutItemInBag",
    "IsFishingLoot", "GetNumLootItems", "GetLootSlotLink", "GetLootSlotInfo", "GetLootSourceInfo",
    "UnitChannelInfo", "UnitCastingInfo", "UnitGUID", "UnitIsAFK", "UnitLevel", "UnitName",
    "GetNormalizedRealmName", "GetZoneText", "GetSubZoneText",
    "GetCameraZoom", "CameraZoomIn", "CameraZoomOut",
    "IsInGuild", "IsInGroup", "IsInRaid", "IsInInstance", "GetNumGroupMembers", "BNGetNumFriends",
    "issecretvalue", "debugprofilestop", "Constants",
    "JoinTemporaryChannel", "LeaveChannelByName", "GetChannelName", "GetChannelList", "GetChatWindowChannels",
    "SetChannelPassword", "DisplayChannelOwner", "IsDisplayChannelOwner",
    "CaseAccentInsensitiveParse", "strcmputf8i",

    -- Constants
    "WOW_PROJECT_ID", "DECIMAL_SEPERATOR", "INVSLOT_MAINHAND", "INVSLOT_OFFHAND", "INVSLOT_RANGED",
    "INVSLOT_FIRST_EQUIPPED", "INVSLOT_LAST_EQUIPPED", "NUM_BAG_SLOTS",
    "LE_PARTY_CATEGORY_HOME", "BNET_CLIENT_WOW", "ERR_CHAT_PLAYER_NOT_FOUND_S", "ERR_TOO_MANY_CHAT_CHANNELS",
    "NUM_CHAT_WINDOWS",
}
