-- Widgets: the frame helpers shared by the windows and pages of UI/: the panel button that grows to its text,
-- font strings, an item's link and icon, the item tooltip with the auction price, radio and checkbox menus, the
-- skill range label and the auction scan button's state, and what the addon's windows share.
local _, ns = ...

-- What every window of the addon shares (the statistics window, the copy window): its global name, Escape, the
-- strata, dragging, the close button and how it stacks with the other windows.
function ns.SetupWindow(frame, globalName)
    _G[globalName] = frame
    table.insert(UISpecialFrames, globalName) -- close on Escape
    -- Below the game's popups (StaticPopup: DIALOG, top-level), which the windows open (the reset questions, the
    -- map pin) and which a click on a top-level window of their strata would cover; HIGH is the Settings panel's.
    frame:SetFrameStrata("HIGH")
    -- A click raises the window with its children: without it two windows of one strata draw through each other.
    frame:SetToplevel(true)
    frame:SetMovable(true)
    frame:SetClampedToScreen(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)

    -- The window template brings a close button; a frame built without the template gets one.
    local close = frame.CloseButton
    if not close then
        close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
        close:SetPoint("TOPRIGHT", -4, -4)
    end
    -- The game's own script hides through HideUIPanel, which refuses addon code in combat without an error (the
    -- button then does nothing; seen in game 2026-11-18). Hiding the frame directly is allowed in a fight.
    close:SetScript("OnClick", function() frame:Hide() end)
end

-- Widens a button to its text when the text is wider than the button's own width (translations are often
-- longer than English). Buttons of ns.CreateButton do it on every SetText.
local function FitButton(button)
    local fontString = button:GetFontString()
    -- GetStringWidth can stop at the width the button already has; the unbounded width is the full text.
    local textWidth = fontString and (fontString.GetUnboundedStringWidth and fontString:GetUnboundedStringWidth()
        or fontString:GetStringWidth())
    if textWidth and textWidth + 16 > button.minWidth then
        button:SetWidth(textWidth + 24)
    else
        button:SetWidth(button.minWidth)
    end
end

-- A standard UI panel button; shared by the settings and statistics windows. `width` is the minimum width; the
-- button grows to its text whenever the text changes.
function ns.CreateButton(parent, text, width, onClick)
    local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    button:SetHeight(22)
    button.minWidth = width
    local setText = button.SetText
    function button:SetText(newText)
        setText(self, newText)
        FitButton(self)
    end
    button:SetText(text)
    button:SetScript("OnClick", onClick)
    return button
end

-- A font string with the game's font object `template` (it picks a font for the text's script).
function ns.CreateText(parent, template, justify)
    local fontString = parent:CreateFontString(nil, "OVERLAY", template)
    fontString:SetJustifyH(justify or "LEFT")
    return fontString
end

-- An item's link (or name, or "item:<id>" until the client knows it) and icon.
function ns.ItemDisplay(itemID)
    local name, link, _, _, _, _, _, _, _, icon = C_Item.GetItemInfo(itemID)
    return link or name or ("item:" .. itemID), icon or C_Item.GetItemIconByID(itemID)
end

-- The colour of the addon's own lines in item tooltips ("Caught in:", the camp bonus tag; UI/ItemHooks.lua).
ns.TOOLTIP_COLOR = { 0.2, 0.8, 1 }

-- A tooltip line with its colour both as a code in the text and in the arguments (ns.ColoredText, Core/Data.lua), so
-- a reset of the tooltip's line colours leaves it coloured.
function ns.AddColoredLine(tooltip, text, r, g, b, wrap)
    tooltip:AddLine(ns.ColoredText(text, r, g, b), r, g, b, wrap)
end

-- The camp bonus tag of a row (specs/020-camp-buffs research R19): the camp feature's icon at the right end of the
-- row's name column, whose right edge is at x; the name keeps the rest of the column. Both tabs' rows use it.
local TAG_SIZE = 14

function ns.CreateTagIcon(row, x)
    local tag = row:CreateTexture(nil, "OVERLAY")
    tag:SetSize(TAG_SIZE, TAG_SIZE)
    tag:SetPoint("LEFT", x - TAG_SIZE, 0)
    tag:Hide()
    return tag
