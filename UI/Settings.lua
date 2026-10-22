-- Settings: Esc -> Options -> AddOns -> OneKeyFishing.
-- Canvas pages with plain widgets, so they do not depend on the Settings setting-type API.
--   OneKeyFishing  - keys, feature toggles, actions
--   Fishing gear   - chosen pole and the list of extra fishing items
local _, ns = ...

local SettingsUI = {}
ns.SettingsUI = SettingsUI

local PADDING = 16
local ROW_HEIGHT = 26
local MAX_GEAR_ROWS = 14

local TOGGLES = {
    { key = "autoLoot", label = "Auto loot while fishing" },
    { key = "bobberIcon", label = "Show the interact icon over the bobber" },
    { key = "exitOnCombat", label = "Leave fishing mode when attacked" },
    { key = "gear", label = "Equip fishing pole and fishing gear" },
    { key = "lure", label = "Apply lures automatically" },
    { key = "openContainers", label = "Open clams and fished containers" },
}

local mainCategory

---------------------------------------------------------------------------
-- Widgets
---------------------------------------------------------------------------
local function CreateText(parent, template, text)
    local fontString = parent:CreateFontString(nil, "ARTWORK", template)
    fontString:SetJustifyH("LEFT")
    if text then
        fontString:SetText(text)
    end
    return fontString
end

local function CreateCheckbox(parent, label, getValue, setValue)
    local checkbox = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    checkbox:SetSize(26, 26)
    local text = CreateText(checkbox, "GameFontHighlight", label)
    text:SetPoint("LEFT", checkbox, "RIGHT", 4, 0)
    checkbox:SetScript("OnShow", function(self) self:SetChecked(getValue()) end)
    checkbox:SetScript("OnClick", function(self) setValue(self:GetChecked()) end)
    return checkbox
end

local function CreateButton(parent, text, width, onClick)
    local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    button:SetSize(width, 22)
    button:SetText(text)
    button:SetScript("OnClick", onClick)
    return button
end

local function KeyText(binding)
    local key = GetBindingKey(binding)
    return key and GetBindingText(key) or "|cffff5555not bound|r"
end

local function ItemDisplay(itemID)
    local name, link, _, _, _, _, _, _, _, icon = C_Item.GetItemInfo(itemID)
    return link or name or ("item:" .. itemID), icon or C_Item.GetItemIconByID(itemID)
end

---------------------------------------------------------------------------
-- Main page
---------------------------------------------------------------------------
local function CreateMainPage()
    local page = CreateFrame("Frame")

    local title = CreateText(page, "GameFontNormalLarge", "OneKeyFishing")
    title:SetPoint("TOPLEFT", PADDING, -PADDING)
    local version = CreateText(page, "GameFontDisableSmall", "v" .. ns.version)
    version:SetPoint("LEFT", title, "RIGHT", 8, 0)

    local keysHeader = CreateText(page, "GameFontNormal", "Keys")
    keysHeader:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -18)
    local keys = CreateText(page, "GameFontHighlight")
    keys:SetPoint("TOPLEFT", keysHeader, "BOTTOMLEFT", 0, -6)
    local keysHint = CreateText(page, "GameFontDisableSmall",
        "Change them in Options -> Keybindings -> AddOns -> OneKeyFishing.")
    keysHint:SetPoint("TOPLEFT", keys, "BOTTOMLEFT", 0, -4)

    local featuresHeader = CreateText(page, "GameFontNormal", "Features")
    featuresHeader:SetPoint("TOPLEFT", keysHint, "BOTTOMLEFT", 0, -18)
    local anchor = featuresHeader
    for _, toggle in ipairs(TOGGLES) do
        local checkbox = CreateCheckbox(page, toggle.label,
            function() return ns.db.settings[toggle.key] end,
            function(value) ns.db.settings[toggle.key] = value end)
        checkbox:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", anchor == featuresHeader and -2 or 0, -4)
        anchor = checkbox
    end
    local note = CreateText(page, "GameFontDisableSmall", "Changes apply the next time you enter fishing mode.")
    note:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 2, -6)

    local actionsHeader = CreateText(page, "GameFontNormal", "Actions")
    actionsHeader:SetPoint("TOPLEFT", note, "BOTTOMLEFT", 0, -18)
    local toggleButton = CreateButton(page, "Toggle fishing mode", 180, function() ns.Mode.Toggle() end)
    toggleButton:SetPoint("TOPLEFT", actionsHeader, "BOTTOMLEFT", 0, -8)
    local apiButton = CreateButton(page, "Run API check", 140, function() ns.RunApiCheck() end)
    apiButton:SetPoint("LEFT", toggleButton, "RIGHT", 8, 0)

    page:SetScript("OnShow", function()
        keys:SetText(("Fishing action: %s      Toggle fishing mode: %s"):format(
            KeyText("ONEKEYFISHING_ACTION"), KeyText("ONEKEYFISHING_TOGGLE")))
    end)
    return page
