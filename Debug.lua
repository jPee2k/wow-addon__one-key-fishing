-- Debug: API availability report for the Forever client.
-- Everything here is read-only; each probe is wrapped so one missing API never breaks the report.
local _, ns = ...

local FISHING_SPELL_IDS = { 7620, 7731, 7732, 18248, 131474 }

local GLOBALS = {
    -- action / bindings
    "SetOverrideBinding", "SetOverrideBindingClick", "SetOverrideBindingSpell", "ClearOverrideBindings",
    "GetBindingKey", "GetBindingAction", "GetNumBindings", "GetBinding", "SetBinding", "SaveBindings",
    "RegisterStateDriver", "SecureHandlerWrapScript", "InCombatLockdown",
    -- spells
    "GetSpellInfo", "IsSpellKnown", "IsPlayerSpell", "C_Spell.GetSpellInfo", "C_Spell.GetSpellName",
    "C_SpellBook.IsSpellKnown", "C_SpellBook.IsSpellInSpellBook", "UnitChannelInfo",
    -- professions / skill
    "GetProfessions", "GetProfessionInfo", "GetNumSkillLines", "GetSkillLineInfo",
    "C_TradeSkillUI.GetProfessionInfoBySkillLineID",
    -- loot
    "IsFishingLoot", "GetNumLootItems", "GetLootSlotLink", "GetLootSlotInfo", "LootSlot",
    -- items / bags / gear
    "GetItemInfo", "C_Item.GetItemInfo", "C_Item.GetItemInfoInstant", "C_Item.GetItemNameByID",
    "C_Container.GetContainerNumSlots", "C_Container.GetContainerItemInfo", "C_Container.UseContainerItem",
    "GetWeaponEnchantInfo", "GetInventoryItemID", "GetInventoryItemLink",
    "EquipItemByName", "C_Item.EquipItemByName", "C_EquipmentSet.GetEquipmentSetIDs",
    "C_EquipmentSet.UseEquipmentSet",
    -- auction house
    "C_AuctionHouse.SendBrowseQuery", "C_AuctionHouse.ReplicateItems", "C_AuctionHouse.SendSearchQuery",
    "QueryAuctionItems", "CanSendAuctionQuery", "GetAuctionItemInfo",
    -- map / zone / afk
    "C_Map.GetBestMapForUnit", "C_Map.GetMapInfo", "GetZoneText", "GetSubZoneText", "UnitIsAFK",
    -- camera / sound
    "GetCameraZoom", "CameraZoomIn", "CameraZoomOut", "SaveView", "SetView", "MuteSoundFile",
    -- UI
    "Settings.RegisterVerticalLayoutCategory", "Settings.RegisterAddOnCategory",
    "Settings.RegisterAddOnSetting", "Settings.CreateCheckbox", "Settings.CreateSlider",
    "Settings.OpenToCategory", "MenuUtil.CreateContextMenu", "AddonCompartmentFrame",
    "C_AddOns.GetAddOnMetadata", "C_CVar.GetCVar", "C_CVar.SetCVar", "C_EventUtils.IsEventValid",
    "Settings.RegisterCanvasLayoutCategory", "Settings.RegisterCanvasLayoutSubcategory",
    "C_TooltipInfo.GetItemByID", "HandleModifiedItemClick", "TooltipDataProcessor.AddTooltipPostCall",
    "C_Item.GetItemIconByID",
    "C_Item.GetItemCount", "C_Item.IsUsableItem", "C_Container.GetContainerNumFreeSlots",
    "C_Container.ContainerIDToInventoryID", "PickupInventoryItem", "PutItemInBackpack", "PutItemInBag",
}

local CVARS = {
    "autoLootDefault", "autoLootKey",
    "SoftTargetInteract", "SoftTargetInteractArc", "SoftTargetInteractRange",
    "SoftTargetIconGameObject", "SoftTargetIconInteract", "SoftTargetIconFriend", "SoftTargetIconEnemy",
    "Sound_EnableMusic", "Sound_EnableAmbience", "Sound_SFXVolume", "Sound_EnableSoundWhenGameIsInBackground",
    "cameraDistanceMaxZoomFactor",
}