end

-- Shows the tag's icon for a bonus (or hides it) and gives the name the column's `width` minus the icon.
function ns.ShowTag(tag, name, width, bonus)
    local icon = bonus and ns.Catalog.BonusIcon(bonus.key)
    if icon then
        tag:SetTexture(icon)
        tag:Show()
        name:SetWidth(width - TAG_SIZE)
    else
        tag:Hide()
        name:SetWidth(width)
    end
end

-- The camp bonus lines of a row's tooltip: the tag's name, its explanation and, unless the tag is plain, the chance
-- with the bonus and its players; whatever settings.tooltipChances says.

function ns.AddBonusLines(tooltip, bonus)
    if not bonus then
        return
    end
    local Catalog = ns.Catalog
    local r, g, b = unpack(ns.TOOLTIP_COLOR)
    ns.AddColoredLine(tooltip, Catalog.BonusTag(bonus.key), r, g, b)
    tooltip:AddLine(Catalog.BonusTip(bonus.key, bonus.several), 1, 1, 1, true)
    if not bonus.plain then
        tooltip:AddLine(Catalog.ChanceText(bonus.chance, bonus.littleData, bonus.players, true), 1, 1, 1)
    end
end

-- { owner, itemID } of the item tooltip ShowItemTooltip drew with its camp bonus lines, or nil: the game's item hook
-- (UI/ItemHooks.lua) then adds no second explanation line. Set on every call, after SetOwner and before SetItemByID
-- (the game runs the item hook inside SetItemByID); cleared when the tooltip hides.
local kept

-- The item tooltip of a row; withPrice adds the addon's auction price (Prices.AddTooltipLine); bonus (an item's camp
-- bonus table, spec 020) adds the tag's lines after the item's own.
function ns.ShowItemTooltip(owner, itemID, withPrice, bonus)
    if not itemID then
        return -- an empty row: the game's tooltip refuses a nil item
    end
    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    kept = bonus and { owner = owner, itemID = itemID } or nil
    GameTooltip:SetItemByID(itemID)
    if withPrice then
        ns.Prices.AddTooltipLine(GameTooltip, itemID)
    end
    ns.AddBonusLines(GameTooltip, bonus)
    GameTooltip:Show()
end

-- Whether the tooltip is the one ShowItemTooltip drew for this item with its camp bonus lines.
function ns.TooltipHasBonus(tooltip, itemID)
    return kept ~= nil and tooltip == GameTooltip and tooltip:GetOwner() == kept.owner and kept.itemID == itemID
end

if GameTooltip and GameTooltip.HookScript then
    GameTooltip:HookScript("OnHide", function()
        kept = nil
    end)
end

---------------------------------------------------------------------------
-- Lists of the statistics window's tabs ("What can be caught here", the catalog): the game's scroll list, or a fixed
-- pool of rows with "and N more" when the client lacks the templates
---------------------------------------------------------------------------
local LIST_X, LIST_LINE, LIST_ROW_WIDTH = 20, 18, 520
local LIST_BOTTOM = 40 -- the lists end above the window's bottom edge
local LIST_WINDOW_HEIGHT = 736 -- the height the fallback rows are counted for: the statistics window's (StatsFrame)
local LIST_MAX_ROWS = 26 -- rows of the fixed list when the scroll templates are missing

