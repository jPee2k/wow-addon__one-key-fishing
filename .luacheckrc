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
    "strsplit", "strtrim", "wipe", "unpack", "time", "date",

    -- Frames and UI
    "CreateFrame", "UIParent", "DEFAULT_CHAT_FRAME", "ChatFontNormal", "GameTooltip", "Minimap",
    "AddonCompartmentFrame", "AuctionHouseFrame", "RaidWarningFrame", "Settings", "MenuUtil", "Enum",
    "StaticPopupDialogs", "StaticPopup_Show", "RaidNotice_AddMessage", "ChatTypeInfo", "YES", "NO",
    "TooltipDataProcessor", "ItemLocation",

    -- Namespaced APIs
    "C_AddOns", "C_CVar", "C_Spell", "C_SpellBook", "C_Item", "C_Container", "C_AuctionHouse", "C_Map",
    "C_Timer", "C_TooltipInfo",

    -- Global API
    "GetAddOnMetadata", "GetBuildInfo", "GetLocale", "InCombatLockdown", "IsPlayerSpell",
    "GetProfessions", "GetProfessionInfo", "GetTime", "GetMoneyString",
    "GetBindingKey", "GetBindingText", "SetOverrideBinding", "SetOverrideBindingClick", "ClearOverrideBindings",
    "RegisterStateDriver", "hooksecurefunc", "HandleModifiedItemClick",
    "IsAltKeyDown", "IsShiftKeyDown", "IsControlKeyDown", "GetCursorPosition",
    "GetInventoryItemID", "GetInventoryItemLink", "GetWeaponEnchantInfo", "GetItemCount",
    "PickupInventoryItem", "PutItemInBackpack", "PutItemInBag",
    "IsFishingLoot", "GetNumLootItems", "GetLootSlotLink", "GetLootSlotInfo", "GetLootSourceInfo",
    "UnitChannelInfo", "UnitCastingInfo", "UnitGUID", "UnitIsAFK", "GetZoneText", "GetSubZoneText",
    "GetCameraZoom", "CameraZoomIn", "CameraZoomOut",

    -- Constants
    "WOW_PROJECT_ID", "INVSLOT_MAINHAND", "INVSLOT_OFFHAND", "INVSLOT_RANGED",
    "INVSLOT_FIRST_EQUIPPED", "INVSLOT_LAST_EQUIPPED", "NUM_BAG_SLOTS",
}
