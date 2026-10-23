-- Settings: Esc -> Options -> AddOns -> OneKeyFishing.
-- Canvas pages with plain widgets, so they do not depend on the Settings setting-type API.
--   OneKeyFishing  - keys, feature toggles, actions
--   Fishing gear   - chosen pole and the list of extra fishing items
local _, ns = ...
local L = ns.L

local SettingsUI = {}
ns.SettingsUI = SettingsUI

local PADDING = 16
local ROW_HEIGHT = 26
local MAX_GEAR_ROWS = 14

local TOGGLES = {
    { key = "autoLoot", label = L["Auto loot while fishing"] },
    { key = "bobberIcon", label = L["Show the interact icon over the bobber"] },
    { key = "exitOnCombat", label = L["Leave fishing mode when attacked"] },
    { key = "gear", label = L["Equip fishing pole and fishing gear"] },
    { key = "lure", label = L["Apply lures automatically"] },
    { key = "openContainers", label = L["Open clams and fished containers"] },
    { key = "indicator", label = L["Show the action indicator and cast timer"] },
    { key = "lockIndicator", label = L["Lock the indicator position"] },
    { key = "toasts", label = L["Show catch notifications"] },
    { key = "sessionTimer", label = L["Show session fishing time under the indicator"] },
    { key = "pauseOnAFK", label = L["Pause the fishing timer while AFK"] },
    { key = "skillCapWarning", label = L["Warn when the Fishing rank is capped"] },
    { key = "auctionPrices", label = L["Use scanned auction prices for catch value"] },
    { key = "camera", label = L["Zoom the camera while fishing"] },
    { key = "minimapButton", label = L["Show the minimap button"] },
}
local COLUMN_OFFSET = 300

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

local CreateButton = ns.CreateButton -- Core.lua