-- initialize(row, element) draws an element on a row (made by the list, built on first use); list.Show(elements,
-- retain) shows them, retain keeping the scroll position.
function ns.CreateList(parent, top, initialize)
    local list = { initialize = initialize }
    -- The scroll list, the scroll bar and the search box render inside the statistics window (V37, seen in game)
    local ok = pcall(function()
        local box = CreateFrame("Frame", nil, parent, "WowScrollBoxList")
        box:SetPoint("TOPLEFT", LIST_X, top)
        box:SetPoint("BOTTOMRIGHT", -LIST_X - 18, LIST_BOTTOM)
        local bar = CreateFrame("EventFrame", nil, parent, "MinimalScrollBar")
        bar:SetPoint("TOPLEFT", box, "TOPRIGHT", 6, 0)
        bar:SetPoint("BOTTOMLEFT", box, "BOTTOMRIGHT", 6, 0)
        local view = CreateScrollBoxListLinearView()
        view:SetElementExtent(LIST_LINE)
        view:SetElementInitializer("Button", initialize)
        ScrollUtil.InitScrollBoxListWithScrollBar(box, bar, view)
        list.box = box
    end)
    if not ok then
        list.box, list.rows = nil, {}
        local rows = math.min(LIST_MAX_ROWS, math.floor((LIST_WINDOW_HEIGHT + top - LIST_BOTTOM) / LIST_LINE) - 1)
        for i = 1, rows do
            local row = CreateFrame("Button", nil, parent)
            row:SetSize(LIST_ROW_WIDTH, LIST_LINE)
            row:SetPoint("TOPLEFT", LIST_X, top - (i - 1) * LIST_LINE)
            list.rows[i] = row
        end
        list.more = ns.CreateText(parent, "GameFontDisableSmall")
        list.more:SetPoint("TOPLEFT", LIST_X, top - rows * LIST_LINE - 2)
    end
    -- Shows the elements; retain keeps the scroll position (new data, FR-028).
    function list.Show(elements, retain)
        if list.box then
            list.box:SetDataProvider(CreateDataProvider(elements), retain and true or nil)
            return
        end
        -- A kind header (spec 014) never takes the last row: it needs room for one of its items, as in CatchHere.
        local last = #list.rows
        if elements[last] and elements[last].header then
            last = last - 1
        end
        for i, row in ipairs(list.rows) do
            if i <= last and elements[i] then
                list.initialize(row, elements[i])
                row:Show()
            else
                row:Hide()
            end
        end
        -- "and N more" counts the elements left out, kind headers not.
        local more = 0
        for i = last + 1, #elements do
            if not elements[i].header then
                more = more + 1
            end
        end
        list.more:SetText(more > 0 and (ns.L["and %d more"]):format(more) or "")
    end
    return list
end

local CHECK_MARK = "|TInterface\\Buttons\\UI-CheckBox-Check:0|t "

-- A menu of choices ({ value, text }) built with the game's element `method` ("CreateRadio" or "CreateCheckbox"):
-- isMarked(value) marks a choice, onClick(value) runs on a click. Without that element: buttons with the check mark.
local function OpenMarkedMenu(owner, choices, isMarked, onClick, method)
    if not (MenuUtil and MenuUtil.CreateContextMenu) then
        return
    end
    MenuUtil.CreateContextMenu(owner, function(_, root)
        for _, choice in ipairs(choices) do
            local function IsMarked() return isMarked(choice.value) end
            local function Click() onClick(choice.value) end
            if root[method] then
                root[method](root, choice.text, IsMarked, Click)
            else
                root:CreateButton((IsMarked() and CHECK_MARK or "") .. choice.text, Click)
            end
        end
    end)
end

-- A menu of choices with the selected one marked; choose(value) runs on a click.
function ns.OpenRadioMenu(owner, choices, isSelected, choose)
    OpenMarkedMenu(owner, choices, isSelected, choose, "CreateRadio")
end

-- A menu of checkboxes; toggle(value) runs on a click. The game's checkbox keeps the menu open and redraws its marks
-- (MenuResponse.Refresh in Blizzard_Menu/MenuTemplates.lua); the fallback buttons close it after a click
-- (specs/014-catch-filters, research R6).
function ns.OpenCheckboxMenu(owner, choices, isChecked, toggle)
    OpenMarkedMenu(owner, choices, isChecked, toggle, "CreateCheckbox")
end

-- Every key bound to a binding, readable, joined with " / " (players bind a punctuation key once per keyboard
-- layout, so two keys are common). The order is the game's (GetBindingKey), as in its Keybindings columns; the game
-- may swap the two on a reload. It is the same wherever the keys are shown. `short` asks the game for the short key
-- names (small labels); `unbound` is the text without a key, the red "not bound" by default; `separator`
-- joins two keys, " / " by default.
function ns.KeyText(binding, short, unbound, separator)
    local texts, seen = {}, {}
    for _, key in ipairs({ GetBindingKey(binding) }) do
        if not seen[key] then
            seen[key] = true
            table.insert(texts, GetBindingText(key, short))
        end
    end
    if #texts == 0 then
        return unbound or ("|cffff5555" .. ns.L["not bound"] .. "|r")
    end
    return table.concat(texts, separator or " / ")