end

---------------------------------------------------------------------------
-- Fishing gear page
---------------------------------------------------------------------------
local function ShowItemTooltip(owner, itemID)
    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    GameTooltip:SetItemByID(itemID)
    GameTooltip:Show()
end

local function CreateGearRow(parent)
    local row = CreateFrame("Frame", nil, parent)
    row:SetSize(520, ROW_HEIGHT)
    row:EnableMouse(true)

    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(22, 22)
    row.icon:SetPoint("LEFT")
    row.name = CreateText(row, "GameFontHighlight")
    row.name:SetPoint("LEFT", row.icon, "RIGHT", 8, 0)
    row.name:SetWidth(280)
    row.slot = CreateText(row, "GameFontDisable")
    row.slot:SetPoint("LEFT", row.name, "RIGHT", 8, 0)
    row.slot:SetWidth(110)
    row.remove = CreateButton(row, "Remove", 80, function() ns.Gear.RemoveItem(row.itemID) end)
    row.remove:SetPoint("RIGHT")

    row:SetScript("OnEnter", function(self) ShowItemTooltip(self, self.itemID) end)
    row:SetScript("OnLeave", function() GameTooltip:Hide() end)
    return row
end

local function CreateGearPage()
    local page = CreateFrame("Frame")

    local title = CreateText(page, "GameFontNormalLarge", "Fishing gear")
    title:SetPoint("TOPLEFT", PADDING, -PADDING)

    -- Pole
    local poleHeader = CreateText(page, "GameFontNormal", "Fishing pole")
    poleHeader:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -18)
    local poleText = CreateText(page, "GameFontHighlight")
    poleText:SetPoint("TOPLEFT", poleHeader, "BOTTOMLEFT", 0, -6)
    poleText:SetWidth(520)
    local autoPoleButton = CreateButton(page, "Use the best pole automatically", 240, function()
        ns.Gear.ClearPole()
    end)
    autoPoleButton:SetPoint("TOPLEFT", poleText, "BOTTOMLEFT", 0, -6)

    -- Add box
    local addHeader = CreateText(page, "GameFontNormal", "Add an item")
    addHeader:SetPoint("TOPLEFT", autoPoleButton, "BOTTOMLEFT", 0, -18)
    local addHint = CreateText(page, "GameFontDisableSmall",
        "Easiest: close this window and Alt+Click an item in your bags or on the character panel.\n" ..
        "Alt+Click it again to remove it. A fishing pole becomes your chosen pole.\n" ..
        "Here you can type an item name, or find all items with a fishing bonus automatically.")
    addHint:SetPoint("TOPLEFT", addHeader, "BOTTOMLEFT", 0, -4)

    local input = CreateFrame("EditBox", nil, page, "InputBoxTemplate")
    input:SetSize(320, 22)
    input:SetAutoFocus(false)
    input:SetPoint("TOPLEFT", addHint, "BOTTOMLEFT", 6, -8)
    local status = CreateText(page, "GameFontHighlightSmall")

    local function AddItem(itemID)
        if not itemID then
            status:SetText("|cffff5555Item not found. Check the name, or Alt+Click the item in your bags.|r")
            return
        end
        local ok, message = ns.Gear.AddItem(itemID)
        status:SetText((ok and "|cff55ff55%s|r" or "|cffff5555%s|r"):format(message))
        if ok then
            input:SetText("")
            input:ClearFocus()
        end
    end

    local addButton = CreateButton(page, "Add", 80, function() AddItem(ns.ParseItem(input:GetText())) end)
    addButton:SetPoint("LEFT", input, "RIGHT", 8, 0)
    local findButton = CreateButton(page, "Find fishing items", 150, function()
        local added = ns.Gear.AddFishingItemsFromBags()
        status:SetText(added > 0 and ("|cff55ff55Added %d item(s).|r"):format(added)
            or "|cffff5555No new items with a fishing bonus found.|r")
    end)
    findButton:SetPoint("LEFT", addButton, "RIGHT", 8, 0)
    status:SetPoint("TOPLEFT", input, "BOTTOMLEFT", -6, -6)

    input:SetScript("OnEnterPressed", function(self) AddItem(ns.ParseItem(self:GetText())) end)
    input:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)

    -- List
    local listHeader = CreateText(page, "GameFontNormal", "Extra fishing gear")
    listHeader:SetPoint("TOPLEFT", status, "BOTTOMLEFT", 0, -16)
    local emptyText = CreateText(page, "GameFontDisable", "No items yet.")
    emptyText:SetPoint("TOPLEFT", listHeader, "BOTTOMLEFT", 0, -8)

    local rows = {}
    for i = 1, MAX_GEAR_ROWS do
        local row = CreateGearRow(page)
        row:SetPoint("TOPLEFT", listHeader, "BOTTOMLEFT", 0, -6 - (i - 1) * ROW_HEIGHT)
        rows[i] = row
    end

    local function Refresh()
        if not page:IsShown() then
            return
        end
        local chosen = ns.Gear.GetChosenPole()
        if chosen then
            local link = ItemDisplay(chosen)
            poleText:SetText(("Chosen: %s (+%d)"):format(link, ns.GetFishingBonus(chosen)))
            autoPoleButton:Show()
        else
            local best, bonus = ns.Gear.FindBestPole()
            poleText:SetText(best and ("Automatic, best in your bags: %s (+%d)"):format(ItemDisplay(best), bonus)
                or "Automatic: no fishing pole in your bags.")
            autoPoleButton:Hide()
        end

        local items = ns.Gear.GetItems()
        emptyText:SetShown(#items == 0)
        for i, row in ipairs(rows) do
            local itemID = items[i]
            row.itemID = itemID
            if itemID then
                local link, icon = ItemDisplay(itemID)
                row.icon:SetTexture(icon)
                row.name:SetText(link)
                row.slot:SetText(ns.Gear.GetSlotName(itemID))
                row:Show()
            else
                row:Hide()
            end
        end
    end

    page:SetScript("OnShow", function()
        status:SetText("")
        Refresh()
    end)
    ns.On("GEAR_LIST_CHANGED", Refresh)
    -- Item names and icons load asynchronously the first time.
    ns.RegisterEvent("GET_ITEM_INFO_RECEIVED", Refresh)
    ns.RegisterEvent("BAG_UPDATE_DELAYED", Refresh)
    return page
end

---------------------------------------------------------------------------
-- Registration
---------------------------------------------------------------------------
function SettingsUI.Open()
    if not mainCategory then
        return
    end
    if InCombatLockdown() then
        ns.Print("Settings cannot be opened in combat.")
        return
    end
    Settings.OpenToCategory(mainCategory:GetID())
end

ns.RegisterEvent("PLAYER_LOGIN", function()
    if not (Settings and Settings.RegisterCanvasLayoutCategory) then
        ns.Print("Settings panel is not available in this client.")
        return
    end
    mainCategory = Settings.RegisterCanvasLayoutCategory(CreateMainPage(), "OneKeyFishing")
    Settings.RegisterCanvasLayoutSubcategory(mainCategory, CreateGearPage(), "Fishing gear")
    Settings.RegisterAddOnCategory(mainCategory)
end)

ns.RegisterCommand("config", "open the settings", SettingsUI.Open)
