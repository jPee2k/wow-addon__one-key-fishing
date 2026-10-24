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

-- Built when the page is created: the labels need the language, which is set after the files load.
local function Toggles()
    return {
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
end

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
    -- Translations can be longer: the label wraps inside its column, from the top of the checkbox down.
    text:SetPoint("TOPLEFT", checkbox, "TOPRIGHT", 4, -7)
    text:SetWidth(COLUMN_OFFSET - 40)
    checkbox.label = text
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
-- Language
---------------------------------------------------------------------------
local RELOAD_POPUP = "ONEKEYFISHING_RELOAD_LANGUAGE"
local CHECK_MARK = "|TInterface\\Buttons\\UI-CheckBox-Check:0|t "

-- The stored preference as the menu sees it: a code that is not shipped (any more) counts as "auto".
local function SelectedLanguage()
    local preference = ns.db.settings.language
    return ns.translations[preference] and preference or "auto"
end

-- The text of the language button: a language by its own name, else the client's language.
function SettingsUI.LanguageLabel(value)
    local translation = value ~= "auto" and ns.translations[value]
    return translation and translation.name or L["Game client language"]
end

-- Saves the preference ("auto" or a language code). The new language shows after a reload, which only the
-- player's click on "Reload now" starts.
function SettingsUI.ChooseLanguage(value)
    if value == ns.db.settings.language or (value ~= "auto" and not ns.translations[value]) then
        return
    end
    ns.db.settings.language = value
    -- No reload when the interface would come back in the language it already has (e.g. "Deutsch" picked on
    -- a German client that follows the client language); a reload offered for an earlier choice is withdrawn.
    if ns.ResolveLanguage(value, GetLocale()) == ns.language then
        StaticPopup_Hide(RELOAD_POPUP)
        return
    end
    ns.ShowPopup(RELOAD_POPUP, L["The language changes after reloading the interface."], function() ReloadUI() end,
        L["Reload now"], L["Later"])
end

-- "Game client language" first, then every shipped language by its own name.
local function LanguageChoices()
    local choices = { { value = "auto", text = L["Game client language"] } }
    for _, language in ipairs(ns.GetLanguages()) do
        table.insert(choices, { value = language.code, text = language.name })
    end
    return choices
end

local function OpenLanguageMenu(owner, onChosen)
    local function Choose(value)
        SettingsUI.ChooseLanguage(value)
        onChosen()
    end
    local choices = LanguageChoices()
    if not (MenuUtil and MenuUtil.CreateContextMenu) then
        return
    end
    MenuUtil.CreateContextMenu(owner, function(_, root)
        for _, choice in ipairs(choices) do
            local function IsSelected() return SelectedLanguage() == choice.value end
            local function Select() Choose(choice.value) end
            if root.CreateRadio then
                root:CreateRadio(choice.text, IsSelected, Select)
            else
                root:CreateButton((IsSelected() and CHECK_MARK or "") .. choice.text, Select)
            end
        end
    end)
end

local function ShowLanguageTooltip(owner)
    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    GameTooltip:AddLine(L["Interface language"])
    GameTooltip:AddLine(L["Korean and Chinese may show as squares on a game client in another language."],
        1, 1, 1, true)
    GameTooltip:AddLine(L["Pick English to get a readable interface back."], 1, 1, 1, true)
    GameTooltip:Show()
end

-- "Language: [button]" in the top right corner of the main page; returns a function that updates the button.
local function CreateLanguageControl(page)
    local button
    local function Update()
        button:SetText(SettingsUI.LanguageLabel(SelectedLanguage()))
        ns.FitButton(button)
    end
    button = CreateButton(page, "", 160, function(self) OpenLanguageMenu(self, Update) end)
    button:SetPoint("TOPRIGHT", -PADDING, -PADDING + 4)
    button:SetScript("OnEnter", ShowLanguageTooltip)
    button:SetScript("OnLeave", function() GameTooltip:Hide() end)
    local label = CreateText(page, "GameFontHighlight", L["Language:"])
    label:SetPoint("RIGHT", button, "LEFT", -8, 0)
    return Update
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
    local UpdateLanguage = CreateLanguageControl(page)

    local keysHeader = CreateText(page, "GameFontNormal", L["Keys"])
    keysHeader:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -18)
    local keys = CreateText(page, "GameFontHighlight")
    keys:SetPoint("TOPLEFT", keysHeader, "BOTTOMLEFT", 0, -6)
    local keysHint = CreateText(page, "GameFontDisableSmall",
        L["Change them in Options -> Keybindings -> AddOns -> OneKeyFishing."])
    keysHint:SetPoint("TOPLEFT", keys, "BOTTOMLEFT", 0, -4)
    keysHint:SetWidth(560)
    -- WoW behaviour: punctuation keys are named by the character the current Windows layout types.
    local layoutHint = CreateText(page, "GameFontDisableSmall",
        L["WoW names punctuation keys (' ; [ , .) by keyboard language: bind them in both slots, once per language."])
    layoutHint:SetPoint("TOPLEFT", keysHint, "BOTTOMLEFT", 0, -2)
    layoutHint:SetWidth(560)

    local featuresHeader = CreateText(page, "GameFontNormal", L["Features"])
    featuresHeader:SetPoint("TOPLEFT", layoutHint, "BOTTOMLEFT", 0, -18)
    -- Two columns so the page fits without scrolling.
    local toggles = Toggles()
    local perColumn = math.ceil(#toggles / 2)
    local checkboxes = {}
    for i, toggle in ipairs(toggles) do
        checkboxes[i] = CreateCheckbox(page, toggle.label,
            function() return ns.db.settings[toggle.key] end,
            function(value)
                ns.db.settings[toggle.key] = value
                ns.Fire("SETTINGS_CHANGED", toggle.key)
            end)
    end
    local note = CreateText(page, "GameFontDisableSmall",
        L["Auto loot, bobber icon and gear changes apply the next time you enter fishing mode."])
    note:SetWidth(560)
    -- A label that wraps pushes the next checkbox down, and the note goes under the taller column. Laid out
    -- again on every show, because a wrapped label is only measured reliably once the page is shown.
    local function LayoutToggles()
        local bottom = { 0, 0 }
        for i, checkbox in ipairs(checkboxes) do
            local column = i <= perColumn and 1 or 2
            local y = bottom[column] - 4
            checkbox:ClearAllPoints()
            checkbox:SetPoint("TOPLEFT", featuresHeader, "BOTTOMLEFT", (column - 1) * COLUMN_OFFSET - 2, y)
            bottom[column] = y - 26 - math.max(0, (checkbox.label:GetStringHeight() or 0) - 14)
        end
        note:ClearAllPoints()
        note:SetPoint("TOPLEFT", featuresHeader, "BOTTOMLEFT", 0, math.min(bottom[1], bottom[2]) - 6)
    end
    LayoutToggles()

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
    -- Under the buttons, not beside them: translated buttons leave no room on their right.
    local scanHint = CreateText(page, "GameFontDisableSmall", L["(open the auction house first)"])
    scanHint:SetPoint("TOPLEFT", resetButton, "BOTTOMLEFT", 2, -4)
    scanHint:SetWidth(560)
    local function UpdateScanButton()
        local usable = ns.Auction.CanScan()
        scanButton:SetEnabled(usable)
        scanHint:SetShown(not ns.Auction.IsOpen())
    end
    ns.On("AUCTION_STATE", UpdateScanButton)

    page:SetScript("OnShow", function()
        LayoutToggles()
        UpdateScanButton()
        UpdateLanguage()
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
    row.name:SetWordWrap(false)
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
    addHint:SetWidth(560)

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
    status:SetWidth(560)

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

ns.RegisterCommand("config", function() return L["open the settings"] end, SettingsUI.Open)
