-- UI/Minimap.lua: in Korean and Chinese the tooltip ends with a blank line, because their glyphs are taller than
-- the line height the game measures, and the last line reached below the frame (spec 007, User Story 6).

-- recorded: the text of each line (the left side of a double line); coloured: { text, r, g, b } of every side given
-- a colour; events: "owner", "clear" and "line" in call order.
local recorded, wrapped, coloured, events
GameTooltip = {
    SetOwner = function() recorded, wrapped, coloured, events = {}, {}, {}, { "owner" } end,
    ClearLines = function() table.insert(events, "clear") end,
    AddLine = function(_, text, r, g, b, wrap)
        table.insert(recorded, text)
        table.insert(events, "line")
        if r then
            table.insert(coloured, { text, r, g, b })
        end
        if wrap then
            table.insert(wrapped, text)
        end
    end,
    AddDoubleLine = function(_, left, right, lr, lg, lb, rr, rg, rb)
        table.insert(recorded, left)
        table.insert(events, "line")
        if lr then
            table.insert(coloured, { left, lr, lg, lb })
        end
        if rr then
            table.insert(coloured, { right, rr, rg, rb })
        end
    end,
    Show = function() end,
    Hide = function() end,
}

-- A line's text without its colour codes, as the player reads it.
local function plain(text)
    return (text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""))
end

load_addon()

local CJK = { koKR = true, zhCN = true, zhTW = true }

local function lastLine(code)
    ns.language = code -- the tooltip reads the language in use when it is built
    local button = assert(_G.OneKeyFishingMinimapButton, "the minimap button")
    button.scripts.OnEnter(button)
    return recorded[#recorded]
end

test("one catch in the session line reads '1 catch' (spec 010 US5)", function()
    local getSession, getTime = ns.Stats.GetSession, ns.Stats.GetSessionTime
    ns.Stats.GetSession = function() return { catches = 1 } end
    ns.Stats.GetSessionTime = function() return 0 end
    local button = assert(_G.OneKeyFishingMinimapButton, "the minimap button")
    button.scripts.OnEnter(button)
    local line = (ns.L["Session: 1 catch, %s"]):format(ns.Stats.FormatTime(0))
    local found = false
    for _, text in ipairs(recorded) do
        found = found or plain(text) == line
    end
    assert(found, "the singular session line: " .. line)
    ns.Stats.GetSession = function() return { catches = 3 } end
    button.scripts.OnEnter(button)
    found = false
    for _, text in ipairs(recorded) do
        found = found or plain(text) == (ns.L["Session: %d catches, %s"]):format(3, ns.Stats.FormatTime(0))
    end
    assert(found, "the plural for 3")
    ns.Stats.GetSession, ns.Stats.GetSessionTime = getSession, getTime
end)

test("a blank last line only for Korean and Chinese", function()
    local languages = ns.GetLanguages()
    eq(#languages, 10, "languages")
    for _, language in ipairs(languages) do
        local last = lastLine(language.code)
        if CJK[language.code] and not CJK[CLIENT_LOCALE] then
            eq(last, " ", language.code .. " last line")
        else
            assert(last ~= " ", language.code .. ": no blank last line")
        end
    end
end)

test("a Korean or Chinese client measures its own font: no blank line", function()
    CLIENT_LOCALE = "koKR"
    assert(lastLine("koKR") ~= " ", "koKR on a Korean client")
    assert(lastLine("zhCN") ~= " ", "zhCN on a Korean client")
    CLIENT_LOCALE = nil
end)

-- The Language button's tooltip wraps two sentences. In game (2026-11-05, ruRU client, addon in zhCN) the game
-- counted the wrapped lines with the Latin font and two lines fell below the frame: no wrapping, and the blank line.
local function languageTooltip(code)
    ns.language = code
    for _, frame in ipairs(frames) do
        if frame.scripts.OnEnter and frame.parent == settings_pages["OneKeyFishing"] then
            frame.scripts.OnEnter(frame)
            if recorded and recorded[1] == ns.L["Interface language"] then
                return recorded, wrapped
            end
        end
    end
    error("no Language button tooltip")
end

test("the Language tooltip does not wrap Korean or Chinese on another client, and ends with a blank line", function()
    local lines, wraps = languageTooltip("zhCN")
    eq(#wraps, 0, "wrapped lines")
    eq(lines[#lines], " ", "last line")
    lines, wraps = languageTooltip("deDE")
    eq(#wraps, 2, "German wraps its two sentences")
    assert(lines[#lines] ~= " ", "no blank line in German")
end)

-- Spec 012 US4: once the game reset the line colours of the shared tooltip and every line turned white (2026-11-08);
-- colour codes inside the text survived. So every line given a colour carries it in its text too, and the tooltip is
-- cleared of earlier lines first.
local function Hex(r, g, b)
    return ("%02x%02x%02x"):format(math.floor(r * 255 + 0.5), math.floor(g * 255 + 0.5), math.floor(b * 255 + 0.5))
end

local function CheckColours(where)
    eq(events[1], "owner", where .. ": SetOwner first")
    eq(events[2], "clear", where .. ": ClearLines before the first line")
    assert(#coloured > 10, where .. ": coloured lines recorded")
    for _, entry in ipairs(coloured) do
        local text, r, g, b = entry[1], entry[2], entry[3], entry[4]
        if text ~= " " then
            local code = "|cff" .. Hex(r, g, b)
            eq(text:sub(1, #code):lower(), code, where .. ": colour code of '" .. plain(text) .. "'")
            eq(text:sub(-2), "|r", where .. ": closed '" .. plain(text) .. "'")
        end
    end
end

test("every coloured line of the minimap tooltip carries its colour code", function()
    ns.language = "enUS"
    local button = assert(_G.OneKeyFishingMinimapButton, "the minimap button")
    button.scripts.OnEnter(button)
    CheckColours("minimap button")
end)

test("the addon compartment's tooltip too", function()
    OneKeyFishing_OnAddonCompartmentEnter(nil, nil)
    CheckColours("compartment")
end)