local EVENTS = {
    "UNIT_SPELLCAST_CHANNEL_START", "UNIT_SPELLCAST_CHANNEL_STOP", "LOOT_READY", "LOOT_OPENED", "LOOT_CLOSED",
    "SKILL_LINES_CHANGED", "CHAT_MSG_SKILL", "TRADE_SKILL_LIST_UPDATE", "PLAYER_FLAGS_CHANGED",
    "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED", "PLAYER_EQUIPMENT_CHANGED", "BAG_UPDATE_DELAYED",
    "UNIT_INVENTORY_CHANGED", "PLAYER_SOFT_INTERACT_CHANGED", "ZONE_CHANGED", "ZONE_CHANGED_NEW_AREA",
    "AUCTION_HOUSE_SHOW", "AUCTION_HOUSE_CLOSED", "AUCTION_ITEM_LIST_UPDATE",
    "AUCTION_HOUSE_BROWSE_RESULTS_UPDATED", "REPLICATE_ITEM_LIST_UPDATE", "PLAYER_LOGOUT",
}

-- { frame type, template }: a template only inherits into its own frame type.
local TEMPLATES = {
    { "Button", "SecureActionButtonTemplate" },
    { "Frame", "SecureHandlerStateTemplate" },
    { "Frame", "SecureHandlerBaseTemplate" },
    { "Frame", "BasicFrameTemplateWithInset" },
    { "Frame", "BackdropTemplate" },
    { "ScrollFrame", "UIPanelScrollFrameTemplate" },
    { "CheckButton", "UICheckButtonTemplate" },
    { "Button", "UIPanelButtonTemplate" },
    { "EditBox", "InputBoxTemplate" },
}

local function Resolve(path)
    local value = _G
    for part in path:gmatch("[^%.]+") do
        if type(value) ~= "table" then
            return nil
        end
        value = value[part]
    end
    return value
end

local function GetCVarValue(name)
    if C_CVar and C_CVar.GetCVar then
        return C_CVar.GetCVar(name)
    end
    return GetCVar(name)
end

local function GetSpellNameSafe(id)
    if C_Spell and C_Spell.GetSpellInfo then
        local info = C_Spell.GetSpellInfo(id)
        return info and info.name, info and info.spellID
    end
    if GetSpellInfo then
        local name, _, _, _, _, _, spellID = GetSpellInfo(id)
        return name, spellID
    end
end

local function IsKnown(id)
    if C_SpellBook and C_SpellBook.IsSpellKnown then
        return C_SpellBook.IsSpellKnown(id)
    end
    if IsPlayerSpell then
        return IsPlayerSpell(id)
    end
    if IsSpellKnown then
        return IsSpellKnown(id)
    end
end

-- Some clients throw on unknown events, others silently ignore them; probe both ways.
local probeFrame = CreateFrame("Frame")
local function IsEventValid(event)
    if C_EventUtils and C_EventUtils.IsEventValid then
        return C_EventUtils.IsEventValid(event)
    end
    local ok = pcall(probeFrame.RegisterEvent, probeFrame, event)
    probeFrame:UnregisterAllEvents()
    return ok
end

local function Probe(lines, label, fn)
    local ok, err = pcall(fn)
    if not ok then
        table.insert(lines, ("  !! %s failed: %s"):format(label, tostring(err)))
    end
end

local function YesNo(value)
    return value and "yes" or "NO"
end