end

-- The skill ranges min to max of CatchDB (whole ranges of RANGE_STEP points; max defaults to min): "0-74",
-- "75-224", "300+", "75+". Real ranges only: the catalog's Skill column and the Skill button's miss range.
function ns.RangeLabel(min, max)
    max = max or min
    local step = ns.CatchDB.RANGE_STEP
    local from = min * step
    if max == ns.CatchDB.MAX_RANGE then
        return from .. "+"
    end
    return from .. "-" .. ((max + 1) * step - 1)
end

-- The skill filter of both tabs (specs/021-cumulative-skill-filter): a value 0 to 3 sums the ranges up to it and
-- reads "up to" the range's top; "all" (300+) sums every range. The misses come from the value's own range.
local function SkillTop(range)
    return (range + 1) * ns.CatchDB.RANGE_STEP - 1
end

local function AllFrom()
    return ns.CatchDB.MAX_RANGE * ns.CatchDB.RANGE_STEP
end

-- The Skill button's text: "Skill: Up to 224", "Skill: All".
function ns.SkillFilterLabel(value)
    if value == "all" then
        return ns.L["Skill: All"]
    end
    return (ns.L["Skill: Up to %d"]):format(SkillTop(value))
end

-- A value's text in the Skill menu, with "(yours)" when it is the own range's value `own` (nil: none).
function ns.SkillMenuText(value, own)
    local L, yours = ns.L, value == own
    if value == "all" then
        return (yours and L["All (%d+) (yours)"] or L["All (%d+)"]):format(AllFrom())
    end
    return (yours and L["Up to %d (yours)"] or L["Up to %d"]):format(SkillTop(value))
end

-- The Skill button's tooltip: what the list sums and the one range its miss rate comes from.
function ns.ShowSkillTooltip(button, value)
    local L = ns.L
    GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
    GameTooltip:AddLine(L["Skill"])
    local all = value == "all"
    local holds = all and L["Catches with any skill."] or (L["Catches with skill up to %d."]):format(SkillTop(value))
    GameTooltip:AddLine(holds, 1, 1, 1, true)
    local miss = all and ns.CatchDB.MAX_RANGE or value
    GameTooltip:AddLine((L["Misses only with skill %s."]):format(ns.RangeLabel(miss)), 1, 1, 1, true)
    GameTooltip:Show()
end

local function ShowReason(button)
    if button.reason then
        GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
        GameTooltip:AddLine(button.reason, 1, 1, 1, true)
        GameTooltip:Show()
    end
end

-- Shows button.reason (when set) in the game tooltip on hover, also while the button is disabled. Set up once.
function ns.ShowReasonOnHover(button)
    if button.showsReason then
        return
    end
    button.showsReason = true
    button:SetMotionScriptsWhileDisabled(true)
    button:HookScript("OnEnter", ShowReason)
    button:HookScript("OnLeave", function(self)
        if GameTooltip:GetOwner() == self then
            GameTooltip:Hide()
        end
    end)
end

-- Sets the reason ShowReasonOnHover shows; a tooltip the button owns follows it at once (the state may change
-- while the pointer rests on the button).
function ns.SetReason(button, reason)
    button.reason = reason
    if GameTooltip:GetOwner() == button then
        GameTooltip:Hide()
        ShowReason(button)
    end
end

-- An auction scan button (the statistics window's, the one above the auction window): clickable while a scan can
-- start, the reason it cannot on hover (Auction.WhyNot); hidden while the prices come from Auctionator
-- (specs/019-auctionator-prices).
function ns.UpdateScanButton(button)
    button:SetShown(not ns.Prices.UsesAuctionator())
    ns.ShowReasonOnHover(button)
    button:SetEnabled(ns.Auction.CanScan())
    ns.SetReason(button, ns.Auction.WhyNot())
end
