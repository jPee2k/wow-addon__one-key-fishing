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

-- `always`: show it even with catch notifications off (an answer to the player's own click, the rank reminders,
-- which have their own setting).
function ns.Toast(text, r, g, b, always)
    if not (always or ns.db.settings.toasts) then
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

-- A trophy new to the account (spec 023): CatchDB settles the cast first (TOC order), so ITEM_FIRST_CAUGHT of a cast
-- comes before this module's FISH_CAUGHT of it. The trophy gets its own loud notice in place of the catch line.
local firstTrophies, firstCast = {}, nil

ns.On("ITEM_FIRST_CAUGHT", function(itemID, castID)
    if ns.Catalog.ItemKind(itemID) == "trophies" then
        if firstCast ~= castID then
            firstTrophies, firstCast = {}, castID
        end
        firstTrophies[itemID] = true
    end
end)

ns.On("FISH_CAUGHT", function(items, castID)
    local trophies = firstCast == castID and firstTrophies or {}
    firstTrophies, firstCast = {}, nil
    local parts, new = {}, {}
    for _, item in ipairs(items) do
        if trophies[item.itemID] == true then
            trophies[item.itemID] = "shown" -- one notice for a trophy in two loot slots
            table.insert(new, item.link)
        elseif not trophies[item.itemID] then
            table.insert(parts, item.quantity > 1 and ("%s x%d"):format(item.link, item.quantity) or item.link)
        end
    end
    if #parts > 0 then
        ns.Toast(L["Caught: %s"]:format(table.concat(parts, ", ")), 1, 1, 1)
    end
    if #new > 0 then
        -- The count already holds every new trophy of the cast: each notice shows the count after its own catch.
        local caught, total = ns.Catalog.TrophyCount()
        for index, link in ipairs(new) do
            ns.Toast(L["New trophy: %s (%d/%d)"]:format(link, caught - #new + index, total), 1, 0.82, 0, true)
        end
    end
end)

ns.On("FISH_MISSED", function()
    ns.Toast(L["Nothing caught"], 1, 0.4, 0.4)
end)

-- The next-rank notices of Fishing/Skill.lua: loud is the cap (orange), else "can learn" (yellow). They have their
-- own setting, so they show with catch notifications off.
ns.On("SKILL_WARNING", function(text, loud)
    if loud then
        ns.Toast(text, 1, 0.55, 0.1, true)
    else
        ns.Toast(text, 1, 0.82, 0, true)
    end
end)

-- A camp bonus ends in 5 minutes or has ended (Fishing/Camp.lua, spec 020): shown like a quiet next-rank notice,
-- also with catch notifications off.
ns.On("CAMP_BONUS_WARNING", function(text)
    ns.Toast(text, 1, 0.82, 0, true)
end)

-- Core/MapPin.lua set the game's map pin at placeName, or the game refused it (nil): the answer to a click.
ns.On("MAP_PIN_SET", function(placeName)
    if placeName then
        ns.Toast((L["Map pin: %s. Open the world map to see it."]):format(placeName), 1, 1, 1, true)
    else
        ns.Toast(L["The game did not accept the map pin."], 1, 0.4, 0.4, true)
    end
end)