local function BuildReport()
    local lines = {}
    local function add(fmt, ...)
        table.insert(lines, select("#", ...) > 0 and fmt:format(...) or fmt)
    end

    add("== OneKeyFishing %s API check ==", ns.version)

    Probe(lines, "build", function()
        local version, build, date, interface = GetBuildInfo()
        add("Build: %s (%s) %s, interface %s", tostring(version), tostring(build), tostring(date), tostring(interface))
        add("WOW_PROJECT_ID: %s (MAINLINE=%s, CLASSIC=%s)", tostring(WOW_PROJECT_ID),
            tostring(WOW_PROJECT_MAINLINE), tostring(WOW_PROJECT_CLASSIC))
        add("Locale: %s, in combat: %s", GetLocale(), tostring(InCombatLockdown()))
    end)

    add("")
    add("-- Bindings containing INTERACT --")
    Probe(lines, "bindings", function()
        local found = false
        for i = 1, GetNumBindings() do
            local command, category, key1, key2 = GetBinding(i)
            if type(command) == "string" and command:find("INTERACT") then
                found = true
                add("  %s [%s] keys: %s, %s", command, tostring(category), tostring(key1), tostring(key2))
            end
        end
        if not found then
            add("  none found")
        end
    end)

    add("")
    add("-- Fishing spell --")
    Probe(lines, "fishing spell", function()
        for _, id in ipairs(FISHING_SPELL_IDS) do
            local name = GetSpellNameSafe(id)
            add("  %d: %s, known: %s", id, tostring(name), tostring(IsKnown(id)))
        end
        local byName, byNameID = GetSpellNameSafe("Fishing")
        add("  by name 'Fishing': %s (id %s)", tostring(byName), tostring(byNameID))
    end)

    add("")
    add("-- Fishing skill --")
    Probe(lines, "GetProfessions", function()
        if not GetProfessions then
            add("  GetProfessions: missing")
            return
        end
        local _, _, _, fishing = GetProfessions()
        if not fishing then
            add("  GetProfessions: no fishing slot (not learned?)")
            return
        end
        local name, _, rank, maxRank, _, _, skillLine = GetProfessionInfo(fishing)
        add("  GetProfessionInfo: %s %s/%s, skillLine %s", tostring(name), tostring(rank),
            tostring(maxRank), tostring(skillLine))
    end)
    Probe(lines, "GetSkillLineInfo", function()
        if not (GetNumSkillLines and GetSkillLineInfo) then
            add("  GetSkillLineInfo: missing")
            return
        end
        for i = 1, GetNumSkillLines() do
            local skillName, isHeader, _, rank, _, _, maxRank = GetSkillLineInfo(i)
            if not isHeader and skillName and skillName:find("Fishing") then
                add("  GetSkillLineInfo: %s %s/%s", skillName, tostring(rank), tostring(maxRank))
            end
        end
    end)

    add("")
    add("-- Main hand / lure --")
    Probe(lines, "main hand", function()
        local slot = INVSLOT_MAINHAND or 16
        local itemID = GetInventoryItemID("player", slot)
        if not itemID then
            add("  main hand: empty")
        else
            local getInstant = (C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant
            local _, itemType, itemSubType, _, _, classID, subclassID = getInstant(itemID)
            add("  main hand: %s %s (%s / %s, class %s sub %s)", tostring(itemID),
                tostring(GetInventoryItemLink("player", slot)), tostring(itemType), tostring(itemSubType),
                tostring(classID), tostring(subclassID))
        end
        if Enum and Enum.ItemWeaponSubclass then
            add("  Enum.ItemWeaponSubclass.Fishingpole = %s", tostring(Enum.ItemWeaponSubclass.Fishingpole))
        end
        if itemID then
            add("  main hand fishing bonus (tooltip): %s", tostring(ns.GetFishingBonus(itemID)))
        end
        local bestPole, bestBonus = ns.Gear.FindBestPole()
        add("  best pole in bags: %s (+%s)", tostring(bestPole and C_Item.GetItemInfo(bestPole) or bestPole),
            tostring(bestBonus))
        local hasEnchant, expiration, charges, enchantID = GetWeaponEnchantInfo()
        add("  weapon enchant: %s, expires %s ms, charges %s, id %s", tostring(hasEnchant),
            tostring(expiration), tostring(charges), tostring(enchantID))
    end)

    add("")
    add("-- CVars (nil = does not exist) --")
    for _, name in ipairs(CVARS) do
        Probe(lines, name, function()
            add("  %s = %s", name, tostring(GetCVarValue(name)))
        end)
    end

    add("")
    add("-- Functions / objects --")
    local missing = {}
    for _, path in ipairs(GLOBALS) do
        if Resolve(path) == nil then
            table.insert(missing, path)
        end
    end
    add("  present: %d/%d", #GLOBALS - #missing, #GLOBALS)
    add("  missing: %s", #missing > 0 and table.concat(missing, ", ") or "none")

    add("")
    add("-- Events --")
    local badEvents = {}
    for _, event in ipairs(EVENTS) do
        if not IsEventValid(event) then
            table.insert(badEvents, event)
        end
    end
    add("  valid: %d/%d", #EVENTS - #badEvents, #EVENTS)
    add("  invalid: %s", #badEvents > 0 and table.concat(badEvents, ", ") or "none")

    add("")
    add("-- Frame templates --")
    for _, entry in ipairs(TEMPLATES) do
        local frameType, template = entry[1], entry[2]
        local ok, frame = pcall(CreateFrame, frameType, nil, nil, template)
        if ok then
            frame:Hide()
        end
        add("  %s: %s", template, YesNo(ok))
    end

    return table.concat(lines, "\n")
end

function ns.RunApiCheck()
    if InCombatLockdown() then
        ns.Print("API check is unavailable in combat.")
        return
    end
    ns.ShowCopyWindow("OneKeyFishing - API check", BuildReport())
end

ns.RegisterCommand("debug", "show the API availability report", ns.RunApiCheck)
