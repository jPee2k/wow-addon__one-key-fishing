-- Widgets: the frame helpers shared by the windows and pages of UI/: the panel button that grows to its text,
-- font strings, an item's link and icon, the item tooltip with the auction price, and radio menus.
local _, ns = ...

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

-- The item tooltip of a row; withPrice adds the auction price when it is not used for values (Prices.lua).
function ns.ShowItemTooltip(owner, itemID, withPrice)
    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    GameTooltip:SetItemByID(itemID)
    if withPrice then
        ns.Prices.AddTooltipLine(GameTooltip, itemID)
    end
    GameTooltip:Show()
end

local CHECK_MARK = "|TInterface\\Buttons\\UI-CheckBox-Check:0|t "

-- A menu of choices ({ value, text }) with the selected one marked; choose(value) runs on a click.
function ns.OpenRadioMenu(owner, choices, isSelected, choose)
    if not (MenuUtil and MenuUtil.CreateContextMenu) then
        return
    end
    MenuUtil.CreateContextMenu(owner, function(_, root)
        for _, choice in ipairs(choices) do
            local function IsSelected() return isSelected(choice.value) end
            local function Select() choose(choice.value) end
            if root.CreateRadio then
                root:CreateRadio(choice.text, IsSelected, Select)
            else
                root:CreateButton((IsSelected() and CHECK_MARK or "") .. choice.text, Select)
            end
        end
    end)
end

-- The text of the key bound to an action, or a red "not bound".
function ns.KeyText(binding)
    local key = GetBindingKey(binding)
    return key and GetBindingText(key) or ("|cffff5555" .. ns.L["not bound"] .. "|r")
end