local function KeyText(binding)
    local key = GetBindingKey(binding)
    return key and GetBindingText(key) or ("|cffff5555" .. L["not bound"] .. "|r")
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

    local keysHeader = CreateText(page, "GameFontNormal", L["Keys"])
    keysHeader:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -18)
    local keys = CreateText(page, "GameFontHighlight")
    keys:SetPoint("TOPLEFT", keysHeader, "BOTTOMLEFT", 0, -6)
    local keysHint = CreateText(page, "GameFontDisableSmall",
        L["Change them in Options -> Keybindings -> AddOns -> OneKeyFishing."])
    keysHint:SetPoint("TOPLEFT", keys, "BOTTOMLEFT", 0, -4)
    -- WoW behaviour: punctuation keys are named by the character the current Windows layout types.
    local layoutHint = CreateText(page, "GameFontDisableSmall",
        L["WoW names punctuation keys (' ; [ , .) by keyboard language: bind them in both slots, once per language."])
    layoutHint:SetPoint("TOPLEFT", keysHint, "BOTTOMLEFT", 0, -2)
    layoutHint:SetWidth(560)

    local featuresHeader = CreateText(page, "GameFontNormal", L["Features"])
    featuresHeader:SetPoint("TOPLEFT", layoutHint, "BOTTOMLEFT", 0, -18)
    -- Two columns so the page fits without scrolling.
    local perColumn = math.ceil(#TOGGLES / 2)
    local anchor, firstColumnLast
    for i, toggle in ipairs(TOGGLES) do
        local checkbox = CreateCheckbox(page, toggle.label,
            function() return ns.db.settings[toggle.key] end,
            function(value)
                ns.db.settings[toggle.key] = value
                ns.Fire("SETTINGS_CHANGED", toggle.key)
            end)
        if i == 1 then
            checkbox:SetPoint("TOPLEFT", featuresHeader, "BOTTOMLEFT", -2, -4)
        elseif i == perColumn + 1 then
            checkbox:SetPoint("TOPLEFT", featuresHeader, "BOTTOMLEFT", COLUMN_OFFSET - 2, -4)
        else
            checkbox:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -4)
        end
        if i == perColumn then
            firstColumnLast = checkbox
        end
        anchor = checkbox
    end
    local note = CreateText(page, "GameFontDisableSmall",
        L["Auto loot, bobber icon and gear changes apply the next time you enter fishing mode."])
    note:SetPoint("TOPLEFT", firstColumnLast, "BOTTOMLEFT", 2, -6)

    -- Camera distance: - value +
    local cameraLabel = CreateText(page, "GameFontHighlight", L["Camera distance while fishing:"])
    cameraLabel:SetPoint("TOPLEFT", note, "BOTTOMLEFT", 0, -12)
    local cameraValue = CreateText(page, "GameFontHighlight")
    local function ChangeDistance(step)
        cameraValue:SetText(ns.Camera.SetDistance(ns.db.settings.cameraDistance + step))
    end
    local minus = CreateButton(page, "-", 26, function() ChangeDistance(-1) end)
    minus:SetPoint("LEFT", cameraLabel, "RIGHT", 8, 0)
    cameraValue:SetPoint("LEFT", minus, "RIGHT", 8, 0)
    cameraValue:SetWidth(24)
    cameraValue:SetJustifyH("CENTER")
    local plus = CreateButton(page, "+", 26, function() ChangeDistance(1) end)
    plus:SetPoint("LEFT", cameraValue, "RIGHT", 8, 0)

    local actionsHeader = CreateText(page, "GameFontNormal", L["Actions"])
    actionsHeader:SetPoint("TOPLEFT", cameraLabel, "BOTTOMLEFT", 0, -18)
    local toggleButton = CreateButton(page, L["Toggle fishing mode"], 180, function() ns.Mode.Toggle() end)
    toggleButton:SetPoint("TOPLEFT", actionsHeader, "BOTTOMLEFT", 0, -8)
    local reportButton = CreateButton(page, L["Debug report"], 140, function() ns.ShowReport() end)
    reportButton:SetPoint("LEFT", toggleButton, "RIGHT", 8, 0)
    local statsButton = CreateButton(page, L["Open statistics"], 140, function() ns.StatsFrame.Toggle() end)
    statsButton:SetPoint("LEFT", reportButton, "RIGHT", 8, 0)
    local resetButton = CreateButton(page, L["Reset indicator position"], 190, function()
        ns.Indicator.ResetPosition()
    end)
    resetButton:SetPoint("TOPLEFT", toggleButton, "BOTTOMLEFT", 0, -6)
    local scanButton = CreateButton(page, L["Scan auction prices"], 160, function() ns.Auction.Scan() end)
    scanButton:SetPoint("LEFT", resetButton, "RIGHT", 8, 0)
    local scanHint = CreateText(page, "GameFontDisableSmall", L["(open the auction house first)"])
    scanHint:SetPoint("LEFT", scanButton, "RIGHT", 8, 0)
    local function UpdateScanButton()
        local usable = ns.Auction.CanScan()
        scanButton:SetEnabled(usable)
        scanHint:SetShown(not ns.Auction.IsOpen())
    end
    ns.On("AUCTION_STATE", UpdateScanButton)

    page:SetScript("OnShow", function()
        UpdateScanButton()
        cameraValue:SetText(ns.db.settings.cameraDistance)
        keys:SetText((L["Fishing action: %s      Toggle fishing mode: %s"]):format(
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
    row.remove = CreateButton(row, L["Remove"], 80, function() ns.Gear.RemoveItem(row.itemID) end)
    row.remove:SetPoint("RIGHT")

    row:SetScript("OnEnter", function(self) ShowItemTooltip(self, self.itemID) end)
    row:SetScript("OnLeave", function() GameTooltip:Hide() end)
    return row
end

local function CreateGearPage()
    local page = CreateFrame("Frame")

    local title = CreateText(page, "GameFontNormalLarge", L["Fishing gear"])
    title:SetPoint("TOPLEFT", PADDING, -PADDING)

    -- Pole
    local poleHeader = CreateText(page, "GameFontNormal", L["Fishing pole"])
    poleHeader:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -18)
    local poleText = CreateText(page, "GameFontHighlight")
    poleText:SetPoint("TOPLEFT", poleHeader, "BOTTOMLEFT", 0, -6)
    poleText:SetWidth(520)
    local autoPoleButton = CreateButton(page, L["Use the best pole automatically"], 240, function()
        ns.Gear.ClearPole()
    end)
    autoPoleButton:SetPoint("TOPLEFT", poleText, "BOTTOMLEFT", 0, -6)

    -- Add box
    local addHeader = CreateText(page, "GameFontNormal", L["Add an item"])
    addHeader:SetPoint("TOPLEFT", autoPoleButton, "BOTTOMLEFT", 0, -18)
    local addHint = CreateText(page, "GameFontDisableSmall",
        L["Easiest: close this window and Alt+Click an item in your bags or on the character panel."] .. "\n" ..
        L["Alt+Click it again to remove it. A fishing pole becomes your chosen pole."] .. "\n" ..
        L["Here you can type an item name, or find all items with a fishing bonus automatically."])
    addHint:SetPoint("TOPLEFT", addHeader, "BOTTOMLEFT", 0, -4)

    local input = CreateFrame("EditBox", nil, page, "InputBoxTemplate")
    input:SetSize(320, 22)
    input:SetAutoFocus(false)
    input:SetPoint("TOPLEFT", addHint, "BOTTOMLEFT", 6, -8)
    local status = CreateText(page, "GameFontHighlightSmall")

    local function AddItem(itemID)
        if not itemID then
            status:SetText("|cffff5555" .. L["Item not found. Check the name, or Alt+Click the item in your bags."]
                .. "|r")
            return
        end
        local ok, message = ns.Gear.AddItem(itemID)
        status:SetText((ok and "|cff55ff55%s|r" or "|cffff5555%s|r"):format(message))
        if ok then
            input:SetText("")
            input:ClearFocus()
        end
    end

    local addButton = CreateButton(page, L["Add"], 80, function() AddItem(ns.ParseItem(input:GetText())) end)
    addButton:SetPoint("LEFT", input, "RIGHT", 8, 0)
    local findButton = CreateButton(page, L["Find fishing items"], 150, function()
        local added = ns.Gear.AddFishingItemsFromBags()
        status:SetText(added > 0 and ("|cff55ff55" .. L["Added %d item(s)."]:format(added) .. "|r")
            or ("|cffff5555" .. L["No new items with a fishing bonus found."] .. "|r"))
    end)
    findButton:SetPoint("LEFT", addButton, "RIGHT", 8, 0)
    status:SetPoint("TOPLEFT", input, "BOTTOMLEFT", -6, -6)

    input:SetScript("OnEnterPressed", function(self) AddItem(ns.ParseItem(self:GetText())) end)
    input:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)

    -- List
    local listHeader = CreateText(page, "GameFontNormal", L["Extra fishing gear"])
    listHeader:SetPoint("TOPLEFT", status, "BOTTOMLEFT", 0, -16)
    local emptyText = CreateText(page, "GameFontDisable", L["No items yet."])
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
            poleText:SetText((L["Chosen: %s (+%d)"]):format(link, ns.GetFishingBonus(chosen)))
            autoPoleButton:Show()
        else
            local best, bonus = ns.Gear.FindBestPole()
            poleText:SetText(best and (L["Automatic, best in your bags: %s (+%d)"]):format(ItemDisplay(best), bonus)
                or L["Automatic: no fishing pole in your bags."])
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
        ns.Print(L["Settings cannot be opened in combat."])
        return
    end
    Settings.OpenToCategory(mainCategory:GetID())
end

ns.RegisterEvent("PLAYER_LOGIN", function()
    if not (Settings and Settings.RegisterCanvasLayoutCategory) then
        ns.Print(L["Settings panel is not available in this client."])
        return
    end
    mainCategory = Settings.RegisterCanvasLayoutCategory(CreateMainPage(), "OneKeyFishing")
    Settings.RegisterCanvasLayoutSubcategory(mainCategory, CreateGearPage(), L["Fishing gear"])
    Settings.RegisterAddOnCategory(mainCategory)
end)

ns.RegisterCommand("config", L["open the settings"], SettingsUI.Open)
