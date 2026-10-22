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
    "OneKeyFishingCopyWindow",
    "BINDING_HEADER_ONEKEYFISHING",
    "BINDING_NAME_ONEKEYFISHING_ACTION",
    "BINDING_NAME_ONEKEYFISHING_TOGGLE",
    "OneKeyFishing_ToggleMode",
    "OneKeyFishing_ActionKeyIdle",
}

read_globals = {
    -- Lua extensions provided by the client
    "strsplit", "strtrim", "wipe", "tinsert", "tremove", "format",

    -- Frames and UI
    "CreateFrame", "UIParent", "DEFAULT_CHAT_FRAME", "ChatFontNormal", "GameTooltip", "Minimap",
    "AddonCompartmentFrame", "Settings", "MenuUtil", "Enum",

    -- Namespaced APIs
    "C_AddOns", "C_CVar", "C_Spell", "C_SpellBook", "C_Item", "C_Container", "C_EquipmentSet",
    "C_AuctionHouse", "C_Map", "C_TradeSkillUI", "C_EventUtils",

    -- Global API
    "GetAddOnMetadata", "GetBuildInfo", "GetLocale", "GetCVar", "InCombatLockdown",
    "GetNumBindings", "GetBinding", "GetSpellInfo", "IsSpellKnown", "IsPlayerSpell",
    "GetProfessions", "GetProfessionInfo", "GetNumSkillLines", "GetSkillLineInfo",
    "GetInventoryItemID", "GetInventoryItemLink", "GetItemInfoInstant", "GetWeaponEnchantInfo",
    "GetTime", "GetBindingKey", "SetOverrideBinding", "SetOverrideBindingClick", "ClearOverrideBindings",
    "RegisterStateDriver",

    -- Constants
    "WOW_PROJECT_ID", "WOW_PROJECT_MAINLINE", "WOW_PROJECT_CLASSIC", "INVSLOT_MAINHAND",
}
