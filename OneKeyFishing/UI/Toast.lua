-- Toast: short messages that rise and fade above the indicator (catches, misses, warnings).
local _, ns = ...
local L = ns.L

local POOL_SIZE = 4
local DURATION = 3
local FADE_TIME = 1
local RISE = 24
local LINE_SPACING = 18

local container = CreateFrame("Frame", nil, UIParent)
container:SetSize(400, 20)
container:SetPoint("BOTTOM", ns.Indicator.frame, "TOP", 0, 10)
container:SetFrameStrata("MEDIUM")

local lines = {}
for i = 1, POOL_SIZE do
    local line = container:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    line:Hide()
    lines[i] = line
end

local function OnUpdate()
    local now, anyShown = GetTime(), false
    for _, line in ipairs(lines) do
        if line:IsShown() then
            local elapsed = now - line.start
            if elapsed >= DURATION then
                line:Hide()
            else
                anyShown = true
                line:SetPoint("BOTTOM", container, "BOTTOM", 0, line.offset + RISE * elapsed / DURATION)
                line:SetAlpha(math.min(1, (DURATION - elapsed) / FADE_TIME))
            end
        end
    end
    if not anyShown then
        container:SetScript("OnUpdate", nil)
    end
end

function ns.Toast(text, r, g, b)
    if not ns.db.settings.toasts then
        return
    end
    -- Reuse a free line, or the oldest one; push the visible ones up.
    local target
    for _, line in ipairs(lines) do
        if not line:IsShown() then
            target = target or line
        else
            line.offset = line.offset + LINE_SPACING
        end
    end
    if not target then
        target = lines[1]
        for _, line in ipairs(lines) do
            if line.start < target.start then
                target = line
            end
        end
    end
    target:SetText(text)
    target:SetTextColor(r or 1, g or 0.82, b or 0)
    target.start = GetTime()
    target.offset = 0
    target:SetAlpha(1)
    target:Show()
    container:SetScript("OnUpdate", OnUpdate)
end

ns.On("FISH_CAUGHT", function(items)
    local parts = {}
    for _, item in ipairs(items) do
        table.insert(parts, item.quantity > 1 and ("%s x%d"):format(item.link, item.quantity) or item.link)
    end
    if #parts > 0 then
        ns.Toast(L["Caught: %s"]:format(table.concat(parts, ", ")), 1, 1, 1)
    end
end)

ns.On("FISH_MISSED", function()
    ns.Toast(L["Nothing caught"], 1, 0.4, 0.4)
end)
