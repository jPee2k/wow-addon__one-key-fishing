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

-- The item tooltip of a row; withPrice adds the addon's auction price (Prices.AddTooltipLine).
function ns.ShowItemTooltip(owner, itemID, withPrice)
    if not itemID then
        return -- an empty row: the game's tooltip refuses a nil item
    end
    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    GameTooltip:SetItemByID(itemID)
    if withPrice then
        ns.Prices.AddTooltipLine(GameTooltip, itemID)
    end
    GameTooltip:Show()
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
-- "75-224", "300+", "75+"; "All skill levels" for "all".
function ns.RangeLabel(min, max)
    if min == "all" then
        return ns.L["All skill levels"]
    end
    max = max or min
    local step = ns.CatchDB.RANGE_STEP
    local from = min * step
    if max == ns.CatchDB.MAX_RANGE then
        return from .. "+"
    end
    return from .. "-" .. ((max + 1) * step - 1)
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
