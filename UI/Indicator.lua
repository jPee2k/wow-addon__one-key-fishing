-- Indicator: shows what the fishing key will do next, plus the remaining cast time while the bobber is out.
local _, ns = ...

local Indicator = {}
ns.Indicator = Indicator

local SIZE = 44
local BAR_WIDTH = 90
local DEFAULT_POSITION = { "CENTER", "CENTER", 0, -180 }
local HOOK_ICON = "Interface\\Icons\\INV_Misc_Fish_02"
local LABELS = {
    cast = "Cast",
    hook = "Hook!",
    lure = "Apply lure",
    open = "Open",
}

local frame = CreateFrame("Frame", "OneKeyFishingIndicator", UIParent, "BackdropTemplate")
Indicator.frame = frame
frame:SetSize(SIZE, SIZE)
frame:SetFrameStrata("MEDIUM")
frame:SetClampedToScreen(true)
frame:SetMovable(true)
frame:RegisterForDrag("LeftButton")
frame:SetBackdrop({ edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 12 })
frame:Hide()

frame.icon = frame:CreateTexture(nil, "ARTWORK")
frame.icon:SetPoint("TOPLEFT", 3, -3)
frame.icon:SetPoint("BOTTOMRIGHT", -3, 3)
frame.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)

frame.key = frame:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmallGray")
frame.key:SetPoint("TOPRIGHT", -4, -4)

frame.label = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
frame.label:SetPoint("TOP", frame, "BOTTOM", 0, -2)

-- The hook state pulses so it is noticeable out of the corner of the eye.
local pulse = frame.icon:CreateAnimationGroup()
pulse:SetLooping("BOUNCE")
local fade = pulse:CreateAnimation("Alpha")
fade:SetFromAlpha(1)
fade:SetToAlpha(0.35)
fade:SetDuration(0.6)

-- Remaining channel time
local bar = CreateFrame("StatusBar", nil, frame)
bar:SetSize(BAR_WIDTH, 8)
bar:SetPoint("TOP", frame.label, "BOTTOM", 0, -3)
bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
bar:SetStatusBarColor(0.2, 0.7, 1)
bar.bg = bar:CreateTexture(nil, "BACKGROUND")
bar.bg:SetAllPoints()
bar.bg:SetColorTexture(0, 0, 0, 0.5)
bar.text = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
bar.text:SetPoint("LEFT", bar, "RIGHT", 4, 0)
bar:Hide()

-- Fishing time of this session, below the cast bar's place.
frame.timer = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
frame.timer:SetPoint("TOP", frame.label, "BOTTOM", 0, -14)

local timerElapsed = 0
frame:SetScript("OnUpdate", function(self, delta)
    timerElapsed = timerElapsed + delta
    if timerElapsed < 1 then
        return
    end
    timerElapsed = 0
    if ns.db.settings.sessionTimer then
        self.timer:SetText(ns.Stats.FormatTime(ns.Stats.GetSessionTime()))
    else
        self.timer:SetText("")
    end
end)

bar:SetScript("OnUpdate", function(self)
    local _, _, _, startMS, endMS = UnitChannelInfo("player")
    if not startMS then
        return
    end
    local remaining = math.max(0, endMS - GetTime() * 1000)
    self:SetMinMaxValues(0, endMS - startMS)
    self:SetValue(remaining)
    self.text:SetFormattedText("%.0f", remaining / 1000)
end)

---------------------------------------------------------------------------
-- State
---------------------------------------------------------------------------
local function IdleState()
    local kind, arg1, arg2 = ns.Action.Resolve()
    if kind == "lure" then
        return kind, C_Item.GetItemIconByID(arg1)
    elseif kind == "open" then
        local info = C_Container.GetContainerItemInfo(arg1, arg2)
        return kind, info and info.iconFileID
    end
    return "cast", C_Spell.GetSpellTexture(ns.GetFishingSpellID() or ns.FISHING_SPELL_IDS[1])
end

local function KeyText()
    local key = GetBindingKey("ONEKEYFISHING_ACTION")
    return key and GetBindingText(key, true) or ""
end

function Indicator.Update()
    if not (ns.Mode.IsActive() and ns.db.settings.indicator) then
        pulse:Stop()
        frame:Hide()
        return
    end
    local kind, icon
    if ns.Action.IsChanneling() then
        kind, icon = "hook", HOOK_ICON
    else
        kind, icon = IdleState()
    end
    frame.icon:SetTexture(icon)
    if kind == "hook" and not ns.IsBobberTargeted() then
        -- The key would interact with something else (or nothing): warn instead of "Hook!".
        frame.label:SetText("|cffff4444No bobber|r")
    else
        frame.label:SetText(LABELS[kind])
    end
    frame.key:SetText(KeyText())
    if kind == "hook" then
        if not pulse:IsPlaying() then
            pulse:Play()
        end
        bar:Show()
    else
        pulse:Stop()
        frame.icon:SetAlpha(1)
        bar:Hide()
    end
    frame:Show()
end

---------------------------------------------------------------------------
-- Position and locking
---------------------------------------------------------------------------
local function ApplyPosition()
    local position = ns.db.indicatorPos or DEFAULT_POSITION
    frame:ClearAllPoints()
    frame:SetPoint(position[1], UIParent, position[2], position[3], position[4])
end

local function ApplyLock()
    frame:EnableMouse(not ns.db.settings.lockIndicator)
end

function Indicator.ResetPosition()
    ns.db.indicatorPos = nil
    ApplyPosition()
end

frame:SetScript("OnDragStart", frame.StartMoving)
frame:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local point, _, relativePoint, x, y = self:GetPoint()
    ns.db.indicatorPos = { point, relativePoint, x, y }
end)
frame:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:AddLine("OneKeyFishing")
    GameTooltip:AddLine("Drag to move. Lock it in the settings.", 1, 1, 1)
    GameTooltip:Show()
end)
frame:SetScript("OnLeave", function() GameTooltip:Hide() end)

ns.RegisterEvent("PLAYER_LOGIN", function()
    ApplyPosition()
    ApplyLock()
end)

ns.On("SETTINGS_CHANGED", function()
    ApplyLock()
    Indicator.Update()
end)
ns.On("MODE_CHANGED", Indicator.Update)
ns.On("ACTION_STATE", Indicator.Update)
ns.RegisterEvent("BAG_UPDATE_DELAYED", Indicator.Update)
-- The next action depends on the loot window: no container is opened over it.
ns.RegisterEvent("LOOT_READY", Indicator.Update)
ns.RegisterEvent("LOOT_CLOSED", function()
    Indicator.Update()
    C_Timer.After(1.2, Indicator.Update) -- after Bags.lua decides about a container left with loot
end)
ns.RegisterEvent("PLAYER_EQUIPMENT_CHANGED", Indicator.Update)
ns.RegisterEvent("UPDATE_BINDINGS", Indicator.Update)
ns.RegisterEvent("PLAYER_SOFT_INTERACT_CHANGED", Indicator.Update)
ns.RegisterEvent("UNIT_INVENTORY_CHANGED", function(_, unit)
    -- Also fires when a lure is applied to the pole.
    if unit == "player" then
        Indicator.Update()
    end
end)
