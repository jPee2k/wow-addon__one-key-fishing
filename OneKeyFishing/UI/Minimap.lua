-- Minimap: a draggable minimap button and the Addon Compartment entry.
--   Left-click: toggle fishing mode     Shift+Left-click: statistics     Right-click: menu with every action
local _, ns = ...
local L = ns.L

local Minimap_ = {}
ns.Minimap = Minimap_

local ICON = "Interface\\Icons\\Trade_Fishing"

local button

local function OpenMenu(owner)
    if not (MenuUtil and MenuUtil.CreateContextMenu) then
        ns.SettingsUI.Open()
        return
    end
    MenuUtil.CreateContextMenu(owner, function(_, root)
        root:CreateTitle("OneKeyFishing")
        root:CreateButton(ns.Mode.IsActive() and L["Leave fishing mode"] or L["Enter fishing mode"], ns.Mode.Toggle)
        root:CreateButton(L["Statistics"], ns.StatsFrame.Toggle)
        root:CreateButton(L["Settings"], ns.SettingsUI.Open)
        local scan = root:CreateButton(L["Scan auction prices"], ns.Auction.Scan)
        if not ns.Auction.IsOpen() then
            scan:SetEnabled(false)
        end
        root:CreateButton(L["Reset indicator position"], ns.Indicator.ResetPosition)
        root:CreateButton(L["Debug report"], ns.ShowReport)
    end)
end

local function KeyText(binding)
    local key = GetBindingKey(binding)
    return key and GetBindingText(key) or ("|cffff5555" .. L["not bound"] .. "|r")
end

local function ShowTooltip(owner)
    GameTooltip:SetOwner(owner, "ANCHOR_LEFT")
    GameTooltip:AddDoubleLine("OneKeyFishing", ns.version, nil, nil, nil, 0.6, 0.6, 0.6)
    local state = ns.Mode.IsActive() and ("|cff55ff55" .. L["ON"] .. "|r") or ("|cffaaaaaa" .. L["OFF"] .. "|r")
    GameTooltip:AddLine(L["Fishing mode: %s"]:format(state), 1, 1, 1)
    local rank, maxRank = ns.Skill.Get()
    if rank then
        local text = L["Fishing skill: %d/%d %s"]:format(rank, maxRank, ns.Skill.GetRankName(maxRank))
        GameTooltip:AddLine(text, 1, 1, 1)
    end
    local session = ns.Stats.GetSession()
    if session then
        GameTooltip:AddLine((L["Session: %d catches, %s"]):format(session.catches,
            ns.Stats.FormatTime(ns.Stats.GetSessionTime())), 1, 1, 1)
    end
    GameTooltip:AddLine(" ")
    GameTooltip:AddDoubleLine(L["Fishing key:"], KeyText("ONEKEYFISHING_ACTION"), 1, 0.82, 0, 1, 1, 1)
    GameTooltip:AddDoubleLine(L["Toggle mode key:"], KeyText("ONEKEYFISHING_TOGGLE"), 1, 0.82, 0, 1, 1, 1)
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine(L["How to use: press the toggle key, then the fishing key to cast,"], 0.8, 0.8, 0.8)
    GameTooltip:AddLine(L["and the same key again when the bobber splashes."], 0.8, 0.8, 0.8)
    GameTooltip:AddLine(L["Alt+Click items in your bags to add fishing gear."], 0.8, 0.8, 0.8)
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine(L["Left-click: toggle fishing mode"], 0, 1, 0)
    GameTooltip:AddLine(L["Shift+Left-click: statistics"], 0, 1, 0)
    GameTooltip:AddLine(L["Right-click: menu"], 0, 1, 0)
    if owner == button then
        GameTooltip:AddLine(L["Drag: move this button"], 0, 1, 0)
    end
    GameTooltip:Show()
end

local function OnClick(owner, mouseButton)
    if mouseButton == "RightButton" then
        OpenMenu(owner)
    elseif IsShiftKeyDown() then
        ns.StatsFrame.Toggle()
    else
        ns.Mode.Toggle()
    end
end

---------------------------------------------------------------------------
-- Minimap button
---------------------------------------------------------------------------
local function UpdatePosition()
    local angle = math.rad(ns.db.minimapAngle)
    local radius = Minimap:GetWidth() / 2 + 5
    button:ClearAllPoints()
    button:SetPoint("CENTER", Minimap, "CENTER", math.cos(angle) * radius, math.sin(angle) * radius)
end

local function OnDragUpdate()
    local centerX, centerY = Minimap:GetCenter()
    local cursorX, cursorY = GetCursorPosition()
    local scale = Minimap:GetEffectiveScale()
    ns.db.minimapAngle = math.deg(math.atan2(cursorY / scale - centerY, cursorX / scale - centerX))
    UpdatePosition()
end

local function UpdateIcon()
    if button then
        button.icon:SetDesaturated(not ns.Mode.IsActive())
    end
end

local function CreateButton()
    button = CreateFrame("Button", "OneKeyFishingMinimapButton", Minimap)
    button:SetSize(31, 31)
    button:SetFrameStrata("MEDIUM")
    button:SetFrameLevel(8)
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    button:RegisterForDrag("LeftButton")
    button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

    local background = button:CreateTexture(nil, "BACKGROUND")
    background:SetSize(20, 20)
    background:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
    background:SetPoint("TOPLEFT", 7, -5)

    button.icon = button:CreateTexture(nil, "ARTWORK")
    button.icon:SetSize(17, 17)
    button.icon:SetTexture(ICON)
    button.icon:SetPoint("TOPLEFT", 7, -6)

    local border = button:CreateTexture(nil, "OVERLAY")
    border:SetSize(53, 53)
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    border:SetPoint("TOPLEFT")

    button:SetScript("OnClick", OnClick)
    button:SetScript("OnEnter", ShowTooltip)
    button:SetScript("OnLeave", function() GameTooltip:Hide() end)
    button:SetScript("OnDragStart", function(self)
        GameTooltip:Hide()
        self:SetScript("OnUpdate", OnDragUpdate)
    end)
    button:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)
end

function Minimap_.Update()
    if not ns.db.settings.minimapButton then
        if button then
            button:Hide()
        end
        return
    end
    if not button then
        CreateButton()
    end
    UpdatePosition()
    UpdateIcon()
    button:Show()
end

ns.RegisterEvent("PLAYER_LOGIN", Minimap_.Update)
ns.On("SETTINGS_CHANGED", Minimap_.Update)
ns.On("MODE_CHANGED", UpdateIcon)

---------------------------------------------------------------------------
-- Addon Compartment (the addons button by the minimap), declared in the TOC
---------------------------------------------------------------------------
function OneKeyFishing_OnAddonCompartmentClick(_, mouseButton)
    OnClick(AddonCompartmentFrame, mouseButton)
end

function OneKeyFishing_OnAddonCompartmentEnter(_, menuButtonFrame)
    ShowTooltip(menuButtonFrame or AddonCompartmentFrame)
end

function OneKeyFishing_OnAddonCompartmentLeave()
    GameTooltip:Hide()
end
